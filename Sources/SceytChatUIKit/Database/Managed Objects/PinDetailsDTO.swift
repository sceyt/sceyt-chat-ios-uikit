//
//  PinDetailsDTO.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import CoreData
import Foundation
import SceytChat

/// The pin state the server sends on a message, mirroring its nested `pinDetails` object.
///
/// `isPinned` is authoritative: `pinnedUntil == nil` means the pin never lapses, **not**
/// that the message is unpinned. That is the difference from a bare nullable date, and the
/// reason this is a separate object at all.
///
/// This is the projection the message bubble reads. `PinnedMessageDTO` is the durable
/// per-channel record — who pinned it, when, to whom it is visible, and the preview
/// snapshot — and the two are always written in the same transaction.
///
/// Two obligations come with being a related entity rather than a column:
///
/// 1. **`LazyMessagesObserver` must list `pinDetails.isPinned` and `pinDetails.pinnedUntil`**
///    in its relationship key paths, or pinning never repaints the bubble.
///    `RelationshipKeyPathsObserver` resolves exactly one hop and walks the inverse, so
///    `message` below is required for that to work — same shape as `poll.votesPerOption`.
/// 2. **`NSBatchDeleteRequest` ignores the Cascade rule**, so `channelId` / `messageTid` are
///    carried here to make these rows sweepable by hand wherever messages are batch-deleted.
@objc(PinDetailsDTO)
public class PinDetailsDTO: NSManagedObject {

    @NSManaged public var isPinned: Bool
    /// When the pin lapses. `nil` means it never does.
    @NSManaged public var pinnedUntil: CDDate?
    /// Denormalized so the row can be swept without touching `MessageDTO`.
    @NSManaged public var channelId: Int64
    @NSManaged public var messageTid: Int64
    @NSManaged public var message: MessageDTO?

    /// Pinned and not lapsed — the question every caller actually asks.
    public var isCurrentlyPinned: Bool {
        guard isPinned else { return false }
        guard let pinnedUntil = pinnedUntil?.bridgeDate else { return true }
        return pinnedUntil > Date()
    }

    /// `isPinned` was set but the deadline has passed.
    public var isExpired: Bool {
        guard isPinned, let pinnedUntil = pinnedUntil?.bridgeDate else { return false }
        return pinnedUntil <= Date()
    }

    /// Matches messages whose pin is live right now.
    ///
    /// Evaluated once, at fetch time: an FRC will not re-run it as the clock passes a
    /// deadline, so a pin lapsing while the screen is open survives until the next fetch or
    /// write. Fine while an open-ended pin (`pinnedUntil == nil`) is the common case.
    public static func currentlyPinnedPredicate(now: Date = Date()) -> NSPredicate {
        NSPredicate(
            format: "pinDetails.isPinned == YES AND (pinDetails.pinnedUntil == nil OR pinDetails.pinnedUntil > %@)",
            now as NSDate
        )
    }

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<PinDetailsDTO> {
        return NSFetchRequest<PinDetailsDTO>(entityName: entityName)
    }

    public static func fetch(
        messageTid: Int64,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) -> PinDetailsDTO? {
        fetchAll(messageTid: messageTid, channelId: channelId, context: context).first
    }

    public static func fetchAll(
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) -> [PinDetailsDTO] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "channelId == %lld", channelId)
        return fetch(request: request, context: context)
    }

    public static func fetchAll(context: NSManagedObjectContext) -> [PinDetailsDTO] {
        fetch(request: fetchRequest(), context: context)
    }

    private static func fetchAll(
        messageTid: Int64,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) -> [PinDetailsDTO] {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "messageTid == %lld AND channelId == %lld", messageTid, Int64(channelId)
        )
        return fetch(request: request, context: context)
    }

    /// Attaches (or reuses) the pin details for a message. Always goes through the message so
    /// the relationship and the denormalized keys cannot disagree.
    public static func fetchOrCreate(
        for message: MessageDTO,
        context: NSManagedObjectContext
    ) -> PinDetailsDTO {
        let messageTid = message.tid != 0 ? message.tid : message.id
        let channelId = ChannelId(message.channelId)

        if let existing = message.pinDetails {
            existing.messageTid = messageTid
            existing.channelId = Int64(channelId)
            return existing
        }

        // A row can survive its message being evicted and recreated; adopt it rather than
        // inserting a second one and tripping the uniqueness constraint.
        let rows = fetchAll(messageTid: messageTid, channelId: channelId, context: context)
        if let mo = rows.first {
            if rows.count > 1 {
                rows.dropFirst().forEach { context.delete($0) }
            }
            mo.message = message
            return mo
        }

        let mo = insertNewObject(into: context)
        mo.messageTid = messageTid
        mo.channelId = Int64(channelId)
        mo.message = message
        return mo
    }

    public static func delete(
        messageTid: Int64,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) {
        fetchAll(messageTid: messageTid, channelId: channelId, context: context)
            .forEach { context.delete($0) }
    }

    public static func deleteAll(channelId: ChannelId, context: NSManagedObjectContext) {
        fetchAll(channelId: channelId, context: context)
            .forEach { context.delete($0) }
    }

    /// `before == nil` wipes the channel's rows; otherwise drops only those whose message
    /// fell inside a cleared history window.
    public static func deleteAll(
        channelId: ChannelId,
        before date: Date?,
        context: NSManagedObjectContext
    ) {
        guard let date else {
            deleteAll(channelId: channelId, context: context)
            return
        }
        fetchAll(channelId: channelId, context: context)
            .filter { dto in
                guard let created = dto.message?.createdAt.bridgeDate else { return true }
                return created <= date
            }
            .forEach { context.delete($0) }
    }

    /// Rows whose message is gone. `NSBatchDeleteRequest` ignores the Cascade rule, so this
    /// is the backstop for every batch-delete path that forgets to sweep.
    @discardableResult
    public static func pruneOrphans(context: NSManagedObjectContext) -> Int {
        let orphans = fetchAll(context: context).filter { $0.message == nil }
        orphans.forEach { context.delete($0) }
        return orphans.count
    }

    /// Local channel id -> server channel id, on channel promotion.
    public static func move(
        fromChannelId: ChannelId,
        toChannelId: ChannelId,
        context: NSManagedObjectContext
    ) {
        guard fromChannelId != toChannelId else { return }
        for dto in fetchAll(channelId: fromChannelId, context: context) {
            dto.channelId = Int64(toChannelId)
        }
    }

    public func convert() -> PinDetails {
        .init(dto: self)
    }
}

extension PinDetailsDTO: Identifiable { }
