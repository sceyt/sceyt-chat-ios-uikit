//
//  PinnedMessageTests.swift
//  SceytChatUIKitTests
//
//  Covers the two-sided pinned-message state: the durable `PinnedMessageDTO` row and the
//  `MessageDTO.pinDetails` projection the bubble reads. The invariant under test throughout is
//  that the two are written in the same transaction and never drift — including across
//  edits, deletes, send acks, history clears and channel-id promotion.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

final class PinnedMessageTests: XCTestCase {

    private var mockDB: MockDatabase!
    private var ctx: NSManagedObjectContext { mockDB.container.viewContext }

    private let channelId: ChannelId = 42

    override func setUp() {
        super.setUp()
        mockDB = MockDatabase()
        seedChannel(id: channelId)
    }

    override func tearDown() {
        mockDB = nil
        super.tearDown()
    }

    // MARK: - Helpers

    @discardableResult
    private func seedChannel(id: ChannelId) -> ChannelDTO {
        let (channel, _) = ChannelDTO.fetchOrCreate(id: id, context: ctx)
        channel.createdAt = Date().bridgeDate
        channel.type = "group"
        try? ctx.save()
        return channel
    }

    @discardableResult
    private func seedMessage(
        id: MessageId,
        tid: Int64 = 0,
        channelId: ChannelId,
        body: String = "hello",
        createdAt: Date = Date()
    ) -> MessageDTO {
        let message = MessageDTO.fetchOrCreate(id: id, tid: tid, channelId: Int64(channelId), context: ctx)
        message.id = Int64(id)
        message.tid = tid == 0 ? Int64(id) : tid
        message.channelId = Int64(channelId)
        message.body = body
        message.type = "text"
        message.createdAt = createdAt.bridgeDate
        message.user = UserDTO.fetchOrCreate(id: "me", context: ctx)
        try? ctx.save()
        return message
    }

    @discardableResult
    private func pin(
        _ message: MessageDTO,
        scope: PinnedMessage.Scope = .forAll,
        at date: Date = Date(),
        until: Date? = nil
    ) -> PinnedMessageDTO? {
        let dto = ctx.pinMessage(
            id: MessageId(message.id),
            tid: message.tid,
            channelId: ChannelId(message.channelId),
            scope: scope,
            pinnedAt: date,
            pinnedUntil: until,
            pinnedBy: "me"
        )
        try? ctx.save()
        return dto
    }

    private func pinRow(tid: Int64, channelId: ChannelId? = nil) -> PinnedMessageDTO? {
        PinnedMessageDTO.fetch(messageTid: tid, channelId: channelId ?? self.channelId, context: ctx)
    }

    // MARK: - Pin / unpin

    func testPin_writesBothSidesInOneTransaction() {
        let message = seedMessage(id: 1, channelId: channelId)
        let pinnedAt = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertNotNil(pin(message, scope: .forAll, at: pinnedAt))

        guard let row = pinRow(tid: message.tid) else {
            return XCTFail("the pin row must exist")
        }
        XCTAssertEqual(row.pinnedAt?.bridgeDate, pinnedAt)
        XCTAssertEqual(row.scope, .forAll)
        XCTAssertEqual(row.pinnedByUserId, "me")

        XCTAssertEqual(message.pinDetails?.isPinned, true, "the projection must be written too")
        XCTAssertNil(message.pinDetails?.pinnedUntil, "no deadline means an open-ended pin")
        XCTAssertTrue(ChatMessage(dto: message).isPinned)
    }

    func testPinForMe_isPersistedDistinctlyFromPinForAll() {
        let message = seedMessage(id: 1, channelId: channelId)
        pin(message, scope: .forMe)

        XCTAssertEqual(
            pinRow(tid: message.tid)?.scope, .forMe,
            "scope lives on the pin row; the message mirror only answers is-it-pinned"
        )
    }

    /// 0 is Core Data's default for a missing Integer 16, so it must never decode as a real
    /// scope — that is the whole point of the shifted encoding.
    func testStoredScope_zeroIsUnspecifiedNotARealCase() {
        XCTAssertEqual(PinnedMessageDTO.StoredScope(rawValue: 0), .unspecified)
        XCTAssertNotEqual(PinnedMessageDTO.StoredScope.forMe.rawValue, 0)
        XCTAssertNotEqual(PinnedMessageDTO.StoredScope.forAll.rawValue, 0)
        XCTAssertEqual(PinnedMessageDTO.StoredScope.unspecified.scope, .forMe, "least surprising fallback")
    }

