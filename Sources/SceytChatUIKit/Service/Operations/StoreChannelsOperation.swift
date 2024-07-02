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
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: ChannelDTO.entityName)
            request.sortDescriptor = NSSortDescriptor(keyPath: \ChannelDTO.id, ascending: false)
            if ids.isEmpty {
                request.predicate = .init(format: "unsynched = NO")
            } else {
                request.predicate = .init(format: "unsynched = NO AND (NOT (id IN %@))", ids)
            }
            
            do {
                try $0.batchDelete(fetchRequest: request)
            } catch {
                logger.errorIfNotNil(error, "")
            }
        }, completion: { [weak self] error in
            logger.errorIfNotNil(error, "StoreChannelsOperation completed with ")
            self?.complete()
        })
    }
}
