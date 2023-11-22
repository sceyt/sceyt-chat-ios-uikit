//
//  SyncService.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import BackgroundTasks
import SceytChat
import CoreData

public final class SyncService: NSObject {
    
    public static var workerQueue = DispatchQueue(label: "com.sceytchat.uikit.syncService")
    public private(set) static var isSyncing = false
    
    public static var reactionQueue: OperationQueue = {
        let op = OperationQueue()
        op.maxConcurrentOperationCount = 1
        return op
    }()
    
    public static var markersQueue: OperationQueue = {
        let op = OperationQueue()
        op.maxConcurrentOperationCount = 5
        return op
    }()
    
    public class func resendPendingItems() {
        logger.verbose("SyncService: resendPendingItems")
        workerQueue.async {
            makePendingReactionOperations {
                if !$0.isEmpty {
                    reactionQueue.addOperations($0, waitUntilFinished: false)
                }
            }
            markersQueue.cancelAllOperations()
            makePendingMarkerOperations {
                markersQueue.addOperations($0, waitUntilFinished: false)
            }
        }
    }
    
    public class func resendPendingMessage() {
        logger.verbose("SyncService: makeMessageResendOperations")
        Components.channelMessageProvider
            .fetchPendingMessages { messages in
                logger.verbose("SyncService: makeMessageResendOperations fetched \(messages.count) messages")
                let groupByChannel = Dictionary(grouping: messages, by: { $0.channelId })
                groupByChannel.forEach { item in
                    let sender = Components.channelMessageSender.init(channelId: item.key)
                    let provider = Components.channelMessageProvider.init(channelId: item.key)
                    let sorted = item.value.sorted(by: { $0.createdAt < $1.createdAt })
                    sorted.forEach { message in
                        if message.attachments?.contains(where: { $0.status == .pauseDownloading || $0.status == .pauseUploading }) == true {
                            logger.verbose("SyncService: makeMessageResendOperations DO NOT RESEND (has paused attachment) message: tid \(message.tid), body \(message.body)")
                            return
                        }
                        logger.verbose("SyncService: makeMessageResendOperations fetched message: tid \(message.tid), body \(message.body)")
                        sender.resendMessage(message) {error in
                            if error?.sceytChatCode == .channelNotExists {
                                provider.deletePending(message: message.tid)
                            }
                        }
                    }
                }
            }
    }
    
    public class func makePendingMarkerOperations(
        completion: @escaping ([MarkerResendOperation]) -> Void
    ) {
        logger.verbose("SyncService: makePendingMarkerOperations")
        var operations = [MarkerResendOperation]()
        Components.channelMessageProvider
            .fetchPendingMarkers { markers in
                logger.verbose("SyncService: makePendingMarkerOperations fetched \(markers.count) markers")
                markers.forEach { (cid, markers) in
                    markers.forEach { (markerName, ids) in
                        let chunked = Array(ids).chunked(into: 50)
                        chunked.forEach { chunk in
                            let provider = Components.channelMessageMarkerProvider.init(channelId: cid)
                            logger.verbose("SyncService: makePendingMarkerOperations fetched markers with MessageIds \(chunk), for markerName \(markerName)")
                            let op = MarkerResendOperation(provider: provider, messageIds: Array(chunk), markerName: markerName)
                            operations.append(op)
                        }
                    }
                }
                completion(operations)
            }
    }
    
    public class func makePendingReactionOperations(
        completion: @escaping ([ReactionResendOperation]) -> Void
    ) {
        var operations = [ReactionResendOperation]()
        Components.channelMessageProvider
            .fetchPendingReaction { reactions in
                let group = Dictionary(grouping: reactions) { $0.1 }
                for ch in group {
                    let provider = Components.channelMessageProvider.init(channelId: ch.key)
                    for reaction in ch.value {
                        let op = ReactionResendOperation(provider: provider, reaction: reaction.0)
                        operations.append(op)
                    }
                }
                completion(operations)
            }
    }
    
    public class func sendPendingMessages() {
        workerQueue
            .async {
                resendPendingMessage()
            }
    }
    
    public class func sendPendingMarkers() {
        workerQueue
            .async {
                makePendingMarkerOperations {
                    markersQueue.addOperations($0, waitUntilFinished: false)
                }
            }
    }
    