    func testUnpin_clearsBothSides() {
        let message = seedMessage(id: 1, channelId: channelId)
        pin(message)

        ctx.unpinMessage(id: MessageId(message.id), tid: message.tid, channelId: channelId)
        try? ctx.save()

        XCTAssertNil(pinRow(tid: message.tid))
        XCTAssertNil(message.pinDetails)
        XCTAssertFalse(ChatMessage(dto: message).isPinned)
    }

    func testUnpinAll_clearsEveryPinAndMirrorInTheChannel() {
        let a = seedMessage(id: 1, channelId: channelId)
        let b = seedMessage(id: 2, channelId: channelId)
        pin(a); pin(b)

        ctx.unpinAllMessages(channelId: channelId)
        try? ctx.save()

        XCTAssertEqual(ctx.pinnedMessageCount(channelId: channelId), 0)
        XCTAssertNil(a.pinDetails)
        XCTAssertNil(b.pinDetails)
    }

    func testPin_snapshotsBodySenderAndFirstAttachment() {
        let message = seedMessage(id: 1, channelId: channelId, body: "the pinned body")
        message.user?.firstName = "Tabitha"
        message.user?.lastName = "Potter"

        let attachment = AttachmentDTO.insertNewObject(into: ctx)
        attachment.type = "video"
        attachment.name = "clip.mp4"
        attachment.filePath = "/a/clip.mp4"
        attachment.message = message
        try? ctx.save()

        pin(message)

        guard let row = pinRow(tid: message.tid) else { return XCTFail("no pin row") }
        XCTAssertEqual(row.body, "the pinned body")
        XCTAssertEqual(row.senderFirstName, "Tabitha")
        XCTAssertEqual(row.senderLastName, "Potter")
        XCTAssertEqual(row.attachmentType, "video")
        XCTAssertEqual(row.attachmentName, "clip.mp4")

        let model = row.convert()
        XCTAssertEqual(model.sender?.firstName, "Tabitha")
        XCTAssertEqual(model.attachment?.type, "video")
    }

    /// A pinned view-once or auto-deleting message would keep a full body snapshot on disk
    /// after it had vanished from the timeline.
    func testPin_refusesViewOnceTransientAndAutoDeleteMessages() {
        let viewOnce = seedMessage(id: 1, channelId: channelId)
        viewOnce.viewOnce = true

        let transient = seedMessage(id: 2, channelId: channelId)
        transient.transient = true

        let autoDelete = seedMessage(id: 3, channelId: channelId)
        autoDelete.autoDeleteAt = Date().addingTimeInterval(600).bridgeDate
        try? ctx.save()

        for message in [viewOnce, transient, autoDelete] {
            XCTAssertNil(pin(message), "message id \(message.id) must not be pinnable")
            XCTAssertNil(message.pinDetails)
        }
        XCTAssertEqual(ctx.pinnedMessageCount(channelId: channelId), 0)
    }

    func testPin_refusesAMessageThatIsNotInTheLocalStore() {
        XCTAssertNil(
            ctx.pinMessage(id: 999, tid: 999, channelId: channelId,
                           scope: .forAll, pinnedAt: Date(), pinnedBy: "me"),
            "there is no row to snapshot"
        )
    }

    // MARK: - Snapshot freshness

    /// The core of the design: `RelationshipKeyPathsObserver` resolves a single hop, so the
    /// snapshot has to be refreshed from the write side.
    func testEditingAMessage_refreshesTheSnapshot_withoutRedatingThePin() {
        let message = seedMessage(id: 1, channelId: channelId, body: "before")
        let pinnedAt = Date(timeIntervalSince1970: 1_700_000_000)
        pin(message, at: pinnedAt)
        let snapshotBefore = pinRow(tid: message.tid)?.snapshotUpdatedAt ?? 0

        message.body = "after"
        message.state = Int16(ChatMessage.State.edited.intValue)
        ctx.syncPin(for: message)
        try? ctx.save()

        guard let row = pinRow(tid: message.tid) else { return XCTFail("no pin row") }
        XCTAssertEqual(row.body, "after", "the preview must follow the edit")
        XCTAssertEqual(row.pinnedAt?.bridgeDate, pinnedAt, "an edit must not re-date the pin")
        XCTAssertNil(row.pinnedUntil, "nor change its deadline")
        XCTAssertEqual(row.pinnedByUserId, "me", "an edit must not change who pinned it")
        XCTAssertGreaterThanOrEqual(row.snapshotUpdatedAt, snapshotBefore)
    }

