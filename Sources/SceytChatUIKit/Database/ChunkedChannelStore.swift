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
///   later chunk cannot bring it back, and is reported in `Outcome.deletedChannelIds`.
/// - A channel that another write changed while the batch was being stored, to a copy newer than
///   the batch's (`updatedAt`), is skipped: an update event stored between two chunks must not be
///   overwritten. Only changes made during the store count; a channel that was already stored
///   before it is updated by the batch as usual.
/// - A failed chunk does not stop the rest; the first error is reported at the end.
/// - The hops between chunks run on a background queue, so a busy main thread does not delay
///   them; only the final completion goes to `resultQueue`.
enum ChunkedChannelStore {

    struct Outcome {
        /// Channels of the batch skipped because they were deleted while it was being stored.
        var deletedChannelIds: Set<ChannelId> = []
        /// The first chunk error, if any chunk failed.
        var error: Error?
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var _chunkSize = 10

    static var chunkSize: Int {
        get { lock.lock(); defer { lock.unlock() }; return _chunkSize }
        set { lock.lock(); _chunkSize = max(1, newValue); lock.unlock() }
    }

    private static let hopQueue = DispatchQueue(
        label: "com.sceyt.database.channel-chunks",
        qos: .userInitiated
    )

    static func store(
        _ channels: [Channel],
        database: Database,
        resultQueue: DispatchQueue = .main,
        completion: @escaping (Outcome) -> Void
    ) {
        Run(
            channels: channels,
            chunkSize: chunkSize,
            database: database,
            resultQueue: resultQueue,
            completion: completion
        ).storeNextChunk()
    }

    /// One batch being stored. Its state is touched by one chunk at a time: in the write block on
    /// the serial writer, then in that write's completion on `hopQueue`.
    private final class Run {
        let channels: [Channel]
        let chunkSize: Int
        let database: Database
        let resultQueue: DispatchQueue
        let completion: (Outcome) -> Void
        let startMark = DeletedChannelLog.currentMark()

        var next = 0
        var outcome = Outcome()
        /// Each batch channel's stored `updatedAt` when the first chunk ran (`.some(nil)`: stored
        /// without one); no entry: not stored then. `nil` until the first chunk runs.
        var baseline: [Int64: Date?]?

        init(
            channels: [Channel],
            chunkSize: Int,
            database: Database,
            resultQueue: DispatchQueue,
            completion: @escaping (Outcome) -> Void
        ) {
            self.channels = channels
            self.chunkSize = chunkSize
            self.database = database
            self.resultQueue = resultQueue
            self.completion = completion
        }

        func storeNextChunk() {
            guard next < channels.count else {
                let outcome = outcome
                let completion = completion
                resultQueue.async { completion(outcome) }
                return
            }
            let start = next
            let end = min(start + chunkSize, channels.count)
            next = end
            let chunk = Array(channels[start..<end])
            database.write(resultQueue: ChunkedChannelStore.hopQueue, { context in
                context.createOrUpdate(channels: self.storable(chunk, context: context))
            }, completion: { error in
                logger.errorIfNotNil(error, "ChunkedChannelStore: chunk \(start)..<\(end) failed")
                if self.outcome.error == nil {
                    self.outcome.error = error
                }
                self.storeNextChunk()
            })
        }

        /// The channels of `chunk` that are safe to write.
        private func storable(_ chunk: [Channel], context: NSManagedObjectContext) -> [Channel] {
            if baseline == nil {
                baseline = Dictionary(
                    ChannelDTO.fetch(ids: channels.map(\.id), context: context)
                        .map { ($0.id, $0.updatedAt?.bridgeDate) },
                    uniquingKeysWith: { first, _ in first }
                )
            }
            let deleted = DeletedChannelLog.ids(deletedAfter: startMark)
            let stored = Dictionary(
                ChannelDTO.fetch(ids: chunk.map(\.id), context: context).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            return chunk.filter { channel in
                if deleted.contains(channel.id) {
                    logger.debug("ChunkedChannelStore: skip \(channel.id), deleted while storing")
                    outcome.deletedChannelIds.insert(channel.id)
                    return false
                }
                if isChangedSinceStartAndNewer(channel, stored: stored[Int64(channel.id)]) {
                    logger.debug("ChunkedChannelStore: skip \(channel.id), updated while storing")
                    return false
                }
                return true
            }
        }

        private func isChangedSinceStartAndNewer(_ channel: Channel, stored: ChannelDTO?) -> Bool {
            guard let storedUpdatedAt = stored?.updatedAt?.bridgeDate,
                  let updatedAt = channel.updatedAt,
                  storedUpdatedAt > updatedAt
            else { return false }
            guard let entry = baseline?[Int64(channel.id)] else {
                return true  // stored by another write after the first chunk
            }
            return entry != storedUpdatedAt
        }
    }
}

/// Channels deleted while a chunked store may be running (`ChunkedChannelStore`), each with a
/// sequence number, so the store can skip a channel deleted after it started.
///
/// A delete is recorded only once it is committed: `ChannelDTO` deletions are collected when a
/// context is about to save and recorded when the save succeeds, so a write that fails and rolls
/// back records nothing. `NSBatchDeleteRequest` never goes through a save; its callers record
/// the ids themselves (`DeleteChannelsOperation`). Entries are kept for a few minutes, far longer
/// than any store.
enum DeletedChannelLog {

    private static let lock = NSLock()
    nonisolated(unsafe) private static var sequence: UInt64 = 0
    nonisolated(unsafe) private static var entries: [(mark: UInt64, id: ChannelId, at: Date)] = []
    static let retention: TimeInterval = 5 * 60
    private static let pendingKey = "com.sceyt.deletedChannelLog.pending"

    private static let saveObservers: [NSObjectProtocol] = {
        let center = NotificationCenter.default
        return [
            center.addObserver(forName: .NSManagedObjectContextWillSave, object: nil, queue: nil) { note in
                // Posted on the context's own queue, before the save.
                guard let context = note.object as? NSManagedObjectContext else { return }
                let ids = context.deletedObjects.compactMap { ($0 as? ChannelDTO)?.id }
                context.userInfo[pendingKey] = ids.isEmpty ? nil : ids
            },
            center.addObserver(forName: .NSManagedObjectContextDidSave, object: nil, queue: nil) { note in
                guard let context = note.object as? NSManagedObjectContext,
                      let ids = context.userInfo[pendingKey] as? [Int64]
                else { return }
                context.userInfo.removeObject(forKey: pendingKey)
                record(ids.map { ChannelId($0) })
            }
        ]
    }()

    /// The current position in the log. Also starts watching saves, which only needs to happen
    /// before the first store asks for a mark.
    static func currentMark() -> UInt64 {
        _ = saveObservers
        lock.lock()
        defer { lock.unlock() }
        return sequence
    }

    static func record(_ ids: [ChannelId], now: Date = Date()) {
        guard !ids.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll { now.timeIntervalSince($0.at) > retention }
        for id in ids {
            sequence += 1
            entries.append((sequence, id, now))
        }
    }

    static func ids(deletedAfter mark: UInt64) -> Set<ChannelId> {
        lock.lock()
        defer { lock.unlock() }
        return Set(entries.lazy.filter { $0.mark > mark }.map(\.id))
    }
}
