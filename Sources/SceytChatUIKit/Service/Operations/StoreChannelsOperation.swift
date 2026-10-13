//
//  StoreChannelsOperation.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import CoreData

//open class StoreChannelsOperation: Operation {
//
//    private let database: Database
//    public var channels: [Channel]
//    private let deleteNonExistences: Bool
//
//    public init(
//        database: Database,
//        channels: [Channel] = [],
//        deleteNonExistences: Bool = true) {
//        self.database = database
//        self.channels = channels
//        self.deleteNonExistences = deleteNonExistences
//    }
//
//    open override func main() {
//        guard !channels.isEmpty
//        else { return }
//        try? database.syncWrite {
//            if self.deleteNonExistences {
//                let ids = self.channels.map { $0.id }
//                let request = NSFetchRequest<NSFetchRequestResult>(entityName: ChannelDTO.entityName)
//                request.sortDescriptor = NSSortDescriptor(keyPath: \ChannelDTO.id, ascending: false)
//                request.predicate = .init(format: "NOT (id IN %@)", ids)
//                do {
//                    try $0.batchDelete(fetchRequest: request)
//                } catch {
//                    logger.debug(error)
//                }
//            }
//
//            self.channels.forEach { channel in
//                if channel.newMessageCount > 0 {
//                    logger.debug("[MARKER CHECK] Store Operator fetched channels: \(channel.id) for \(channel.newMessageCount)")
//                }
//            }
//            for channel in self.channels {
//                $0.createOrUpdate(channel: channel)
//                if self.isCancelled {
//                    break
//                }
//            }
//        }
//        Components.channelListProvider.syncMessageForReactions(channels: channels)
//    }
//}


open class StoreChannelsOperation: AsyncOperation {
    
    private let database: Database
    public var channels: [Channel]

    public init(
        database: Database,
        channels: [Channel] = []) {
            self.database = database
            self.channels = channels
            super.init()
        }
    
    open override func main() {
        guard !channels.isEmpty
        else { return }
        database.performWriteTask({
            $0.createOrUpdate(channels: self.channels)
        }, completion: { [weak self] error in
            logger.errorIfNotNil(error, "StoreChannelsOperation completed with ")
            self?.complete()
        })
//        Components.channelListProvider.syncMessageForReactions(channels: channels)
    }
}

/// Channels that `DeleteChannelsOperation` must never prune.
///
/// That sweep deletes every synced channel the channel-list query did not return. A channel the
/// client reaches by subscription alone — a live-stream comments channel — is never in that list,
/// so the first channel-list sync after opening it deletes the channel and every message stored
/// under it, including one just sent. Marking such a channel `unsynched` does not work as a
/// substitute: `ChannelDTO.map(channel)` clears that flag on every store of the channel, an
/// incoming message included, and the flag additionally routes sends through channel creation.
/// A screen that opens a channel of this kind registers it here for as long as it is on screen.
public enum ProtectedChannels {

    private static let lock = NSLock()
    nonisolated(unsafe) private static var ids = Set<ChannelId>()

    public static func protect(channelId: ChannelId) {
        lock.lock()
        ids.insert(channelId)
        lock.unlock()
    }

    public static func release(channelId: ChannelId) {
        lock.lock()
        ids.remove(channelId)
        lock.unlock()
    }

    public static var channelIds: Set<ChannelId> {
        lock.lock()
        defer { lock.unlock() }
        return ids
    }
}

/// Deletes the synced channels the channel-list sync did not return — but only once the server
/// confirms each one is gone.
///
/// The sync pages by offset, so a channel that gets a new message mid-sync moves into a page
/// already read and every later page skips it. Deleting on absence alone dropped that channel and
/// all its messages, and with them its search results. Each missing channel is now asked about
/// by id first (`MissingChannelsVerifier`): one that still exists is stored again, one whose
/// answer is inconclusive is kept for the next sync, and only the confirmed rest is deleted.
open class DeleteChannelsOperation: AsyncOperation {
    
    private let database: Database
    public private(set) var channelIds: [ChannelId]

    /// Asks the server about the missing channels before any is deleted. `nil` deletes them all
    /// unconfirmed.
    public let verifier: MissingChannelsVerifier?

    /// `false` deletes the missing channels unconfirmed. Set when the sync returned no channels at
    /// all: an empty first page cannot come from an offset shift, so it means the user really has
    /// none, and confirming would only cost a request per local channel.
    public var confirmsMissingChannels = true