    func testSoftDeletedMessage_autoUnpins() {
        let message = seedMessage(id: 1, channelId: channelId)
        pin(message)

        message.state = Int16(ChatMessage.State.deleted.intValue)
        ctx.syncPin(for: message)
        try? ctx.save()

        XCTAssertNil(pinRow(tid: message.tid), "a deleted message must not stay pinned")
        XCTAssertNil(message.pinDetails)
    }

    /// `MessageDTO.fetchOrCreate` can hand back a fresh row for a previously evicted message,
    /// whose mirror is empty while the pin row survived.
    func testRecreatedMessageRow_regainsItsPinMirror() {
        let message = seedMessage(id: 1, channelId: channelId)
        pin(message)

        if let details = message.pinDetails {
            ctx.delete(details)
            message.pinDetails = nil
        }
        ctx.syncPin(for: message)
        try? ctx.save()

        XCTAssertEqual(
            message.pinDetails?.isPinned, true,
            "syncPin must re-project, not just refresh the snapshot"
        )
    }

    /// The reverse repair: the pin row is gone (a batch delete took it) but the mirror survived.
    func testOrphanedMirror_isRepaired() {
        let message = seedMessage(id: 1, channelId: channelId)
        pin(message)
        PinnedMessageDTO.deleteAll(channelId: channelId, context: ctx)

        ctx.syncPin(for: message)
        try? ctx.save()

        XCTAssertNil(message.pinDetails, "a projection with no pin row must be cleared")
    }

    // MARK: - Deletes

    func testHardDeleteById_dropsThePin() {
        let message = seedMessage(id: 1, channelId: channelId)
        pin(message)

        ctx.deleteMessage(id: 1)
        try? ctx.save()

        XCTAssertEqual(ctx.pinnedMessageCount(channelId: channelId), 0)
    }

    /// `deleteMessage(tid:)` delegates with `channelId: 0`, so the sweep has to read the
    /// channel id off the fetched row rather than trusting the argument.
    func testHardDeleteByTid_dropsThePin_evenOnTheLegacyGlobalPath() {
        let message = seedMessage(id: 1, tid: 777, channelId: channelId)
        pin(message)

        ctx.deleteMessage(tid: 777)
        try? ctx.save()

        XCTAssertEqual(ctx.pinnedMessageCount(channelId: channelId), 0)
    }

    /// Exercises the sweep `deleteAllMessages(channelId:before:)` performs. That method itself
    /// can't run here: its `batchDelete` merges into `SceytChatUIKit.shared.database`, whose
    /// persistent store coordinator differs from `MockDatabase`'s — same limitation as
    /// `ChannelDraftTests.testDeleteDraftForChannel_purgesOnlyThatChannelsDraft`.
    func testClearingAChannel_dropsAllPinsAndMirrors() {
        let a = seedMessage(id: 1, channelId: channelId)
        let b = seedMessage(id: 2, channelId: channelId)
        pin(a); pin(b)

        ctx.unpinMessages(channelId: channelId, before: nil)
        try? ctx.save()

        XCTAssertEqual(ctx.pinnedMessageCount(channelId: channelId), 0)
        XCTAssertNil(a.pinDetails)
        XCTAssertNil(b.pinDetails)
    }

    /// Same limitation as above; this is the `before:` branch of that sweep.
    func testClearingHistoryBeforeADate_dropsOnlyTheOlderPins() {
        let oldMessage = seedMessage(id: 1, channelId: channelId,
                                     createdAt: Date(timeIntervalSince1970: 1_000))
        let newMessage = seedMessage(id: 2, channelId: channelId,
                                     createdAt: Date(timeIntervalSince1970: 9_000))
        pin(oldMessage); pin(newMessage)

        ctx.unpinMessages(channelId: channelId, before: Date(timeIntervalSince1970: 5_000))
        try? ctx.save()

        XCTAssertNil(pinRow(tid: 1), "a pin inside the cleared window must go")
        XCTAssertNil(oldMessage.pinDetails, "and so must its projection")
        XCTAssertNotNil(pinRow(tid: 2), "a pin after the cleared window must survive")
        XCTAssertNotNil(newMessage.pinDetails)
    }

    /// Exercises the purge `deleteChannel(id:)` performs, for the same reason as above.
    func testDeletingAChannel_purgesOnlyThatChannelsPins() {
        let otherChannelId: ChannelId = 43
        seedChannel(id: otherChannelId)
        pin(seedMessage(id: 1, channelId: channelId))
        pin(seedMessage(id: 2, tid: 2, channelId: otherChannelId))

        PinnedMessageDTO.deleteAll(channelId: channelId, context: ctx)
        try? ctx.save()

        XCTAssertEqual(ctx.pinnedMessageCount(channelId: channelId), 0)
        XCTAssertEqual(
            ctx.pinnedMessageCount(channelId: otherChannelId), 1,
            "other channels must be untouched"
        )
    }

