//
//  ChannelPinnedMessageProvider.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import CoreData
import Foundation
import SceytChat

/// Pins and unpins messages in one channel, and stores the pins the server reports.
///
/// The shape is the one pending reactions use: **store the intent, attempt it, clear the intent
/// on success** — and if the attempt cannot be made or fails, leave the intent on disk for
/// `SyncService.sendPendingPins()` to drain on the next sync.
///
/// So a pin taken with no connection stays visible, survives relaunch, and is sent when the
/// connection comes back. Nothing is rolled back: `reconcilePins` deliberately never deletes a
/// pending row, because the server's answer says nothing about an intent it has not been told.
///
/// **The "X pinned" system message is posted from here, not from the view model**, and only when
/// the server acks a `.forAll` pin — which for an offline pin is minutes later, inside the sync.
/// `confirmPin` reports whether *this* ack is the one that flipped the intent, so a retry that
/// lands twice cannot post it twice.
///
/// One SDK subtlety this class has to absorb: **the device that performs a pin never receives
/// the `didPinMessages` event.** The SDK resolves the pending request id and takes the
/// completion-handler path instead. So `flushPendingPin` here and
/// `ChannelEventHandler.channel(_:didPinMessages:)` are two halves of the same write, and both
/// have to be idempotent.
open class ChannelPinnedMessageProvider: DataProvider {

    public let channelId: ChannelId

    /// The SDK handle every pin/unpin request goes through.
    ///
    /// Built through `makeChannelOperator()` rather than inline so a subclass can substitute
    /// one — the same shape as `ChannelListViewModel.makeChannelObserver()`. That is the only
    /// way to exercise these paths without a server, since `SceytChat.PinnedMessage` cannot be
    /// constructed outside the SDK.
    public private(set) lazy var channelOperator: ChannelOperator = makeChannelOperator()

    public required init(channelId: ChannelId) {
        self.channelId = channelId
        super.init()
    }

    open func makeChannelOperator() -> ChannelOperator {
        .init(channelId: channelId)
    }

    /// Whether a pin request can be sent at all.
    ///
    /// Kept separate from the request itself because "could not ask" and "the server said no"
    /// must not share a branch — see `flushPendingPin`. `open` so a subclass can substitute it,
    /// which is also how the provider's request paths are tested without a server.
    open var canReachServer: Bool {
        chatClient.connectionState == .connected
    }

    /// The query the channel-open sweep paginates.
    ///
    /// `.all` rather than a scope filter, because the sweep's answer is what `reconcilePins`
    /// diffs against: filtering to `.shared` would make every personal pin look server-deleted
    /// and the reconcile would delete them all.
    ///
    /// `.asc` so pages arrive in the same direction as `PinnedMessageDTO.defaultSortDescriptors`
    /// — the banner fills in its final order as pages land instead of reshuffling per page.
    open func createDefaultQuery() -> PinnedMessagesListQuery {
        PinnedMessagesListQuery
            .Builder(channelId: channelId)
            .limit(SceytChatUIKit.shared.config.queryLimits.pinnedMessageListQueryLimit)
            .pinType(.all)
            .order(.asc)
            .build()
    }

    /// - Parameter pinnedUntil: When the pin lapses. `nil` — the default — is an open-ended
    ///   pin, matching the server's `pinDetails.pinnedUntil` being absent.
    open func pin(
        message: ChatMessage,
        scope: PinnedMessage.Scope = .forAll,
        pinnedUntil: Date? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        var record: PinnedMessage?
        database.write {
            record = $0.pinMessage(
                id: message.id,
                tid: message.tid,
                channelId: self.channelId,
                scope: scope,
                pinnedAt: Date(),
                pinnedUntil: pinnedUntil,
                pinnedBy: SceytChatUIKit.shared.currentUserId
            )?.convert()
        } completion: { error in
            guard let record else {
                // Nothing was stored — the message is not in the local store, or it is
                // transient / view-once / auto-deleting. See `pinMessage`.
                completion?(error)
                return
            }
            // The row is already on disk as a `.pendingPin` intent, so this attempt is allowed to
            // fail: the sync drains what is left over.
            self.flushPendingPin(record) { completion?($0 ?? error) }
        }
    }

