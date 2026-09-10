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

    /// The server's own pin id (`SceytChat.PinnedMessage.id`) — and the primary sort key,
    /// see `defaultSortDescriptors`.
    ///
    /// Three values are not real ids:
    /// - `unknownServerPinId` — an optimistic local pin whose id the server has not sent back yet.
    /// - `0` — a row written before the server pin API existed, or by UI-test seeding. The next
    ///   sync either stamps it with a real id (matched by `messageTid`) or sweeps it.
    @NSManaged public var serverPinId: Int64
    @NSManaged public var syncState: Int16
    @NSManaged public var retryCount: Int16
    /// Milliseconds since epoch of the last network attempt. Read by `reconcilePins` to decide
    /// whether an unsynced row is a pin still in flight or one stranded by a crash.
    @NSManaged public var lastAttemptAt: Int64

    /// A pin taken locally whose server id is not known yet.
    ///
    /// `.max` rather than `0` for two reasons. `0` is already taken — it is what rows written
    /// before the server pin API carry. And at the numeric extreme an optimistic pin lands at
    /// the *newest pin* end of the list under both ascending and descending order, so no read
    /// path has to special-case it.
    public static let unknownServerPinId: Int64 = .max

    /// The server has confirmed this pin and told us its id.
    public var hasServerPinId: Bool {
        serverPinId > 0 && serverPinId != Self.unknownServerPinId
    }

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

    /// Same shifted encoding.
    ///
    /// A row is `.pendingPin` on creation and flips to `.synced` when the server acks it. An
    /// unpin of an already-synced pin flips it to `.pendingUnpin` — the row stays on disk, hidden
    /// from every display fetch, until the server acks the removal and it is deleted.
    ///
    /// Both pending states are **durable intents**: they survive relaunch and are drained by
    /// `SyncService.sendPendingPins()`, the same way a pending reaction is. `reconcilePins`
    /// therefore never deletes them, however stale they look — the server has not been told yet,
    /// so its answer cannot be evidence against them.
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

    /// The row carries an intent the server has not acknowledged yet.
    public var isPendingSync: Bool {
        sync == .pendingPin || sync == .pendingUnpin
    }

    /// A pin whose `pinnedUntil` has passed. Lapsed pins stay on disk until something
    /// sweeps them, so every read path has to filter them out.
    public var isExpired: Bool {
        guard let pinnedUntil = pinnedUntil?.bridgeDate else { return false }
        return pinnedUntil <= Date()
    }

    /// Excludes a pin the user has unpinned but the server has not been told about yet.
    ///
    /// The row has to stay on disk — it is the durable intent `SyncService.sendPendingPins()`
    /// drains — but it must not appear anywhere the user can see it, or unpinning offline would
    /// look like it did nothing.
    public static func notPendingUnpinPredicate() -> NSPredicate {
        NSPredicate(format: "syncState != %d", StoredSyncState.pendingUnpin.rawValue)
    }

    /// Matches the rows that are still pinned *now*.
    ///
    /// Note this is evaluated once, at fetch time: an FRC will not re-run it as the clock
    /// passes a pin's expiry, so a pin lapsing while the screen is open survives until the
    /// next fetch or write. Good enough while `Date.distantFuture` is the common case.
    public static func unexpiredPredicate(now: Date = Date()) -> NSPredicate {
        NSPredicate(format: "pinnedUntil == nil OR pinnedUntil > %@", now as NSDate)
    }

    /// The canonical order: **pin order, oldest pin first** — `serverPinId` ascending.
    ///
    /// The server assigns pin ids monotonically and sends no pin timestamp at all
    /// (`SceytChat.PinnedMessage` has an `id`, a `pinnedBy` and a message, and nothing else),
    /// so the pin id is the only thing that can express pin recency. Ascending, so a new pin
    /// *appends*: existing ordinals in the banner ("2 of 5") do not shift under someone else
    /// pinning something, and an optimistic local pin carrying `unknownServerPinId` lands at
    /// the end where it belongs.
    ///
    /// The consequence, which the previous timeline ordering existed to avoid: the banner now
    /// walks pin order, so consecutive taps can move *backwards* through the conversation, and
    /// pinning an old message puts it last in the banner rather than at its timeline position.
    /// That is intended.
    ///
    /// The three timeline descriptors are demoted to tiebreakers and are **not** optional. They
    /// order the rows that tie on the leading key — every pre-server-API row (`serverPinId == 0`)
    /// and every in-flight optimistic pin — and an unstable sort makes the FRC emit phantom
    /// `.move` events.
    ///
    /// One definition, shared by `fetchAll` and the observer, so the list and the
    /// "next pinned message" iteration can never drift apart.
    public static var defaultSortDescriptors: [NSSortDescriptor] {
        [
            NSSortDescriptor(keyPath: \PinnedMessageDTO.serverPinId, ascending: true),
            NSSortDescriptor(keyPath: \PinnedMessageDTO.messageCreatedAt, ascending: true),
            NSSortDescriptor(keyPath: \PinnedMessageDTO.messageId, ascending: true),
            NSSortDescriptor(keyPath: \PinnedMessageDTO.messageTid, ascending: true)
        ]
    }

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<PinnedMessageDTO> {
        return NSFetchRequest<PinnedMessageDTO>(entityName: entityName)
    }

    /// The request the banner and the standalone pinned-messages screen both observe —
    /// one predicate and one order for both, so the two can never disagree about which
    /// pins are live or about which one is the newest. Lapsed pins are excluded; see
    /// `unexpiredPredicate(now:)` for the one caveat about when that is evaluated.
    public static func fetchRequest(channelId: ChannelId) -> NSFetchRequest<PinnedMessageDTO> {
        let request = fetchRequest()
        request.predicate = NSCompoundPredicate(type: .and, subpredicates: [
            NSPredicate(format: "channelId == %lld", channelId),
            unexpiredPredicate(),
            notPendingUnpinPredicate()
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

    public static func fetch(
        serverPinId: Int64,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) -> PinnedMessageDTO? {
        guard serverPinId > 0, serverPinId != unknownServerPinId else { return nil }
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "serverPinId == %lld AND channelId == %lld", serverPinId, Int64(channelId)
        )
        request.sortDescriptors = defaultSortDescriptors
        return fetch(request: request, context: context).first
    }

    /// The channel's pins the server did **not** report — the reconcile candidates.
    ///
    /// Built on `fetchAll(channelId:)` rather than the display request on purpose: a lapsed pin
    /// the server has also dropped has to be swept too, and the display request hides those.
    public static func fetchAll(
        channelId: ChannelId,
        excludingServerPinIds serverPinIds: Set<Int64>,
        context: NSManagedObjectContext
    ) -> [PinnedMessageDTO] {
        fetchAll(channelId: channelId, context: context)
            .filter { !serverPinIds.contains($0.serverPinId) }
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

    /// Every unacknowledged pin intent, oldest first — the work
    /// `SyncService.sendPendingPins()` drains. Ordered so a pin taken before an unpin is sent
    /// in that order.
    public static func fetchPending(context: NSManagedObjectContext) -> [PinnedMessageDTO] {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "syncState == %d OR syncState == %d",
            StoredSyncState.pendingPin.rawValue,
            StoredSyncState.pendingUnpin.rawValue
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \PinnedMessageDTO.lastAttemptAt, ascending: true),
            NSSortDescriptor(keyPath: \PinnedMessageDTO.messageTid, ascending: true)
        ]
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
            unexpiredPredicate(),
            notPendingUnpinPredicate()
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

    /// The pinned message's first attachment, flattened to the five columns the preview needs.
    ///
    /// Exists so the "which attachment represents this message" rule lives in exactly one place
    /// (`pick(from:)`) and can be fed from either a stored `AttachmentDTO` or an SDK `Attachment`.
    /// `ChatMessage.init(dto:)` picks the same way — if these two ever disagree, the pinned
    /// banner and the message bubble show different attachments for the same message.
    public struct AttachmentSnapshot {
        public let type: String
        public let name: String?
        public let filePath: String?
        public let url: String?
        public let metadata: String?

        public init(type: String, name: String?, filePath: String?, url: String?, metadata: String?) {
            self.type = type
            self.name = name
            self.filePath = filePath
            self.url = url
            self.metadata = metadata
        }

        public init(_ dto: AttachmentDTO) {
            self.init(
                type: dto.type,
                name: dto.name,
                filePath: dto.filePath,
                url: dto.url,
                metadata: dto.metadata
            )
        }

        public init(_ attachment: SceytChat.Attachment) {
            self.init(
                type: attachment.type,
                name: attachment.name,
                filePath: attachment.filePath,
                url: attachment.url,
                metadata: attachment.metadata
            )
        }

        public static func pick(from attachments: [AttachmentSnapshot]) -> AttachmentSnapshot? {
            attachments.sorted { lhs, rhs in
                if let l = lhs.filePath, let r = rhs.filePath { return l < r }
                if let l = lhs.url, let r = rhs.url { return l < r }
                return lhs.type < rhs.type
            }.first
        }
    }

    /// The pinned message's sender, flattened. Rebuilt into a `ChatUser` by
    /// `PinnedMessage.init(dto:)` so the existing `UserFormatting` formatters work unchanged.
    public struct SenderSnapshot {
        public let id: String
        public let firstName: String?
        public let lastName: String?
        public let username: String?
        public let avatarUrl: String?

        public init(_ dto: UserDTO) {
            id = dto.id
            firstName = dto.firstName
            lastName = dto.lastName
            username = dto.username
            avatarUrl = dto.avatarUrl
        }

        /// Takes a `ChatUser` rather than the SDK's `User`, whose `init` is unavailable — so
        /// this stays reachable from tests and from any caller that only has a stored user.
        /// `ChatUser(user:)` is the bridge from an SDK user.
        public init(_ user: ChatUser) {
            id = user.id
            firstName = user.firstName
            lastName = user.lastName
            username = user.username
            avatarUrl = user.avatarUrl
        }
    }

    /// The **only** writer of the snapshot columns.
    ///
    /// Deliberately does not touch `pinnedAt` / `pinScope` / `pinnedByUserId` /
    /// `syncState` / `serverPinId`: editing a message's body must not re-date the pin,
    /// change who pinned it, or discard the server's pin id.
    @discardableResult
    public func applySnapshot(from message: MessageDTO) -> PinnedMessageDTO {
        applySnapshot(
            channelId: message.channelId,
            messageId: message.id,
            messageTid: message.tid != 0 ? message.tid : message.id,
            messageCreatedAt: message.createdAt,
            body: message.body,
            messageType: message.type,
            messageState: message.state,
            sender: message.user.map(SenderSnapshot.init),
            attachment: AttachmentSnapshot.pick(
                from: (message.attachments ?? []).map(AttachmentSnapshot.init)
            )
        )
    }

    /// Snapshots straight from an SDK message, **without** inserting a `MessageDTO`.
    ///
    /// This is what the server pin sync uses, and it is not an optimization. Routing pin sync
    /// through `createOrUpdate(message:channelId:)` would insert message rows the conversation
    /// never asked for: `LazyMessagesObserver`'s fetch predicate is channel-wide rather than
    /// range-bounded, so each one becomes a bubble floating alone inside a history gap — and
    /// that method also sets `parent.replied = true`, which (the list fetches on
    /// `replied == false`) would make pin-syncing a *reply* delete its parent from the
    /// conversation.
    ///
    /// It is also what this table was shaped for: a pin renders offline even when its message
    /// was never fetched into the local store. See the class doc.
    ///
    /// - Parameter messageTid: The tid resolved from an existing local row, when there is one.
    ///   Pass `0` to derive it the way `MessageDTO.map(_:)` does. Getting this wrong inserts a
    ///   second pin row for a message that already has one.
    @discardableResult
    public func applySnapshot(
        from message: SceytChat.Message,
        channelId: ChannelId,
        messageTid: Int64 = 0
    ) -> PinnedMessageDTO {
        let resolvedTid = messageTid != 0
            ? messageTid
            : ((message.incoming || message.tid == 0) ? Int64(message.id) : Int64(message.tid))

        return applySnapshot(
            channelId: Int64(channelId),
            messageId: Int64(message.id),
            messageTid: resolvedTid,
            messageCreatedAt: message.createdAt.bridgeDate,
            body: message.body,
            messageType: message.type,
            messageState: Int16(message.state.rawValue),
            // `Message.user` imports as non-optional, but the SDK fills it from the connected
            // client's own user — which is nil for a message built before connecting. Round-trip
            // it through an optional so that case is a missing sender, not a crash.
            sender: (message.user as SceytChat.User?).map { SenderSnapshot(ChatUser(user: $0)) },
            attachment: AttachmentSnapshot.pick(
                from: (message.attachments ?? []).map(AttachmentSnapshot.init)
            )
        )
    }

    @discardableResult
    private func applySnapshot(
        channelId: Int64,
        messageId: Int64,
        messageTid: Int64,
        messageCreatedAt: CDDate?,
        body: String,
        messageType: String?,
        messageState: Int16,
        sender: SenderSnapshot?,
        attachment: AttachmentSnapshot?
    ) -> PinnedMessageDTO {
        self.channelId = channelId
        self.messageId = messageId
        self.messageTid = messageTid
        self.messageCreatedAt = messageCreatedAt

        self.body = body
        self.messageType = messageType
        self.messageState = messageState

        senderId = sender?.id
        senderFirstName = sender?.firstName
        senderLastName = sender?.lastName
        senderUsername = sender?.username
        senderAvatarUrl = sender?.avatarUrl

        attachmentType = attachment?.type
        attachmentName = attachment?.name
        attachmentFilePath = attachment?.filePath
        attachmentUrl = attachment?.url
        attachmentMetadata = attachment?.metadata

        snapshotUpdatedAt = Int64(Date().timeIntervalSince1970 * 1000)
        return self
    }

    public func convert() -> PinnedMessage {
        .init(dto: self)
    }
}

extension PinnedMessageDTO: Identifiable { }
