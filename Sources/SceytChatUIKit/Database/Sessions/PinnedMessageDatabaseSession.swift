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

    /// Unpins a message. A pin the server has already acked is kept as a `.pendingUnpin`
    /// intent rather than deleted; one that never reached the server is simply dropped.
    /// Returns the intent that now needs sending, or `nil` when there is nothing to send.
    @discardableResult
    func unpinMessage(id: MessageId, tid: Int64, channelId: ChannelId) -> PinnedMessageDTO?
    func unpinAllMessages(channelId: ChannelId)

    func pinnedMessage(tid: Int64, channelId: ChannelId) -> PinnedMessageDTO?
    func pinnedMessages(channelId: ChannelId) -> [PinnedMessage]
    func pinnedMessageCount(channelId: ChannelId) -> Int

    // Server truth.

    /// Writes a pin the server reported — from a `PinnedMessagesListQuery` page or a
    /// `didPinMessages` event. Returns `nil` when the pin was refused; see the implementation.
    @discardableResult
    func storePin(_ pinnedMessage: SceytChat.PinnedMessage, channelId: ChannelId) -> PinnedMessageDTO?

    /// `storePin`'s core, taking the pin's own fields as values.
    ///
    /// The split exists because `SceytChat.PinnedMessage` and `SceytChat.PinDetails` declare
    /// `init` unavailable — only the SDK can build one — so nothing outside the SDK, tests
    /// included, can reach the method above. `SceytChat.Message` *can* be built
    /// (`Message.Builder`), which is why it stays in this signature.
    @discardableResult
    func storePin(
        message: SceytChat.Message,
        channelId: ChannelId,
        serverPinId: Int64,
        pinnedBy: ChatUser?,
        pinnedUntil: Date?,
        scope: PinnedMessage.Scope
    ) -> PinnedMessageDTO?

    /// Drops a pin the server reported unpinned.
    func deletePin(serverPinId: Int64, messageId: MessageId, channelId: ChannelId)

    /// Deletes the channel's pins the server did not report, once a full sync sweep finished.
    func reconcilePins(channelId: ChannelId, keeping serverPinIds: Set<Int64>)

    /// Re-derives the `MessageDTO.pinDetails` mirror from the pin rows for one channel.
    @discardableResult
    func repairPinMirrors(channelId: ChannelId) -> Int

    /// Stamps an optimistic pin with the id the server assigned it.
    ///
    /// Returns `true` only when this call is what flipped a pending intent to `.synced` — the
    /// signal the caller uses to post the "X pinned" system message exactly once, however many
    /// times a retry lands.
    @discardableResult
    func confirmPin(
        messageTid: Int64,
        channelId: ChannelId,
        serverPinId: Int64,
        pinnedUntil: Date?,
        scope: PinnedMessage.Scope
    ) -> Bool

    /// The server acked an unpin; drop the intent and its row.
    func confirmUnpin(messageTid: Int64, channelId: ChannelId)

    /// Records that an attempt was made and failed, so the retry has a trail.
    func recordPinAttemptFailure(messageTid: Int64, channelId: ChannelId)

    /// Applies the pin state the server sends nested on a message.
    func applyPinDetails(_ pin: SceytChat.PinDetails?, to dto: MessageDTO)

    /// `applyPinDetails`'s core, taking the pin details as values — see `storePin` above for
    /// why the SDK-typed method needs a value twin.
    func applyPinState(
        isPinned: Bool,
        pinnedUntil: Date?,
        scope: PinnedMessage.Scope,
        to dto: MessageDTO
    )

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
        // The server has not told us this pin's id yet. The sentinel sorts it at the newest-pin
        // end of the banner (see `defaultSortDescriptors`) until `confirmPin` replaces it, and
        // `lastAttemptAt` is what tells `reconcilePins` this row is a pin in flight rather than
        // one stranded by a crash.
        if !pin.hasServerPinId {
            pin.serverPinId = PinnedMessageDTO.unknownServerPinId
        }
        pin.lastAttemptAt = Int64(Date().timeIntervalSince1970 * 1000)

        // Projection, same transaction.
        let details = PinDetailsDTO.fetchOrCreate(for: message, context: self)
        details.isPinned = true
        details.pinnedUntil = pinnedUntil?.bridgeDate
        return pin
    }

    @discardableResult
    public func unpinMessage(id: MessageId, tid: Int64, channelId: ChannelId) -> PinnedMessageDTO? {
        // By tid *and* by id: a row whose tid drifted must still be found.
        let rows = [
            tid != 0 ? PinnedMessageDTO.fetch(messageTid: tid, channelId: channelId, context: self) : nil,
            id != 0 ? PinnedMessageDTO.fetch(messageId: id, channelId: channelId, context: self) : nil
        ].compactMap { $0 }

        // The mirror goes immediately either way — the bubble must lose its pin the moment the
        // user asks, not when the server agrees.
        if let message = resolveMessage(id: id, tid: tid, channelId: channelId) {
            clearPinMirror(on: message)
        }

        var intent: PinnedMessageDTO?
        for row in rows {
            if row.sync == .pendingPin {
                // Never reached the server, so there is nothing to unpin there. Dropping the row
                // cancels the queued pin outright.
                logger.info("Unpin cancels the still-pending pin for message tid \(row.messageTid)")
                delete(row)
            } else if row.sync == .pendingUnpin {
                intent = row   // already queued; leave it alone
            } else {
                // The server knows about this pin, so the removal has to be sent. Keep the row as
                // the durable intent; `notPendingUnpinPredicate` hides it from every display fetch.
                row.sync = .pendingUnpin
                row.lastAttemptAt = Int64(Date().timeIntervalSince1970 * 1000)
                intent = row
            }
        }
        return intent
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

    // MARK: - Server truth

    /// The server-truth writer. **Never inserts a `MessageDTO`** — see
    /// `applySnapshot(from: SceytChat.Message, channelId:messageTid:)` for why that would be
    /// actively harmful.
    @discardableResult
    public func storePin(
        _ pinnedMessage: SceytChat.PinnedMessage,
        channelId: ChannelId
    ) -> PinnedMessageDTO? {
        let message = pinnedMessage.message
        return storePin(
            message: message,
            channelId: channelId,
            serverPinId: Int64(pinnedMessage.id),
            pinnedBy: ChatUser(user: pinnedMessage.pinnedBy),
            pinnedUntil: message.pin?.pinnedTill,
            // `SceytChat.PinnedMessage` carries no pinType of its own — the scope lives on the
            // message's nested pin details.
            scope: PinnedMessage.Scope(message.pin?.pinType ?? .shared)
        )
    }

    @discardableResult
    public func storePin(
        message: SceytChat.Message,
        channelId: ChannelId,
        serverPinId: Int64,
        pinnedBy: ChatUser?,
        pinnedUntil: Date?,
        scope: PinnedMessage.Scope
    ) -> PinnedMessageDTO? {
        guard message.id != 0 else {
            logger.info("Refusing to store pin \(serverPinId): message has no server id")
            return nil
        }
        let localMessage = MessageDTO.fetch(id: message.id, context: self)

        // The pin table is keyed by `(messageTid, channelId)`, so this has to be derived once and
        // used for both the lookup and the snapshot — deriving it twice lets the two disagree for
        // an outgoing message and inserts a second row for a message that already has a pin.
        //
        // The local row wins, because the server does not always echo an outgoing message's tid.
        // Failing that, the canonical rule from `MessageDTO.map(_:)`.
        let pinTid = localMessage?.tid
            ?? ((message.incoming || message.tid == 0) ? Int64(message.id) : Int64(message.tid))

        // The same refusals `pinMessage` applies: a pinned view-once or auto-deleting message
        // would keep a full body snapshot on disk after it has vanished from the timeline.
        guard !message.transient, !message.viewOnce, message.autoDeleteAt == nil else {
            logger.info("Refusing to store pin \(serverPinId): transient/view-once/auto-deleting message id \(message.id)")
            return nil
        }

        // And one the local path gets for free. A soft-deleted message is auto-unpinned by
        // `syncPin(for:)` on the next message write, so storing it here would flap: sync
        // creates the row, the next write deletes it, the next sync creates it again.
        guard message.state != .deleted,
              localMessage?.state != Int16(ChatMessage.State.deleted.intValue)
        else {
            logger.info("Refusing to store pin \(serverPinId): message id \(message.id) is deleted")
            return nil
        }

        let pin = PinnedMessageDTO.fetchOrCreate(
            messageTid: pinTid,
            channelId: channelId,
            context: self
        )
        pin.applySnapshot(from: message, channelId: channelId, messageTid: pinTid)
        pin.serverPinId = serverPinId
        pin.sync = .synced
        pin.retryCount = 0
        pin.pinnedByUserId = pinnedBy?.id
        pin.pinnedUntil = pinnedUntil?.bridgeDate
        pin.scope = scope
        // Deliberately does not set `pinnedAt`: the SDK sends no pin timestamp, and an existing
        // local value is better than overwriting it with nil. Pin *order* comes from `serverPinId`.

        if let pinnedBy {
            createOrUpdate(user: pinnedBy)
        }

        // Projection, same transaction — the module's one invariant. Only when the message is
        // actually in the local store; a pin whose message was never fetched has no bubble to mark.
        if let localMessage {
            let details = PinDetailsDTO.fetchOrCreate(for: localMessage, context: self)
            details.isPinned = true
            details.pinnedUntil = pin.pinnedUntil
        }
        return pin
    }

    public func deletePin(serverPinId: Int64, messageId: MessageId, channelId: ChannelId) {
        // By pin id when we have it, else by message id: an unpin can name a pin this device
        // never stored (personal pin from another device, or a row swept by a batch delete).
        let pin = PinnedMessageDTO.fetch(serverPinId: serverPinId, channelId: channelId, context: self)
            ?? PinnedMessageDTO.fetch(messageId: messageId, channelId: channelId, context: self)

        if let pin {
            delete(pin)
        }
        if messageId != 0, let message = MessageDTO.fetch(id: messageId, context: self) {
            clearPinMirror(on: message)
        }
    }

    /// Deletes every pin the server did not report — **except** the ones it has not been told
    /// about yet.
    ///
    /// A `.pendingPin` or `.pendingUnpin` row is a durable intent waiting on
    /// `SyncService.sendPendingPins()`. The server's answer says nothing about it, so its absence
    /// from that answer is not evidence: deleting it here would silently discard a pin the user
    /// took while offline. This holds however old the intent is — the same way a pending reaction
    /// survives until it is sent.
    public func reconcilePins(
        channelId: ChannelId,
        keeping serverPinIds: Set<Int64>
    ) {
        let doomed = PinnedMessageDTO
            .fetchAll(channelId: channelId, excludingServerPinIds: serverPinIds, context: self)
            .filter { !$0.isPendingSync }
        guard !doomed.isEmpty else {
            // Still worth a pass: the drift this repairs needs no stale pin to exist.
            repairPinMirrors(channelId: channelId)
            return
        }

        logger.verbose("reconcilePins: dropping \(doomed.count) stale pin(s) in channel \(channelId)")
        for pin in doomed {
            if let message = resolveMessage(
                id: MessageId(pin.messageId),
                tid: pin.messageTid,
                channelId: channelId
            ) {
                clearPinMirror(on: message)
            }
            delete(pin)
        }

        repairPinMirrors(channelId: channelId)
    }

    /// Re-derives the bubble mirror from the pin rows, and returns how many rows it had to fix.
    ///
    /// `syncPin(for:)` keeps the two sides in step on every message write, but there are two ways
    /// they can drift with no message write to follow:
    ///
    /// - **A batch delete.** `NSBatchDeleteRequest` ignores deletion rules, so a swept
    ///   `PinDetailsDTO` leaves its pin row behind, and vice versa.
    /// - **A pin racing an unpin on two contexts.** Both entities carry a
    ///   `(messageTid, channelId)` uniqueness constraint, so a pending insert of the mirror can
    ///   be constraint-merged onto a row another context is deleting in the same instant — the
    ///   delete wins and the mirror vanishes, while the pin row (a separate entity, with no
    ///   delete pending) survives. Every pin write in this module goes through
    ///   `Database.write`, which is one serial context, so this is really about the
    ///   `performWriteTask` sweeps and any host writing pins on a context of its own.
    ///
    /// Either way the banner would list a pin whose bubble shows no indicator. Called from
    /// `reconcilePins`, so opening the channel converges it; the work is bounded because a
    /// channel holds tens of pins, not thousands.
    @discardableResult
    public func repairPinMirrors(channelId: ChannelId) -> Int {
        var repaired = 0

        // A pin row with no live mirror: re-project it. `fetchUnexpired` already excludes a
        // `.pendingUnpin` row, which must not mark a bubble.
        for pin in PinnedMessageDTO.fetchUnexpired(channelId: channelId, context: self) {
            guard !pin.isDeleted else { continue }
            guard let message = resolveMessage(
                id: MessageId(pin.messageId),
                tid: pin.messageTid,
                channelId: channelId
            ), !message.isDeleted else { continue }

            let details = PinDetailsDTO.fetchOrCreate(for: message, context: self)
            guard !details.isPinned || details.pinnedUntil != pin.pinnedUntil else { continue }
            details.isPinned = true
            details.pinnedUntil = pin.pinnedUntil
            repaired += 1
        }

        // A mirror with no pin row behind it: clear it.
        //
        // Only for messages this channel has no pin row for at all. A personal pin from another
        // device legitimately arrives on the message payload before the sweep creates its row,
        // and `applyPinDetails` is allowed to leave that transient state behind.
        for details in PinDetailsDTO.fetchAll(channelId: channelId, context: self) where details.isPinned {
            guard !details.isDeleted else { continue }
            // A `.pendingUnpin` row does not count as a pin: the user has unpinned it and only
            // the server ack is outstanding, so its bubble must not stay marked.
            let backingPin = PinnedMessageDTO.fetch(
                messageTid: details.messageTid,
                channelId: channelId,
                context: self
            )
            let hasPin = backingPin != nil && backingPin?.sync != .pendingUnpin
            guard !hasPin else { continue }

            // Resolved by fetch rather than through `details.message`. Faulting a to-one at a
            // row a batch delete removed throws `NSObjectInaccessibleException` — the same
            // hazard `RelationshipKeyPathsObserver` refuses to walk deletes for — whereas a
            // fetch for a missing row simply returns nil.
            guard let message = MessageDTO.fetch(
                tid: details.messageTid,
                channelId: Int64(channelId),
                context: self
            ), !message.isDeleted else {
                // The mirror outlived its message entirely; nothing renders it, so drop it.
                delete(details)
                repaired += 1
                continue
            }
            clearPinMirror(on: message)
            repaired += 1
        }

        if repaired > 0 {
            logger.info("repairPinMirrors: repaired \(repaired) pin mirror(s) in channel \(channelId)")
        }
        return repaired
    }

    @discardableResult
    public func confirmPin(
        messageTid: Int64,
        channelId: ChannelId,
        serverPinId: Int64,
        pinnedUntil: Date?,
        scope: PinnedMessage.Scope
    ) -> Bool {
        guard let pin = PinnedMessageDTO.fetch(
            messageTid: messageTid,
            channelId: channelId,
            context: self
        ) else { return false }

        // Captured before the flip: this is what makes the system message fire once, no matter
        // how many acks or retries arrive for the same pin.
        let wasPending = pin.sync != .synced

        pin.serverPinId = serverPinId
        pin.sync = .synced
        pin.retryCount = 0
        pin.lastAttemptAt = Int64(Date().timeIntervalSince1970 * 1000)
        pin.pinnedUntil = pinnedUntil?.bridgeDate
        pin.scope = scope

        if let message = resolveMessage(
            id: MessageId(pin.messageId),
            tid: pin.messageTid,
            channelId: channelId
        ) {
            let details = PinDetailsDTO.fetchOrCreate(for: message, context: self)
            details.isPinned = true
            details.pinnedUntil = pin.pinnedUntil
        }
        return wasPending
    }

    public func confirmUnpin(messageTid: Int64, channelId: ChannelId) {
        guard let pin = PinnedMessageDTO.fetch(
            messageTid: messageTid,
            channelId: channelId,
            context: self
        ) else { return }

        if let message = resolveMessage(
            id: MessageId(pin.messageId),
            tid: pin.messageTid,
            channelId: channelId
        ) {
            clearPinMirror(on: message)
        }
        delete(pin)
    }

    public func recordPinAttemptFailure(messageTid: Int64, channelId: ChannelId) {
        guard let pin = PinnedMessageDTO.fetch(
            messageTid: messageTid,
            channelId: channelId,
            context: self
        ) else { return }
        pin.retryCount = pin.retryCount &+ 1
        pin.lastAttemptAt = Int64(Date().timeIntervalSince1970 * 1000)
    }

    /// Applies the pin state the server nests on a message.
    ///
    /// Runs from `createOrUpdate(message:channelId:)` immediately **after** `syncPin(for:)`, and
    /// the ordering is the point: `syncPin` maintains the *pin row => mirror* direction, this is
    /// the more authoritative *server => mirror* signal and re-asserts it.
    ///
    /// The state "mirror set, no pin row" that this can leave behind is not a bug. It is what a
    /// personal pin from another device looks like, and what the window before the pin sweep
    /// lands looks like — the bubble shows its indicator, the banner does not list it yet, and
    /// the next sweep resolves it.
    public func applyPinDetails(_ pin: SceytChat.PinDetails?, to dto: MessageDTO) {
        // No pin details at all is not "unpinned". Locally built messages, notification payloads
        // and any pre-pin-API server payload all carry nil; treating that as unpinned would wipe
        // good state on every such write.
        guard let pin else { return }

        applyPinState(
            isPinned: pin.pinned,
            pinnedUntil: pin.pinnedTill,
            scope: PinnedMessage.Scope(pin.pinType),
            to: dto
        )
    }

    public func applyPinState(
        isPinned: Bool,
        pinnedUntil: Date?,
        scope: PinnedMessage.Scope,
        to dto: MessageDTO
    ) {
        let channelId = ChannelId(dto.channelId)
        let existing = PinnedMessageDTO.fetch(messageTid: dto.tid, channelId: channelId, context: self)
            ?? PinnedMessageDTO.fetch(messageId: MessageId(dto.id), channelId: channelId, context: self)

        // An optimistic pin/unpin outranks a message payload: a stale page arriving right after
        // the local write would otherwise wipe it before its ack lands. Same guard, same reason,
        // as the pending-delete check in `createOrUpdate(message:channelId:)`.
        if let existing, existing.sync == .pendingPin || existing.sync == .pendingUnpin {
            return
        }

        guard isPinned else {
            if let existing { delete(existing) }
            clearPinMirror(on: dto)
            return
        }

        let details = PinDetailsDTO.fetchOrCreate(for: dto, context: self)
        details.isPinned = true
        details.pinnedUntil = pinnedUntil?.bridgeDate

        // Refresh an existing row, but never create one. There is no pin id and no `pinnedBy`
        // here, and a row with `serverPinId == 0` would sort to the head of the banner and then
        // be swept by the next reconcile. The sweep and the pin events are what create rows.
        if let existing {
            existing.pinnedUntil = pinnedUntil?.bridgeDate
            existing.scope = scope
        }
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
