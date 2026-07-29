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
            Self.endSend(tid: Int64(message.tid))
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
            let sendAckTid = sentMessage.tid
            var suppressedDelete: PendingMessageDelete?
            // `database.write` can report completion twice (see `OneShotCompletion`), and this one
            // starts a network request, so it must not be repeated.
            let flushOnce = OneShotCompletion { [weak self] _ in
                guard let self, let suppressedDelete else { return }
                self.flushPendingDelete(suppressedDelete, force: true)
            }
            self.database.write ({
                logger.info("[SendAck] tid \(sendAckTid) write block started")
                let predicate = NSPredicate(format: "channelId == %lld AND id > 0", self.channelId)
                let message = MessageDTO.lastMessage(predicate: predicate, context: $0)
                let channel = ChannelDTO.fetch(id: self.channelId, context: $0)
                let lastMessageId = message?.id
                switch $0.resolveSendAck(sentMessage: sentMessage, channelId: self.channelId) {
                case .suppressedByPendingDelete(let tid, let serverMessageId):
                    // The user deleted this message while it was being sent. Don't store it;
                    // the delete is retried below, now that the server id is known.
                    logger.info("[SendAck] tid \(tid) suppressed: pending delete exists, server id \(serverMessageId)")
                    suppressedDelete = $0.pendingMessageDelete(messageTid: tid, channelId: self.channelId)?.convert()
                case .stored:
                    logger.info("[SendAck] tid \(sendAckTid) createOrUpdate done")
                    if let channel {
                        channel.lastReceivedMessageId = Int64(sentMessage.id)
                        let min = min(sentMessage.id, MessageId(lastMessageId ?? Int64(sentMessage.id)))
                        let max = max(sentMessage.id, MessageId(lastMessageId ?? Int64(sentMessage.id)))
                        $0.updateRanges(startMessageId: min, endMessageId: max, channelId: ChannelId(channel.id))
                        if channel.lastDisplayedMessageId < Int64(sentMessage.id) {
                            channel.lastDisplayedMessageId = Int64(sentMessage.id)
                        }
                    }
                }
                logger.info("[SendAck] tid \(sendAckTid) channel update done, block end")
            }) { dbError in
                logger.info("[SendAck] tid \(sendAckTid) database.write completion, error: \(String(describing: dbError))")
                flushOnce.fire(nil)
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
                Self.beginSend(tid: Int64(message.tid))
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
                        Self.beginSend(tid: Int64(sendableMessage.tid))
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
                    Self.endSend(tid: Int64(sendableMessage.tid))
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
                    let resendAckTid = sentMessage.tid
                    var suppressedDelete: PendingMessageDelete?
                    // `database.write` can report completion twice (see `OneShotCompletion`), and
                    // this one starts a network request, so it must not be repeated.
                    let flushOnce = OneShotCompletion { [weak self] _ in
                        guard let self, let suppressedDelete else { return }
                        self.flushPendingDelete(suppressedDelete, force: true)
                    }
                    self.database.write ({
                        logger.info("[ResendAck] tid \(resendAckTid) write block started")
                        let predicate = NSPredicate(format: "channelId == %lld AND id > 0", self.channelId)
                        let message = MessageDTO.lastMessage(predicate: predicate, context: $0)
                        let channel = ChannelDTO.fetch(id: self.channelId, context: $0)
                        let lastMessageId = message?.id

                        // Preserve pending votes from the original message
                        var pendingVotes: NSSet? = nil
                        if chatMessage.poll?.pendingVotes != nil {
                            let existingMessageDTO = MessageDTO.fetch(tid: Int64(chatMessage.tid), channelId: Int64(self.channelId), context: $0)
                            pendingVotes = existingMessageDTO?.poll?.pendingVotes
                        }

                        switch $0.resolveSendAck(sentMessage: sentMessage, channelId: self.channelId) {
                        case .suppressedByPendingDelete(let tid, let serverMessageId):
                            // The user deleted this message while it was being resent. Don't store
                            // it; the delete is retried below with the now known server id.
                            logger.info("[ResendAck] tid \(tid) suppressed: pending delete exists, server id \(serverMessageId)")
                            suppressedDelete = $0.pendingMessageDelete(messageTid: tid, channelId: self.channelId)?.convert()
                        case .stored:
                            logger.info("[ResendAck] tid \(resendAckTid) createOrUpdate done")

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
                        }
                        logger.info("[ResendAck] tid \(resendAckTid) channel update done, block end")
                    }) { dbError in
                        logger.info("[ResendAck] tid \(resendAckTid) database.write completion, error: \(String(describing: dbError))")
                        flushOnce.fire(nil)
                        completion?(dbError)
                    }
                }
                Self.beginSend(tid: Int64(sendableMessage.tid))
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
    
    /// Deletes a message that has no server id yet (delivery status `pending` or `failed`).
    ///
    /// The message is identified on the server by its `tid`, because `deleteMessage(id:type:)`
    /// can't be used with id `0`. The local row is removed immediately so the UI reacts at once,
    /// and in the same transaction a `PendingMessageDeleteDTO` records the intent: the server may
    /// already hold the message (ack lost, or a queued send lands later), so the request is
    /// retried by `SyncService` until the server confirms it or the intent is dropped as terminal.
    open func deleteMessage(
        pendingMessage: ChatMessage,
        type: DeleteMessageType = .deleteForMe,
        completion: ((Error?) -> Void)? = nil
    ) {
        let tid = pendingMessage.tid
        logger.info("Deleting pending message with tid \(tid) in channel \(channelId), type \(type.rawValue)")
        var record: PendingMessageDelete?
        // The write completion can fire twice on a save error and this one sends a request.
        let once = OneShotCompletion { [weak self] dbError in
            guard let self, let record else {
                logger.errorIfNotNil(dbError, "Storing pending delete for tid \(tid) failed")
                completion?(dbError)
                return
            }
            self.flushPendingDelete(record) { error in
                completion?(error ?? dbError)
            }
        }
        database.performWriteTask ({ context in
            let dto = context.addPendingMessageDelete(
                messageTid: tid,
                channelId: self.channelId,
                messageId: pendingMessage.id,
                type: type
            )
            context.deleteMessage(tid: tid, channelId: self.channelId)
            record = dto.convert()
        }) { dbError in
            once.fire(dbError)
        }
    }

    /// Makes one attempt to tell the server about a stored delete intent, then updates or removes
    /// the record according to `PendingMessageDeleteRetryPolicy`.
    ///
    /// - Parameter force: bypasses the "a send for this tid is in flight" guard. Only the send ack
    ///   itself passes `true`, because it has just learned the server id and holds the outcome.
    open func flushPendingDelete(
        _ record: PendingMessageDelete,
        force: Bool = false,
        completion: ((Error?) -> Void)? = nil
    ) {
        if !force, Self.isSending(tid: record.messageTid) {
            // The ack will resolve the record via `resolveSendAck`, with the real message id.
            logger.info("Skip pending delete flush for tid \(record.messageTid): a send is in flight")
            completion?(nil)
            return
        }
        let once = OneShotCompletion(completion)
        let ack: (Message?, Error?) -> Void = { [weak self] message, error in
            guard let self else {
                once.fire(error)
                return
            }
            logger.errorIfNotNil(error, "Deleting pending message with tid \(record.messageTid) failed")
            self.resolvePendingDelete(record, message: message, error: error, completion: once.fire)
        }
        if record.messageId > 0 {
            logger.info("Flushing pending delete for tid \(record.messageTid) by id \(record.messageId)")
            channelOperator.deleteMessage(id: record.messageId, type: record.type, completion: ack)
        } else {
            logger.info("Flushing pending delete for tid \(record.messageTid) by tid")
            channelOperator.deleteMessage(tid: .init(record.messageTid), type: record.type, completion: ack)
        }
    }

    private func resolvePendingDelete(
        _ record: PendingMessageDelete,
        message: Message?,
        error: Error?,
        completion: ((Error?) -> Void)?
    ) {
        let outcome = PendingMessageDeleteRetryPolicy.outcome(error: error)
        switch outcome {
        case .done:
            logger.info("Pending delete for tid \(record.messageTid) confirmed by the server")
        case .drop(let reason):
            logger.info("Dropping pending delete for tid \(record.messageTid): \(reason)")
        case .retry:
            logger.info("Keeping pending delete for tid \(record.messageTid) for a later retry, attempt \(record.retryCount + 1)")
        }
        database.write ({ context in
            switch outcome {
            case .done, .drop:
                context.removePendingMessageDelete(messageTid: record.messageTid, channelId: record.channelId)
                // Nothing must survive locally: a late ack may have recreated the row.
                context.deleteMessage(tid: record.messageTid, channelId: record.channelId)
                if let id = message?.id, id > 0 {
                    context.deleteMessage(id: id)
                }
            case .retry:
                guard let dto = context.pendingMessageDelete(
                    messageTid: record.messageTid,
                    channelId: record.channelId
                ) else { return }
                dto.retryCount += 1
                dto.lastAttemptAt = Int64(Date().timeIntervalSince1970 * 1000)
                if let id = message?.id, id > 0 {
                    dto.messageId = Int64(id)
                }
            }
        }) { _ in
            completion?(outcome.isRetry ? error : nil)
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

// MARK: - In flight sends

public extension ChannelMessageSender {

    /// Tids currently being sent or resent, refcounted because the same tid can be retried.
    ///
    /// A pending delete must not be flushed while a send for the same tid is in flight: the send
    /// ack is the only place that learns the server id, and it resolves the intent itself
    /// (see `MessageDatabaseSession.resolveSendAck(sentMessage:channelId:)`).
    private struct InFlightSend {
        var count: Int
        let startedAt: Date
    }

    /// An entry older than this is ignored, so a send whose callback never arrives can't block
    /// its delete for the rest of the session.
    public static var inFlightSendStaleInterval: TimeInterval = 60

    private static let inFlightLock = NSLock()
    nonisolated(unsafe) private static var inFlightSendTids = [Int64: InFlightSend]()

    static func beginSend(tid: Int64) {
        guard tid != 0 else { return }
        inFlightLock.lock()
        defer { inFlightLock.unlock() }
        if let existing = inFlightSendTids[tid] {
            inFlightSendTids[tid] = InFlightSend(count: existing.count + 1, startedAt: existing.startedAt)
        } else {
            inFlightSendTids[tid] = InFlightSend(count: 1, startedAt: Date())
        }
    }

    static func endSend(tid: Int64) {
        guard tid != 0 else { return }
        inFlightLock.lock()
        defer { inFlightLock.unlock() }
        guard let existing = inFlightSendTids[tid] else { return }
        if existing.count <= 1 {
            inFlightSendTids[tid] = nil
        } else {
            inFlightSendTids[tid] = InFlightSend(count: existing.count - 1, startedAt: existing.startedAt)
        }
    }

    static func isSending(tid: Int64, now: Date = Date()) -> Bool {
        inFlightLock.lock()
        defer { inFlightLock.unlock() }
        guard let existing = inFlightSendTids[tid] else { return false }
        guard now.timeIntervalSince(existing.startedAt) <= inFlightSendStaleInterval else {
            logger.info("Send for tid \(tid) has been in flight for too long, stop treating it as pending")
            inFlightSendTids[tid] = nil
            return false
        }
        return true
    }
}