    /// Records a pin-for-everyone in the conversation as a system message.
    ///
    /// Posted from `flushPendingPin`'s success path only, so it fires exactly when the server has
    /// accepted the pin — immediately for an online pin, and at sync time for one taken offline.
    /// A pin written straight to the store (UI-test seeding, the server sweep's `storePin`) never
    /// goes through that path and so stays silent, which is the property the old
    /// `ChannelViewModel`-side call was protecting.
    ///
    /// Mirrors `ChannelProvider.sendSystemMessage`: silent (no push), `displayCount` 0 (no
    /// unread bump), stored locally before it goes out. The one difference is the parent
    /// link, which is why this does not reuse `ChannelMessageProvider.storePending`.
    open func sendPinSystemMessage(for message: ChatMessage) {
        let builder = Message.Builder()
            .type(ChatMessage.MessageType.system)
            .body(ChatMessage.SystemMessageType.pinnedMessage)
            .parentMessageId(message.id)
            .silent(true)
            .displayCount(0)
        if let metadata = SystemMessageMetadata.PinnedMessage(id: message.id).toJSONString() {
            builder.metadata(metadata)
        }
        let sdkMessage = builder.build()

        database.write { context in
            let dto = context.createOrUpdate(message: sdkMessage, channelId: self.channelId)
            // The SDK's `Message` carries no parent — `parentMessage` is readonly and only
            // the server fills it in, the builder takes an id — so link the pending copy by
            // hand, inside this same write. A second write instead would render the row as
            // `Adam pinned: ""` first and correct it a frame later.
            //
            // Deliberately does not touch `parent.replied`: the message list fetches on
            // `replied == false`, so flipping it would make the message that was just
            // pinned disappear from the conversation.
            dto.parent = MessageDTO.fetch(id: message.id, context: context)
            // And for the same reason, attach the sender. A locally built message carries
            // no user either, so `SystemMessageBodyFormatter` would render the row as
            // " pinned: …" with the name missing until the echo. It is the current user by
            // definition — this device is the one doing the pinning.
            if let currentUserId = SceytChatUIKit.shared.currentUserId,
               let me = UserDTO.fetch(id: currentUserId, context: context) {
                dto.user = me
            }
        } completion: { error in
            logger.errorIfNotNil(error, "Store pending pin system message for \(message.id)")
            ChannelMessageSender(channelId: self.channelId).sendMessage(sdkMessage)
        }
    }

    open func unpin(message: ChatMessage, completion: ((Error?) -> Void)? = nil) {
        unpin(messageId: message.id, messageTid: message.tid, completion: completion)
    }

    /// Unpins a stored pin directly.
    ///
    /// The pinned-messages list works from `PinnedMessage` snapshots, not from
    /// `ChatMessage`: a pin outlives the `MessageDTO` it points at (see `PinnedMessageDTO`),
    /// so the list can offer Unpin for a row whose message was never fetched.
    open func unpin(_ pinnedMessage: PinnedMessage, completion: ((Error?) -> Void)? = nil) {
        unpin(
            messageId: pinnedMessage.messageId,
            messageTid: pinnedMessage.messageTid,
            completion: completion
        )
    }

    /// The one unpin path.
    ///
    /// The bubble and the banner lose the pin immediately. Whether anything needs sending depends
    /// on how far the pin got: one the server never saw is simply dropped, and one it acked
    /// becomes a `.pendingUnpin` intent that outlives a failed attempt.
    open func unpin(
        messageId: MessageId,
        messageTid: Int64,
        completion: ((Error?) -> Void)? = nil
    ) {
        var needsSending = false
        database.write {
            needsSending = $0.unpinMessage(
                id: messageId,
                tid: messageTid,
                channelId: self.channelId
            ) != nil
        } completion: { error in
            guard needsSending else {
                completion?(error)
                return
            }
            self.flushPendingUnpin(messageId: messageId, messageTid: messageTid) {
                completion?($0 ?? error)
            }
        }
    }

    open func fetchPinnedMessages(completion: @escaping ([PinnedMessage]) -> Void) {
        let channelId = channelId
        database.read {
            $0.pinnedMessages(channelId: channelId)
        } completion: { result in
            switch result {
            case .success(let messages):
                completion(messages)
            case .failure(let error):
                logger.errorIfNotNil(error, "Fetch pinned messages")
                completion([])
            }
        }
    }

