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
            let reconcile = self.pageReconciler(source: .next, anchor: nil, limit: query.limit)
            loadNextMessagesWithRetry(query: query, messageId: nil)
            { messages, error in
                guard let messages = messages
                else {
                    completion?(error)
                    return
                }
                self.store(
                    messages: messages,
                    reconciliation: reconcile(messages, query.hasNext),
                    completion: { error in
                        completion?(error)
                    }
                )
                self.sendReceivedMarker(messages: messages)
            }
        } else {
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
                let reconcile = self.pageReconciler(source: .nextAfter, anchor: messageId, limit: query.limit)
                loadNextMessagesWithRetry(query: query, messageId: messageId)
                { messages, error in
                    guard let messages = messages
                    else {
                        completion?(error)
                        return
                    }
                    self.store(
                        messages: messages,
                        triggerMessage: messageId,
                        reconciliation: reconcile(messages, query.hasNext),
                        completion: { error in
                            completion?(error)
                        }
                    )
                    self.sendReceivedMarker(messages: messages)
                }
            } else {
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
            let reconcile = self.pageReconciler(source: .prev, anchor: nil, limit: query.limit)
            loadPrevMessagesWithRetry(query: query, messageId: nil)
            { messages, error in
                guard let messages = messages
                else {
                    completion?(error)
                    return
                }
                self.store(
                    messages: messages,
                    reconciliation: reconcile(messages, query.hasNext),
                    completion: completion
                )
                self.sendReceivedMarker(messages: messages)
            }
        } else {
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
                let reconcile = self.pageReconciler(source: .prevBefore, anchor: messageId, limit: query.limit)
                loadPrevMessagesWithRetry(query: query, messageId: messageId)
                { messages, error in
                    guard let messages = messages
                    else {
                        completion?(error)
                        return
                    }
                    self.store(
                        messages: messages,
                        triggerMessage: messageId,
                        reconciliation: reconcile(messages, query.hasNext),
                        completion: completion
                    )
                    self.sendReceivedMarker(messages: messages)
                }
            } else {
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
            let reconcile = self.pageReconciler(source: .near, anchor: messageId, limit: query.limit)
            loadNearMessagesWithRetry(query: query, messageId: messageId)
            { messages, error in
                guard let messages = messages
                else {
                    completion?(nil, error)
                    return
                }
                self.store(
                    messages: messages,
                    reconciliation: reconcile(messages, query.hasNext),
                    completion: { _ in
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
    /// Stores a server page and, when `reconciliation` is given, deletes in the same write the
    /// stored rows the page proves are gone on the server (hard deletes whose event was missed).
    ///
    /// One method with a defaulted parameter, not an overload: every page load and every other
    /// caller goes through it, so a subclass override sees them all.
    open func store(
        messages: [Message],
        triggerMessage: MessageId? = nil,
        reconciliation: MessagePageReconciliation? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        let startMessageId = messages.min(by: { $0.id < $1.id})?.id
        let endMessageId = messages.max(by: { $0.id < $1.id})?.id
        database.write ({
            $0.createOrUpdate(
                messages: messages,
                channelId: self.channelId
            )
            if let reconciliation {
                $0.deleteMessagesMissing(from: reconciliation)
            }
        }) { error in
            // The range is written on its own context, unordered against the message
            // write above, and every caller re-anchors the observer from `completion` —
            // `restartToNear` reads the ranges back (`maxRange`) to build its window.
            // Completing before the range has landed hands that lookup a stale or
            // missing range, so the completion waits for both writes.
            guard error == nil, let startMessageId, let endMessageId else {
                completion?(error)
                return
            }
            self.database.performWriteTask {
                $0.updateRanges(
                    startMessageId: startMessageId,
                    endMessageId: endMessageId,
                    triggerMessage: triggerMessage,
                    channelId: self.channelId)
            } completion: { _ in
                completion?(nil)
            }
        }
    }
    
    /// Stores a new outgoing message before it is sent.
    ///
    /// Runs on a context of its own (`performWriteTask`), not the serial writer, so the bubble
    /// and the send never wait behind other queued writes (message pages, sync, markers). The
    /// cost: the newest-row lookup below sees only committed rows, so an incoming message still
    /// being written, or another pending store running at the same moment, can be missed.
    open func storePending(
        message: Message,
        completion: ((Error?) -> Void)? = nil
    ) {
        database.performWriteTask ({
            let stored = $0.createOrUpdate(
                message: message,
                channelId: self.channelId
            )
            // Never above the newest message: with a phone clock behind the server, the phone's
            // time would put the new message above one received just before it. The server's
            // time replaces this one on the ack (`MessageDTO.map(_:)`), which then stays below too.
            // Only the stored row is changed: the caller keeps using `message` (send payload,
            // in-memory model) on other threads, so it must not be written to from here.
            if let newest = Self.newestListCreatedAt(
                for: stored,
                threadMessageId: self.threadMessageId,
                context: $0
            ), stored.createdAt.bridgeDate <= newest {
                stored.createdAt = newest.addingTimeInterval(0.001).bridgeDate
                Self.promoteToLastMessageIfNewer(stored, channelId: self.channelId, context: $0)
            }
            if let ownerChannel = ChannelDTO.fetch(id: self.channelId, context: $0),
                let createdAt = ownerChannel.lastMessage?.createdAt.bridgeDate,
               createdAt < stored.createdAt.bridgeDate {
                ownerChannel.lastDisplayedMessageId = 0
            }
        }) { error in
            completion?(error)
        }
    }
    
    /// `createdAt` of the newest other row in the list `row` belongs to, with the same rules and
    /// sort as that list: the channel's main list (`LazyMessagesObserver.listPredicate`), or, for
    /// a thread reply, the thread's replies. `nil` when there is none, or when a thread reply's
    /// thread is unknown (no list to place it in, so it keeps its own time).
    static func newestListCreatedAt(
        for row: MessageDTO,
        threadMessageId: MessageId?,
        context: NSManagedObjectContext
    ) -> Date? {
        let listPredicate: NSPredicate
        if row.repliedInThread {
            guard let threadId = threadMessageId ?? row.parent.map({ MessageId($0.id) }),
                  threadId > 0
            else { return nil }
            listPredicate = NSPredicate(
                format: "channelId == %lld AND repliedInThread == true AND parent.id == %lld AND unlisted == false",
                row.channelId,
                Int64(threadId)
            )
        } else {
            listPredicate = LazyMessagesObserver.listPredicate(channelId: ChannelId(row.channelId))
        }
        let request = MessageDTO.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            listPredicate,
            NSPredicate(format: "SELF != %@", row)
        ])
        request.sortDescriptors = [
            .init(keyPath: \MessageDTO.createdAt, ascending: false),
            .init(keyPath: \MessageDTO.id, ascending: false)
        ]
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first?.createdAt.bridgeDate
    }

    /// Re-runs `createOrUpdate`'s last-message rule for an unsent row (by `createdAt`) after its
    /// time was moved forward, since that rule saw the phone's time.
    private static func promoteToLastMessageIfNewer(
        _ row: MessageDTO,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) {
        guard row.id == 0,
              let channel = ChannelDTO.fetch(id: channelId, context: context),
              channel.lastMessage != row
        else { return }
        if let lastMessage = channel.lastMessage,
           lastMessage.createdAt.bridgeDate >= row.createdAt.bridgeDate {
            return
        }
        channel.lastMessage = row
        if let lastReactionAt = channel.lastReaction?.createdAt?.bridgeDate,
           row.createdAt.bridgeDate > lastReactionAt {
            channel.lastReaction = nil
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
                        let pollDTO = messageDTO.poll ?? PollDTO.fetch(id: pollId, context: $0)
                        if pollDTO?.allowMultipleVotes == false {
                            // A single-vote poll carries at most one vote, and the server swaps it
                            // on every add. A new tap therefore supersedes EVERY stored pending
                            // vote for this poll, not just the one for the same option — otherwise
                            // the reconnect replay fires one add per option and whichever lands
                            // last wins, not the user's last tap.
                            let context = $0
                            PendingVoteDTO.fetch(pollId: pollId, userId: userId, context: context)
                                .forEach { context.delete($0) }
                        } else if let existingPendingVote = PendingVoteDTO.fetch(
                            pollId: pollId,
                            optionId: optionId,
                            userId: userId,
                            context: $0
                        ) {
                            // Cancel any existing pending vote for the same option
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
                    // No error and no changed votes: the server accepted the request but the vote
                    // was already in the target state (e.g. re-adding an option that never got
                    // removed server-side). Clear the pending row — keeping it would replay this
                    // no-op on every reconnect and hold the stale-snapshot guard engaged forever.
                    self.database.write { context in
                        self.deletePendingVote(pollId: pollId, optionId: optionId, context: context)
                    } completion: { _ in
                        completion?(nil)
                    }
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
                    // No error and no changed votes: the vote was already absent server-side.
                    // Clear the pending row so it is not replayed on every reconnect.
                    self.database.write { context in
                        self.deletePendingVote(pollId: pollId, optionId: optionId, context: context)
                    } completion: { _ in
                        completion?(nil)
                    }
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
                // A message the user already deleted must never be resent, even if some path
                // recreated its row while the delete was still being retried.
                let deletedTids = Set(PendingMessageDeleteDTO.fetchAll(context: $0).map { $0.messageTid })
                return MessageDTO.fetch(request: request, context: $0)
                    .compactMap { dto -> ChatMessage? in
                        if deletedTids.contains(dto.tid) {
                            logger.info("Skip resending message with tid \(dto.tid): a pending delete exists for it")
                            return nil
                        }
                        return dto.convert()
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

    /// Stored delete intents waiting to reach the server, oldest first.
    ///
    /// A record is only ever removed once the server has answered, so nothing is filtered here.
    public class func fetchPendingMessageDeletes(
        _ completion: @escaping ([PendingMessageDelete]) -> Void) {
            database.performBgTask(resultQueue: .global()) { context in
                PendingMessageDeleteDTO.fetchAll(context: context)
                    .map { $0.convert() }
            } completion: { result in
                switch result {
                case .success(let records):
                    completion(records)
                case .failure(let error):
                    logger.errorIfNotNil(error, "Fetching pending message deletes failed")
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

// MARK: - Hard-delete reconciliation

extension ChannelMessageProvider {

    /// Which load produced a server page — decides what the page proves about its edges.
    public enum PageSource {
        case next, nextAfter, prev, prevBefore, near
    }

    /// The `before:` anchor that asks for the latest page of a channel.
    public static let latestPageAnchor = MessageId(Int64.max)

    /// Reads the newest stored id now, before the request is sent, and returns what turns the
    /// page into a reconciliation once it arrives. One call per load keeps the snapshot and the
    /// page's source/anchor together.
    public func pageReconciler(
        source: PageSource,
        anchor: MessageId?,
        limit: UInt
    ) -> (_ messages: [Message], _ hasMore: Bool) -> MessagePageReconciliation? {
        let newestStoredId = newestStoredMessageId()
        return { [weak self] messages, hasMore in
            self?.pageReconciliation(
                source: source,
                anchor: anchor,
                limit: limit,
                messages: messages,
                hasMore: hasMore,
                newestStoredId: newestStoredId
            )
        }
    }

    /// Newest stored id of the channel, read before a page request is sent. Rows stored after
    /// it (a message event racing the request) are never reconciled against that page.
    /// `nil` for thread lists, which are not reconciled.
    ///
    /// On main this reads `viewContext` inline; off main the read-only background context.
    /// Neither is the writer nor the shared observable context, so it cannot deadlock. If
    /// `viewContext` has not merged the newest write yet the id is lower than the truth, which
    /// only makes the reconciliation delete less.
    public func newestStoredMessageId() -> MessageId? {
        guard threadMessageId == nil else { return nil }
        let channelId = self.channelId
        let result = database.read { context -> MessageId? in
            let request = MessageDTO.fetchRequest()
            request.predicate = NSPredicate(format: "channelId == %lld AND id > 0", Int64(channelId))
            request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.id, ascending: false)
            request.fetchLimit = 1
            return MessageDTO.fetch(request: request, context: context).first.map { MessageId($0.id) }
        }
        return (try? result.get()) ?? nil
    }

    /// What a page of `messages` from `source` proves, or `nil` when it proves nothing safe to
    /// act on: thread lists, an empty page (never wipe local history on an empty response),
    /// or an empty channel before the request.
    public func pageReconciliation(
        source: PageSource,
        anchor: MessageId?,
        limit: UInt,
        messages: [Message],
        hasMore: Bool,
        newestStoredId: MessageId?
    ) -> MessagePageReconciliation? {
        guard threadMessageId == nil,
              let newestStoredId,
              !messages.isEmpty
        else { return nil }
        // The end of the history in the load direction needs both signals: the page came back
        // short of `limit` AND the query says there is nothing more (`hasNext`, which follows
        // the load direction). Short alone is not enough: if the server capped pages below our
        // `limit`, every page would look short and an edge would wipe all history past it.
        let isLastPage = messages.count < Int(limit) && !hasMore
        let reachedOldest: Bool
        let reachedNewest: Bool
        switch source {
        case .prev, .prevBefore:
            reachedOldest = isLastPage
            // `before: Int64.max` asks for the latest page: nothing exists above it.
            reachedNewest = source == .prevBefore && anchor == Self.latestPageAnchor
        case .next, .nextAfter:
            reachedOldest = false
            reachedNewest = isLastPage
        case .near:
            // A short near-page could have run out on either side; prove nothing past it.
            reachedOldest = false
            reachedNewest = false
        }
        return MessagePageReconciliation(
            channelId: channelId,
            serverIds: Set(messages.map(\.id)),
            newestStoredIdBeforeRequest: newestStoredId,
            reachedOldest: reachedOldest,
            reachedNewest: reachedNewest
        )
    }
}
