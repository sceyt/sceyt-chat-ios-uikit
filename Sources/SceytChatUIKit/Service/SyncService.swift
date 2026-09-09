//
//  SyncService.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import BackgroundTasks
import SceytChat
import CoreData

public final class SyncService: NSObject {

    public static var workerQueue = DispatchQueue(label: "com.sceytchat.uikit.syncService")
    private static let syncStateLock = NSLock()
    private static var _isSyncing = false
    /// Bumped for every sync that starts and for every `cancelSync()`. A completion block
    /// carries the generation it was created with, so a block belonging to an abandoned
    /// session can no longer clear a newer sync's state.
    private static var syncGeneration: UInt64 = 0
    /// Queues of the sync currently in flight, so `cancelSync()` has something to cancel —
    /// they are created inside `syncChannels` and would otherwise be unreachable.
    private static var activeSyncQueues = [OperationQueue]()

    // MARK: - Pinned message sync state
    //
    // Deliberately a *separate*, per-channel guard rather than the single global slot above:
    // `syncChannels` claims that slot for the whole channel list, so sharing it would mean
    // opening a conversation blocks a channel-list sync and vice versa. Same generation
    // pattern, keyed by channel.
    private static let pinSyncLock = NSLock()
    private static var pinSyncGenerations = [ChannelId: UInt64]()
    private static var activePinSyncQueues = [ChannelId: OperationQueue]()
    private static var pinSyncCounter: UInt64 = 0

    private static func startPinSyncIfNeeded(channelId: ChannelId) -> UInt64? {
        pinSyncLock.lock()
        defer { pinSyncLock.unlock() }

        guard activePinSyncQueues[channelId] == nil, pinSyncGenerations[channelId] == nil else {
            return nil
        }
        pinSyncCounter += 1
        pinSyncGenerations[channelId] = pinSyncCounter
        return pinSyncCounter
    }

    private static func registerPinSync(queue: OperationQueue, channelId: ChannelId, generation: UInt64) {
        pinSyncLock.lock()
        defer { pinSyncLock.unlock() }

        guard pinSyncGenerations[channelId] == generation else { return }
        activePinSyncQueues[channelId] = queue
    }

    /// Ends the pin sync started as `generation`. Returns `false` — and changes nothing — when
    /// that session was cancelled or superseded, so a stale completion block cannot release a
    /// newer sweep's slot.
    @discardableResult
    private static func finishPinSync(channelId: ChannelId, generation: UInt64) -> Bool {
        pinSyncLock.lock()
        defer { pinSyncLock.unlock() }

        guard pinSyncGenerations[channelId] == generation else {
            logger.verbose("SyncService: ignoring stale pin sync completion for channel \(channelId) (generation \(generation))")
            return false
        }
        pinSyncGenerations[channelId] = nil
        activePinSyncQueues[channelId] = nil
        return true
    }

    private static func isCurrentPinSync(channelId: ChannelId, generation: UInt64) -> Bool {
        pinSyncLock.lock()
        defer { pinSyncLock.unlock() }

        return pinSyncGenerations[channelId] == generation
    }

    /// Abandons the pin sweep in flight for one channel. Clearing the generation neuters any
    /// completion block still to fire, so the slot is free immediately.
    public class func cancelPinSync(channelId: ChannelId) {
        pinSyncLock.lock()
        let queue = activePinSyncQueues[channelId]
        pinSyncGenerations[channelId] = nil
        activePinSyncQueues[channelId] = nil
        pinSyncLock.unlock()

        queue?.cancelAllOperations()
    }

    /// Abandons every pin sweep. Called from `cancelSync` — which runs *before* the database is
    /// wiped on account switch, so the wipe is the barrier for pages already in flight.
    public class func cancelAllPinSyncs() {
        pinSyncLock.lock()
        let queues = Array(activePinSyncQueues.values)
        pinSyncGenerations.removeAll()
        activePinSyncQueues.removeAll()
        pinSyncLock.unlock()

        guard !queues.isEmpty else { return }
        logger.verbose("SyncService: cancelAllPinSyncs — abandoning \(queues.count) in-flight pin sweep(s)")
        queues.forEach { $0.cancelAllOperations() }
    }

