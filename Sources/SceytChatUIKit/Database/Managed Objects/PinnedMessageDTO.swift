//
//  PinnedMessageDTO.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import CoreData
import Foundation
import SceytChat

/// A channel's pinned message — the durable record of *what* is pinned.
///
/// Two things make this table's shape non-obvious, and both are deliberate:
///
/// **1. It carries a denormalized preview snapshot, not a relationship.**
/// `MessageDTO` rows are batch-deleted in several places (`deleteAllMessages`,
/// `DeleteChannelsOperation`) and `NSBatchDeleteRequest` does not honour deletion
/// rules, so a relationship would leave dangling references — the crash documented
/// in `ChannelDatabaseSession.deleteMembers`. The snapshot also means a pin renders
/// offline even when its message was never fetched into the local store.
///
/// **2. Snapshot freshness is driven from the write side, never by an observer.**
/// `RelationshipKeyPathsObserver` resolves a *single* hop — it splits the key path
/// on `.` and walks the relationship's inverse — so a `DatabaseObserver` over this
/// entity could not be refreshed by a `message.body` key path even if a `message`
/// relationship existed, and the inverse would then be walked on every `MessageDTO`
/// update in the app. Do not add one. `NSManagedObjectContext.syncPin(for:)` keeps
/// the snapshot current, hooked into `createOrUpdate(message:channelId:changedBy:)`.
///
/// `MessageDTO.pinnedAt` / `.pinScope` mirror this row so the message bubble can show
/// its pin indicator and refresh through the existing `LazyMessagesObserver` with no
/// relationship hop at all. Both sides are always written in the same transaction.
///
/// Not to be confused with `ChannelDTO.pinnedAt`, which means "this channel is pinned
/// to the top of the channel list" — an unrelated, pre-existing feature.
@objc(PinnedMessageDTO)
public class PinnedMessageDTO: NSManagedObject {

    // Identity.
    @NSManaged public var channelId: Int64
    /// The server id, 0 while the message is still a pending send.
    @NSManaged public var messageId: Int64
    @NSManaged public var messageTid: Int64

    // Pin state.
    /// `StoredScope` raw value — never `PinnedMessage.Scope` directly, see `StoredScope`.
    @NSManaged public var pinScope: Int16
    /// When the pin was created.
    @NSManaged public var pinnedAt: CDDate?
    /// When the pin lapses — the field the server sends on the message itself, mirrored
    /// onto `MessageDTO.pinnedUntil`. An indefinite pin is `Date.distantFuture`; `nil`
    /// here means the same thing as a missing row: not pinned.
    @NSManaged public var pinnedUntil: CDDate?
    @NSManaged public var pinnedByUserId: String?

    /// The pinned message's own `createdAt`. Denormalized because it is the sort key
    /// and because `deleteAllMessages(channelId:before:)` batch-deletes the message
    /// rows — after that nothing else can tell which pins fell inside the window.
    @NSManaged public var messageCreatedAt: CDDate?

    // Preview snapshot. Written only by `applySnapshot(from:)`.
    @NSManaged public var body: String
    @NSManaged public var messageType: String?
    @NSManaged public var messageState: Int16
    @NSManaged public var senderId: String?
    @NSManaged public var senderFirstName: String?
    @NSManaged public var senderLastName: String?
    @NSManaged public var senderUsername: String?
    @NSManaged public var senderAvatarUrl: String?
    @NSManaged public var attachmentType: String?
    @NSManaged public var attachmentName: String?
    @NSManaged public var attachmentFilePath: String?
    @NSManaged public var attachmentUrl: String?
    @NSManaged public var attachmentMetadata: String?
    @NSManaged public var snapshotUpdatedAt: Int64

    // Dormant until the SDK grows a message-pin API. Cheap to carry now, and it
    // saves a model version later.
    @NSManaged public var serverPinId: Int64
    @NSManaged public var syncState: Int16
    @NSManaged public var retryCount: Int16
    @NSManaged public var lastAttemptAt: Int64

