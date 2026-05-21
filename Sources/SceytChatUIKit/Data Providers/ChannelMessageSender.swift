//
//  ChannelMessageSender.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

public protocol ChannelMessageSenderDelegate: AnyObject {
    
    func channelMessageSender(_ sender: ChannelMessageSender, willSend message: Message) -> Message?
    func channelMessageSender(_ sender: ChannelMessageSender, didSend message: Message?, error: Error?) -> Message?
    
    func channelMessageSender(_ sender: ChannelMessageSender, willEdit message: Message) -> Message?
    func channelMessageSender(_ sender: ChannelMessageSender, didEdit message: Message?, error: Error?) -> Message?
    
    func channelMessageSender(_ sender: ChannelMessageSender, willResend message: Message) -> Message?
    func channelMessageSender(_ sender: ChannelMessageSender, didResend message: Message?, error: Error?) -> Message?
    
    func channelMessageSender(_ sender: ChannelMessageSender, willDelete messageId: MessageId) -> MessageId?
    func channelMessageSender(_ sender: ChannelMessageSender, didDelete messageId: MessageId?, error: Error?) -> MessageId?
}

open class ChannelMessageSender: DataProvider {
    
    public let channelId: ChannelId
    public let channelOperator: ChannelOperator
    public let threadMessageId: MessageId?
    public var maxSendRetryCount = 3
    
    public weak var delegate: ChannelMessageSenderDelegate?
    
    private lazy var messageProvider = Components.channelMessageProvider.init(channelId: channelId, threadMessageId: threadMessageId)
    
    public required init(channelId: ChannelId,
                         threadMessageId: MessageId? = nil ) {
        self.channelId = channelId
        self.channelOperator = .init(channelId: channelId)
        self.threadMessageId = threadMessageId
        super.init()
    }
    
    open func sendMessage(
        _ message: Message,
        storeBeforeSend: Bool = true,
        completion: ((Error?) -> Void)? = nil
    ) {
        
        logger.info("Prepare send message with tid \(message.tid)")
        func store(completion: @escaping () -> Void) {
            if storeBeforeSend {
                messageProvider.storePending(message: message) { _ in
                    completion()
                }
            } else {
                completion()
            }
        }
        func handleAck(sentMessage: Message?, error: Error?) {
            let sentMessage = didSend(sentMessage, error: error)
            guard let sentMessage = sentMessage,
                  sentMessage.deliveryStatus != .failed,
                  sentMessage.deliveryStatus != .pending
            else {
                logger.errorIfNotNil(error, "Sent message filed status: \(String(describing: sentMessage?.deliveryStatus)), tid \(message.tid)")
                if error?.sceytChatCode?.isBadParam ?? false {
                    self.database.write {
                        $0.deleteMessage(tid: Int64(message.tid))
                    }
                }
                completion?(error)
                return
            }
             logger.info("message with tid \(sentMessage.tid) id: \(sentMessage.id) sent successfully")
            self.database.write ({
                let predicate = NSPredicate(format: "channelId == %lld AND id > 0", self.channelId)
                let message = MessageDTO.lastMessage(predicate: predicate, context: $0)
                let channel = ChannelDTO.fetch(id: self.channelId, context: $0)
                let lastMessageId = message?.id
                $0.createOrUpdate(message: sentMessage, channelId: self.channelId)
                if let channel {
                    channel.lastReceivedMessageId = Int64(sentMessage.id)
                    let min = min(sentMessage.id, MessageId(lastMessageId ?? Int64(sentMessage.id)))
                    let max = max(sentMessage.id, MessageId(lastMessageId ?? Int64(sentMessage.id)))
                    $0.updateRanges(startMessageId: min, endMessageId: max, channelId: ChannelId(channel.id))
                    if channel.lastDisplayedMessageId < Int64(sentMessage.id) {
                        channel.lastDisplayedMessageId = Int64(sentMessage.id)
                    }
                }
            }) { dbError in
                completion?(error ?? dbError)
            }
        }
        
        store {
            let chatMessage = ChatMessage(message: message, channelId: self.channelId)
            if self.uploadableAttachments(of: chatMessage).isEmpty {
                logger.info("The message has no attachments. Sending message with tid \(message.tid)")
                guard let message = self.willSend(message)
                else {
                    completion?(nil)
                    return
                }
                self.sendMessageWithRetry(message)
                { sentMessage, error in
                    handleAck(sentMessage: sentMessage, error: error)
                }
            } else {
                 logger.info("The message has attachments. will send message with tid \(message.tid) after upload")
                self.uploadAttachmentsIfNeeded(message: chatMessage)
                { message, error in
                    if error == nil, let message {
                         logger.info("Message attachments uploaded successfully. will send message with tid \(message.tid)")
                        let sendableMessage = message.builder.build()
                        guard let sendableMessage = self.willSend(sendableMessage)
                        else {
                             logger.info("Message with tid \(message.tid) build failed can't send message")
                            completion?(nil)
                            return
                        }
                         logger.info("Send message with tid \(message.tid)")
                        self.sendMessageWithRetry(sendableMessage)
                        { sentMessage, error in
                            handleAck(sentMessage: sentMessage, error: error)
                        }
                    } else {
                        completion?(error)
                    }
                }
            }
        }
    }
    