    public static var isSyncing: Bool {
        syncStateLock.lock()
        defer { syncStateLock.unlock() }
        return _isSyncing
    }

    /// Claims the sync slot. Returns the generation identifying this sync, or `nil` if a
    /// sync is already in flight.
    private static func startSyncIfNeeded() -> UInt64? {
        syncStateLock.lock()
        defer { syncStateLock.unlock() }

        guard !_isSyncing else { return nil }
        _isSyncing = true
        syncGeneration += 1
        activeSyncQueues = []
        return syncGeneration
    }

    private static func register(queues: [OperationQueue], generation: UInt64) {
        syncStateLock.lock()
        defer { syncStateLock.unlock() }

        guard generation == syncGeneration else { return }
        activeSyncQueues = queues
    }

    /// Ends the sync started as `generation`. Returns `false` — and changes nothing — when
    /// that session was cancelled or superseded, so a stale completion block can't release
    /// a newer sync's slot or announce a finish that never happened.
    @discardableResult
    private static func finishSync(generation: UInt64) -> Bool {
        syncStateLock.lock()
        defer { syncStateLock.unlock() }

        guard generation == syncGeneration, _isSyncing else {
            logger.verbose("SyncService: ignoring stale sync completion (generation \(generation), current \(syncGeneration))")
            return false
        }
        _isSyncing = false
        activeSyncQueues = []
        return true
    }

    private static func isCurrent(generation: UInt64) -> Bool {
        syncStateLock.lock()
        defer { syncStateLock.unlock() }

        return generation == syncGeneration
    }

    /// Abandons the channel sync in flight: unstarted operations are cancelled and the
    /// generation bump neuters any completion block still to fire, so the sync slot is free
    /// immediately for the next session.
    ///
    /// Call this when the session the sync belongs to ends — chat disconnect, and account
    /// switch — and *before* wiping the database, so the wipe is the barrier for pages that
    /// were already in flight (`FetchAllChannelsOperation` only checks `isCancelled` between
    /// pages). Without it a sync interrupted mid-flight leaves `_isSyncing` true until its
    /// operations drain, and the next `syncChannels()` is skipped as "already syncing".
    ///
    /// - Parameter includingPendingItems: also cancel the shared resend queues (reactions,
    ///   poll votes, markers, message deletes). Pass `true` on account switch, where those
    ///   operations carry the outgoing account's pending items and must not be replayed
    ///   under the incoming session. Leave `false` for a plain disconnect, where they are
    ///   still this account's work and should finish or be retried on reconnect.
    public class func cancelSync(includingPendingItems: Bool = false) {
        syncStateLock.lock()
        let queues = activeSyncQueues
        let wasSyncing = _isSyncing
        _isSyncing = false
        activeSyncQueues = []
        syncGeneration += 1
        syncStateLock.unlock()

        if wasSyncing {
            logger.verbose("SyncService: cancelSync — abandoning in-flight channel sync")
            queues.forEach { $0.cancelAllOperations() }
            Components.channelMessageMarkerProvider.canMarkMessage = true
        }

        cancelAllPinSyncs()

        if includingPendingItems {
            logger.verbose("SyncService: cancelSync — cancelling pending item queues")
            reactionQueue.cancelAllOperations()
            pollVoteQueue.cancelAllOperations()
            markersQueue.cancelAllOperations()
            messageDeleteQueue.cancelAllOperations()
            pinQueue.cancelAllOperations()
        }
    }

    /// Signals that channel sync has finished so open screens can reconcile a stale local
    /// direct placeholder against the channels just written to the database.
    private static func notifyChannelsSyncFinished() {
        NotificationCenter.default.post(name: .didFinishChannelsSync, object: nil)
    }

    public static var reactionQueue: OperationQueue = {
        let op = OperationQueue()
        op.maxConcurrentOperationCount = 1
        return op
    }()

    public static var pollVoteQueue: OperationQueue = {
        let op = OperationQueue()
        op.maxConcurrentOperationCount = 1
        return op
    }()

    /// Drains stored pin/unpin intents. Serial, like the other pending-item queues: two pins for
    /// the same message must not race, and the "X pinned" system message is posted from the ack.
    public static var pinQueue: OperationQueue = {
        let op = OperationQueue()
        op.maxConcurrentOperationCount = 1
        return op
    }()