    /// `PinnedMessage.Scope` is stored shifted, for the same reason as
    /// `PendingMessageDeleteDTO.StoredType`: Core Data's default for a missing
    /// `Integer 16` is 0, so no real case may occupy 0 or a decoding accident
    /// silently becomes a real value.
    public enum StoredScope: Int16 {
        case unspecified = 0
        case forMe = 1
        case forAll = 2

        public init(_ scope: PinnedMessage.Scope) {
            switch scope {
            case .forMe: self = .forMe
            case .forAll: self = .forAll
            }
        }

        public var scope: PinnedMessage.Scope {
            switch self {
            case .forAll: return .forAll
            case .forMe, .unspecified: return .forMe
            }
        }
    }

    /// Same shifted encoding. Every row is `.pendingPin` on creation and flipped to
    /// `.synced` by the (currently no-op) flush; when the server API lands, nothing
    /// about this shape changes.
    public enum StoredSyncState: Int16 {
        case unspecified = 0
        case synced = 1
        case pendingPin = 2
        case pendingUnpin = 3
    }

    public var scope: PinnedMessage.Scope {
        get { (StoredScope(rawValue: pinScope) ?? .forMe).scope }
        set { pinScope = StoredScope(newValue).rawValue }
    }

    public var sync: StoredSyncState {
        get { StoredSyncState(rawValue: syncState) ?? .unspecified }
        set { syncState = newValue.rawValue }
    }

    /// A pin whose `pinnedUntil` has passed. Lapsed pins stay on disk until something
    /// sweeps them, so every read path has to filter them out.
    public var isExpired: Bool {
        guard let pinnedUntil = pinnedUntil?.bridgeDate else { return false }
        return pinnedUntil <= Date()
    }

    /// Matches the rows that are still pinned *now*.
    ///
    /// Note this is evaluated once, at fetch time: an FRC will not re-run it as the clock
    /// passes a pin's expiry, so a pin lapsing while the screen is open survives until the
    /// next fetch or write. Good enough while `Date.distantFuture` is the common case.
    public static func unexpiredPredicate(now: Date = Date()) -> NSPredicate {
        NSPredicate(format: "pinnedUntil == nil OR pinnedUntil > %@", now as NSDate)
    }

    /// The canonical order: timeline order, oldest first — *not* pin recency.
    ///
    /// The banner's ordinal ("2 of 5") has to stay put while the user scrolls, and
    /// tapping through has to walk the conversation forward; sorting by `pinnedAt`
    /// reshuffles the whole banner the moment somebody pins an old message.
    /// `messageCreatedAt` leads so a still-pending pin (`messageId == 0`) sorts at its
    /// real timeline position instead of jumping to the head. The tiebreakers are not
    /// optional: an unstable sort makes the FRC emit phantom `.move` events.
    ///
    /// One definition, shared by `fetchAll` and the observer, so the list and the
    /// "next pinned message" iteration can never drift apart.
    public static var defaultSortDescriptors: [NSSortDescriptor] {
        [
            NSSortDescriptor(keyPath: \PinnedMessageDTO.messageCreatedAt, ascending: true),
            NSSortDescriptor(keyPath: \PinnedMessageDTO.messageId, ascending: true),
            NSSortDescriptor(keyPath: \PinnedMessageDTO.messageTid, ascending: true)
        ]
    }

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<PinnedMessageDTO> {
        return NSFetchRequest<PinnedMessageDTO>(entityName: entityName)
    }

    /// The request the banner and the pinned list both observe. Lapsed pins are excluded —
    /// see `unexpiredPredicate(now:)` for the one caveat about when that is evaluated.
    public static func fetchRequest(channelId: ChannelId) -> NSFetchRequest<PinnedMessageDTO> {
        let request = fetchRequest()
        request.predicate = NSCompoundPredicate(type: .and, subpredicates: [
            NSPredicate(format: "channelId == %lld", channelId),
            unexpiredPredicate()
        ])
        request.sortDescriptors = defaultSortDescriptors
        return request
    }

