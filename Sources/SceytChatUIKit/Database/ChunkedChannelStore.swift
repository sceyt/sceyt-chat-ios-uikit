//
//  ChunkedChannelStore.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import CoreData
import Foundation
import SceytChat

/// Stores a batch of server channels on the serial writer (`Database.write`), one chunk per write.
///
/// The serial writer, not `performWriteTask`: each channel's `lastMessage` is stored too, and the
/// chat screen stores the same message on the serial writer. On separate contexts both inserts
/// miss each other; MessageDTO's uniqueness constraint merges the rows, AttachmentDTO has none,
/// and the attachment is drawn twice (ChannelListStoreWriteContextTests).
///
/// Chunked because a 50-channel page takes 210–340 ms on device, and every write queued behind it
/// on the serial writer (a received message, a send ack, a pending send, a chat's message page)
/// waited for all of it. The next chunk is queued only once the previous one finished, so such a
/// write runs between two chunks.
///
/// Chunking means the batch is no longer one commit. To keep that safe:
/// - A channel deleted while the batch is being stored (`DeletedChannelLog`) is skipped, so a
///   later chunk cannot bring it back.
/// - A channel whose stored `updatedAt` is newer than the batch's copy is skipped: an update event
///   stored between two chunks is newer than the batch and must not be overwritten.
/// - A failed chunk does not stop the rest; the first error is reported at the end.
/// - The hops between chunks run on a background queue, so a busy main thread does not delay
///   them; only the final completion goes to `resultQueue`.
enum ChunkedChannelStore {

    static var chunkSize = 10

    private static let hopQueue = DispatchQueue(
        label: "com.sceyt.database.channel-chunks",
        qos: .userInitiated
    )

    static func store(
        _ channels: [Channel],
        database: Database,
        resultQueue: DispatchQueue = .main,
        completion: @escaping (Error?) -> Void
    ) {
        storeChunk(
            channels,
            from: 0,
            startMark: DeletedChannelLog.currentMark(),
            firstError: nil,
            database: database,
            resultQueue: resultQueue,
            completion: completion
        )
    }

    private static func storeChunk(
        _ channels: [Channel],
        from start: Int,
        startMark: UInt64,
        firstError: Error?,
        database: Database,
        resultQueue: DispatchQueue,
        completion: @escaping (Error?) -> Void
    ) {
        guard start < channels.count else {
            resultQueue.async { completion(firstError) }
            return
        }
        let end = min(start + max(1, chunkSize), channels.count)
        let chunk = Array(channels[start..<end])
        database.write(resultQueue: hopQueue, { context in
            context.createOrUpdate(channels: storable(chunk, since: startMark, context: context))
        }, completion: { error in
            logger.errorIfNotNil(error, "ChunkedChannelStore: chunk \(start)..<\(end) failed")
            storeChunk(
                channels,
                from: end,
                startMark: startMark,
                firstError: firstError ?? error,
                database: database,
                resultQueue: resultQueue,
                completion: completion
            )
        })
    }

    /// The channels of `chunk` that are safe to write: not deleted since `mark`, and not older
    /// than what is stored.
    static func storable(
        _ chunk: [Channel],
        since mark: UInt64,
        context: NSManagedObjectContext
    ) -> [Channel] {
        let deleted = DeletedChannelLog.ids(deletedAfter: mark)
        let stored = Dictionary(
            ChannelDTO.fetch(ids: chunk.map(\.id), context: context).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return chunk.filter { channel in
            if deleted.contains(channel.id) {
                logger.debug("ChunkedChannelStore: skip \(channel.id), deleted while storing")
                return false
            }
            if let storedUpdatedAt = stored[Int64(channel.id)]?.updatedAt?.bridgeDate,
               let updatedAt = channel.updatedAt,
               storedUpdatedAt > updatedAt {
                logger.debug("ChunkedChannelStore: skip \(channel.id), stored copy is newer")
                return false
            }
            return true
        }
    }
}

/// Channels deleted through `deleteChannel(id:)` (channel-deleted, left, blocked and similar
/// events), each with a sequence number, so a chunked store can skip a channel deleted after it
/// started (`ChunkedChannelStore`). Entries are kept for a few minutes, far longer than any store.
enum DeletedChannelLog {

    private static let lock = NSLock()
    nonisolated(unsafe) private static var sequence: UInt64 = 0
    nonisolated(unsafe) private static var entries: [(mark: UInt64, id: ChannelId, at: Date)] = []
    static let retention: TimeInterval = 5 * 60

    static func currentMark() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return sequence
    }

    static func record(_ id: ChannelId, now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        sequence += 1
        entries.removeAll { now.timeIntervalSince($0.at) > retention }
        entries.append((sequence, id, now))
    }

    static func ids(deletedAfter mark: UInt64) -> Set<ChannelId> {
        lock.lock()
        defer { lock.unlock() }
        return Set(entries.lazy.filter { $0.mark > mark }.map(\.id))
    }
}