    func testExpiredAutoDeleteMessage_dropsItsPin() {
        let message = seedMessage(id: 1, channelId: channelId)
        pin(message)
        // Set the expiry only after pinning; pinning an auto-delete message is refused.
        message.autoDeleteAt = Date().addingTimeInterval(-600).bridgeDate
        try? ctx.save()

        ctx.deleteExpiredAutoDeleteMessages()
        try? ctx.save()

        XCTAssertEqual(ctx.pinnedMessageCount(channelId: channelId), 0)
    }

    // MARK: - Re-keying

    func testPromote_carriesThePinFromTidToServerId() {
        let message = seedMessage(id: 0, tid: 555, channelId: channelId)
        pin(message)
        XCTAssertEqual(pinRow(tid: 555)?.messageId, 0, "a pending send has no server id yet")

        PinnedMessageDTO.promote(messageTid: 555, channelId: channelId, to: 909, context: ctx)
        try? ctx.save()

        XCTAssertEqual(pinRow(tid: 555)?.messageId, 909)
        XCTAssertEqual(ctx.pinnedMessageCount(channelId: channelId), 1, "still exactly one row")
    }

    func testChannelIdMove_carriesPinsToTheServerId_andDedupesByTid() {
        let localId: ChannelId = 990
        let serverId: ChannelId = 991
        seedChannel(id: localId)
        seedChannel(id: serverId)

        let local = seedMessage(id: 1, tid: 100, channelId: localId)
        pin(local)
        let clash = seedMessage(id: 2, tid: 100, channelId: serverId)
        pin(clash)

        PinnedMessageDTO.move(fromChannelId: localId, toChannelId: serverId, context: ctx)
        try? ctx.save()

        XCTAssertEqual(ctx.pinnedMessageCount(channelId: localId), 0)
        XCTAssertEqual(
            ctx.pinnedMessageCount(channelId: serverId), 1,
            "the colliding tid must be deduped, source winning"
        )
        XCTAssertEqual(pinRow(tid: 100, channelId: serverId)?.messageId, 1, "the source row won")
    }

    func testPruneOrphans_removesPinsWhoseChannelIsGone() {
        let message = seedMessage(id: 1, channelId: channelId)
        pin(message)
        // Delete the channel row directly, the way a batch delete would.
        if let channel = ChannelDTO.fetch(id: channelId, context: ctx) {
            ctx.delete(channel)
        }
        try? ctx.save()

        XCTAssertEqual(PinnedMessageDTO.pruneOrphans(context: ctx), 1)
        try? ctx.save()
        XCTAssertEqual(ctx.pinnedMessageCount(channelId: channelId), 0)
    }

    // MARK: - Ordering

    /// Timeline order, oldest first — not pin recency, or the banner reshuffles the moment
    /// somebody pins an old message.
    func testPinnedOrder_isTimelineOrderNotPinOrder() {
        let older = seedMessage(id: 1, channelId: channelId, createdAt: Date(timeIntervalSince1970: 1_000))
        let newer = seedMessage(id: 2, channelId: channelId, createdAt: Date(timeIntervalSince1970: 2_000))

        // Pin the NEWER one first, so pin order and timeline order disagree.
        pin(newer, at: Date(timeIntervalSince1970: 5_000))
        pin(older, at: Date(timeIntervalSince1970: 6_000))

        XCTAssertEqual(
            ctx.pinnedMessages(channelId: channelId).map(\.messageId), [1, 2],
            "the banner walks the conversation forward"
        )
    }

    func testPendingPin_sortsByCreatedAtNotById() {
        seedMessage(id: 5, channelId: channelId, createdAt: Date(timeIntervalSince1970: 1_000))
        let pending = seedMessage(id: 0, tid: 400, channelId: channelId,
                                  createdAt: Date(timeIntervalSince1970: 2_000))
        pin(MessageDTO.fetch(id: 5, context: ctx)!)
        pin(pending)

        XCTAssertEqual(
            ctx.pinnedMessages(channelId: channelId).map(\.messageTid), [5, 400],
            "messageId 0 must not sort the pending pin to the head"
        )
    }

    // MARK: - Offline