    open func resendMessage(
        _ chatMessage: ChatMessage,
        completion: ((Error?) -> Void)? = nil
    ) {
        if let parent = chatMessage.parent {
            logger.info("Resending message with tid \(chatMessage.tid) parent: \(parent.id) upload attachments if needed")
        } else {
            logger.info("Resending message with tid \(chatMessage.tid) upload attachments if needed")
        }
        uploadAttachmentsIfNeeded(message: chatMessage) { message, error in
            if error == nil, let message {
                let sendableMessage = message.builder.build()
                guard let sendableMessage = self.willResend(sendableMessage)
                else {
                     logger.info("Message with tid \(message.tid) build failed can't resend message")
                    completion?(nil)
                    return
                }
                
                func callback(sentMessage: Message?, error: Error?) {
                    if error != nil || sentMessage?.deliveryStatus == .failed {
                         logger.errorIfNotNil(error, "Resending message with tid \(String(describing: sentMessage?.tid)) failed")
                    }
                    self.didResend(sentMessage, error: error)
                    guard let sentMessage = sentMessage
                    else {
                        if error?.sceytChatCode == .badMessageParam {
                            self.database.write {
                                $0.deleteMessage(tid: Int64(message.tid))
                            }
                        }
                        logger.error("Message with tid \(String(describing: sentMessage?.tid)) build failed can't store message")
                        completion?(error)
                        return
                    }
                    if sentMessage.deliveryStatus == .pending || sentMessage.deliveryStatus == .failed {
                        logger.error("Resending message with tid \(String(describing: sentMessage.tid)) failed error: \(error)")
                        completion?(error)
                        return
                    }
                     logger.info("Message with tid \(sentMessage.tid), id \(sentMessage.id) will store in db")
                    self.database.write ({
                        let predicate = NSPredicate(format: "channelId == %lld AND id > 0", self.channelId)
                        let message = MessageDTO.lastMessage(predicate: predicate, context: $0)
                        let channel = ChannelDTO.fetch(id: self.channelId, context: $0)
                        let lastMessageId = message?.id

                        // Preserve pending votes from the original message
                        var pendingVotes: NSSet? = nil
                        if chatMessage.poll?.pendingVotes != nil {
                            let existingMessageDTO = MessageDTO.fetch(tid: Int64(chatMessage.tid), context: $0)
                            pendingVotes = existingMessageDTO?.poll?.pendingVotes
                        }
                        
                        $0.createOrUpdate(
                            message: sentMessage,
                            channelId: self.channelId
                        )

                        // Restore pending votes to the updated message
                        if let pendingVotes = pendingVotes, pendingVotes.count > 0 {
                            if let updatedMessageDTO = MessageDTO.fetch(id: sentMessage.id, context: $0),
                               let pollDTO = updatedMessageDTO.poll {
                                pollDTO.pendingVotes = pendingVotes
                            }
                        }

                        if let channel {
                            let min = min(sentMessage.id, MessageId(lastMessageId ?? Int64(sentMessage.id)))
                            let max = max(sentMessage.id, MessageId(lastMessageId ?? Int64(sentMessage.id)))
                            $0.updateRanges(startMessageId: min, endMessageId: max, channelId: ChannelId(channel.id))
                            if channel.lastDisplayedMessageId < Int64(sentMessage.id) {
                                channel.lastDisplayedMessageId = Int64(sentMessage.id)
                            }
                        }
                    }, completion: completion)
                }
                switch message.state {
                case .none:
                    logger.info("Resending message with tid \(chatMessage.tid) \(sendableMessage.parent != nil ? "parent: \(sendableMessage.parent?.id)" : "")")
                    self.channelOperator.resendMessage(sendableMessage, completion: callback(sentMessage:error:))
                case .edited:
                     logger.info("Reediting message with tid \(chatMessage.tid)")
                    self.channelOperator.editMessage(sendableMessage, completion: callback(sentMessage:error:))
                case .deleted:
                     logger.info("Redeleting message with tid \(chatMessage.tid)")
                    self.channelOperator.deleteMessage(sendableMessage, type: .deleteForMe, completion: callback(sentMessage:error:))
                }
            }
        }
    }
    
