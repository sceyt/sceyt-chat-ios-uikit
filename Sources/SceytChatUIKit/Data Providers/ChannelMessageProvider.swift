//
//  ChannelMessageProvider.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import CoreData

open class ChannelMessageProvider: DataProvider {

    public var queryLimit = SceytChatUIKit.shared.config.queryLimits.messageListQueryLimit
    public var maxFetchRetryCount = 3

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
            loadNextMessagesWithRetry(query: query, messageId: nil)
            { messages, error in
                guard let messages = messages
                else {
                    print("[ScrollTest][SCROLL-FETCH] provider.loadNext(initial) SERVER-ERROR error=\(error.map { "\($0)" } ?? "nil")")
                    completion?(error)
                    return
                }
                let _firstId = messages.map { $0.id }.min() ?? 0
                let _lastId = messages.map { $0.id }.max() ?? 0
                print("[ScrollTest][SCROLL-FETCH] provider.loadNext(initial) SERVER-OK count=\(messages.count) firstId=\(_firstId) lastId=\(_lastId) limit=\(query.limit)")
                self.store(
                    messages: messages,
                    completion: { error in
                        print("[ScrollTest][SCROLL-FETCH] provider.loadNext(initial) DB-WRITE-DONE count=\(messages.count) error=\(error.map { "\($0)" } ?? "nil")")
                        completion?(error)
                    }
                )
                self.sendReceivedMarker(messages: messages)
            }
        } else {
            print("[ScrollTest][SCROLL-FETCH] provider.loadNext(initial) QUERY-IN-PROGRESS")
            completion?(SceytChatError.queryInProgress)
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
                loadNextMessagesWithRetry(query: query, messageId: messageId)
                { messages, error in
                    guard let messages = messages
                    else {
                        print("[ScrollTest][SCROLL-FETCH] provider.loadNext SERVER-ERROR after=\(messageId) error=\(error.map { "\($0)" } ?? "nil")")
                        completion?(error)
                        return
                    }
                    let _ids = messages.map { $0.id }
                    let _firstId = _ids.min() ?? 0
                    let _lastId = _ids.max() ?? 0
                    print("[ScrollTest][SCROLL-FETCH] provider.loadNext SERVER-OK after=\(messageId) count=\(messages.count) firstId=\(_firstId) lastId=\(_lastId) limit=\(query.limit)")
                    self.store(
                        messages: messages,
                        triggerMessage: messageId,
                        completion: { error in
                            print("[ScrollTest][SCROLL-FETCH] provider.loadNext DB-WRITE-DONE after=\(messageId) count=\(messages.count) error=\(error.map { "\($0)" } ?? "nil")")
                            completion?(error)
                        }
                    )
                    self.sendReceivedMarker(messages: messages)
                }
            } else {
                print("[ScrollTest][SCROLL-FETCH] provider.loadNext QUERY-IN-PROGRESS after=\(messageId)")
                completion?(SceytChatError.queryInProgress)
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
            loadPrevMessagesWithRetry(query: query, messageId: nil)
            { messages, error in
                guard let messages = messages
                else {
                    print("[ScrollTest][SCROLL-FETCH] provider.loadPrev(initial) SERVER-ERROR error=\(error.map { "\($0)" } ?? "nil")")
                    completion?(error)
                    return
                }
                let _firstId = messages.map { $0.id }.min() ?? 0
                let _lastId = messages.map { $0.id }.max() ?? 0
                print("[ScrollTest][SCROLL-FETCH] provider.loadPrev(initial) SERVER-OK count=\(messages.count) firstId=\(_firstId) lastId=\(_lastId) limit=\(query.limit)")
                self.store(
                    messages: messages,
                    completion: { error in
                        print("[ScrollTest][SCROLL-FETCH] provider.loadPrev(initial) DB-WRITE-DONE count=\(messages.count) error=\(error.map { "\($0)" } ?? "nil")")
                        completion?(error)
                    }
                )
                self.sendReceivedMarker(messages: messages)
            }
        } else {
            print("[ScrollTest][SCROLL-FETCH] provider.loadPrev(initial) QUERY-IN-PROGRESS")
            completion?(SceytChatError.queryInProgress)
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
                loadPrevMessagesWithRetry(query: query, messageId: messageId)
                { messages, error in
                    guard let messages = messages
                    else {
                        print("[ScrollTest][SCROLL-FETCH] provider.loadPrev SERVER-ERROR before=\(messageId) error=\(error.map { "\($0)" } ?? "nil")")
                        completion?(error)
                        return
                    }
                    let _ids = messages.map { $0.id }
                    let _firstId = _ids.min() ?? 0
                    let _lastId = _ids.max() ?? 0
                    print("[ScrollTest][SCROLL-FETCH] provider.loadPrev SERVER-OK before=\(messageId) count=\(messages.count) firstId=\(_firstId) lastId=\(_lastId) limit=\(query.limit)")
                    self.store(
                        messages: messages,
                        triggerMessage: messageId,
                        completion: { error in
                            print("[ScrollTest][SCROLL-FETCH] provider.loadPrev DB-WRITE-DONE before=\(messageId) count=\(messages.count) error=\(error.map { "\($0)" } ?? "nil")")
                            completion?(error)
                        }
                    )
                    self.sendReceivedMarker(messages: messages)
                }
            } else {
                print("[ScrollTest][SCROLL-FETCH] provider.loadPrev QUERY-IN-PROGRESS before=\(messageId)")
                completion?(SceytChatError.queryInProgress)
            }
        }
    
    open func loadNearMessages(
        near messageId: MessageId,
        completion: (([Message]?, Error?) -> Void)? = nil
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
        completion: (([Message]?, Error?) -> Void)? = nil) {
            print("[ScrollTest][SCROLL-FETCH] provider.loadNear REQUEST near=\(messageId) limit=\(query.limit)")
            loadNearMessagesWithRetry(query: query, messageId: messageId)
            { messages, error in
                guard let messages = messages
                else {
                    print("[ScrollTest][SCROLL-FETCH] provider.loadNear SERVER-ERROR near=\(messageId) error=\(error.map { "\($0)" } ?? "nil")")
                    completion?(nil, error)
                    return
                }
                let _firstId = messages.map { $0.id }.min() ?? 0
                let _lastId = messages.map { $0.id }.max() ?? 0
                print("[ScrollTest][SCROLL-FETCH] provider.loadNear SERVER-OK near=\(messageId) count=\(messages.count) firstId=\(_firstId) lastId=\(_lastId)")
                self.store(
                    messages: messages,
                    completion: { _ in
                        print("[ScrollTest][SCROLL-FETCH] provider.loadNear DB-WRITE-DONE near=\(messageId) count=\(messages.count)")
                        completion?(messages, nil)
                    }
                )
                self.sendReceivedMarker(messages: messages)
            }
        }

    private func loadNextMessagesWithRetry(
        query: MessageListQuery,
        messageId: MessageId?,
        attempt: Int = 0,
        completion: @escaping ([Message]?, Error?) -> Void
    ) {
        let loadBlock: (@escaping (MessageListQuery?, [Message]?, Error?) -> Void) -> Void = { callback in
            if let messageId = messageId {
                query.loadNext(messageId: messageId, callback)
            } else {
                query.loadNext(callback)
            }
        }

        loadBlock { [weak self] _, messages, error in
            guard let self else { return }

            guard self.shouldRetryFetch(messages: messages, error: error, attempt: attempt) else {
                completion(messages, error)
                return
            }

            let delay = self.retryDelay(forAttempt: attempt)
            logger.info("Retry fetch next messages, attempt \(attempt + 1)/\(self.maxFetchRetryCount), delay \(Int(delay * 1000))ms")
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                self.loadNextMessagesWithRetry(query: query, messageId: messageId, attempt: attempt + 1, completion: completion)
            }
        }
    }

    private func loadPrevMessagesWithRetry(
        query: MessageListQuery,
        messageId: MessageId?,
        attempt: Int = 0,
        completion: @escaping ([Message]?, Error?) -> Void
    ) {
        let loadBlock: (@escaping (MessageListQuery?, [Message]?, Error?) -> Void) -> Void = { callback in
            if let messageId = messageId {
                query.loadPrevious(messageId: messageId, callback)
            } else {
                query.loadPrevious(callback)
            }
        }

        loadBlock { [weak self] _, messages, error in
            guard let self else { return }

            guard self.shouldRetryFetch(messages: messages, error: error, attempt: attempt) else {
                completion(messages, error)
                return
            }

            let delay = self.retryDelay(forAttempt: attempt)
            logger.info("Retry fetch prev messages, attempt \(attempt + 1)/\(self.maxFetchRetryCount), delay \(Int(delay * 1000))ms")
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                self.loadPrevMessagesWithRetry(query: query, messageId: messageId, attempt: attempt + 1, completion: completion)
            }
        }
    }

    private func loadNearMessagesWithRetry(
        query: MessageListQuery,
        messageId: MessageId,
        attempt: Int = 0,
        completion: @escaping ([Message]?, Error?) -> Void
    ) {
        query.loadNear(messageId: messageId) { [weak self] _, messages, error in
            guard let self else { return }

            guard self.shouldRetryFetch(messages: messages, error: error, attempt: attempt) else {
                completion(messages, error)
                return
            }

            let delay = self.retryDelay(forAttempt: attempt)
            logger.info("Retry fetch near messages, attempt \(attempt + 1)/\(self.maxFetchRetryCount), delay \(Int(delay * 1000))ms")
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                self.loadNearMessagesWithRetry(query: query, messageId: messageId, attempt: attempt + 1, completion: completion)
            }
        }
    }

    // TODO: Optimize this
    open func store(
        messages: [Message],
        triggerMessage: MessageId? = nil,
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
        
        guard let startMessageId = messages.min(by: { $0.id < $1.id})?.id,
              let endMessageId = messages.max(by: { $0.id < $1.id})?.id
        else { return }
        
        database.performWriteTask {
            $0.updateRanges(
                startMessageId: startMessageId,
                endMessageId: endMessageId,
                triggerMessage: triggerMessage,
                channelId: self.channelId)
        } completion: { _ in
            
        }
    }
    
    open func storePending(
        message: Message,
        completion: ((Error?) -> Void)? = nil
    ) {
        database.performWriteTask ({
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
    
    // MARK: - Poll Operations

    open func addPollVote(
        messageId: MessageId,
        pollId: String,
        optionId: String,
        storeForResend: Bool = true,
        completion: ((Error?) -> Void)? = nil
    ) {
        database.write {
            if storeForResend {
                // Store pending votes for each option
                if let messageDTO = MessageDTO.fetch(id: messageId, context: $0) {
                    if let userId = SceytChatUIKit.shared.currentUserId, !userId.isEmpty {
                        // Cancel any existing pending vote for the same option
                        if let existingPendingVote = PendingVoteDTO.fetch(
                            pollId: pollId,
                            optionId: optionId,
                            userId: userId,
                            context: $0
                        ) {
                            $0.delete(existingPendingVote)
                        }

                        // Create fresh pending vote
                        let pendingVote = PendingVoteDTO.fetchOrCreate(
                            pollId: pollId,
                            optionId: optionId,
                            userId: userId,
                            messageTid: messageDTO.tid,
                            context: $0
                        )
                        pendingVote.isAdd = true
                        pendingVote.createdAt = Int64(Date().timeIntervalSince1970 * 1000)
                    }
                }
            }
        } completion: { _ in
            self.channelOperator.addPollVote(
                messageId: messageId,
                pollId: pollId,
                optionIds: [optionId]
            ) { changedVotes, message, error in
                if let error {
                    if error.code == 1301 {
                        self.database.write { context in
                            self.deletePendingVote(pollId: pollId, optionId: optionId, context: context)
                        }
                    }

                    completion?(error)
                    return
                }

                guard let changedVotes else {
                    completion?(error)
                    return
                }
                
                guard let message = message else {
                    completion?(error)
                    return
                }

                self.database.write { context in
                    // Remove pending votes after successful vote
                    if let messageDTO = MessageDTO.fetch(id: message.id, context: context) {
                        self.deletePendingVote(pollId: pollId, optionId: optionId, context: context)
                        // Apply changed votes to ownVotes
                        context.applyChangedVotes(changedVotes, pollId: pollId, messageDTO: messageDTO)
                    }
                } completion: { _ in
                    completion?(nil)
                }
            }
        }
    }

    private func deletePendingVote(pollId: String, optionId: String, context: NSManagedObjectContext) {
        if let userId = SceytChatUIKit.shared.currentUserId, !userId.isEmpty {
            if let pendingVote = PendingVoteDTO.fetch(
                pollId: pollId,
                optionId: optionId,
                userId: userId,
                context: context
            ) {
                context.delete(pendingVote)
            }
        }
    }
    
    open func deletePollVote(
        messageId: MessageId,
        pollId: String,
        optionId: String,
        storeForResend: Bool = true,
        completion: ((Error?) -> Void)? = nil
    ) {
        database.write {
            if storeForResend {
                // Store pending vote removals
                if let messageDTO = MessageDTO.fetch(id: messageId, context: $0) {
                    if let userId = SceytChatUIKit.shared.currentUserId, !userId.isEmpty {
                        // Cancel any existing pending vote for the same option
                        if let existingPendingVote = PendingVoteDTO.fetch(
                            pollId: pollId,
                            optionId: optionId,
                            userId: userId,
                            context: $0
                        ) {
                            $0.delete(existingPendingVote)
                        }
                        
                        // Create fresh pending vote removal
                        let pendingVote = PendingVoteDTO.fetchOrCreate(
                            pollId: pollId,
                            optionId: optionId,
                            userId: userId,
                            messageTid: messageDTO.tid,
                            context: $0
                        )
                        pendingVote.isAdd = false
                        pendingVote.createdAt = Int64(Date().timeIntervalSince1970 * 1000)
                    }
                }
            }
        } completion: { _ in
            self.channelOperator.deletePollVote(
                messageId: messageId,
                pollId: pollId,
                optionIds: [optionId]
            ) { changedVotes, message, error in
                if let error {
                    if error.code == 1301 {
                        self.database.write { context in
                            self.deletePendingVote(pollId: pollId, optionId: optionId, context: context)
                        }
                    }

                    completion?(error)
                    return
                }

                guard let changedVotes else {
                    completion?(error)
                    return
                }

                guard let message = message else {
                    completion?(error)
                    return
                }

                self.database.write { context in
                    // Remove pending votes after successful deletion
                    if let messageDTO = MessageDTO.fetch(id: message.id, context: context) {
                        self.deletePendingVote(pollId: pollId, optionId: optionId, context: context)
                        // Apply changed votes to ownVotes
                        context.applyChangedVotes(changedVotes, pollId: pollId, messageDTO: messageDTO)
                    }
                } completion: { _ in
                    completion?(nil)
                }
            }
        }
    }
    
    open func retractPollVote(
        messageId: MessageId,
        pollId: String,
        storeForResend: Bool = true,
        completion: ((Error?) -> Void)? = nil
    ) {
        database.write { context in
            // Remove any pending votes for this poll
            if let messageDTO = MessageDTO.fetch(id: messageId, context: context) {
                let pendingVotes = PendingVoteDTO.fetch(messageTid: messageDTO.tid, context: context)
                pendingVotes.forEach { pendingVote in
                    if pendingVote.pollId == pollId {
                        context.delete(pendingVote)
                    }
                }
            }
        } completion: { _ in
            self.channelOperator.retractPollVote(
                messageId: messageId,
                pollId: pollId
            ) { changedVotes, message, error in
                guard let changedVotes else {
                    completion?(error)
                    return
                }

                guard let message = message else {
                    completion?(error)
                    return
                }

                self.database.write { context in
                    if let messageDTO = MessageDTO.fetch(id: message.id, context: context) {
                        // Apply changed votes to ownVotes
                        context.applyChangedVotes(changedVotes, pollId: pollId, messageDTO: messageDTO)
                    }
                } completion: { _ in
                    completion?(nil)
                }
            }
        }
    }
    
    open func closePoll(
        messageId: MessageId,
        pollId: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        channelOperator.closePoll(
            messageId: messageId,
            pollId: pollId
        ) { voteDetails, message, error in
            if let error {
                completion?(error)
                return
            }
            guard let message = message else {
                completion?(error)
                return
            }
            self.database.write { context in
                guard let messageDTO = MessageDTO.fetch(id: message.id, context: context),
                      let pollDTO = messageDTO.poll else {
                    return
                }

                // Update poll to closed state
                pollDTO.closed = true
                if let closedAt = message.poll?.closedAt {
                    pollDTO.closedAt = Int64(closedAt.timeIntervalSince1970)
                }

                // Update votes
                if let votes = voteDetails?.votes {
                    let voteDTOs = votes.map { vote -> PollVoteDTO in
                        let voteDTO = PollVoteDTO.fetchOrCreate(
                            optionId: vote.optionId,
                            userId: vote.user.id,
                            pollId: pollId,
                            context: context
                        ).map(vote)
                        voteDTO.user = context.createOrUpdate(user: vote.user)
                        voteDTO.pollDetails = pollDTO
                        return voteDTO
                    }

                    let votesSet = pollDTO.mutableOrderedSetValue(forKey: "votes")
                    votesSet.removeAllObjects()
                    votesSet.addObjects(from: voteDTOs)
                }

                // Update ownVotes
                if let ownVotes = voteDetails?.ownVotes {
                    let ownVoteDTOs = ownVotes.map { vote -> PollVoteDTO in
                        let voteDTO = PollVoteDTO.fetchOrCreate(
                            optionId: vote.optionId,
                            userId: vote.user.id,
                            pollId: pollId,
                            context: context
                        ).map(vote)
                        voteDTO.user = context.createOrUpdate(user: vote.user)
                        voteDTO.ownPollDetails = pollDTO
                        return voteDTO
                    }

                    let ownVotesSet = pollDTO.mutableOrderedSetValue(forKey: "ownVotes")
                    ownVotesSet.removeAllObjects()
                    ownVotesSet.addObjects(from: ownVoteDTOs)
                }

                // Update votesPerOption
                if let votesPerOption = voteDetails?.votesPerOption, !votesPerOption.isEmpty {
                    var dict: [String: NSNumber] = [:]
                    for (key, value) in votesPerOption {
                        dict[key] = value
                    }
                    pollDTO.votesPerOption = dict as NSDictionary
                }

            } completion: { _ in
                // Post notification to force UI reload after poll is closed
                NotificationCenter.default.post(
                    name: .didClosePoll,
                    object: nil,
                    userInfo: [
                        "messageId": messageId,
                        "pollId": pollId,
                        "channelId": self.channelId
                    ]
                )
                completion?(nil)
            }
        }
    }
    
    open func markMessagesAsReceived (
        ids: [MessageId],
        storeForResend: Bool = true,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard !ids.isEmpty else { return }
        if storeForResend {
            print("[ScrollTest][SCROLL-MARKER] markMessagesAsReceived.writePending count=\(ids.count) channelId=\(self.channelId)")
            database.write ({
                $0.update(messagePendingMarkers: ids, markerName: DefaultMarker.received.rawValue)
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
            print("[ScrollTest][SCROLL-MARKER] markMessagesAsReceived.writeSelfMarkers count=\(markerList.messageIds.count) channelId=\(self.channelId)")
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
            print("[ScrollTest][SCROLL-MARKER] markMessagesAsDisplayed.writePending count=\(ids.count) channelId=\(self.channelId)")
            database.write ({
                $0.update(messagePendingMarkers: ids, markerName: DefaultMarker.displayed.rawValue)
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
            print("[ScrollTest][SCROLL-MARKER] markMessagesAsDisplayed.writeSelfMarkers count=\(markerList.messageIds.count) channelId=\(self.channelId)")
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
            print("[ScrollTest][SCROLL-MARKER] markMessages.writePending count=\(ids.count) marker=\(markerName) channelId=\(self.channelId)")
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
            print("[ScrollTest][SCROLL-MARKER] markMessages.writeSelfMarkers count=\(markerList.messageIds.count) marker=\(markerName) channelId=\(self.channelId)")
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
                $0.update(messagePendingMarkers: [MessageId(dto.id)], markerName: DefaultMarker.received.rawValue)
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
    
    public class func fetchPendingPollVotes(
        _ completion: @escaping ([(PendingPollVote, MessageId, ChannelId)]) -> Void) {
            database.performBgTask(resultQueue: .global()) {
                let request = PendingVoteDTO.fetchRequest()
                request.sortDescriptor = NSSortDescriptor(keyPath: \PendingVoteDTO.createdAt, ascending: true)
                let context = $0
                return PendingVoteDTO.fetch(request: request, context: context)
                    .compactMap { pendingVoteDTO in
                        // Get message from messageTid
                        if let messageDTO = MessageDTO.fetch(tid: pendingVoteDTO.messageTid, context: context),
                           let pollId = pendingVoteDTO.pollId,
                           let optionId = pendingVoteDTO.optionId {
                            let pendingVote = PendingPollVote(dto: pendingVoteDTO)
                            return (pendingVote, MessageId(messageDTO.id), ChannelId(messageDTO.channelId))
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

            database.write(resultQueue: .global()) { context in
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
                let converted = chatMessages.compactMap { ChatMessage(dto: $0 as! MessageDTO)}
                DispatchQueue.main.async {
                    completion(converted)
                }
            } completion: { error in
                completion(nil)
            }
        }

    /// Deletes expired auto-delete messages from the database
    /// This should be called when starting the database observer to clean up expired messages
    open func deleteExpiredAutoDeleteMessages() {
        Self.deleteExpiredAutoDeleteMessages()
    }

    private func shouldRetryFetch(messages: [Message]?, error: Error?, attempt: Int) -> Bool {
        guard messages == nil || messages?.isEmpty == true else { return false }
        guard chatClient.connectionState == .connected else { return false }
        guard attempt < max(0, maxFetchRetryCount) else { return false }
        return error?.sdkError?.isResendable == true
    }

    private func retryDelay(forAttempt attempt: Int) -> TimeInterval {
        let baseSeconds = 1.0 * pow(2.0, Double(attempt))
        let jitterSeconds = Double.random(in: 0...(baseSeconds * 0.3))
        return baseSeconds + jitterSeconds
    }
}

private extension ChannelMessageProvider {

    func sendReceivedMarker(messages: [Message]) {
        DispatchQueue.global(qos: .background).async {
            let ids: [MessageId] = messages.compactMap { message in
                let alreadyReceived = message.userMarkers?.contains { $0.name == DefaultMarker.received.rawValue } ?? false
                if message.incoming && !alreadyReceived {
                    return message.id
                }
                return nil
            }

            guard !ids.isEmpty else { return }
            self.markMessagesAsReceived(ids: ids)
        }
    }
}
