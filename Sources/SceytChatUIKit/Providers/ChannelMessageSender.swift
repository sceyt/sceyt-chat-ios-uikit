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

open class ChannelMessageSender: Provider {
    
    public let channelId: ChannelId
    public let channelOperator: ChannelOperator
    public let threadMessageId: MessageId?
    
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
        if ((message.body as NSString).length == 0 && (message.attachments ?? []).isEmpty) || (message.body as NSString).length > 1_000 {
            let data = Data(message.body.utf8)
            let hexString = data.map{ String(format:"%02x", $0) }.joined()
            log.verbose("[EMPTY] Send text message by hex [\(hexString)] orig [\(message.body.prefix(5))]")
        }
        
        log.info("Prepare send message with tid \(message.tid)")
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
                  sentMessage.deliveryStatus != .failed
            else {
                log.errorIfNotNil(error, "Sent message filed status: \(String(describing: sentMessage?.deliveryStatus)), tid \(message.tid)")
                if error?.sceytChatCode == .badMessageParam {
                    self.database.write {
                        $0.deleteMessage(tid: Int64(message.tid))
                    }
                }
                completion?(error)
                return
            }
            log.info("message with tid \(sentMessage.tid) id: \(sentMessage.id) sent successfully")
            self.database.write ({
                $0.update(message: sentMessage, channelId: self.channelId)?
                    .ownerChannel?
                    .lastDisplayedMessageId = Int64(sentMessage.id)
            }) { dbError in
                completion?(error ?? dbError)
            }
        }
        
        store {
            if message.attachments == nil || message.attachments?.count == 0 {
                guard let message = self.willSend(message)
                else {
                    completion?(nil)
                    return
                }
                self.channelOperator.sendMessage(message)
                { sentMessage, error in
                    handleAck(sentMessage: sentMessage, error: error)
                }
            } else {
                log.info("The message has attachments. will send message with tid \(message.tid) after upload")
                let chatMessage = ChatMessage(message: message, channelId: self.channelId)
                self.uploadAttachmentsIfNeeded(message: chatMessage)
                { message, error in
                    if error == nil, let message {
                        log.info("Message attachments uploaded successfully. will send message with tid \(message.tid)")
                        let sendableMessage = message.builder.build()
                        guard let sendableMessage = self.willSend(sendableMessage)
                        else {
                            log.info("Message with tid \(message.tid) build failed can't send message")
                            completion?(nil)
                            return
                        }
                        log.info("Send message with tid \(message.tid)")
                        self.channelOperator.sendMessage(sendableMessage)
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
        if ((chatMessage.body as NSString).length == 0 && (chatMessage.attachments ?? []).isEmpty) || (chatMessage.body as NSString).length > 1_000 {
            let data = Data(chatMessage.body.utf8)
            let hexString = data.map{ String(format:"%02x", $0) }.joined()
            log.verbose("[EMPTY] ReSend text message by hex [\(hexString)] orig [\(chatMessage.body.prefix(5))]")
        }
        log.info("Resend message with tid \(chatMessage.tid) upload attachments if needed")
        uploadAttachmentsIfNeeded(message: chatMessage) { message, error in
            if error == nil, let message {
                let sendableMessage = message.builder.build()
                guard let sendableMessage = self.willResend(sendableMessage)
                else {
                    log.info("Message with tid \(message.tid) build failed can't resend message")
                    completion?(nil)
                    return
                }
                
                func callback(sentMessage: Message?, error: Error?) {
                    if error != nil || sentMessage?.deliveryStatus == .failed {
                        log.errorIfNotNil(error, "Resending message with tid \(String(describing: sentMessage?.tid)) failed")
                    }
                    self.didResend(sentMessage, error: error)
                    guard let sentMessage = sentMessage
                    else {
                        if error?.sceytChatCode == .badMessageParam {
                            self.database.write {
                                $0.deleteMessage(tid: Int64(message.tid))
                            }
                        }
                        log.error("Message with tid \(String(describing: sentMessage?.tid)) build failed can't store message")
                        completion?(error)
                        return
                    }
                    log.info("Message with tid \(sentMessage.tid), id \(sentMessage.id) will store in db")
                    self.database.write ({
                        let ownerChannel =
                        $0.createOrUpdate(
                            message: sentMessage,
                            channelId: self.channelId
                        ).ownerChannel
                        if let ownerChannel,
                           ownerChannel.lastDisplayedMessageId < Int64(sentMessage.id) {
                            ownerChannel.lastDisplayedMessageId = Int64(sentMessage.id)
                        }
                    }, completion: completion)
                }
                switch message.state {
                case .none:
                    log.info("Resending message with tid \(chatMessage.tid)")
                    self.channelOperator.resendMessage(sendableMessage, completion: callback(sentMessage:error:))
                case .edited:
                    log.info("Reediting message with tid \(chatMessage.tid)")
                    self.channelOperator.editMessage(sendableMessage, completion: callback(sentMessage:error:))
                case .deleted:
                    log.info("Redeleting message with tid \(chatMessage.tid)")
                    self.channelOperator.deleteMessage(sendableMessage, forMe: true, completion: callback(sentMessage:error:))
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
                { message, error in
                    if error == nil, let message {
                        let sendableMessage = message.builder.build()
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
        forMeOnly: Bool = false,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard let id = willDelete(id)
        else {
            completion?(nil)
            return
        }
        channelOperator
            .deleteMessage(id: id,
                           forMe: forMeOnly
            ) {message, error in
                self.didDelete(message?.id, error: error)
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
    
    open func uploadAttachmentsIfNeeded(
        message: ChatMessage,
        completion: @escaping (ChatMessage?, Error?) -> Void) {
            guard let attachments = message.attachments?.filter({ $0.status != .done && $0.type != "link" && $0.filePath != nil }),
                  !attachments.isEmpty
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