    public init(
        database: Database,
        channelIds: [ChannelId] = [],
        verifier: MissingChannelsVerifier? = ServerMissingChannelsVerifier()
    ) {
        self.database = database
        self.channelIds = channelIds
        self.verifier = verifier
        super.init()
    }
    
    open func addChannel(ids: [ChannelId]) {
        channelIds += ids
    }
    
    open override func main() {
        // A protected channel is kept even when the sync returned nothing at all, which is the
        // case this guards: an empty result would otherwise clear every synced channel.
        let keep = Set(channelIds).union(ProtectedChannels.channelIds)
        database.performBgTask(resultQueue: .global(), { context in
            Self.channelIds(matching: Self.missingPredicate(keep: keep), context: context)
        }, completion: { [weak self] result in
            guard let self else { return }
            let missing: [ChannelId]
            switch result {
            case let .success(ids):
                missing = ids
            case let .failure(error):
                logger.errorIfNotNil(error, "DeleteChannelsOperation: read missing channels")
                missing = []
            }
            guard !missing.isEmpty, !self.isCancelled else {
                self.complete()
                return
            }
            guard self.confirmsMissingChannels, let verifier = self.verifier else {
                self.delete(confirmedIds: missing)
                return
            }
            verifier.verify(channelIds: missing) { [weak self] gone in
                self?.delete(confirmedIds: gone)
            }
        })
    }

    /// Deletes the confirmed channels and the side tables keyed by them.
    ///
    /// Overridable because `NSBatchDeleteRequest` merges into `SceytChatUIKit.shared.database`,
    /// which a test's in-memory store cannot share.
    open func delete(channelIds ids: [ChannelId], context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: ChannelDTO.entityName)
        request.sortDescriptor = NSSortDescriptor(keyPath: \ChannelDTO.id, ascending: false)
        request.predicate = .init(format: "id IN %@", ids)
        try context.batchDelete(fetchRequest: request)

        // `NSBatchDeleteRequest` bypasses deletion rules, so the channel-scoped side tables have
        // to be swept explicitly or their rows outlive the channel forever.
        for id in ids {
            DraftMessageDTO.delete(channelId: id, context: context)
            DraftAttachmentDTO.deleteAll(channelId: id, context: context)
            // This path never reaches `deleteChannel(id:)`, so the pin rows would
            // otherwise be stranded on a channel that no longer exists.
            PinnedMessageDTO.deleteAll(channelId: id, context: context)
            PinDetailsDTO.deleteAll(channelId: id, context: context)
        }
    }

    private func delete(confirmedIds: [ChannelId]) {
        // The sync is cancelled before an account switch wipes the database; a delete landing
        // after that would act on the incoming account's rows.
        guard !confirmedIds.isEmpty, !isCancelled else {
            complete()
            return
        }
        database.performWriteTask({
            // Re-checked at delete time: the server check takes a round trip, and a channel can
            // be protected or turned back into a local placeholder meanwhile.
            let predicate = NSPredicate(
                format: "unsynched = NO AND (id IN %@) AND (NOT (id IN %@))",
                confirmedIds,
                Array(ProtectedChannels.channelIds)
            )
            let doomed = Self.channelIds(matching: predicate, context: $0)
            guard !doomed.isEmpty else { return }
            do {
                try self.delete(channelIds: doomed, context: $0)
            } catch {
                logger.errorIfNotNil(error, "")
            }
        }, completion: { [weak self] error in
            logger.errorIfNotNil(error, "DeleteChannelsOperation completed with ")
            self?.complete()
        })
    }

    private static func missingPredicate(keep: Set<ChannelId>) -> NSPredicate {
        keep.isEmpty
            ? NSPredicate(format: "unsynched = NO")
            : NSPredicate(format: "unsynched = NO AND (NOT (id IN %@))", Array(keep))
    }

    /// Read as a dictionary so a full channel-list sync does not materialize every doomed row
    /// just to learn its id.
    private static func channelIds(matching predicate: NSPredicate, context: NSManagedObjectContext) -> [ChannelId] {
        let request = NSFetchRequest<NSDictionary>(entityName: ChannelDTO.entityName)
        request.predicate = predicate
        request.propertiesToFetch = ["id"]
        request.resultType = .dictionaryResultType
        return (ChannelDTO.fetch(request: request, context: context) as? [[String: Int64]] ?? [])
            .compactMap { $0["id"].map { ChannelId($0) } }
    }
}
