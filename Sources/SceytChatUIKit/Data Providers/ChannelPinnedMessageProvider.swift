//
//  ChannelPinnedMessageProvider.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import CoreData
import Foundation
import SceytChat

/// Pins and unpins messages in one channel.
///
/// **Local-only today.** The bundled SceytChat SDK has no message-pin API — `SCTMessage`
/// carries nothing pin-related and `SCTChannelOperator` only pins *channels* — so the
/// network step below is a no-op that simply marks the stored intent `.synced`.
///
/// The shape is deliberately the one every other mutating provider here uses: **local write
/// first (optimistic), then the network step, then a reconcile write**. When the SDK grows
/// `pinMessage` / `unpinMessage`, only `flushPendingPin` changes — no call site moves,
/// because the row already carries `serverPinId`, `syncState`, `retryCount` and
/// `lastAttemptAt`, and `PendingMessageDeleteOperation` is the retry machine to copy.
open class ChannelPinnedMessageProvider: DataProvider {

    public let channelId: ChannelId
    /// Present so the eventual server call has a home; unused while pinning is local-only.
    public let channelOperator: ChannelOperator

    public required init(channelId: ChannelId) {
        self.channelId = channelId
        self.channelOperator = .init(channelId: channelId)
        super.init()
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
            self.flushPendingPin(record) { completion?($0 ?? error) }
        }
    }

    /// Records a pin-for-everyone in the conversation as a system message.
    ///
    /// Deliberately not called from `pin` — a pin written straight to the store (UI-test
    /// seeding, a future sync sweep) must stay silent. `ChannelViewModel.pinMessage` is
    /// what decides a pin is user-initiated and `.forAll`.
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
        database.write {
            $0.unpinMessage(id: message.id, tid: message.tid, channelId: self.channelId)
        } completion: { error in
            completion?(error)
        }
    }

    /// Unpins a stored pin directly.
    ///
    /// The pinned-messages list works from `PinnedMessage` snapshots, not from
    /// `ChatMessage`: a pin outlives the `MessageDTO` it points at (see `PinnedMessageDTO`),
    /// so the list can offer Unpin for a row whose message was never fetched.
    open func unpin(_ pinnedMessage: PinnedMessage, completion: ((Error?) -> Void)? = nil) {
        database.write {
            $0.unpinMessage(
                id: pinnedMessage.messageId,
                tid: pinnedMessage.messageTid,
                channelId: self.channelId
            )
        } completion: { error in
            completion?(error)
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

    /// One network attempt for a stored intent, then update or clear the record.
    ///
    /// Today there is no request to make, so the row is marked `.synced` immediately.
    /// This is the single method the future server API replaces.
    open func flushPendingPin(_ record: PinnedMessage, completion: ((Error?) -> Void)? = nil) {
        database.write {
            guard let dto = PinnedMessageDTO.fetch(
                messageTid: record.messageTid,
                channelId: record.channelId,
                context: $0
            ) else { return }
            dto.sync = .synced
            dto.lastAttemptAt = Int64(Date().timeIntervalSince1970 * 1000)
        } completion: { error in
            completion?(error)
        }
    }

    /// Every unsynced pin across all channels. Mirrors
    /// `ChannelMessageProvider.fetchPendingMessageDeletes` for the future sync sweep.
    public class func fetchPendingPins(completion: @escaping ([PinnedMessage]) -> Void) {
        database.read {
            PinnedMessageDTO.fetchAll(context: $0)
                .filter { $0.sync == .pendingPin || $0.sync == .pendingUnpin }
                .map { $0.convert() }
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