    /// One network attempt for a stored pin intent.
    ///
    /// Every exit that is not a server ack leaves the `.pendingPin` row exactly where it is, so
    /// `SyncService.sendPendingPins()` can try again later. Nothing is rolled back — an
    /// optimistic pin that vanished on a flaky connection is worse than one that is simply still
    /// on its way.
    open func flushPendingPin(_ record: PinnedMessage, completion: ((Error?) -> Void)? = nil) {
        // `canPin` already blocks pending sends, but the store path used by UI-test seeding does
        // not. A pin for a message with no server id has nothing to send *yet* — the row stays
        // pending and the send ack's tid -> id promotion makes it sendable later.
        guard record.messageId != 0 else {
            logger.info("[Pin] not sending pin for message tid \(record.messageTid): no server id yet — it stays queued until the send ack promotes it")
            completion?(nil)
            return
        }

        // UI-test mode never connects; see `SceytChatUIKit.uiTestPinRequestsCompleteLocally`.
        // Routed through the real `confirm` so the ack logic — including the once-only system
        // message — is what the tests exercise.
        if SceytChatUIKit.uiTestPinRequestsCompleteLocally {
            confirm(
                record,
                serverPinId: SceytChatUIKit.nextUITestPinId(),
                pinnedUntil: record.pinnedUntil,
                scope: record.scope,
                completion: completion
            )
            return
        }

        guard canReachServer else {
            logger.info("[Pin] not sending pin for message \(record.messageId): offline — the intent stays queued for the next sync")
            completion?(nil)
            return
        }

        logger.info("[Pin] sending pin: message \(record.messageId), channel \(channelId), scope \(record.scope), until \(record.pinnedUntil.map { "\($0)" } ?? "never"), attempt \(record.retryCount + 1)")
        channelOperator.pinMessages(
            ids: [NSNumber(value: record.messageId)],
            pinTill: record.pinnedUntil,
            pinType: record.scope.pinType
        ) { [weak self] pins, error in
            guard let self else {
                completion?(error)
                return
            }
            guard let pin = pins?.first, error == nil else {
                logger.error("[Pin] pin FAILED: message \(record.messageId), channel \(self.channelId), error \(error.map { "\($0)" } ?? "server returned no pin"). The intent stays queued for the next sync.")
                self.database.write {
                    $0.recordPinAttemptFailure(
                        messageTid: record.messageTid,
                        channelId: self.channelId
                    )
                } completion: { _ in
                    completion?(error)
                }
                return
            }
            self.confirm(
                record,
                serverPinId: Int64(pin.id),
                pinnedUntil: pin.message.pin?.pinnedTill ?? record.pinnedUntil,
                scope: PinnedMessage.Scope(pin.message.pin?.pinType ?? record.scope.pinType),
                completion: completion
            )
        }
    }

    /// Stamps the server's answer onto the intent, and posts the system message if that ack is
    /// what completed a pin-for-everyone.
    ///
    /// Split out of `flushPendingPin` for two reasons: it is also the acting device's *only*
    /// notification that the pin landed (that device gets no `didPinMessages` event — see the
    /// class doc), and `SceytChat.PinnedMessage` cannot be constructed outside the SDK, so this
    /// is the seam that keeps the success path reachable from a test.
    open func confirm(
        _ record: PinnedMessage,
        serverPinId: Int64,
        pinnedUntil: Date?,
        scope: PinnedMessage.Scope,
        completion: ((Error?) -> Void)? = nil
    ) {
        var didCompletePendingPin = false
        database.write {
            didCompletePendingPin = $0.confirmPin(
                messageTid: record.messageTid,
                channelId: self.channelId,
                serverPinId: serverPinId,
                pinnedUntil: pinnedUntil,
                scope: scope
            )
        } completion: { error in
            if let error {
                logger.error("[Pin] pin acked but storing it FAILED: message \(record.messageId), channel \(self.channelId), error \(error)")
                completion?(error)
                return
            }
            // Only a pin for everyone is a channel event worth recording in the conversation: a
            // personal pin is invisible to the other members. And only on the ack that actually
            // completed the intent, so a retry landing twice cannot post it twice.
            let announces = didCompletePendingPin
                && scope == .forAll
                && SceytChatUIKit.shared.config.sendsPinSystemMessage
            logger.info("[Pin] pin SUCCESS: message \(record.messageId), channel \(self.channelId), serverPinId \(serverPinId), scope \(scope)\(didCompletePendingPin ? "" : " (already synced — duplicate ack)")\(announces ? ", posting system message" : "")")
            if announces {
                self.sendPinSystemMessage(for: record.previewMessage)
            }
            completion?(error)
        }
    }

