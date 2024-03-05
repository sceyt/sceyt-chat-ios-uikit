//
//  ChannelMessageProvider.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class ChannelMessageProvider: Provider {
    
    public var queryLimit = UInt(30)
    
    public let channelId: ChannelId
    public let channelOperator: ChannelOperator
    public let threadMessageId: MessageId?
    
    private lazy var sendMessageQueue: OperationQueue = {
        $0.maxConcurrentOperationCount = 1
        return $0
    }(OperationQueue())
    
    public required init(channelId: ChannelId,
                         threadMessageId: MessageId? = nil ) {
        self.channelId = channelId
        self.channelOperator = .init(channelId: channelId)
        self.threadMessageId = threadMessageId
        super.init()
    }
    
    public lazy var defaultQuery: MessageListQuery = {
        makeQuery()
    }()
    
    public func makeQuery() -> MessageListQuery {
        (threadMessageId != nil ?
         MessageListQuery.Builder(threadId: threadMessageId!) :
            MessageListQuery.Builder(channelId: channelId))
        .limit(queryLimit)
        .build()
    }
    
    open func loadNextMessages(
        completion: ((Error?) -> Void)? = nil
    ) {
        loadNextMessages(
            query: defaultQuery,
            completion: completion
        )
    }
    
    open func loadNextMessages(
        query: MessageListQuery,
        completion: ((Error?) -> Void)? = nil
    ) {
        if !query.loading {
            query.loadNext
            { (_, messages, error) in
                guard let messages = messages
                else {
                    completion?(error)
                    return
                }
                self.store(
                    messages: messages,
                    completion: completion
                )
                self.sendReceivedMarker(messages: messages)
            }
        }
    }
    
    open func loadNextMessages(
        after messageId: MessageId,
        completion: ((Error?) -> Void)? = nil
    ) {
        loadNextMessages(
            query: defaultQuery,
            after: messageId,
            completion: completion
        )
    }
    
    open func loadNextMessages(
        query: MessageListQuery,
        after messageId: MessageId,
        completion: ((Error?) -> Void)? = nil) {
            if !query.loading {
                query.loadNext(messageId: messageId)
                { (_, messages, error) in
                    guard let messages = messages
                    else {
                        completion?(error)
                        return
                    }
                    self.store(
                        messages: messages,
                        completion: completion
                    )
                    self.sendReceivedMarker(messages: messages)
                }
            }
        }
    
    open func loadPrevMessages(
        completion: ((Error?) -> Void)? = nil
    ) {
        loadPrevMessages(
            query: defaultQuery,
            completion: completion
        )
    }
    
    open func loadPrevMessages(
        query: MessageListQuery,
        completion: ((Error?) -> Void)? = nil
    ) {
        if !query.loading {
            defaultQuery.loadPrevious
            { (_, messages, error) in
                guard let messages = messages
                else {
                    completion?(error)
                    return
                }
                self.store(
                    messages: messages,
                    completion: completion
                )
                self.sendReceivedMarker(messages: messages)
            }
        }
    }
    
    open func loadPrevMessages(
        before messageId: MessageId,
        completion: ((Error?) -> Void)? = nil
    ) {
        loadPrevMessages(
            query: defaultQuery,
            before: messageId,
            completion: completion
        )
    }
    
    open func loadPrevMessages(
        query: MessageListQuery,
        before messageId: MessageId,
        completion: ((Error?) -> Void)? = nil) {
            if !query.loading {
                query.loadPrevious(messageId: messageId)
                { (_, messages, error) in
                    guard let messages = messages
                    else {
                        completion?(error)
                        return
                    }

                    print("<><>save: on messages save before \(messageId)<><>")
                    messages.sorted(by: { $0.id < $1.id }).forEach {
                        print("<><>\($0.id), \($0.user.firstName ?? ""), \($0.body)<><>")
                    }
                    print("<><>-------------------<><>")

                    self.store(
                        messages: messages,
                        triggerMessage: messageId,
                        completion: completion
                    )
                    self.sendReceivedMarker(messages: messages)
                }
            }
        }
    
    open func loadNearMessages(
        near messageId: MessageId,
        completion: ((Error?) -> Void)? = nil
    ) {
        loadNearMessages(
            query: defaultQuery,
            near: messageId,
            completion: completion
        )
    }
    
    open func loadNearMessages(
        query: MessageListQuery,
        near messageId: MessageId,
        completion: ((Error?) -> Void)? = nil) {
            query.loadNear(messageId: messageId)
            {  (_, messages, error) in
                guard let messages = messages
                else {
                    completion?(error)
                    return
                }
                self.store(
                    messages: messages,
                    completion: completion
                )
                self.sendReceivedMarker(messages: messages)
            }
        }
    
    open func store(
        messages: [Message],
        triggerMessage: MessageId? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        database.write ({ context in
            context.createOrUpdate(
                messages: messages,
                channelId: self.channelId
            )
            
            let sorted = messages.sorted(by: { $0.id < $1.id })
            if let channelId = sorted.first?.channelId,
               let startMessageId = sorted.first?.id,
               let endMessageId = sorted.last?.id {
                
                let ranges = LoadRangeDTO.fetchMatching(
                    channelId: channelId,
                    startMessageId: startMessageId,
                    endMessageId: endMessageId,
                    triggerMessageId: triggerMessage,
                    context: context
                )
                
                let minLocalId = ranges.min(by: { $0.startMessageId < $1.startMessageId })?.startMessageId ?? Int64(startMessageId)
                let maxLocalId = ranges.max(by: { $0.endMessageId > $1.endMessageId })?.endMessageId ?? Int64(endMessageId)
                
                var minId = min(Int64(startMessageId), minLocalId)
                var maxId = max(Int64(endMessageId), maxLocalId)
                
                if let triggerMessage, triggerMessage != 0 {
                    if triggerMessage < minId {
                        minId = Int64(triggerMessage)
                    }
                    if triggerMessage > maxId {
                        maxId = Int64(triggerMessage)
                    }
                }
                
                if ranges.count == 1 && minId >= ranges[0].startMessageId && maxId <= ranges[0].endMessageId {
                    return
                }
                ranges.forEach { context.delete($0) }
                
                let dto = LoadRangeDTO.insertNewObject(into: context)
                dto.channelId = Int64(channelId)
                dto.startMessageId = minId
                dto.endMessageId = maxId
            }
        }) { error in
            completion?(error)
        }
    }
    
    open func storePending(
        message: Message,
        completion: ((Error?) -> Void)? = nil
    ) {
        database.write ({
            $0.createOrUpdate(
                message: message,
                channelId: self.channelId
            )
            if let ownerChannel = ChannelDTO.fetch(id: self.channelId, context: $0),
                let createdAt = ownerChannel.lastMessage?.createdAt.bridgeDate,
               createdAt < message.createdAt {
                ownerChannel.lastDisplayedMessageId = 0
            }
        }) { error in
            
            completion?(error)
        }
    }
    
    open func deletePending(
        message tid: Int64,
        completion: ((Error?) -> Void)? = nil
    ) {
        database.write ({
            $0.deleteMessage(tid: tid)
        }) { error in
            completion?(error)
        }
    }
    

    open func addReactionToMessage(
        id: MessageId,
        key: String,
        score: UInt16 = 1,
        reason: String? = nil,
        enforceUnique: Bool = false,
        storeForResend: Bool = true,
        completion: ((Error?) -> Void)? = nil
    ) {
        database.write {
            if storeForResend {
                $0.addPendingReaction(messageId: id, key: key, score: score, reason: reason, enforceUnique: enforceUnique)
            }
        } completion: { _ in
            self.channelOperator.addReaction(
                messageId: id,
                key: key,
                score: score,
                reason: reason,
                enforceUnique: enforceUnique
            ) { _, message, error in
                guard let message = message
                else {
                    completion?(error)
                    return
                }
                self.database.write ({
                    $0.removePendingReaction(messageId: message.id, key: key)
                    $0.createOrUpdate(
                        message: message,
                        channelId: self.channelId
                    )
                }, completion: completion)
            }
        }
    }
    
    open func deleteReactionFromMessage(
        message: ChatMessage,
        key: String,
        storeForResend: Bool = true,
        completion: ((Error?) -> Void)? = nil
    ) {
        let reactionId = message.userReactions?.first(where: { $0.key == key})?.id
        database.write {
            $0.removePendingReaction(messageId: message.id, key: key)
        } completion: { _ in   
        }

        channelOperator.deleteReaction(
            messageId: message.id,
            key: key
        ) {  _, message, error in
            guard let message = message
            else {
                completion?(error)
                return
            }
            self.database.write ({
                $0.createOrUpdate(
                    message: message,
                    channelId: self.channelId
                )
                if let reactionId {
                    $0.deleteReaction(id: reactionId)
                }
            }, completion: completion)
        }
    }
    
    open func markMessagesAsReceived (
        ids: [MessageId],
        storeForResend: Bool = true,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard !ids.isEmpty else { return }
        if storeForResend {
            database.write ({
                $0.update(messagePendingMarkers: ids, markerName: DefaultMarker.received)
            })
        }
        channelOperator.markMessagesAsReceived(
            ids: ids.map { $0 as NSNumber }
        ) {  markerList, error in
            guard let markerList = markerList
            else {
                completion?(error)
                return
            }
            self.database.write ({
                $0.update(messageSelfMarkers: markerList)
            }, completion: completion)
        }
    }
    
    open func markMessagesAsDisplayed(
        ids: [MessageId],
        storeForResend: Bool = true,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard !ids.isEmpty else { return }
        if storeForResend {
            database.write ({
                $0.update(messagePendingMarkers: ids, markerName: DefaultMarker.displayed)
            })
        }
        channelOperator.markMessagesAsDisplayed(
            ids: ids.map { $0 as NSNumber }
        ) {  markerList, error in
            guard let markerList = markerList
            else {
                completion?(error)
                return
            }
            self.database.write ({
                $0.update(messageSelfMarkers: markerList)
            }, completion: completion)
        }
    }
    
    open func markMessages(
        markerName: String,
        ids: [MessageId],
        storeForResend: Bool = true,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard !ids.isEmpty else { return }
        if storeForResend {
            database.write ({
                $0.update(messagePendingMarkers: ids, markerName: markerName)
            })
        }
        channelOperator.markMessages(
            markerName: markerName,
            ids: ids.map { $0 as NSNumber }
        ) { markerList, error in
            guard let markerList = markerList
            else {
                completion?(error)
                return
            }
            self.database.write ({
                $0.update(messageSelfMarkers: markerList)
            }, completion: completion)
        }
    }
    
    open func storeLinkMetadata(
        _ metadata: LinkMetadata,
        to message: ChatMessage
    ) {
        metadata.storeImages()
        database.write {
            if message.id > 0 {
                $0.add(
                    linkMetadatas: [metadata],
                    messageId: message.id
                )
            } else {
                $0.add(
                    linkMetadatas: [metadata],
                    messageTid: message.tid
                )
            }   
        }
    }
    
    open func storeMessage(
        notificationContent userInfo: [AnyHashable : Any],
        completion: ((Error?) -> Void)? = nil
    ) {
        database.write ({
            if let dto = try $0.createOrUpdate(notificationContent: userInfo) {
                $0.update(messagePendingMarkers: [MessageId(dto.id)], markerName: DefaultMarker.received)
            }
        }) { error in
            completion?(error)
        }
    }
    
}

