//
//  ChannelEventHandler.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import CoreData

open class ChannelEventHandler: NSObject, ChannelDelegate {

    public static let channelDelegateIdentifier = NSUUID().uuidString

    let database: Database
    let chatClient: ChatClient

    // Per-message mutex for didChangeVote operations
    private let voteChangeLocks = NSMapTable<NSNumber, NSLock>.strongToStrongObjects()
    private let voteChangeLocksAccessLock = NSLock()

    public required init(
        database: Database,
        chatClient: ChatClient
    ) {
        self.database = database
        self.chatClient = chatClient
        super.init()
    }
    
    deinit {
        stopEventHandler()
    }
    
    open func startEventHandler() {
        SceytChatUIKit.shared.chatClient.add(
            channelDelegate: self,
            identifier: Self.channelDelegateIdentifier
        )
    }
    
    open func stopEventHandler() {
        SceytChatUIKit.shared.chatClient.removeChannelDelegate(identifier: Self.channelDelegateIdentifier)
    }
    
    // MARK: ChannelsDelegate
    open func channelDidDelete(id: ChannelId) {
        database.write {
            $0.deleteChannel(id: id)
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }
    
    open func channelDidCreate(_ channel: Channel) {
        var channelId: Int64 = Crypto.hash(value: (channel.members ?? []).map { $0.id }.sorted().joined(separator: "$"))
        if channelId < 0 {
            channelId *= -1
        }
        database.write {
            if let dto = ChannelDTO.fetch(id: ChannelId(channelId), context: $0) {
                let oldId = dto.id
                dto.id = Int64(channel.id)
                dto.unsynched = false
                try? $0.batchUpdate(object: MessageDTO.self, predicate: .init(format: "channelId == %lld", dto.id), propertiesToUpdate: [#keyPath(MessageDTO.channelId): oldId])
                let chatChannel = $0.createOrUpdate(channel: channel).convert()
                NotificationCenter.default
                    .post(name: .didUpdateLocalCreateChannelOnEventChannelCreate,
                          object: nil,
                          userInfo: ["localChannelId": channelId, "channel": chatChannel])
            } else {
                $0.createOrUpdate(channel: channel)
            }
            
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }

    open func channel(_ channel: Channel, didAdd members: [Member]) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.add(members: members, channelId: channel.id)
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }
    
    open func channel(_ channel: Channel, didJoin member: Member) {
        database.write {
            $0.add(members: [member], channelId: channel.id)
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }
    
    open func channel(_ channel: Channel, didKick members: [Member]) {
        let me = members.contains(where: { $0.id == chatClient.user.id })
        database.write {
            if me {
                $0.deleteChannel(id: channel.id)
            } else {
                $0.createOrUpdate(channel: channel)
                $0.delete(members: members, channelId: channel.id)
            }
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }
    
    open func channel(_ channel: Channel, didLeave member: Member) {
        let me = member.id == chatClient.user.id
        database.write {
            if me {
                $0.deleteChannel(id: channel.id)
            } else {
                $0.createOrUpdate(channel: channel)
                $0.delete(members: [member], channelId: channel.id)
            }
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }
    
    open func channelDidUpdate(_ channel: Channel) {
        database.write {
            $0.createOrUpdate(channel: channel)
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }
    
    open func channel(_ channel: Channel, didReceive marker: MessageListMarker) {
        logger.debug("[MARKER CHECK] didReceive in cid \(channel.id) mark: \(marker.name) for \(marker.messageIds) in channelId:\(marker.channelId)")
        database.write {
            $0.update(messageMarkers: marker)
        } completion: { _ in
        }
    }
    
    open func channel(_ channel: Channel, didReceive message: Message) {
        database.write {
            let lastMessageId: MessageId = MessageId(
                ChannelDTO
                .fetch(id: channel.id, context: $0)?.lastMessage?.id ?? 
                Int64((channel.lastMessage?.id ?? message.id))
            )
            $0.createOrUpdate(channel: channel)
            $0.createOrUpdate(message: message, channelId: channel.id)
            $0.updateRanges(
                startMessageId: lastMessageId,
                endMessageId: message.id,
                channelId: channel.id
            )
            if message.id > 0,
               let state = ChannelSyncStateDTO.fetch(channelId: channel.id, context: $0),
               state.lastSyncedMessageId > 0,
               state.lastSyncedMessageId == Int64(lastMessageId),
               Int64(message.id) > state.lastSyncedMessageId {
                state.lastSyncedMessageId = Int64(message.id)
            }
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
        markReceivedMessageAsReceivedIfNeeded(message: message, channel: channel)
    }
    
    open func channel(_ channel: Channel, user: User, didEdit message: Message) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.createOrUpdate(message: message, channelId: channel.id, changedBy: user)
        }
    }
    
    open func channel(_ channel: Channel, user: User, didDelete message: Message) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.createOrUpdate(message: message, channelId: channel.id, changedBy: user)
        }
    }
    
    open func channel(_ channel: Channel, user: User, message: Message, didAdd reaction: Reaction) {
        database.write {
            if $0.add(reaction: reaction) == nil {
                $0.createOrUpdate(message: message, channelId: channel.id)
                    .unlisted = true
                // The persisted payload's reactionTotals already include this reaction —
                // add() must only store the ReactionDTO, not increment the total again.
                $0.add(reaction: reaction, updateTotal: false)
            }
        }
    }
    
    open func channel(_ channel: Channel, user: User, message: Message, didDelete reaction: Reaction) {
        database.write {
            $0.delete(reaction: reaction)
        }
    }
    
    open func channel(_ channel: Channel, didChange newOwner: Member, oldOwner: Member) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.update(owner: newOwner, channelId: channel.id)
        }
    }
    
    open func channel(_ channel: Channel, didChangeRole members: [Member]) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.createOrUpdate(members: members, channelId: channel.id)
        }
    }
    