    open func editMessage(
        _ message: Message,
        storeBeforeSend: Bool = true,
        completion: ((Error?) -> Void)? = nil
    ) {
        func store(completion: @escaping () -> Void) {
            if storeBeforeSend {
                database.write ({
                    $0.createOrUpdate(
                        message: message,
                        channelId: self.channelId
                    )
                    .state = Int16(ChatMessage.State.edited.intValue)
                }) { _ in
                    completion()
                }
            } else {
                completion()
            }
        }
        
        func handleAck(sentMessage: Message?, error: Error?) {
            didEdit(sentMessage, error: error)
            guard let sentMessage = sentMessage,
                  sentMessage.deliveryStatus != .failed
            else {
                completion?(error)
                return
            }
            
            self.database.write ({
                $0.createOrUpdate(
                    message: sentMessage,
                    channelId: self.channelId
                )
            }, completion: completion)
        }
        
        store {
            if message.attachments == nil || message.attachments?.isEmpty == true {
                guard let message = self.willEdit(message)
                else {
                    completion?(nil)
                    return
                }
                self.channelOperator.editMessage(message)
                { sentMessage, error in
                    handleAck(sentMessage: sentMessage, error: error)
                }
            } else {
                let chatMessage = ChatMessage(message: message, channelId: self.channelId)
                self.uploadAttachmentsIfNeeded(message: chatMessage)
                { messageResponse, error in
                    if error == nil, let messageResponse {
                        let sendableMessageBuilder = messageResponse.builder
                        sendableMessageBuilder.mentionUserIds(message.requestedMentionUserIds ?? [])
                        let sendableMessage = sendableMessageBuilder.build()
                        guard let sendableMessage = self.willEdit(sendableMessage)
                        else {
                            completion?(nil)
                            return
                        }
                        self.channelOperator.editMessage(sendableMessage)
                        { sentMessage, error in
                            handleAck(sentMessage: sentMessage, error: error)
                        }
                    } else {
                        completion?(error)
                    }
                }
            }
        }
    }
    
    open func deleteMessage(
        id: MessageId,
        type: DeleteMessageType = .deleteForMe,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard let id = willDelete(id)
        else {
            completion?(nil)
            return
        }
        channelOperator
            .deleteMessage(id: id,
                           type: type
            ) {message, error in
                self.didDelete(message?.id, error: error)
                guard let message = message
                else {
                    completion?(error)
                    return
                }
                self.database.write ({
                    switch type {
                    case .deleteHard:
                        $0.deleteMessage(id: message.id)
                    default:
                        $0.createOrUpdate(
                            message: message,
                            channelId: self.channelId
                        )
                    }
                    
                }, completion: completion)
            }
    }
    