extension ChannelMessageProvider {
    
    public class func fetchPendingMessages(
        _ completion: @escaping ([(ChatMessage)]) -> Void) {
            database.performBgTask(resultQueue: .global()) {
                let request = MessageDTO.fetchRequest()
                request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.createdAt, ascending: true)
                request.predicate = .init(
                    format: "id == %lld AND incoming = %d AND (deliveryStatus == %d || deliveryStatus == %d)",
                    0,
                    false,
                    ChatMessage.DeliveryStatus.pending.intValue,
                    ChatMessage.DeliveryStatus.failed.intValue)
                return MessageDTO.fetch(request: request, context: $0)
                    .compactMap {
                        $0.convert()
                    }
            } completion: { result in
                switch result {
                case .success(let result):
                    completion(result)
                case .failure(let error):
                    logger.errorIfNotNil(error, "")
                    completion([])
                }
            }
        }
    
    public class func fetchPendingMarkers(
        _ completion: @escaping ([ChannelId: [String: Set<MessageId>]]) -> Void) {
            database.performBgTask(resultQueue: .global()) {
                let request = MessageDTO.fetchRequest()
                request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.tid, ascending: false)
                request.predicate = .init(
                    format: "pendingMarkerNames != nil")
                return MessageDTO.fetch(request: request, context: $0)
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
            } completion: { result in
                switch result {
                case .success(let result):
                    completion(result)
                case .failure(let error):
                    logger.errorIfNotNil(error, "")
                    completion([:])
                }
            }
        }
    
    public class func fetchPendingReaction(
        _ completion: @escaping ([(ChatMessage.Reaction, ChannelId)]) -> Void) {
            database.performBgTask(resultQueue: .global()) {
                let request = ReactionDTO.fetchRequest()
                request.sortDescriptor = NSSortDescriptor(keyPath: \ReactionDTO.createdAt, ascending: true)
                request.predicate = .init(format: "pending == true")
                return ReactionDTO.fetch(request: request, context: $0)
                    .compactMap {
                        if let m = $0.message {
                            return ($0.convert(), ChannelId(m.channelId))
                        }
                        return nil
                    }
            } completion: { result in
                switch result {
                case .success(let result):
                    completion(result)
                case .failure(let error):
                    logger.errorIfNotNil(error, "")
                    completion([])
                }
            }
        }
    
    public class func fetchMessage(
        id: MessageId,
        completion: @escaping (ChatMessage?) -> Void
    ) {
        database.read {
            MessageDTO.fetch(id: id, context: $0)?.convert()
        } completion: { result in
            completion(try? result.get())
        }
    }

    public class func updateFromDatabase(
        messages: [Message],
        sortDescriptors: [NSSortDescriptor] = [],
        completion: @escaping ([ChatMessage]?) -> Void) {

            database.performBgTask(resultQueue: .global()) { context in
                var chatMessages = NSMutableArray()
                for message in messages {
                    if let m = MessageDTO.fetch(id: message.id, context: context) {
                        chatMessages.add(m)
                    } else {
                        let dto = context.createOrUpdate(message: message, channelId: message.channelId)
                        dto.unlisted = true
                        chatMessages.add(dto)
                    }
                }
                if !sortDescriptors.isEmpty {
                    chatMessages.sort(using: sortDescriptors)
                }
                return chatMessages.compactMap { ChatMessage(dto: $0 as! MessageDTO)}

            } completion: { result in
                completion(try? result.get())
            }
        }
}

private extension ChannelMessageProvider {
    
    func sendReceivedMarker(messages: [Message]) {
        DispatchQueue
            .global(qos: .background)
            .async {
                let ids: [MessageId] = messages.compactMap {
                    ($0.incoming || $0.userMarkers?.contains(where: { $0.name == "received"}) == true) ? nil : $0.id
                }
                self.markMessagesAsReceived(ids: ids)
        }
    }
}