    public class func sendPendingReactions() {
        workerQueue
            .async {
                makePendingReactionOperations {
                    reactionQueue.addOperations($0, waitUntilFinished: false)
                }
            }
    }
    
    public class func syncChannels(
        task: BGAppRefreshTask? = nil,
        completion: ((Bool) -> Void)? = nil) {
            Components.channelMessageMarkerProvider.canMarkMessage = false
            Self.isSyncing = true
            Self.sendPendingReactions()
            
            let channelSyncQueue = OperationQueue()
            channelSyncQueue.maxConcurrentOperationCount = 1
            let messageSyncQueue = OperationQueue()
            messageSyncQueue.maxConcurrentOperationCount = 10
            
            let completionOperator = Operation()
            let channelCompletionOperator = Operation()
            
            let results = try? Provider.database.read { context in
                let result1 = context.fetchChannelsToSyncMessages()
                let result2 = context.fetchPendingMarkerToSyncMessages()
                let result3 = context.fetchChannelsForPendingMessages()
                return (result1, result2, result3)
            }.get()
            
            let channelsResult = results?.0
            let operations = Operations.syncChannelOperations(undeleteChannelIds: results?.2 ?? []) { channels in
                for channel in channels where channel.lastDisplayedMessageId != 0  {
                    let cachedId = channelsResult?[channel.id] ?? 0
                    let minDisplayId = cachedId != 0 ? min(cachedId, channel.lastDisplayedMessageId) : channel.lastDisplayedMessageId
                    guard minDisplayId != channel.lastMessage?.id
                    else { continue }
                    let operation = Operations.syncChannelMessagesOperations(
                        startMessageId: minDisplayId,
                        channelId: channel.id
                    )
                    completionOperator.addDependency(operation)
                    messageSyncQueue.addOperation(operation)
                }
            }
            if let createChannel = operations.first(where: {$0 is CreateUnSyncChannelsOperation}) as? CreateUnSyncChannelsOperation {
                createChannel.completionBlock = {
                    Self.sendPendingMessages()
                }
            } else {
                Self.sendPendingMessages()
            }
            guard !operations.isEmpty else {
                completion?(true)
                return
            }
            let markerResult = results?.1
            let markerOperations = Operations.syncMessageMarkersOperations(markersGroup: markerResult ?? [:])
            
            let lastOperation: Operation = markerOperations.last ?? operations.last!
            completionOperator.addDependency(lastOperation)
            channelCompletionOperator.addDependency(operations.last!)
            channelCompletionOperator.completionBlock = {
                Components.channelMessageMarkerProvider.canMarkMessage = true
            }
            if let task {
                task.expirationHandler = {
                    channelSyncQueue.cancelAllOperations()
                    messageSyncQueue.cancelAllOperations()
                    Self.isSyncing = false
                }
                
                completionOperator.completionBlock = {
                    task.setTaskCompleted(success: !completionOperator.isCancelled)
                    completion?(completionOperator.isFinished)
                    Self.isSyncing = false
                }
            } else {
                completionOperator.completionBlock = {
                    Self.isSyncing = false
                    completion?(completionOperator.isFinished)
                }
            }
            channelSyncQueue.addOperations(operations + [channelCompletionOperator] + markerOperations + [completionOperator], waitUntilFinished: false)
        }
}

public struct Operations {
    
    public static func syncChannelOperations(undeleteChannelIds: [ChannelId] = [], onLoad: (([Channel]) -> Void)? = nil) -> [Operation] {
        let createChannel = CreateUnSyncChannelsOperation()
        
        let provider = Components.channelListProvider.init()
        provider.queryLimit = 10
        let fetchChannels = FetchAllChannelsOperation(query: provider.defaultQuery)
        fetchChannels.onLoad = onLoad
        
        let deleteChannels = DeleteChannelsOperation(database: Provider.database, channelIds: undeleteChannelIds)
        
        let fetchDone = BlockOperation { [unowned fetchChannels, unowned deleteChannels, unowned createChannel] in
            guard case let .success(channels)? = fetchChannels.result else {
                deleteChannels.cancel()
                return
            }
            deleteChannels.addChannel(ids: channels.map { $0.id })
            
            if  case let .success(channels)? = createChannel.result {
                deleteChannels.addChannel(ids: channels.map { $0.id })
            }
        }
        fetchChannels.addDependency(createChannel)
        fetchDone.addDependency(fetchChannels)
        deleteChannels.addDependency(fetchDone)
        
        return [createChannel,
                fetchChannels,
                fetchDone,
                deleteChannels]
    }
    
