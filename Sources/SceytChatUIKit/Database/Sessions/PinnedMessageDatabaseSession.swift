//
//  PinnedMessageDatabaseSession.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import CoreData
import Foundation
import SceytChat

/// Reads and writes a channel's pinned messages.
///
/// The one invariant every method here upholds: `PinnedMessageDTO` and the
/// `MessageDTO.pinDetails` projection are written **in the same transaction,
/// never one alone**. See `PinnedMessageDTO` for why the state is stored twice.
public protocol PinnedMessageDatabaseSession {

    /// Pins a message. Returns `nil` when the message cannot be pinned — it is not in
    /// the local store, or it is transient / view-once / auto-deleting.
    @discardableResult
    func pinMessage(
        id: MessageId,
        tid: Int64,
        channelId: ChannelId,
        scope: PinnedMessage.Scope,
        pinnedAt: Date,
        pinnedUntil: Date?,
        pinnedBy userId: UserId?
    ) -> PinnedMessageDTO?

    func unpinMessage(id: MessageId, tid: Int64, channelId: ChannelId)
    func unpinAllMessages(channelId: ChannelId)

    func pinnedMessage(tid: Int64, channelId: ChannelId) -> PinnedMessageDTO?
    func pinnedMessages(channelId: ChannelId) -> [PinnedMessage]
    func pinnedMessageCount(channelId: ChannelId) -> Int

    // Lifecycle hooks, called from the existing session methods.

    /// Reconciles a message row with its pin: refreshes the preview snapshot, auto-unpins
    /// a soft-deleted message, and repairs a mirror left behind by a batch delete.
    func syncPin(for dto: MessageDTO)
    /// The message row is about to be hard-deleted; drop its pin.
    func dropPin(for dto: MessageDTO)
    func movePinnedMessages(fromChannelId: ChannelId, toChannelId: ChannelId)
    func unpinMessages(channelId: ChannelId, before date: Date?)
}

extension NSManagedObjectContext: PinnedMessageDatabaseSession {

    @discardableResult
    public func pinMessage(
        id: MessageId,
        tid: Int64,
        channelId: ChannelId,
        scope: PinnedMessage.Scope,
        pinnedAt: Date,
        pinnedUntil: Date? = nil,
        pinnedBy userId: UserId?
    ) -> PinnedMessageDTO? {
        guard let message = resolveMessage(id: id, tid: tid, channelId: channelId) else {
            logger.info("Cannot pin message id \(id) tid \(tid): no local row to snapshot")
            return nil
        }

        // A pinned view-once or auto-deleting message would keep a full body snapshot on
        // disk after it has vanished from the timeline. Refuse rather than leak it.
        guard !message.transient, !message.viewOnce, message.autoDeleteAt == nil else {
            logger.info("Refusing to pin transient/view-once/auto-deleting message id \(id)")
            return nil
        }

        let resolvedTid = message.tid != 0 ? message.tid : message.id
        let pin = PinnedMessageDTO.fetchOrCreate(
            messageTid: resolvedTid,
            channelId: ChannelId(message.channelId),
            context: self
        )
        pin.applySnapshot(from: message)
        pin.scope = scope
        pin.pinnedAt = pinnedAt.bridgeDate
        pin.pinnedUntil = pinnedUntil?.bridgeDate
        pin.pinnedByUserId = userId
        pin.sync = .pendingPin

        // Projection, same transaction.
        let details = PinDetailsDTO.fetchOrCreate(for: message, context: self)
        details.isPinned = true
        details.pinnedUntil = pinnedUntil?.bridgeDate
        return pin
    }

    public func unpinMessage(id: MessageId, tid: Int64, channelId: ChannelId) {
        // Delete by tid *and* by id: a row whose tid drifted must still go.
        if tid != 0 {
            PinnedMessageDTO.delete(messageTid: tid, channelId: channelId, context: self)
        }
        if id != 0 {
            PinnedMessageDTO.delete(messageId: id, channelId: channelId, context: self)
        }
        if let message = resolveMessage(id: id, tid: tid, channelId: channelId) {
            clearPinMirror(on: message)
        }
    }

    public func unpinAllMessages(channelId: ChannelId) {
        PinnedMessageDTO.deleteAll(channelId: channelId, context: self)
        clearPinMirrors(channelId: channelId)
        // Backstop for rows whose message was already batch-deleted: the Cascade rule
        // never ran for those, so `clearPinMirrors` cannot reach them.
        PinDetailsDTO.deleteAll(channelId: channelId, context: self)
    }

    public func pinnedMessage(tid: Int64, channelId: ChannelId) -> PinnedMessageDTO? {
        PinnedMessageDTO.fetch(messageTid: tid, channelId: channelId, context: self)
    }

