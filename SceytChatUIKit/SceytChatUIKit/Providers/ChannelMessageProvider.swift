//
//  ChannelMessageProvider.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class ChannelMessageProvider: Provider {
    
    public static var queryLimit = UInt(30)
    
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
        .limit(Self.queryLimit)
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
                    self.store(
                        messages: messages,
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
        completion: ((Error?) -> Void)? = nil
    ) {
        database.write ({
            $0.createOrUpdate(
                messages: messages,
                channelId: self.channelId
            )
        }) { error in
            completion?(error)
        }
    }
    
    open func storePending(
        message: Message,
        completion: ((Error?) -> Void)? = nil
    ) {
        database.write ({
            let ownerChannel =
            $0.createOrUpdate(
                message: message,
                channelId: self.channelId
            ).ownerChannel
            if let createdAt = ownerChannel?.lastMessage?.createdAt.bridgeDate,
               createdAt < message.createdAt {
                ownerChannel?.lastDisplayedMessageId = 0
            }
        }) { error in
            
            completion?(error)
        }
    }
    
    open func deletePending(
        message id: MessageId,
        completion: ((Error?) -> Void)? = nil
    ) {
        database.write ({
            $0.deleteMessage(id: id)
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
        completion: ((Error?) -> Void)? = nil
    ) {
        channelOperator.addReaction(
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
                $0.createOrUpdate(
                    message: message,
                    channelId: self.channelId
                )
            }, completion: completion)
        }
    }
    
    open func deleteReactionFromMessage(
        id: MessageId,
        key: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        channelOperator.deleteReaction(
            messageId: id,
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
                $0.update(messagePendingMarkers: ids, markerName: "received")
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
                $0.update(messagePendingMarkers: ids, markerName: "displayed")
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
            $0.add(
                linkMetadatas: [metadata],
                toMessage: message.id
            )
        }
    }
}

extension ChannelMessageProvider {
    
    public class func fetchPendingMessages(
        _ completion: @escaping ([(ChatMessage)]) -> Void) {
            database.read {
                let request = MessageDTO.fetchRequest()
                request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.createdAt, ascending: true)
                request.predicate = .init(
                    format: "deliveryStatus == %d || deliveryStatus == %d",
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
                    debugPrint(error)
                    completion([])
                }
            }
        }
    
    public class func fetchPendingMarkers(
        _ completion: @escaping ([ChannelId: [String: Set<MessageId>]]) -> Void) {
            database.read {
                let request = MessageDTO.fetchRequest()
                request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.tid, ascending: false)
                request.predicate = .init(
                    format: "pendingMarkerNames != nil")
                return MessageDTO.fetch(request: request, context: $0)
                    .reduce([ChannelId: [String: Set<MessageId>]]()) { partialResult, element in
                        var result = partialResult
                        guard let channel = element.ownerChannel,
                              let pendingMarkerNames = element.pendingMarkerNames
                        else { return result }
                        let cid = ChannelId(channel.id)
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
                    debugPrint(error)
                    completion([:])
                }
            }
        }
}

private extension ChannelMessageProvider {
    
    func sendReceivedMarker(messages: [Message]) {
        DispatchQueue
            .global(qos: .background)
            .async {
                let ids: [MessageId] = messages.compactMap {
                    guard $0.incoming else { return nil }
                    return $0.selfMarkerNames?.contains("received") == true ? nil : $0.id
                }
                self.markMessagesAsReceived(ids: ids)
        }
    }
}


open class SendMessageOperation: Operation {
    enum OperationError: Error {
        case cancelled
    }
    
    public private(set) var result: Result<Message, Error>?
    
    private var sending = false
    private let channelOperator: ChannelOperator
    private let message: Message
    
    public init(channelOperator: ChannelOperator, message: Message) {
        self.channelOperator = channelOperator
        self.message = message
    }
    
    public override var isAsynchronous: Bool {
        return true
    }
    
    public override var isExecuting: Bool {
        return sending
    }
    
    public override var isFinished: Bool {
        return result != nil
    }
    
    public override func start() {
        print("[Operation] fetch start ")
        willChangeValue(forKey: #keyPath(isExecuting))
        sending = true
        didChangeValue(forKey: #keyPath(isExecuting))
        
        guard !isCancelled else {
            print("[Operation] fetch isCancelled ", isCancelled)
            finish(result: .failure(OperationError.cancelled))
            return
        }
        
        sendMessage()
    }
    
    func finish(result: Result<Message, Error>) {
        guard sending else { return }
        
        willChangeValue(forKey: #keyPath(isExecuting))
        willChangeValue(forKey: #keyPath(isFinished))
        
        sending = false
        self.result = result
        print("[Operation] fetch result ", (try? result.get()) != nil)
        didChangeValue(forKey: #keyPath(isFinished))
        didChangeValue(forKey: #keyPath(isExecuting))
    }
    
    public override func cancel() {
        super.cancel()
    }
    
    private func sendMessage() {
        print("[Operation] send Message ")
        if !isCancelled {
            sending = true
            print("[Operation] sending Message")
            channelOperator.sendMessage(message) { sentMessage, error in
                print("[Operation] sent Message")
                if let error {
                    self.finish(result: .failure(error))
                } else {
                    self.finish(result: .success(sentMessage!))
                }
            }
        } else {
            print("[Operation] fetch loadChannels isCancelled", true)
            self.finish(result: .failure(OperationError.cancelled))
        }
    }
}