    public static var markersQueue: OperationQueue = {
        let op = OperationQueue()
        op.maxConcurrentOperationCount = 5
        return op
    }()

    public static var messageDeleteQueue: OperationQueue = {
        let op = OperationQueue()
        op.maxConcurrentOperationCount = 1
        return op
    }()

    public class func resendPendingItems() {
        logger.verbose("SyncService: resendPendingItems")
        workerQueue.async {
            makePendingReactionOperations {
                if !$0.isEmpty {
                    reactionQueue.addOperations($0, waitUntilFinished: false)
                }
            }
            makePendingPollVoteOperations {
                if !$0.isEmpty {
                    pollVoteQueue.addOperations($0, waitUntilFinished: false)
                }
            }
            markersQueue.cancelAllOperations()
            makePendingMarkerOperations {
                markersQueue.addOperations($0, waitUntilFinished: false)
            }
            makePendingMessageDeleteOperations {
                if !$0.isEmpty {
                    messageDeleteQueue.addOperations($0, waitUntilFinished: false)
                }
            }
        }
    }

    public class func resendPendingMessage() {
        guard Bundle.isMainApp else {
            logger.verbose("SyncService: resendPendingMessage skipped - running in app extension")
            return
        }
        logger.verbose("SyncService: makeMessageResendOperations")

        Components.channelMessageProvider
            .fetchPendingMessages { messages in
                logger.verbose("SyncService: makeMessageResendOperations fetched \(messages.count) messages")
                let groupByChannel = Dictionary(grouping: messages, by: { $0.channelId })

                // Count total messages to resend
                let totalMessagesToResend = groupByChannel.values.reduce(0) { count, channelMessages in
                    count + channelMessages.filter { message in
                        message.attachments?.contains(where: { $0.status == .pauseDownloading || $0.status == .pauseUploading }) != true
                    }.count
                }

                guard totalMessagesToResend > 0 else {
                    // No messages to resend, send pending poll votes immediately
                    logger.verbose("SyncService: No messages to resend, sending pending poll votes")
                    sendPendingPollVotes()
                    sendPendingMessageDeletes()
                    return
                }

                var completedCount = 0
                let lock = NSLock()

                groupByChannel.forEach { item in
                    let sender = Components.channelMessageSender.init(channelId: item.key)
                    let provider = Components.channelMessageProvider.init(channelId: item.key)
                    let sorted = item.value.sorted(by: { $0.createdAt < $1.createdAt })
                    sorted.forEach { message in
                        if message.attachments?.contains(where: { $0.status == .pauseDownloading || $0.status == .pauseUploading }) == true {
                            logger.verbose("SyncService: makeMessageResendOperations DO NOT RESEND (has paused attachment) message: tid \(message.tid), body \(message.body)")
                            return
                        }
                        logger.verbose("SyncService: makeMessageResendOperations fetched message: tid \(message.tid)")
                        sender.resendMessage(message) {error in
                            if error?.sceytChatCode == .channelNotExists {
                                provider.deletePending(message: message.tid)
                            }

                            // Track completion
                            lock.lock()
                            completedCount += 1
                            let shouldSendPollVotes = completedCount == totalMessagesToResend
                            lock.unlock()

                            if shouldSendPollVotes {
                                logger.verbose("SyncService: All pending messages sent, sending pending poll votes")
                                sendPendingPollVotes()
                                sendPendingMessageDeletes()
                            }
                        }
                    }
                }
            }
    }

    public class func makePendingMarkerOperations(
        completion: @escaping ([MarkerResendOperation]) -> Void
    ) {
        logger.verbose("SyncService: makePendingMarkerOperations")
        var operations = [MarkerResendOperation]()
        Components.channelMessageProvider
            .fetchPendingMarkers { markers in
                logger.verbose("SyncService: makePendingMarkerOperations fetched \(markers.count) markers")
                markers.forEach { (cid, markers) in
                    markers.forEach { (markerName, ids) in
                        let chunked = Array(ids).chunked(into: 50)
                        chunked.forEach { chunk in
                            let provider = Components.channelMessageMarkerProvider.init(channelId: cid)
                            logger.verbose("SyncService: makePendingMarkerOperations fetched markers with MessageIds \(chunk), for markerName \(markerName)")
                            let op = MarkerResendOperation(provider: provider, messageIds: Array(chunk), markerName: markerName)
                            operations.append(op)
                        }
                    }
                }
                completion(operations)
            }
    }

