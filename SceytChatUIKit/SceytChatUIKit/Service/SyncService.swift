//
//  SyncService.swift
//  SceytChatUIKit
//

import Foundation
import BackgroundTasks
import SceytChat
import CoreData

public final class SyncService: NSObject {
    
    public class func sendPendingMessages() {
        DispatchQueue
            .global(qos: .userInteractive)
            .async {
                ChannelMessageProvider
                    .fetchPendingMessages { messages in
                        messages.forEach { message in
                            ChannelMessageSender(channelId: message.channelId)
                                .resendMessage(message) {error in
                                    debugPrint(error as Any)
                                }
                        }
                    }
            }
    }
    
    public class func sendPendingMarkers() {
        DispatchQueue
            .global(qos: .userInteractive)
            .async {
                ChannelMessageProvider
                    .fetchPendingMarkers { markers in
                        markers.forEach { (cid, markers) in
                            markers.forEach { (markerName, ids) in
                                let chunked = Array(ids).chunked(into: 50)
                                chunked.forEach { chunk in
                                    ChannelMessageProvider(channelId: cid)
                                        .markMessages(
                                            markerName: markerName,
                                            ids: Array(ids),
                                            storeForResend: false
                                        )
                                }
                            }
                        }
                    }
            }
    }
    
    public class func syncChannels(task: BGAppRefreshTask? = nil) {
        
        let channelSyncQueue = OperationQueue()
        channelSyncQueue.maxConcurrentOperationCount = 1
        let messageSyncQueue = OperationQueue()
        messageSyncQueue.maxConcurrentOperationCount = 10
        
        let completionOperator = Operation()
        
        let result = try? Provider.database.read { context in
            context.fetchChannelsToSyncMessages()
        }.get()
        
        let operations = Operations.syncChannelOperations { channels in
            for channel in channels {
                let cachedId = result?[channel.id]
                let minDisplayId = cachedId != nil ? min(cachedId!, channel.lastDisplayedMessageId) : channel.lastDisplayedMessageId
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
        
        let lastOperation = operations.last!
        completionOperator.addDependency(lastOperation)
        if let task {
            task.expirationHandler = {
                channelSyncQueue.cancelAllOperations()
                messageSyncQueue.cancelAllOperations()
            }
            
            completionOperator.completionBlock = {
                task.setTaskCompleted(success: !completionOperator.isCancelled)
            }
        }
        channelSyncQueue.addOperations(operations + [completionOperator], waitUntilFinished: false)
    }
}

public struct Operations {
    
    public static func syncChannelOperations(onLoad: (([Channel]) -> Void)? = nil) -> [Operation] {
        
        let fetchChannels = FetchAllChannelsOperation(query: ChannelListProvider().defaultQuery)
        fetchChannels.onLoad = onLoad
        
        let storeChannels = StoreChannelsOperation(database: Provider.database)
        
        let fetchDone = BlockOperation { [unowned fetchChannels, unowned storeChannels] in
            guard case let .success(channels)? = fetchChannels.result else {
                print("[Operation] fetchDone result error")
                storeChannels.cancel()
                return
            }
            storeChannels.channels = channels
        }
        fetchDone.addDependency(fetchChannels)
        storeChannels.addDependency(fetchDone)
        
        
        return [fetchChannels,
                fetchDone,
                storeChannels]
    }
    
    public static func syncChannelMessagesOperations(startMessageId: MessageId, channelId: ChannelId) -> Operation {
        
        let query = MessageListQuery
            .Builder(channelId: channelId)
            .limit(30)
            .build()
        let messageOperation = FetchChannelMessagesOperation(query: query)
        messageOperation.startMessageId = startMessageId
        let provider = ChannelMessageProvider(channelId: channelId)
        messageOperation.onLoad = { result, end in
            if let messages = try? result.get() {
                provider.store(messages: messages) { _ in
                    end()
                }
                provider.markMessagesAsReceived(
                    ids: messages.map { $0.id },
                    storeForResend: true
                )
            }
        }
        return messageOperation
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