    /// One network attempt for a stored unpin intent.
    ///
    /// The row is already hidden from the UI; on success it is deleted, and on any other outcome
    /// it stays a `.pendingUnpin` intent for the next sync.
    open func flushPendingUnpin(
        messageId: MessageId,
        messageTid: Int64,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard messageId != 0 else {
            completion?(nil)
            return
        }
        if SceytChatUIKit.uiTestPinRequestsCompleteLocally {
            database.write {
                $0.confirmUnpin(messageTid: messageTid, channelId: self.channelId)
            } completion: { error in
                completion?(error)
            }
            return
        }

        guard canReachServer else {
            logger.info("[Pin] not sending unpin for message \(messageId): offline — the intent stays queued for the next sync")
            completion?(nil)
            return
        }
        logger.info("[Pin] sending unpin: message \(messageId), channel \(channelId)")
        channelOperator.unpinMessages(ids: [NSNumber(value: messageId)]) { [weak self] _, error in
            guard let self else {
                completion?(error)
                return
            }
            self.database.write {
                if let error {
                    logger.error("[Pin] unpin FAILED: message \(messageId), channel \(self.channelId), error \(error). The intent stays queued for the next sync.")
                    $0.recordPinAttemptFailure(messageTid: messageTid, channelId: self.channelId)
                } else {
                    logger.info("[Pin] unpin SUCCESS: message \(messageId), channel \(self.channelId)")
                    $0.confirmUnpin(messageTid: messageTid, channelId: self.channelId)
                }
            } completion: { writeError in
                completion?(error ?? writeError)
            }
        }
    }

    /// Sends one stored intent, whichever direction it is. What `PinResendOperation` drives.
    open func flushPendingIntent(_ record: PinnedMessage, completion: ((Error?) -> Void)? = nil) {
        switch record.syncState {
        case .pendingPin:
            flushPendingPin(record, completion: completion)
        case .pendingUnpin:
            flushPendingUnpin(
                messageId: record.messageId,
                messageTid: record.messageTid,
                completion: completion
            )
        case .synced, .unspecified:
            completion?(nil)
        }
    }

    /// Stores one page of server pins. The `provider.onStoreChannels` analogue that
    /// `FetchAllPinnedMessagesOperation` drives.
    open func store(
        pinnedMessages: [SceytChat.PinnedMessage],
        completion: ((Error?) -> Void)? = nil
    ) {
        guard !pinnedMessages.isEmpty else {
            completion?(nil)
            return
        }
        database.write {
            for pinnedMessage in pinnedMessages {
                $0.storePin(pinnedMessage, channelId: self.channelId)
            }
        } completion: { error in
            logger.errorIfNotNil(error, "Store \(pinnedMessages.count) server pin(s) for channel \(self.channelId)")
            completion?(error)
        }
    }

    /// Deletes the pins the server did not report in a completed sweep.
    open func reconcile(
        serverPinIds: Set<Int64>,
        completion: ((Error?) -> Void)? = nil
    ) {
        database.write {
            $0.reconcilePins(channelId: self.channelId, keeping: serverPinIds)
        } completion: { error in
            logger.errorIfNotNil(error, "Reconcile pins for channel \(self.channelId)")
            completion?(error)
        }
    }


    /// Every unacknowledged pin intent across all channels, oldest attempt first. What
    /// `SyncService.makePendingPinOperations` drains — the analogue of
    /// `ChannelMessageProvider.fetchPendingReaction`.
    public class func fetchPendingPins(completion: @escaping ([PinnedMessage]) -> Void) {
        database.read {
            PinnedMessageDTO.fetchPending(context: $0).map { $0.convert() }
        } completion: { result in
            switch result {
            case .success(let records):
                completion(records)
            case .failure(let error):
                logger.errorIfNotNil(error, "Fetch pending pins")
                completion([])
            }
        }
    }
}