    /// Sends every stored pin/unpin intent. The `sendPendingReactions()` analogue.
    ///
    /// Called from `syncChannels` on connect and from `syncChannelPins` when a channel opens, so
    /// a pin taken with no connection goes out at the first opportunity either way.
    public class func sendPendingPins() {
        workerQueue
            .async {
                makePendingPinOperations {
                    guard !$0.isEmpty else { return }
                    logger.info("[Pin] sync: \($0.count) pending pin intent(s) to send")
                    pinQueue.addOperations($0, waitUntilFinished: false)
                }
            }
    }

    /// One operation per stored intent, grouped so a channel shares its provider.
    ///
    /// - Parameter channelId: Restricts the batch to one channel, for the channel-open sweep.
    ///   `nil` takes every channel, which is what the connect-time sync wants.
    public class func makePendingPinOperations(
        channelId: ChannelId? = nil,
        completion: @escaping ([PinResendOperation]) -> Void
    ) {
        Components.channelPinnedMessageProvider
            .fetchPendingPins { records in
                let scoped = channelId.map { id in records.filter { $0.channelId == id } } ?? records
                var providers = [ChannelId: ChannelPinnedMessageProvider]()
                var operations = [PinResendOperation]()
                for record in scoped {
                    let provider = providers[record.channelId]
                        ?? Components.channelPinnedMessageProvider.init(channelId: record.channelId)
                    providers[record.channelId] = provider
                    operations.append(PinResendOperation(provider: provider, record: record))
                }
                completion(operations)
            }
    }

    public class func makePendingReactionOperations(
        completion: @escaping ([ReactionResendOperation]) -> Void
    ) {
        var operations = [ReactionResendOperation]()
        Components.channelMessageProvider
            .fetchPendingReaction { reactions in
                let group = Dictionary(grouping: reactions) { $0.1 }
                for ch in group {
                    let provider = Components.channelMessageProvider.init(channelId: ch.key)
                    for reaction in ch.value {
                        let op = ReactionResendOperation(provider: provider, reaction: reaction.0)
                        operations.append(op)
                    }
                }
                completion(operations)
            }
    }

    public class func makePendingPollVoteOperations(
        completion: @escaping ([PollVoteResendOperation]) -> Void
    ) {
        var operations = [(op: PollVoteResendOperation, createdAt: Int64)]()
        Components.channelMessageProvider
            .fetchPendingPollVotes { pendingVotes in
                let group = Dictionary(grouping: pendingVotes) { $0.2 } // Group by ChannelId
                for ch in group {
                    let provider = Components.channelMessageProvider.init(channelId: ch.key)
                    // Group by optionId to ensure only the latest pending vote per option is processed
                    let optionGroups = Dictionary(grouping: ch.value) { $0.0.optionId }
                    for (optionId, votes) in optionGroups {
                        // Get the latest pending vote for this option (highest createdAt)
                        if let latestVote = votes.max(by: { $0.0.createdAt < $1.0.createdAt }) {
                            let op = PollVoteResendOperation(
                                provider: provider,
                                messageId: latestVote.1,
                                pollId: latestVote.0.pollId,
                                optionId: optionId,
                                isAdd: latestVote.0.isAdd
                            )
                            operations.append((op, latestVote.0.createdAt))
                        }
                    }
                }
                // Replay in the order the user cast the votes. The queue is serial, so on a
                // single-vote poll (where the server swaps the vote on every add) the user's most
                // recent choice is the one that lands last and wins.
                completion(operations.sorted { $0.createdAt < $1.createdAt }.map(\.op))
            }
    }