    /// The channel's live pins, in timeline order. Lapsed pins are filtered out rather
    /// than deleted here — a read must not write.
    public func pinnedMessages(channelId: ChannelId) -> [PinnedMessage] {
        PinnedMessageDTO.fetchUnexpired(channelId: channelId, context: self)
            .map { $0.convert() }
    }

    public func pinnedMessageCount(channelId: ChannelId) -> Int {
        PinnedMessageDTO.countUnexpired(channelId: channelId, context: self)
    }

    // MARK: - Lifecycle

    public func syncPin(for dto: MessageDTO) {
        let channelId = ChannelId(dto.channelId)
        let pin = PinnedMessageDTO.fetch(messageTid: dto.tid, channelId: channelId, context: self)
            ?? PinnedMessageDTO.fetch(messageId: MessageId(dto.id), channelId: channelId, context: self)

        guard let pin else {
            // No pin row, but the mirror is set: a batch delete dropped the pin, or
            // `MessageDTO.fetchOrCreate` handed back a row that outlived its pin. Repair.
            if dto.pinDetails != nil {
                clearPinMirror(on: dto)
            }
            return
        }

        guard !pin.isExpired else {
            // The pin lapsed. Drop it rather than let a stale row keep the bubble marked.
            delete(pin)
            clearPinMirror(on: dto)
            return
        }

        guard dto.state != Int16(ChatMessage.State.deleted.intValue) else {
            // Soft delete => auto-unpin. A "message deleted" tombstone is not worth pinning.
            delete(pin)
            clearPinMirror(on: dto)
            return
        }

        // Covers a body edit, an attachment landing, and the tid -> server id promotion
        // that follows a send ack.
        pin.applySnapshot(from: dto)

        // Re-project rather than assume: the message row may be a fresh one with no
        // pinDetails while the pin row survived.
        let details = PinDetailsDTO.fetchOrCreate(for: dto, context: self)
        details.isPinned = true
        details.pinnedUntil = pin.pinnedUntil
    }

    public func dropPin(for dto: MessageDTO) {
        // The channel id must come from the fetched row, never from a caller's argument:
        // `deleteMessage(tid:)` delegates with `channelId: 0`.
        let channelId = ChannelId(dto.channelId)
        if dto.tid != 0 {
            PinnedMessageDTO.delete(messageTid: dto.tid, channelId: channelId, context: self)
        }
        if dto.id != 0 {
            PinnedMessageDTO.delete(messageId: MessageId(dto.id), channelId: channelId, context: self)
        }
        clearPinMirror(on: dto)
    }

    public func movePinnedMessages(fromChannelId: ChannelId, toChannelId: ChannelId) {
        PinnedMessageDTO.move(
            fromChannelId: fromChannelId,
            toChannelId: toChannelId,
            context: self
        )
        PinDetailsDTO.move(
            fromChannelId: fromChannelId,
            toChannelId: toChannelId,
            context: self
        )
    }

    public func unpinMessages(channelId: ChannelId, before date: Date?) {
        PinnedMessageDTO.deleteAll(channelId: channelId, before: date, context: self)
        clearPinMirrors(channelId: channelId, before: date)
        PinDetailsDTO.deleteAll(channelId: channelId, before: date, context: self)
    }

    // MARK: - Private

    private func resolveMessage(id: MessageId, tid: Int64, channelId: ChannelId) -> MessageDTO? {
        if id != 0, let dto = MessageDTO.fetch(id: id, context: self) {
            return dto
        }
        if tid != 0 {
            return MessageDTO.fetch(tid: tid, channelId: Int64(channelId), context: self)
        }
        return nil
    }

    private func clearPinMirror(on message: MessageDTO) {
        guard let details = message.pinDetails else { return }
        delete(details)
        message.pinDetails = nil
    }

    /// Clears the mirror in-context rather than with `batchUpdate`: pins per channel are
    /// bounded, and only an in-context write makes the `LazyMessagesObserver` FRC emit an
    /// `.update` for the affected rows, which is what repaints the bubbles.
    private func clearPinMirrors(channelId: ChannelId, before date: Date? = nil) {
        let request = MessageDTO.fetchRequest()
        var predicate = NSPredicate(format: "channelId == %lld AND pinDetails != nil", channelId)
        if let date {
            predicate = NSCompoundPredicate(type: .and, subpredicates: [
                predicate,
                NSPredicate(format: "createdAt <= %@", date as NSDate)
            ])
        }
        request.predicate = predicate
        MessageDTO.fetch(request: request, context: self)
            .forEach { clearPinMirror(on: $0) }
    }
}