    /// The reason the snapshot exists at all.
    func testPinnedMessage_stillRendersAfterItsMessageRowIsGone() throws {
        let message = seedMessage(id: 1, channelId: channelId, body: "survives")
        message.user?.firstName = "Tabitha"
        try? ctx.save()
        pin(message)

        // Wipe the message the way a batch delete of history would, leaving the pin behind.
        ctx.delete(message)
        try? ctx.save()

        guard let model = ctx.pinnedMessages(channelId: channelId).first else {
            return XCTFail("the pin must outlive its message row")
        }
        XCTAssertEqual(model.body, "survives")
        XCTAssertEqual(model.sender?.firstName, "Tabitha")
    }

    func testDuplicatePinRows_areCollapsedByFetchOrCreate() {
        let message = seedMessage(id: 1, channelId: channelId)
        pin(message)

        // Simulate two write contexts having inserted concurrently.
        let duplicate = PinnedMessageDTO.insertNewObject(into: ctx)
        duplicate.messageTid = message.tid
        duplicate.channelId = Int64(channelId)
        try? ctx.save()

        _ = PinnedMessageDTO.fetchOrCreate(messageTid: message.tid, channelId: channelId, context: ctx)
        try? ctx.save()

        XCTAssertEqual(ctx.pinnedMessageCount(channelId: channelId), 1)
    }

    // MARK: - Expiry

    /// `pinnedUntil` is what the server sends, so a lapsed pin must stop counting as pinned
    /// everywhere — the bubble, the banner count and the banner's list.
    func testExpiredPin_doesNotCountAsPinned() {
        let message = seedMessage(id: 1, channelId: channelId)
        pin(message, until: Date().addingTimeInterval(-60))
        XCTAssertEqual(message.pinDetails?.isPinned, true, "the flag stays set; the deadline lapsed")

        XCTAssertFalse(ChatMessage(dto: message).isPinned, "a lapsed pin must not mark the bubble")
        XCTAssertEqual(ctx.pinnedMessageCount(channelId: channelId), 0)
        XCTAssertTrue(ctx.pinnedMessages(channelId: channelId).isEmpty)
    }

    func testPinWithFutureExpiry_stillCountsAsPinned() {
        let message = seedMessage(id: 1, channelId: channelId)
        pin(message, until: Date().addingTimeInterval(3_600))

        XCTAssertTrue(ChatMessage(dto: message).isPinned)
        XCTAssertEqual(ctx.pinnedMessageCount(channelId: channelId), 1)
    }

    /// `pinnedUntil == nil` means "never lapses", NOT "unpinned" — that distinction is the
    /// whole reason pin state is an object with its own `isPinned` flag.
    func testOpenEndedPin_neverExpires() {
        let message = seedMessage(id: 1, channelId: channelId)
        pin(message)

        XCTAssertNil(message.pinDetails?.pinnedUntil)
        XCTAssertEqual(message.pinDetails?.isCurrentlyPinned, true)
        XCTAssertEqual(pinRow(tid: message.tid)?.isExpired, false)
        XCTAssertTrue(ChatMessage(dto: message).isPinned)
    }

    func testPinDetails_isPinnedFalse_isNotPinnedEvenWithAFutureDeadline() {
        let message = seedMessage(id: 1, channelId: channelId)
        pin(message, until: Date().addingTimeInterval(3_600))
        message.pinDetails?.isPinned = false
        try? ctx.save()

        XCTAssertFalse(ChatMessage(dto: message).isPinned, "isPinned is authoritative")
    }

    /// A lapsed row is swept the next time its message is written, so it does not sit on disk
    /// forever holding a body snapshot.
    func testExpiredPin_isDroppedOnTheNextMessageWrite() {
        let message = seedMessage(id: 1, channelId: channelId)
        pin(message, until: Date().addingTimeInterval(-60))

        ctx.syncPin(for: message)
        try? ctx.save()

        XCTAssertNil(pinRow(tid: message.tid), "the lapsed row must be swept")
        XCTAssertNil(message.pinDetails)
    }

    /// The display fetch hides lapsed pins; the maintenance fetch must still see them, or a
    /// lapsed pin is stranded on a deleted channel forever.
    func testMaintenanceFetch_stillSeesExpiredPins() {
        let message = seedMessage(id: 1, channelId: channelId)
        pin(message, until: Date().addingTimeInterval(-60))

        XCTAssertEqual(
            PinnedMessageDTO.fetchAll(channelId: channelId, context: ctx).count, 1,
            "delete/move/prune must see rows the display never shows"
        )
        XCTAssertTrue(PinnedMessageDTO.fetchUnexpired(channelId: channelId, context: ctx).isEmpty)

        PinnedMessageDTO.deleteAll(channelId: channelId, context: ctx)
        try? ctx.save()
        XCTAssertTrue(PinnedMessageDTO.fetchAll(channelId: channelId, context: ctx).isEmpty)
    }
}