    public func channel(_ channel: Channel, didBlock members: [Member]) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.createOrUpdate(members: members, channelId: channel.id)
        }
    }
    
    public func channel(_ channel: Channel, didUnblock members: [Member]) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.createOrUpdate(members: members, channelId: channel.id)
        }
    }
    
    open func channelDidDeleteAllMessagesForMe(_ channel: Channel) {
        database.write {
            do {
                try $0.deleteAllMessages(
                    channelId: channel.id,
                    before: channel.messagesClearedAt
                )
                ChannelSyncStateDTO.delete(channelId: channel.id, context: $0)
            } catch {
                logger.errorIfNotNil(error, "")
            }
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }

    open func channelDidDeleteAllMessagesForEveryone(_ channel: Channel) {
        database.write {
            do {
                try $0.deleteAllMessages(
                    channelId: channel.id,
                    before: channel.messagesClearedAt
                )
                ChannelSyncStateDTO.delete(channelId: channel.id, context: $0)
            } catch {
                logger.errorIfNotNil(error, "")
            }
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }
    
    open func channelDidUpdateUnreadCount(
        _ channel: Channel,
        totalUnreadChannelCount: UInt,
        totalUnreadMessageCount: UInt) {
            logger.debug("[MARKER CHECK] received channelDidUpdateUnreadCount: \(channel.id) for \(channel.newMessageCount)")
            database.write {
                $0.createOrUpdate(channel: channel)
            } completion: { error in
                logger.errorIfNotNil(error, "Unable update channel from ```channelDidUpdateUnreadCount```")
            }
        }
    
    open func channelDidMute(_ channel: Channel) {
        database.write {
            $0.createOrUpdate(channel: channel)
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }
    
    open func channelDidUnmute(_ channel: Channel) {
        database.write {
            $0.createOrUpdate(channel: channel)
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }
    
    open func channelDidPin(_ channel: Channel) {
        database.write {
            $0.createOrUpdate(channel: channel)
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }
    
    open func channelDidUnpin(_ channel: Channel) {
        database.write {
            $0.createOrUpdate(channel: channel)
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }
    
    open func channelDidMarkAsRead(_ channel: Channel) {
        database.write {
            $0.createOrUpdate(channel: channel)
            $0.markAsRead(channelId: channel.id)
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }

    open func channelDidMarkAsUnread(_ channel: Channel) {
        database.write {
            $0.createOrUpdate(channel: channel)
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }
    
    public func channel(_ channel: Channel, user: User, didRetractVote message: Message, changedVotes: ChangedVotes?) {
        self.channel(channel, user: user, didChangeVote: message, changedVotes: changedVotes)
    }
    
    public func channel(_ channel: Channel, user: User, didChangeVote message: Message, changedVotes: ChangedVotes?) {
        guard let changedVotes = changedVotes,
              let pollId = message.poll?.id else {
            return
        }
        postPollUpdateNotification(channel, user: user, message: message, changedVotes: changedVotes)
        // Get or create lock for this specific message
        let messageId = NSNumber(value: message.id)
        voteChangeLocksAccessLock.lock()
        let lock: NSLock
        if let existingLock = voteChangeLocks.object(forKey: messageId) {
            lock = existingLock
        } else {
            lock = NSLock()
            voteChangeLocks.setObject(lock, forKey: messageId)
        }
        voteChangeLocksAccessLock.unlock()

        // Lock for this specific message to ensure synchronous processing
        lock.lock()
        defer { lock.unlock() }

        do {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                try? self.database.syncWrite { context in
                    if let messageDTO = MessageDTO.fetch(id: message.id, context: context) {
                        // Apply changed votes to ownVotes
                        context.applyChangedVotes(changedVotes, pollId: pollId, messageDTO: messageDTO)
                    }
                }
            }
        } catch {
            logger.debug(error.localizedDescription)
        }
    }

    func postPollUpdateNotification(_ channel: Channel, user: User, message: Message, changedVotes: ChangedVotes?) {
        guard let poll = message.poll,
              let changedVotes = changedVotes else { return }

        self.database.read { context in
            guard let messageDTO = MessageDTO.fetch(id: message.id, context: context),
                  let pollDTO = messageDTO.poll else { return }

            let currentUserId = SceytChatUIKit.shared.currentUserId

            // Get current state from database
            var votesPerOption = (pollDTO.votesPerOption as? [String: NSNumber]) ?? [:]
            var ownVotes = (pollDTO.ownVotes?.array as? [PollVoteDTO]) ?? []
            var votes = (pollDTO.votes?.array as? [PollVoteDTO]) ?? []

            // Apply added votes - matching applyChangedVotes logic
            for vote in changedVotes.addedVotes {
                let isOwnVote = vote.user.id == currentUserId

                // Fetch or create vote DTO
                let voteDTO = PollVoteDTO.fetchOrCreate(
                    optionId: vote.optionId,
                    userId: vote.user.id,
                    pollId: poll.id,
                    context: context
                ).map(vote)
                voteDTO.user = context.createOrUpdate(user: vote.user)

                if isOwnVote {
                    // Only add if not already present
                    if !ownVotes.contains(where: { $0.optionId == vote.optionId && $0.id == vote.user.id }) {
                        ownVotes.append(voteDTO)
                    }
                } else {
                    // Only add if not already present
                    if !votes.contains(where: { $0.optionId == vote.optionId && $0.id == vote.user.id }) {
                        votes.append(voteDTO)
                    }
                }

                // Update votesPerOption - increment count for this option
                let currentCount = votesPerOption[vote.optionId]?.intValue ?? 0
                votesPerOption[vote.optionId] = NSNumber(value: currentCount + 1)
            }

            // Apply removed votes - matching applyChangedVotes logic
            for vote in changedVotes.removedVotes {
                let isOwnVote = vote.user.id == currentUserId

                if isOwnVote {
                    ownVotes.removeAll { $0.optionId == vote.optionId && $0.user?.id == vote.user.id }
                } else {
                    votes.removeAll { $0.optionId == vote.optionId && $0.user?.id == vote.user.id }
                }

                // Update votesPerOption - decrement count for this option
                let currentCount = votesPerOption[vote.optionId]?.intValue ?? 0
                let newCount = max(0, currentCount - 1)
                if newCount > 0 {
                    votesPerOption[vote.optionId] = NSNumber(value: newCount)
                } else {
                    // Remove the option from dictionary if count reaches 0
                    votesPerOption.removeValue(forKey: vote.optionId)
                }
            }

            // Get pending votes to include in PollDetails
            let pendingVotes = (pollDTO.pendingVotes?.allObjects as? [PendingVoteDTO])?.map { PendingPollVote(dto: $0) }

            // Create PollDetails with updated votes
            let pollDetails = PollDetails(
                id: pollDTO.id,
                name: pollDTO.name ?? "",
                messageTid: pollDTO.messageTid,
                description: pollDTO.pollDescription ?? "",
                options: (pollDTO.options?.array as? [PollOptionDTO])?.map { PollOption(dto: $0) } ?? [],
                anonymous: pollDTO.anonymous,
                allowMultipleVotes: pollDTO.allowMultipleVotes,
                allowVoteRetract: pollDTO.allowVoteRetract,
                votesPerOption: votesPerOption.mapValues { $0.intValue },
                votes: votes.map { PollVote(dto: $0) },
                ownVotes: ownVotes.map { PollVote(dto: $0) },
                pendingVotes: pendingVotes,
                createdAt: pollDTO.createdAt,
                updatedAt: pollDTO.updatedAt,
                closedAt: pollDTO.closedAt,
                closed: pollDTO.closed
            )

            let pollUIModel = PollViewModel(from: pollDetails, isIncmoing: message.incoming)
            NotificationCenter.default.post(
                name: .didUpdateMessagePoll,
                object: nil,
                userInfo: ["pollUIModel": pollUIModel]
            )
        }
    }

    public func channel(_ channel: Channel, user: User, didClosePoll message: Message, voteDetails: VoteDetails?) {
        guard let poll = message.poll else {
            return
        }

        database.write { context in
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
                        pollId: poll.id,
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
                        pollId: poll.id,
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
                    "messageId": message.id,
                    "pollId": poll.id,
                    "channelId": channel.id
                ]
            )
        }
    }

    func updatePollMessage(_ channel: Channel, _ message: Message, user: User) {
        guard let poll = message.poll else {
            return
        }

        self.database.read {
            let messageDTO = MessageDTO.fetch(id: message.id, context: $0)
            let ownVotes = (messageDTO?.poll?.ownVotes?.array as? [PollVoteDTO]) ?? []
            let pollDetails = PollDetails(poll: poll, messageTid: Int64(message.tid), ownVotes: ownVotes)
            let pollUIModel = PollViewModel(from: pollDetails, isIncmoing: message.incoming)
            NotificationCenter.default.post(
                name: .didUpdateMessagePoll,
                object: nil,
                userInfo: ["pollUIModel": pollUIModel]
            )
        }

        // Update database after UI animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.database.write {
                // Preserve existing ownVotes when updating poll votes
                let existingMessageDTO = MessageDTO.fetch(id: message.id, context: $0)
                let existingOwnVotes = existingMessageDTO?.poll?.ownVotes?.array as? [PollVoteDTO]
                let messageDTO = $0.createOrUpdate(message: message, channelId: channel.id, changedBy: user)
                // Restore ownVotes if they existed
                if let existingOwnVotes = existingOwnVotes, let pollDTO = messageDTO.poll {
                    let ownVotesSet = pollDTO.mutableOrderedSetValue(forKey: "ownVotes")
                    ownVotesSet.removeAllObjects()
                    ownVotesSet.addObjects(from: existingOwnVotes)
                }
            } completion: { error in
                logger.debug(error?.localizedDescription ?? "")
            }
        }
    }


    open func markReceivedMessageAsReceivedIfNeeded(
        message: Message,
        channel: Channel
    ) {
        guard channel.userRole != nil
        else { return }
        
        if message.incoming {
            ChannelOperator(channelId: channel.id)
                .markMessagesAsReceived(ids: [message.id as NSNumber])
            { marker, error in
                if let marker {
                    self.database.write {
                        $0.update(messageMarkers: marker)
                    }
                }
            }
        }
    }
}