    public static func syncChannelMessagesOperations(startMessageId: MessageId, channelId: ChannelId) -> Operation {
        
        let query = MessageListQuery
            .Builder(channelId: channelId)
            .limit(30)
            .build()
        let messageOperation = FetchChannelMessagesOperation(query: query)
        messageOperation.startMessageId = startMessageId
        let provider = Components.channelMessageProvider.init(channelId: channelId)
        messageOperation.onLoad = { result, end in
            if let messages = try? result.get() {
                provider.store(messages: messages) { _ in
                    end()
                }
                let messageIds = messages.compactMap {
                    if $0.incoming && ($0.userMarkers == nil || !$0.userMarkers!.contains(where: { $0.name == ChatMessage.DeliveryStatus.received.rawValue })) {
                        return $0.id
                    }
                    return nil
                }
                provider.markMessagesAsReceived(
                    ids: messageIds,
                    storeForResend: true
                )
            }
        }
        return messageOperation
    }
    
    public static func syncMessageMarkersOperations(markersGroup: [ChannelId: [String: Set<MessageId>]]) -> [Operation] {
        var operations = [MarkerResendOperation]()
        markersGroup.forEach { (cid, markers) in
            markers.forEach { (markerName, ids) in
                let chunked = Array(ids).chunked(into: 50)
                chunked.forEach { chunk in
                    let provider = Components.channelMessageMarkerProvider.init(channelId: cid)
                    logger.verbose("SyncService: makePendingMarkerOperations fetched markers with MessageIds \(chunk), for markerName \(markerName)")
                    let op = MarkerResendOperation(provider: provider, messageIds: Array(chunk), markerName: markerName)
                    operations.append(op)
                }
            }
        }
        return operations
    }
}


private extension ChannelDatabaseSession where Self: NSManagedObjectContext {
    
    func fetchChannelsToSyncMessages() -> [ChannelId: MessageId] {
        
        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: ChannelDTO.entityName)
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = ["id", "lastDisplayedMessageId"]
        let results = ChannelDTO.fetch(request: fetchRequest, context: self)
        var items = [ChannelId: MessageId]()
        for result in results {
            guard let channelId = result["id"] as? ChannelId,
                  let lastDisplayedId = result["lastDisplayedMessageId"] as? MessageId
            else { continue }
            items[channelId] = lastDisplayedId
        }
        return items
        
    }
}

private extension MessageDatabaseSession where Self: NSManagedObjectContext {
    
    func fetchPendingMarkerToSyncMessages() -> [ChannelId: [String: Set<MessageId>]] {
        let request = MessageDTO.fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.tid, ascending: false)
        request.predicate = .init(
            format: "pendingMarkerNames != nil")
        return MessageDTO.fetch(request: request, context: self)
            .reduce([ChannelId: [String: Set<MessageId>]]()) { partialResult, element in
                var result = partialResult
                let channelId = element.channelId
                guard let pendingMarkerNames = element.pendingMarkerNames
                else { return result }
                let cid = ChannelId(channelId)
                if result[cid] == nil {
                    result[cid] = [:]
                }
                pendingMarkerNames.forEach { marker in
                    if result[cid]![marker] == nil {
                        result[cid]![marker] = .init()
                    }
                    result[cid]![marker]!.insert(MessageId(element.id))
                }
                return result
                
            }
    }
    
    func fetchChannelsForPendingMessages() -> [ChannelId] {
        let request = NSFetchRequest<NSDictionary>(entityName: MessageDTO.entityName)
        request.predicate = .init(
            format: "id == %lld AND incoming = %d AND (deliveryStatus == %d || deliveryStatus == %d)",
            0,
            false,
            ChatMessage.DeliveryStatus.pending.intValue,
            ChatMessage.DeliveryStatus.failed.intValue)
        
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["channelId"]
        
        let results = MessageDTO.fetch(request: request, context: self)
            
        var items = [ChannelId: Bool]()
        for result in results {
            guard let channelId = result["channelId"] as? ChannelId
            else { continue }
            items[channelId] = true
        }
        return Array(items.keys)
    }
}