    // MARK: - Fetch

    public static func fetch(
        messageTid: Int64,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) -> PinnedMessageDTO? {
        fetchAll(messageTid: messageTid, channelId: channelId, context: context).first
    }

    public static func fetch(
        messageId: MessageId,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) -> PinnedMessageDTO? {
        guard messageId != 0 else { return nil }
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "messageId == %lld AND channelId == %lld", Int64(messageId), Int64(channelId)
        )
        request.sortDescriptors = defaultSortDescriptors
        return fetch(request: request, context: context).first
    }

    /// **Every** row for the channel, lapsed pins included.
    ///
    /// Deliberately not built on `fetchRequest(channelId:)`: that one hides expired pins for
    /// display, and the maintenance callers below (delete, move, prune) must see rows the
    /// display never shows, or a lapsed pin is stranded on a deleted channel forever.
    public static func fetchAll(
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) -> [PinnedMessageDTO] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "channelId == %lld", channelId)
        request.sortDescriptors = defaultSortDescriptors
        return fetch(request: request, context: context)
    }

    /// The channel's live pins, in timeline order.
    public static func fetchUnexpired(
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) -> [PinnedMessageDTO] {
        fetch(request: fetchRequest(channelId: channelId), context: context)
    }

    public static func fetchAll(context: NSManagedObjectContext) -> [PinnedMessageDTO] {
        let request = fetchRequest()
        request.sortDescriptors = defaultSortDescriptors
        return fetch(request: request, context: context)
    }

    public static func count(channelId: ChannelId, context: NSManagedObjectContext) -> Int {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "channelId == %lld", channelId)
        return (try? context.count(for: request)) ?? 0
    }

    /// Only the pins that have not lapsed — what the banner's "N pinned" reads.
    public static func countUnexpired(channelId: ChannelId, context: NSManagedObjectContext) -> Int {
        let request = fetchRequest()
        request.predicate = NSCompoundPredicate(type: .and, subpredicates: [
            NSPredicate(format: "channelId == %lld", channelId),
            unexpiredPredicate()
        ])
        return (try? context.count(for: request)) ?? 0
    }

    private static func fetchAll(
        messageTid: Int64,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) -> [PinnedMessageDTO] {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "messageTid == %lld AND channelId == %lld", messageTid, Int64(channelId)
        )
        request.sortDescriptors = defaultSortDescriptors
        return fetch(request: request, context: context)
    }

    // MARK: - Create

    public static func fetchOrCreate(
        messageTid: Int64,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) -> PinnedMessageDTO {
        let existing = fetchAll(messageTid: messageTid, channelId: channelId, context: context)
        if let mo = existing.first {
            // Two write contexts can insert concurrently; keep the oldest record.
            // Leaning on the uniqueness constraint instead would abort the entire
            // transaction, taking unrelated writes down with it.
            if existing.count > 1 {
                existing.dropFirst().forEach { context.delete($0) }
            }
            return mo
        }

        let mo = insertNewObject(into: context)
        mo.messageTid = messageTid
        mo.channelId = Int64(channelId)
        return mo
    }

    // MARK: - Delete

    public static func delete(
        messageTid: Int64,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) {
        fetchAll(messageTid: messageTid, channelId: channelId, context: context)
            .forEach { context.delete($0) }
    }

    public static func delete(
        messageId: MessageId,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) {
        guard messageId != 0 else { return }
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "messageId == %lld AND channelId == %lld", Int64(messageId), Int64(channelId)
        )
        fetch(request: request, context: context).forEach { context.delete($0) }
    }

    public static func deleteAll(channelId: ChannelId, context: NSManagedObjectContext) {
        fetchAll(channelId: channelId, context: context)
            .forEach { context.delete($0) }
    }

    /// `before == nil` wipes the channel's pins; otherwise drops only the pins whose
    /// message fell inside a cleared history window. A pin whose `messageCreatedAt`
    /// is unknown is dropped too — it can no longer be rendered or navigated to.
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
                guard let created = dto.messageCreatedAt?.bridgeDate else { return true }
                return created <= date
            }
            .forEach { context.delete($0) }
    }

    /// Rows whose `channelId` names no `ChannelDTO`. Safety net for the batch-delete
    /// sites: every one of them has to sweep this table by hand, and a future one
    /// will forget.
    @discardableResult
    public static func pruneOrphans(context: NSManagedObjectContext) -> Int {
        let all = fetchAll(context: context)
        guard !all.isEmpty else { return 0 }
        var alive = Set<Int64>()
        var dead = Set<Int64>()
        var pruned = 0
        for dto in all {
            let id = dto.channelId
            if alive.contains(id) { continue }
            if !dead.contains(id) {
                if ChannelDTO.fetch(id: ChannelId(id), context: context) != nil {
                    alive.insert(id)
                    continue
                }
                dead.insert(id)
            }
            context.delete(dto)
            pruned += 1
        }
        return pruned
    }

    // MARK: - Re-keying

    /// Local channel id -> server channel id, on channel promotion.
    ///
    /// Unlike `DraftMessageDTO.move` (one draft per channel, newest wins) the two
    /// sets are UNIONED and deduped by `messageTid`, with the source row winning:
    /// both ids can legitimately hold pins for different messages.
    public static func move(
        fromChannelId: ChannelId,
        toChannelId: ChannelId,
        context: NSManagedObjectContext
    ) {
        guard fromChannelId != toChannelId else { return }
        let source = fetchAll(channelId: fromChannelId, context: context)
        guard !source.isEmpty else { return }

        let destinationByTid = Dictionary(
            fetchAll(channelId: toChannelId, context: context).map { ($0.messageTid, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for dto in source {
            if let clash = destinationByTid[dto.messageTid] {
                context.delete(clash)
            }
            dto.channelId = Int64(toChannelId)
        }
    }

    /// Send ack: the row was keyed by tid, the server id is now known.
    public static func promote(
        messageTid: Int64,
        channelId: ChannelId,
        to messageId: MessageId,
        context: NSManagedObjectContext
    ) {
        guard let dto = fetch(messageTid: messageTid, channelId: channelId, context: context)
        else { return }
        dto.messageId = Int64(messageId)
    }

    // MARK: - Snapshot

    /// The **only** writer of the snapshot columns.
    ///
    /// Deliberately does not touch `pinnedAt` / `pinScope` / `pinnedByUserId` /
    /// `syncState`: editing a message's body must not re-date the pin or change who
    /// pinned it.
    @discardableResult
    public func applySnapshot(from message: MessageDTO) -> PinnedMessageDTO {
        channelId = message.channelId
        messageId = message.id
        messageTid = message.tid != 0 ? message.tid : message.id
        messageCreatedAt = message.createdAt

        body = message.body
        messageType = message.type
        messageState = message.state

        if let user = message.user {
            senderId = user.id
            senderFirstName = user.firstName
            senderLastName = user.lastName
            senderUsername = user.username
            senderAvatarUrl = user.avatarUrl
        } else {
            senderId = nil
            senderFirstName = nil
            senderLastName = nil
            senderUsername = nil
            senderAvatarUrl = nil
        }

        // Pick "first attachment" with the same ordering `ChatMessage.init(dto:)`
        // uses, so the pinned preview and the bubble never disagree about which
        // attachment represents the message.
        let first = message.attachments?.sorted { lhs, rhs in
            if let l = lhs.filePath, let r = rhs.filePath { return l < r }
            if let l = lhs.url, let r = rhs.url { return l < r }
            return lhs.type < rhs.type
        }.first

        attachmentType = first?.type
        attachmentName = first?.name
        attachmentFilePath = first?.filePath
        attachmentUrl = first?.url
        attachmentMetadata = first?.metadata

        snapshotUpdatedAt = Int64(Date().timeIntervalSince1970 * 1000)
        return self
    }

    public func convert() -> PinnedMessage {
        .init(dto: self)
    }
}

extension PinnedMessageDTO: Identifiable { }