    open func uploadAttachmentsIfNeeded(
        message: ChatMessage,
        completion: @escaping (ChatMessage?, Error?) -> Void) {
            let attachments = uploadableAttachments(of: message)
            guard !attachments.isEmpty
            else {
                completion(message, nil)
                return
            }
            fileProvider
                .uploadMessageAttachments(
                    message: message,
                    attachments: attachments
                ) { chatMessage, error in
                    completion(chatMessage, error)
                }
        }
    
    open func uploadableAttachments(of message: ChatMessage) -> [ChatMessage.Attachment] {
        guard let attachments = message.attachments?.filter({ $0.status != .done && $0.type != "link" && $0.filePath != nil }),
              !attachments.isEmpty
        else { return [] }
        
        return attachments
    }
    
    private func sendMessageWithRetry(
        _ message: Message,
        attempt: Int = 0,
        completion: @escaping (Message?, Error?) -> Void
    ) {
        channelOperator.sendMessage(message) { [weak self] sentMessage, error in
            guard let self else { return }
            
            guard self.shouldRetrySend(sentMessage: sentMessage, error: error, attempt: attempt) else {
                completion(sentMessage, error)
                return
            }
            
            let delay = self.retryDelay(forAttempt: attempt)
            logger.info("Retry send message tid \(message.tid), attempt \(attempt + 1)/\(self.maxSendRetryCount), delay \(Int(delay * 1000))ms")
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                self.sendMessageWithRetry(message, attempt: attempt + 1, completion: completion)
            }
        }
    }
    
    private func shouldRetrySend(sentMessage: Message?, error: Error?, attempt: Int) -> Bool {
        guard let message = sentMessage else {
            return false
        }
        guard message.deliveryStatus == .pending else { return false }
        guard chatClient.connectionState == .connected else { return false }
        guard attempt < max(0, maxSendRetryCount) else { return false }
        return error?.sdkError?.isResendable == true
    }
    
    private func retryDelay(forAttempt attempt: Int) -> TimeInterval {
        let baseSeconds = 1.0 * pow(2.0, Double(attempt))
        let jitterSeconds = Double.random(in: 0...(baseSeconds * 0.3))
        return baseSeconds + jitterSeconds
    }
}

private extension ChannelMessageSender {
    
    @discardableResult
    func willSend(_ message: Message) -> Message? {
        if let delegate {
            return delegate.channelMessageSender(self, willSend: message)
        }
        return message
    }
    
    @discardableResult
    func didSend(_ message: Message?, error: Error?) -> Message? {
        if let delegate {
            return delegate.channelMessageSender(self, didSend: message, error: error)
        }
        return message
    }
    
    @discardableResult
    func willResend(_ message: Message) -> Message? {
        if let delegate {
            return delegate.channelMessageSender(self, willResend: message)
        }
        return message
    }
    
    @discardableResult
    func didResend(_ message: Message?, error: Error?) -> Message? {
        if let delegate {
            return delegate.channelMessageSender(self, didResend: message, error: error)
        }
        return message
    }
    
    @discardableResult
    func willEdit(_ message: Message) -> Message? {
        if let delegate {
            return delegate.channelMessageSender(self, willEdit: message)
        }
        return message
    }
    
    @discardableResult
    func didEdit(_ message: Message?, error: Error?) -> Message? {
        if let delegate {
            return delegate.channelMessageSender(self, didEdit: message, error: error)
        }
        return message
    }
    
    @discardableResult
    func willDelete(_ messageId: MessageId) -> MessageId? {
        if let delegate {
            return delegate.channelMessageSender(self, willDelete: messageId)
        }
        return messageId
    }
    
    @discardableResult
    func didDelete(_ messageId: MessageId?, error: Error?) -> MessageId? {
        if let delegate {
            return delegate.channelMessageSender(self, didDelete: messageId, error: error)
        }
        return messageId
    }
}