    public class func makePendingMessageDeleteOperations(
        completion: @escaping ([PendingMessageDeleteOperation]) -> Void
    ) {
        Components.channelMessageProvider
            .fetchPendingMessageDeletes { records in
                logger.verbose("SyncService: makePendingMessageDeleteOperations fetched \(records.count) records")
                // The flush is triggered from more than one place (a reconnect sync and
                // `resendPendingItems`), so skip records already queued to avoid sending the
                // same delete twice.
                let queued = Set(messageDeleteQueue.operations.compactMap { ($0 as? AsyncOperation)?.uuid })
                completion(records.compactMap { record in
                    let sender = Components.channelMessageSender.init(channelId: record.channelId)
                    let operation = PendingMessageDeleteOperation(sender: sender, record: record)
                    guard !queued.contains(operation.uuid) else {
                        logger.verbose("SyncService: pending delete for tid \(record.messageTid) is already queued")
                        return nil
                    }
                    return operation
                })
            }
    }

    public class func sendPendingMessages() {
        workerQueue
            .async {
                resendPendingMessage()
            }
    }

    public class func sendPendingMarkers() {
        workerQueue
            .async {
                makePendingMarkerOperations {
                    markersQueue.addOperations($0, waitUntilFinished: false)
                }
            }
    }

    public class func sendPendingReactions() {
        workerQueue
            .async {
                makePendingReactionOperations {
                    reactionQueue.addOperations($0, waitUntilFinished: false)
                }
            }
    }

    public class func sendPendingPollVotes() {
        workerQueue
            .async {
                makePendingPollVoteOperations {
                    pollVoteQueue.addOperations($0, waitUntilFinished: false)
                }
            }
    }

    /// Replays the stored "delete this message" intents.
    ///
    /// Runs after pending messages have been resent, so the server never receives a delete for a
    /// tid before the message it refers to.
    public class func sendPendingMessageDeletes() {
        guard Bundle.isMainApp else {
            logger.verbose("SyncService: sendPendingMessageDeletes skipped - running in app extension")
            return
        }
        workerQueue
            .async {
                makePendingMessageDeleteOperations {
                    if !$0.isEmpty {
                        messageDeleteQueue.addOperations($0, waitUntilFinished: false)
                    }
                }
            }
    }

