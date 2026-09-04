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

open class DeleteChannelsOperation: AsyncOperation {
    
    private let database: Database
    public private(set) var channelIds: [ChannelId]
    public init(
        database: Database,
        channelIds: [ChannelId] = []
    ) {
        self.database = database
        self.channelIds = channelIds
        super.init()
    }
    
    open func addChannel(ids: [ChannelId]) {
        channelIds += ids
    }
    
    open override func main() {
        database.performWriteTask({
            let ids = self.channelIds
            // A protected channel is kept even when the sync returned nothing at all, which is the
            // case this guards: an empty result would otherwise clear every synced channel.
            let keep = Set(ids).union(ProtectedChannels.channelIds)
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: ChannelDTO.entityName)
            request.sortDescriptor = NSSortDescriptor(keyPath: \ChannelDTO.id, ascending: false)
            if keep.isEmpty {
                request.predicate = .init(format: "unsynched = NO")
            } else {
                request.predicate = .init(format: "unsynched = NO AND (NOT (id IN %@))", Array(keep))
            }
            
            do {
                // Collect the ids before the delete: `NSBatchDeleteRequest` bypasses deletion
                // rules, so the channel-scoped side tables have to be swept explicitly or their
                // rows outlive the channel forever. Read as a dictionary so a full channel-list
                // sync does not materialize every doomed row just to learn its id.
                let idRequest = NSFetchRequest<NSDictionary>(entityName: ChannelDTO.entityName)
                idRequest.predicate = request.predicate
                idRequest.propertiesToFetch = ["id"]
                idRequest.resultType = .dictionaryResultType
                let doomed = (ChannelDTO.fetch(request: idRequest, context: $0) as? [[String: Int64]] ?? [])
                    .compactMap { $0["id"].map { ChannelId($0) } }

                try $0.batchDelete(fetchRequest: request)

                for id in doomed {
                    DraftMessageDTO.delete(channelId: id, context: $0)
                    DraftAttachmentDTO.deleteAll(channelId: id, context: $0)
                }
            } catch {
                logger.errorIfNotNil(error, "")
            }
        }, completion: { [weak self] error in
            logger.errorIfNotNil(error, "StoreChannelsOperation completed with ")
            self?.complete()
        })
    }
}
