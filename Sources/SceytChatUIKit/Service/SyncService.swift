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

    public static var isSyncing: Bool {
        syncStateLock.lock()
        defer { syncStateLock.unlock() }
        return _isSyncing
    }

    private static func startSyncIfNeeded() -> Bool {
        syncStateLock.lock()
        defer { syncStateLock.unlock() }

        guard !_isSyncing else { return false }
        _isSyncing = true
        return true
    }

    private static func finishSync() {
        syncStateLock.lock()
        _isSyncing = false
        syncStateLock.unlock()
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
        var operations = [PollVoteResendOperation]()
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
                            operations.append(op)
                        }
                    }
                }
                completion(operations)
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
            guard Self.startSyncIfNeeded() else {
                logger.verbose("SyncService: syncChannels skipped — already syncing")
                task?.setTaskCompleted(success: true)
                completion?(false)
                return
            }
            logger.verbose("SyncService: syncChannels started")
            Components.channelMessageMarkerProvider.canMarkMessage = false
            Self.sendPendingReactions()

            let channelSyncQueue = OperationQueue()
            channelSyncQueue.maxConcurrentOperationCount = 1
            let messageSyncQueue = OperationQueue()
            messageSyncQueue.maxConcurrentOperationCount = 1

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
                Self.finishSync()
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
                    Self.finishSync()
                }

                completionOperator.completionBlock = {
                    completion?(completionOperator.isFinished)
                    Self.finishSync()
                    Self.notifyChannelsSyncFinished()
                    task.setTaskCompleted(success: !completionOperator.isCancelled)
                }
            } else {
                completionOperator.completionBlock = {
                    Self.finishSync()
                    Self.notifyChannelsSyncFinished()
                    completion?(completionOperator.isFinished)
                }
            }
            channelSyncQueue.addOperations(operations + [channelCompletionOperator] + markerOperations + [completionOperator], waitUntilFinished: false)
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