    public class func syncChannels(
        task: BGAppRefreshTask? = nil,
        completion: ((Bool) -> Void)? = nil) {
            guard let generation = Self.startSyncIfNeeded() else {
                logger.verbose("SyncService: syncChannels skipped — already syncing")
                task?.setTaskCompleted(success: true)
                completion?(false)
                return
            }
            logger.verbose("SyncService: syncChannels started (generation \(generation))")
            Components.channelMessageMarkerProvider.canMarkMessage = false
            Self.sendPendingReactions()
            Self.sendPendingPins()

            let channelSyncQueue = OperationQueue()
            channelSyncQueue.maxConcurrentOperationCount = 1
            let messageSyncQueue = OperationQueue()
            messageSyncQueue.maxConcurrentOperationCount = 1
            Self.register(queues: [channelSyncQueue, messageSyncQueue], generation: generation)

            let completionOperator = Operation()
            let channelCompletionOperator = Operation()

            let results = try? DataProvider.database.read { context in
                let result1 = context.fetchChannelsToSyncMessages()
                let result2 = context.fetchPendingMarkerToSyncMessages()
                let result3 = context.fetchChannelsForPendingMessages()
                let result4 = ChannelSyncStateDTO.fetchAll(context: context)
                return (result1, result2, result3, result4)
            }.get()

            let channelsResult = results?.0
            let syncStateResult = results?.3 ?? [:]
            let operations = Operations.syncChannelOperations(undeleteChannelIds: results?.2 ?? []) { channels in
                for channel in channels where channel.lastDisplayedMessageId != 0  {
                    let cachedId = channelsResult?[channel.id] ?? 0
                    let minDisplayId = cachedId != 0 ? min(cachedId, channel.lastDisplayedMessageId) : channel.lastDisplayedMessageId
                    guard minDisplayId != channel.lastMessage?.id,
                          minDisplayId > 0
                    else { continue }
                    let channelLastMessageId = channel.lastMessage?.id ?? 0
                    if channelLastMessageId == 0 {
                        continue
                    }
                    let lastSyncedMessageId = syncStateResult[channel.id] ?? 0
                    if lastSyncedMessageId > 0,
                       channelLastMessageId > 0,
                       lastSyncedMessageId >= channelLastMessageId {
                        logger.verbose("SyncService: skip syncChannelMessages for channel \(channel.id) — lastSyncedMessageId \(lastSyncedMessageId) >= lastMessageId \(channelLastMessageId)")
                        continue
                    }
                    let operation = Operations.syncChannelMessagesOperations(
                        startMessageId: minDisplayId - 1,
                        channelId: channel.id,
                        channelLastMessageId: channelLastMessageId
                    )
                    completionOperator.addDependency(operation)
                    messageSyncQueue.addOperation(operation)
                }
            }
            if let createChannel = operations.first(where: {$0 is CreateUnSyncChannelsOperation}) as? CreateUnSyncChannelsOperation {
                createChannel.completionBlock = {
                    Self.sendPendingMessages()
                }
            } else {
                Self.sendPendingMessages()
            }
            guard !operations.isEmpty else {
                Components.channelMessageMarkerProvider.canMarkMessage = true
                guard Self.finishSync(generation: generation) else {
                    completion?(false)
                    return
                }
                Self.notifyChannelsSyncFinished()
                completion?(true)
                return
            }
            let markerResult = results?.1
            let markerOperations = Operations.syncMessageMarkersOperations(markersGroup: markerResult ?? [:])

            let lastOperation: Operation = markerOperations.last ?? operations.last!
            completionOperator.addDependency(lastOperation)
            channelCompletionOperator.addDependency(operations.last!)
            channelCompletionOperator.completionBlock = {
                Components.channelMessageMarkerProvider.canMarkMessage = true
            }
            if let task {
                task.expirationHandler = {
                    channelSyncQueue.cancelAllOperations()
                    messageSyncQueue.cancelAllOperations()
                    Self.finishSync(generation: generation)
                }

                completionOperator.completionBlock = {
                    // The BG task has to be completed even for a superseded session, or the
                    // scheduler counts it as never finished — only the sync state and the
                    // finished notification are gated on the generation.
                    let isCurrent = Self.finishSync(generation: generation)
                    completion?(isCurrent && completionOperator.isFinished)
                    if isCurrent {
                        Self.notifyChannelsSyncFinished()
                    }
                    task.setTaskCompleted(success: !completionOperator.isCancelled)
                }
            } else {
                completionOperator.completionBlock = {
                    guard Self.finishSync(generation: generation) else {
                        completion?(false)
                        return
                    }
                    Self.notifyChannelsSyncFinished()
                    completion?(completionOperator.isFinished)
                }
            }
            // Cancellation can land between claiming the slot and here — the database read
            // above is not instant. Enqueueing then would run a whole sync for a session
            // that no longer exists, writing the previous account's channels into a database
            // that was just wiped for the incoming one.
            guard Self.isCurrent(generation: generation) else {
                logger.verbose("SyncService: sync generation \(generation) cancelled before enqueue — dropping operations")
                Components.channelMessageMarkerProvider.canMarkMessage = true
                completionOperator.completionBlock = nil
                channelCompletionOperator.completionBlock = nil
                task?.setTaskCompleted(success: false)
                completion?(false)
                return
            }
            channelSyncQueue.addOperations(operations + [channelCompletionOperator] + markerOperations + [completionOperator], waitUntilFinished: false)
        }
}

extension SyncService {

    /// Reconciles one channel's pinned messages against the server.
    ///
    /// The `syncChannels` shape, scoped to a channel: paginate the server's pins, storing each
    /// page as it lands so the banner fills progressively, then delete the local pins the server
    /// did not report. The conversation shows whatever is already on disk the instant it opens —
    /// this only mutates the database, and the existing `pinnedMessageObserver` repaints.
    ///
    /// Safe to call from several places for the same channel (the conversation and the pinned
    /// list both do): the per-channel guard makes the second call a no-op.
    public class func syncChannelPins(channelId: ChannelId, completion: ((Bool) -> Void)? = nil) {
        guard channelId != 0 else {
            completion?(false)
            return
        }
        guard let generation = Self.startPinSyncIfNeeded(channelId: channelId) else {
            logger.verbose("SyncService: syncChannelPins skipped for channel \(channelId) — already syncing")
            completion?(false)
            return
        }
        logger.verbose("SyncService: syncChannelPins started for channel \(channelId) (generation \(generation))")

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        Self.registerPinSync(queue: queue, channelId: channelId, generation: generation)

