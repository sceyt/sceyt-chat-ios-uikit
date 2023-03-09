//
//  ChannelMessageSender.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class ChannelMessageSender: Provider {
    
    public let channelId: ChannelId
    public let channelOperator: ChannelOperator
    public let threadMessageId: MessageId?
    
    private lazy var messageProvider = ChannelMessageProvider(channelId: channelId, threadMessageId: threadMessageId)
    
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
                ).ownerChannel?
                    .lastDisplayedMessageId = Int64(sentMessage.id)
            }, completion: completion)
        }
        
        store {
            if message.attachments == nil || message.attachments?.count == 0 {
                self.channelOperator.sendMessage(message)
                { sentMessage, error in
                    handleAck(sentMessage: sentMessage, error: error)
                }
            } else {
                let chatMessage = ChatMessage(message: message, channelId: self.channelId)
                self.uploadAttachmentsIfNeeded(message: chatMessage)
                { message, error in
                    if error == nil, let message {
                        let sendableMessage = message.builder.build()
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
        uploadAttachmentsIfNeeded(message: chatMessage) { message, error in
            if error == nil, let message {
                let sendableMessage = message.builder.build()
                self.channelOperator.resendMessage(sendableMessage)
                {sentMessage, error in
                    guard let sentMessage = sentMessage
                    else {
                        completion?(error)
                        return
                    }
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
                    let ownerChannel =
                    $0.createOrUpdate(
                        message: message,
                        channelId: self.channelId
                    )
                }) { _ in
                    completion()
                }
            } else {
                completion()
            }
        }
        
        func handleAck(sentMessage: Message?, error: Error?) {
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
            if message.attachments == nil {
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
        channelOperator
            .deleteMessage(id: id,
                           forMe: forMeOnly
            ) {message, error in
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
            let needsToUploadAttachments = attachments.filter {
                $0.status != .pauseUploading
            }
            fileProvider
                .uploadMessageAttachments(
                    message: message,
                    attachments: needsToUploadAttachments
                ) { chatMessage, error in
                    completion(chatMessage, error)
                }
        }
    
    open func isNeedToUpload(attachment: ChatMessage.Attachment) -> Bool {
        attachment.status != .done && attachment.type != "link" && attachment.filePath != nil
    }
}