        // The channel's own stored intents go out **first**, on the same serial queue, so a pin
        // taken offline is on the server before the fetch reads the server's answer — otherwise
        // the sweep's first page would simply not contain it. (Nothing would be lost either way:
        // `reconcilePins` never deletes a pending row. This just means the pin arrives synced
        // instead of staying queued for another round.)
        Self.makePendingPinOperations(channelId: channelId) { pendingOperations in
            if !pendingOperations.isEmpty {
                logger.info("[Pin] channel \(channelId): \(pendingOperations.count) pending pin intent(s) to send before the sweep")
            }
            let operations = pendingOperations + Operations.syncChannelPinOperations(channelId: channelId)
            let completionOperator = Operation()
            completionOperator.addDependency(operations.last!)
            completionOperator.completionBlock = {
                guard Self.finishPinSync(channelId: channelId, generation: generation) else {
                    completion?(false)
                    return
                }
                Self.notifyChannelPinsSyncFinished(channelId: channelId)
                completion?(completionOperator.isFinished)
            }

            // Cancellation can land between claiming the slot and here — and the read above is
            // not instant. Enqueueing then would run a whole sweep for a session that no longer
            // exists, and on account switch reconcile the incoming account's pins against the
            // outgoing account's answer.
            guard Self.isCurrentPinSync(channelId: channelId, generation: generation) else {
                logger.verbose("SyncService: pin sync generation \(generation) for channel \(channelId) cancelled before enqueue")
                completionOperator.completionBlock = nil
                Self.finishPinSync(channelId: channelId, generation: generation)
                completion?(false)
                return
            }
            queue.addOperations(operations + [completionOperator], waitUntilFinished: false)
        }
    }

    /// Signals that one channel's pin sweep finished, so an open screen can react to the
    /// reconcile rather than only to the observer's row-level changes.
    private static func notifyChannelPinsSyncFinished(channelId: ChannelId) {
        NotificationCenter.default.post(
            name: .didFinishChannelPinsSync,
            object: nil,
            userInfo: ["channelId": channelId]
        )
    }
}

public struct Operations {

    public static func syncChannelOperations(undeleteChannelIds: [ChannelId] = [], onLoad: (([Channel]) -> Void)? = nil) -> [Operation] {
        let createChannel = CreateUnSyncChannelsOperation()

        let provider = Components.channelListProvider.init()
        provider.config.queryLimit = 20
        let fetchChannels = FetchAllChannelsOperation(query: provider.defaultQuery)
        fetchChannels.onLoad = onLoad

        let deleteChannels = DeleteChannelsOperation(database: DataProvider.database, channelIds: undeleteChannelIds)

        let fetchDone = BlockOperation { [unowned fetchChannels, unowned deleteChannels, unowned createChannel] in
            guard case let .success(channels)? = fetchChannels.result else {
                deleteChannels.cancel()
                return
            }
            deleteChannels.addChannel(ids: channels.map { $0.id })

            if  case let .success(channels)? = createChannel.result {
                deleteChannels.addChannel(ids: channels.map { $0.id })
            }
        }
        fetchChannels.addDependency(createChannel)
        fetchDone.addDependency(fetchChannels)
        deleteChannels.addDependency(fetchDone)

        return [createChannel,
                fetchChannels,
                fetchDone,
                deleteChannels]
    }

    /// `fetchPins -> fetchDone -> reconcilePins`, the same three-step graph as
    /// `syncChannelOperations`.
    ///
    /// `fetchDone` is where the safety lives: it seeds the reconcile's keep set from the fetch's
    /// accumulated result, and **cancels the reconcile outright when the fetch failed**. Without
    /// that single line a dropped connection mid-sweep reads as "the server has no pins" and
    /// deletes every local pin in the channel.
    public static func syncChannelPinOperations(channelId: ChannelId) -> [Operation] {
        let provider = Components.channelPinnedMessageProvider.init(channelId: channelId)

        let fetchPins = FetchAllPinnedMessagesOperation(
            query: provider.createDefaultQuery(),
            provider: provider
        )
        let reconcilePins = ReconcilePinnedMessagesOperation(channelId: channelId, provider: provider)

        let fetchDone = BlockOperation { [unowned fetchPins, unowned reconcilePins] in
            guard case let .success(pins)? = fetchPins.result else {
                reconcilePins.cancel()
                return
            }
            reconcilePins.addPin(serverPinIds: pins.map { Int64($0.id) })
        }
        fetchDone.addDependency(fetchPins)
        reconcilePins.addDependency(fetchDone)

        return [fetchPins, fetchDone, reconcilePins]
    }

    public static func syncChannelMessagesOperations(
        startMessageId: MessageId,
        channelId: ChannelId,
        channelLastMessageId: MessageId = 0
    ) -> Operation {
        let query = MessageListQuery
            .Builder(channelId: channelId)
            .limit(SceytChatUIKit.shared.config.queryLimits.messageListQueryLimit)
            .build()
        let messageOperation = FetchChannelMessagesOperation(query: query)
        messageOperation.syncLastPageImmediately = false
        messageOperation.startMessageId = startMessageId
        let provider = Components.channelMessageProvider.init(channelId: channelId)
        messageOperation.onLoad = { result, end in
            if let messages = try? result.get() {
                provider.store(messages: messages) { _ in
                    end()
                }
                let messageIds = messages.compactMap {
                    if $0.incoming && ($0.userMarkers == nil || !$0.userMarkers!.contains(where: { $0.name == ChatMessage.DeliveryStatus.received.rawValue })) {
                        return $0.id
                    }
                    return nil
                }
                provider.markMessagesAsReceived(
                    ids: messageIds,
                    storeForResend: true
                )
            }
        }
        if channelLastMessageId > 0 {
            messageOperation.completionBlock = { [weak messageOperation] in
                guard let op = messageOperation,
                      case .success = op.result
                else { return }
                DataProvider.database.write { context in
                    let state = ChannelSyncStateDTO.fetchOrCreate(channelId: channelId, context: context)
                    if state.lastSyncedMessageId < Int64(channelLastMessageId) {
                        state.lastSyncedMessageId = Int64(channelLastMessageId)
                    }
                }
            }
        }
        return messageOperation
    }

    public static func syncMessageMarkersOperations(markersGroup: [ChannelId: [String: Set<MessageId>]]) -> [Operation] {
        var operations = [MarkerResendOperation]()
        markersGroup.forEach { (cid, markers) in
            markers.forEach { (markerName, ids) in
                let chunked = Array(ids).chunked(into: 50)
                chunked.forEach { chunk in
                    let provider = Components.channelMessageMarkerProvider.init(channelId: cid)
                    logger.verbose("SyncService: makePendingMarkerOperations fetched markers with MessageIds \(chunk), for markerName \(markerName)")
                    let op = MarkerResendOperation(provider: provider, messageIds: Array(chunk), markerName: markerName)
                    operations.append(op)
                }
            }
        }
        return operations
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

private extension MessageDatabaseSession where Self: NSManagedObjectContext {

    func fetchPendingMarkerToSyncMessages() -> [ChannelId: [String: Set<MessageId>]] {
        let request = MessageDTO.fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.tid, ascending: false)
        request.predicate = .init(
            format: "pendingMarkerNames != nil")
        return MessageDTO.fetch(request: request, context: self)
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
    }

    func fetchChannelsForPendingMessages() -> [ChannelId] {
        let request = NSFetchRequest<NSDictionary>(entityName: MessageDTO.entityName)
        request.predicate = .init(
            format: "id == %lld AND incoming = %d AND (deliveryStatus == %d || deliveryStatus == %d)",
            0,
            false,
            ChatMessage.DeliveryStatus.pending.intValue,
            ChatMessage.DeliveryStatus.failed.intValue)

        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["channelId"]

        let results = MessageDTO.fetch(request: request, context: self)

        var items = [ChannelId: Bool]()
        for result in results {
            guard let channelId = result["channelId"] as? ChannelId
            else { continue }
            items[channelId] = true
        }
        return Array(items.keys)
    }
}
