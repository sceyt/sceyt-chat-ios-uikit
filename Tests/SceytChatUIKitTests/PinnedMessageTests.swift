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

// `PinnedMessage` is ambiguous in this file, and not by accident: the SDK now has its own
// `SceytChat.PinnedMessage` (the server's pin record — id, pinnedBy, message) next to the
// UIKit's `PinnedMessage` (the row snapshot the banner renders). Inside the SceytChatUIKit
// module same-module lookup picks the UIKit one; here, and in any integrator file importing
// both, they are peers — hence `PinnedMessageScope`, which the UIKit exports for exactly this.
private typealias PinScope = PinnedMessageScope

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
        scope: PinScope = .forAll,
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

    /// Marks every pin row `.synced`, so a reconcile treats them as server truth rather than as
    /// optimistic writes inside the grace window.
    private func markSynced() {
        PinnedMessageDTO.fetchAll(context: ctx).forEach { $0.sync = .synced }
        try? ctx.save()
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

    // MARK: - Pending intents

    /// A pin the server has never seen is simply dropped: there is nothing to unpin remotely, so
    /// unpinning cancels the queued pin outright.
    func testUnpinningAPendingPin_dropsTheRowWithNothingToSend() {
        let message = seedMessage(id: 70, channelId: channelId)
        pin(message)
        XCTAssertEqual(pinRow(tid: 70)?.sync, .pendingPin)

        let intent = ctx.unpinMessage(id: 70, tid: message.tid, channelId: channelId)
        try? ctx.save()

        XCTAssertNil(intent, "nothing to send — the server never knew about it")
        XCTAssertNil(pinRow(tid: 70))
        XCTAssertNil(message.pinDetails)
    }

    /// A pin the server acked has to be unpinned *there* too, so the row is kept as a durable
    /// intent instead of deleted.
    func testUnpinningASyncedPin_keepsAPendingUnpinIntent() {
        let message = seedMessage(id: 71, channelId: channelId)
        let row = pin(message)
        row?.serverPinId = 600
        row?.sync = .synced
        try? ctx.save()

        let intent = ctx.unpinMessage(id: 71, tid: message.tid, channelId: channelId)
        try? ctx.save()

        XCTAssertNotNil(intent, "the removal has to be sent")
        XCTAssertEqual(pinRow(tid: 71)?.sync, .pendingUnpin)
        XCTAssertEqual(pinRow(tid: 71)?.serverPinId, 600, "the pin id is what identifies it to the server")
        XCTAssertNil(message.pinDetails, "but the bubble loses its pin at once")
    }

    /// The kept row must be invisible everywhere the user can see, or unpinning offline would
    /// look like it did nothing.
    func testPendingUnpin_isHiddenFromEveryDisplayFetch() {
        let message = seedMessage(id: 72, channelId: channelId)
        let row = pin(message)
        row?.serverPinId = 601
        row?.sync = .synced
        try? ctx.save()
        XCTAssertEqual(ctx.pinnedMessageCount(channelId: channelId), 1)

        ctx.unpinMessage(id: 72, tid: message.tid, channelId: channelId)
        try? ctx.save()

        XCTAssertEqual(ctx.pinnedMessages(channelId: channelId).count, 0)
        XCTAssertEqual(ctx.pinnedMessageCount(channelId: channelId), 0)
        XCTAssertEqual(PinnedMessageDTO.fetchUnexpired(channelId: channelId, context: ctx).count, 0)
        XCTAssertEqual(
            PinnedMessageDTO.fetchAll(channelId: channelId, context: ctx).count, 1,
            "the maintenance fetch must still see it — it is the work the sync has to do"
        )
    }

    func testUnpinningAnAlreadyQueuedUnpin_isIdempotent() {
        let message = seedMessage(id: 73, channelId: channelId)
        let row = pin(message)
        row?.serverPinId = 602
        row?.sync = .synced
        try? ctx.save()

        ctx.unpinMessage(id: 73, tid: message.tid, channelId: channelId)
        try? ctx.save()
        let first = pinRow(tid: 73)?.lastAttemptAt

        let intent = ctx.unpinMessage(id: 73, tid: message.tid, channelId: channelId)
        try? ctx.save()

        XCTAssertNotNil(intent)
        XCTAssertEqual(pinRow(tid: 73)?.sync, .pendingUnpin)
        XCTAssertEqual(pinRow(tid: 73)?.lastAttemptAt, first, "re-asking must not re-date the attempt")
        XCTAssertEqual(PinnedMessageDTO.fetchAll(channelId: channelId, context: ctx).count, 1)
    }

    func testConfirmUnpin_dropsTheRowAndTheMirror() {
        let message = seedMessage(id: 74, channelId: channelId)
        let row = pin(message)
        row?.serverPinId = 603
        row?.sync = .synced
        try? ctx.save()
        ctx.unpinMessage(id: 74, tid: message.tid, channelId: channelId)
        try? ctx.save()

        ctx.confirmUnpin(messageTid: message.tid, channelId: channelId)
        try? ctx.save()

        XCTAssertNil(pinRow(tid: 74))
        XCTAssertNil(message.pinDetails)
    }

    /// `confirmPin` reports whether *this* ack is the one that completed the intent. That boolean
    /// is what stops a retry landing twice from posting two "X pinned" system messages.
    func testConfirmPin_reportsTheTransitionOnlyOnce() {
        let message = seedMessage(id: 75, channelId: channelId)
        pin(message)
        try? ctx.save()

        XCTAssertTrue(
            ctx.confirmPin(messageTid: message.tid, channelId: channelId,
                           serverPinId: 700, pinnedUntil: nil, scope: .forAll),
            "the first ack completes the pending pin"
        )
        try? ctx.save()

        XCTAssertFalse(
            ctx.confirmPin(messageTid: message.tid, channelId: channelId,
                           serverPinId: 700, pinnedUntil: nil, scope: .forAll),
            "a second ack for an already-synced pin is not a transition"
        )
    }

    func testConfirmPin_onAnUnknownRow_reportsNoTransition() {
        XCTAssertFalse(
            ctx.confirmPin(messageTid: 99_999, channelId: channelId,
                           serverPinId: 1, pinnedUntil: nil, scope: .forAll)
        )
    }

    func testRecordPinAttemptFailure_bumpsTheRetryCountAndKeepsTheIntent() {
        let message = seedMessage(id: 76, channelId: channelId)
        pin(message)
        try? ctx.save()

        ctx.recordPinAttemptFailure(messageTid: message.tid, channelId: channelId)
        try? ctx.save()

        let row = pinRow(tid: 76)
        XCTAssertEqual(row?.retryCount, 1)
        XCTAssertEqual(row?.sync, .pendingPin, "a failed attempt must not discard the intent")
    }

    func testFetchPending_returnsBothDirectionsOldestAttemptFirst() {
        let a = seedMessage(id: 80, channelId: channelId)
        let b = seedMessage(id: 81, channelId: channelId)
        let c = seedMessage(id: 82, channelId: channelId)

        pin(a)?.lastAttemptAt = 3_000
        let synced = pin(b)
        synced?.serverPinId = 800
        synced?.sync = .synced
        pin(c)?.lastAttemptAt = 1_000
        try? ctx.save()

        ctx.unpinMessage(id: 81, tid: b.tid, channelId: channelId)
        pinRow(tid: 81)?.lastAttemptAt = 2_000
        try? ctx.save()

        let pending = PinnedMessageDTO.fetchPending(context: ctx)
        XCTAssertEqual(pending.map(\.messageTid), [82, 81, 80])
        XCTAssertEqual(pending.map(\.sync), [.pendingPin, .pendingUnpin, .pendingPin])
    }

    func testFetchPending_ignoresSyncedRows() {
        let message = seedMessage(id: 83, channelId: channelId)
        let row = pin(message)
        row?.serverPinId = 900
        row?.sync = .synced
        try? ctx.save()

        XCTAssertTrue(PinnedMessageDTO.fetchPending(context: ctx).isEmpty)
    }

    /// A queued unpin must not keep the bubble marked, and the repair must not put the mirror
    /// back — the user has already unpinned it.
    func testRepairPinMirrors_doesNotReMarkABubbleForAPendingUnpin() {
        let message = seedMessage(id: 84, channelId: channelId)
        let row = pin(message)
        row?.serverPinId = 901
        row?.sync = .synced
        try? ctx.save()
        ctx.unpinMessage(id: 84, tid: message.tid, channelId: channelId)
        try? ctx.save()

        ctx.repairPinMirrors(channelId: channelId)
        try? ctx.save()

        XCTAssertNil(message.pinDetails, "a pin awaiting removal must not mark its bubble")
        XCTAssertEqual(pinRow(tid: 84)?.sync, .pendingUnpin, "and the intent must survive the repair")
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

    /// An integrator's own message type has to survive the round trip, because the banner
    /// renders from the snapshot and a host formatter can only tell a shared location from a
    /// plain photo by the type — both carry an image attachment and an empty body. Losing the
    /// type here would silently make every custom share preview as its attachment.
    func testPin_snapshotsACustomMessageTypeThroughToThePreviewMessage() {
        let message = seedMessage(id: 1, channelId: channelId, body: "")
        message.type = "location"

        let attachment = AttachmentDTO.insertNewObject(into: ctx)
        attachment.type = "image"
        attachment.name = "map.jpg"
        attachment.message = message
        try? ctx.save()

        pin(message)

        guard let row = pinRow(tid: message.tid) else { return XCTFail("no pin row") }
        XCTAssertEqual(row.messageType, "location")

        let preview = row.convert().previewMessage
        XCTAssertEqual(preview.type, "location", "the type is what a host formatter switches on")
        XCTAssertEqual(
            preview.attachments?.first?.type, "image",
            "and the attachment still has to be there, or a location loses its map thumbnail"
        )
    }

    /// The same guarantee on the other write path: a pin learned from the server sweep, whose
    /// message may never have been fetched into the local store.
    func testStorePin_snapshotsACustomMessageTypeFromTheServerPath() {
        let stored = ctx.storePin(
            message: Message.Builder().id(91).tid(9_100).body("").type("video_post").build(),
            channelId: channelId,
            serverPinId: 6_700,
            pinnedBy: ChatUser(id: "them"),
            pinnedUntil: nil,
            scope: .forAll
        )
        try? ctx.save()

        XCTAssertEqual(stored?.messageType, "video_post")
        XCTAssertEqual(stored?.convert().previewMessage.type, "video_post")
    }

    /// A row written before the snapshot carried a type — or by any path that leaves it unset —
    /// must read back as a plain text message rather than as an empty type no formatter matches.
    func testPinSnapshot_withNoMessageTypeReadsBackAsText() {
        let message = seedMessage(id: 1, channelId: channelId)
        pin(message)

        guard let row = pinRow(tid: message.tid) else { return XCTFail("no pin row") }
        row.messageType = nil
        try? ctx.save()

        XCTAssertEqual(row.convert().messageType, "text")
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
    /// The primary sort key is the server's pin id, ascending.
    func testPinnedOrder_isPinOrderByServerPinId() {
        let older = seedMessage(id: 1, channelId: channelId, createdAt: Date(timeIntervalSince1970: 1_000))
        let newer = seedMessage(id: 2, channelId: channelId, createdAt: Date(timeIntervalSince1970: 2_000))

        // Pin the NEWER message first, so pin order and timeline order disagree.
        pin(newer)?.serverPinId = 100
        pin(older)?.serverPinId = 200
        try? ctx.save()

        XCTAssertEqual(
            ctx.pinnedMessages(channelId: channelId).map(\.messageId), [2, 1],
            "the banner walks pin order, oldest pin first — not the conversation"
        )
    }

    /// With no pin ids yet every row ties on the leading descriptor, so the timeline
    /// tiebreakers decide. This is what keeps seeded fixtures and UI tests in seeding order.
    func testPinsWithNoServerId_fallBackToTimelineOrder() {
        let older = seedMessage(id: 1, channelId: channelId, createdAt: Date(timeIntervalSince1970: 1_000))
        let newer = seedMessage(id: 2, channelId: channelId, createdAt: Date(timeIntervalSince1970: 2_000))

        pin(newer, at: Date(timeIntervalSince1970: 5_000))
        pin(older, at: Date(timeIntervalSince1970: 6_000))

        XCTAssertEqual(ctx.pinnedMessages(channelId: channelId).map(\.messageId), [1, 2])
    }

    /// An optimistic pin is the newest pin by definition, and must read that way *before* the
    /// server tells us its id. That is the whole reason the sentinel is `.max` and not `0`.
    func testOptimisticPin_sortsAsTheNewestPin() {
        let confirmed = seedMessage(id: 1, channelId: channelId, createdAt: Date(timeIntervalSince1970: 9_000))
        let optimistic = seedMessage(id: 2, channelId: channelId, createdAt: Date(timeIntervalSince1970: 1_000))

        pin(confirmed)?.serverPinId = 500
        pin(optimistic)   // keeps `unknownServerPinId`
        try? ctx.save()

        XCTAssertEqual(pinRow(tid: 2)?.serverPinId, PinnedMessageDTO.unknownServerPinId)
        XCTAssertEqual(
            ctx.pinnedMessages(channelId: channelId).map(\.messageId), [1, 2],
            "the in-flight pin sorts last even though its message is the older one"
        )
    }

    /// A row written before the server pin API carries `serverPinId == 0`, which sorts ahead of
    /// every real pin. Harmless: `reconcilePins` sweeps it, or `storePin` stamps it by tid.
    func testLegacyPinWithoutServerId_sortsAheadOfServerPins() {
        let legacy = seedMessage(id: 1, channelId: channelId, createdAt: Date(timeIntervalSince1970: 9_000))
        let server = seedMessage(id: 2, channelId: channelId, createdAt: Date(timeIntervalSince1970: 1_000))

        pin(legacy)?.serverPinId = 0
        pin(server)?.serverPinId = 700
        try? ctx.save()

        XCTAssertEqual(ctx.pinnedMessages(channelId: channelId).map(\.messageId), [1, 2])
    }

    func testPendingPin_withoutAServerId_sortsByCreatedAtNotById() {
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

    func testFetchByServerPinId_ignoresTheSentinelAndZero() {
        let message = seedMessage(id: 1, channelId: channelId)
        let row = pin(message)
        row?.serverPinId = 900
        try? ctx.save()

        XCTAssertEqual(
            PinnedMessageDTO.fetch(serverPinId: 900, channelId: channelId, context: ctx)?.messageTid, 1
        )
        XCTAssertNil(
            PinnedMessageDTO.fetch(serverPinId: 0, channelId: channelId, context: ctx),
            "0 is not a pin id, it is the absence of one"
        )
        XCTAssertNil(
            PinnedMessageDTO.fetch(
                serverPinId: PinnedMessageDTO.unknownServerPinId,
                channelId: channelId,
                context: ctx
            ),
            "the sentinel is not a pin id either"
        )
    }

    // MARK: - Server sync

    /// The regression test for the "never insert a `MessageDTO`" decision. Routing pin sync
    /// through `createOrUpdate(message:)` would make every pinned message a visible bubble
    /// floating in a history gap, and would flip `parent.replied` on a pinned reply — which,
    /// because the message list fetches on `replied == false`, deletes the parent from the
    /// conversation.
    func testStorePin_buildsTheSnapshotWithoutInsertingAMessageRow() {
        let message = Message.Builder()
            .id(77)
            .tid(77)
            .body("pinned from the server")
            .type("text")
            .build()

        let row = ctx.storePin(
            message: message,
            channelId: channelId,
            serverPinId: 4242,
            pinnedBy: ChatUser(id: "them"),
            pinnedUntil: nil,
            scope: .forAll
        )
        try? ctx.save()

        XCTAssertNotNil(row)
        XCTAssertNil(
            MessageDTO.fetch(id: 77, context: ctx),
            "the pin must not conjure a message row the conversation never fetched"
        )
        XCTAssertEqual(row?.serverPinId, 4242)
        XCTAssertEqual(row?.body, "pinned from the server")
        XCTAssertEqual(row?.pinnedByUserId, "them")
        XCTAssertEqual(row?.sync, .synced)
        XCTAssertEqual(row?.scope, .forAll)
    }

    /// The pin table is keyed by `(messageTid, channelId)`, and the server does not always echo
    /// an outgoing message's tid — so the tid has to come from the local row or a message that
    /// already has a pin gets a second one.
    func testStorePin_adoptsTheExistingRowByTid_andStampsTheServerId() {
        let message = seedMessage(id: 80, tid: 9_001, channelId: channelId)
        pin(message)
        XCTAssertEqual(PinnedMessageDTO.count(channelId: channelId, context: ctx), 1)

        let sdkMessage = Message.Builder().id(80).tid(0).body("edited").type("text").build()
        ctx.storePin(
            message: sdkMessage,
            channelId: channelId,
            serverPinId: 5555,
            pinnedBy: ChatUser(id: "them"),
            pinnedUntil: nil,
            scope: .forMe
        )
        try? ctx.save()

        XCTAssertEqual(
            PinnedMessageDTO.count(channelId: channelId, context: ctx), 1,
            "no duplicate row"
        )
        let row = pinRow(tid: 9_001)
        XCTAssertEqual(row?.serverPinId, 5555)
        XCTAssertEqual(row?.body, "edited")
        XCTAssertEqual(row?.scope, .forMe)
        XCTAssertEqual(
            MessageDTO.fetch(id: 80, context: ctx)?.pinDetails?.isPinned, true,
            "the mirror is written in the same transaction"
        )
    }

    /// The pin table is keyed by `(messageTid, channelId)`. With no local row to read the tid
    /// from, the lookup key and the snapshot's tid have to be derived the same way — deriving
    /// them separately inserted a second row for an outgoing message on the next sweep.
    func testStorePin_isIdempotentForAnOutgoingMessageWithNoLocalRow() {
        func store() -> PinnedMessageDTO? {
            ctx.storePin(
                message: Message.Builder().id(90).tid(7_777).body("outgoing").type("text").build(),
                channelId: channelId,
                serverPinId: 6_600,
                pinnedBy: ChatUser(id: "me"),
                pinnedUntil: nil,
                scope: .forAll
            )
        }

        let first = store()
        try? ctx.save()
        XCTAssertEqual(first?.messageTid, 7_777, "an outgoing message keys off its tid")

        store()   // a second sweep reporting the same pin
        try? ctx.save()

        XCTAssertEqual(
            PinnedMessageDTO.count(channelId: channelId, context: ctx), 1,
            "the lookup key and the snapshot must agree, or the sweep duplicates the row"
        )
    }

    func testStorePin_refusesAMessageWithNoServerId() {
        XCTAssertNil(
            ctx.storePin(
                message: Message.Builder().tid(500).build(),
                channelId: channelId,
                serverPinId: 1,
                pinnedBy: ChatUser(id: "me"),
                pinnedUntil: nil,
                scope: .forAll
            )
        )
        XCTAssertEqual(PinnedMessageDTO.count(channelId: channelId, context: ctx), 0)
    }

    func testStorePin_refusesViewOnceTransientAndDeletedMessages() {
        func store(_ message: Message, pinId: Int64) -> PinnedMessageDTO? {
            ctx.storePin(
                message: message,
                channelId: channelId,
                serverPinId: pinId,
                pinnedBy: ChatUser(id: "them"),
                pinnedUntil: nil,
                scope: .forAll
            )
        }

        XCTAssertNil(store(Message.Builder().id(1).transient(true).build(), pinId: 1))
        XCTAssertNil(store(Message.Builder().id(2).viewOnce(true).build(), pinId: 2))
        XCTAssertEqual(PinnedMessageDTO.count(channelId: channelId, context: ctx), 0)

        // A soft-deleted message would flap: the sweep creates the row, `syncPin` deletes it on
        // the next message write, the next sweep creates it again.
        let deleted = seedMessage(id: 3, channelId: channelId)
        deleted.state = Int16(ChatMessage.State.deleted.intValue)
        try? ctx.save()
        XCTAssertNil(store(Message.Builder().id(3).build(), pinId: 3))
        XCTAssertEqual(PinnedMessageDTO.count(channelId: channelId, context: ctx), 0)
    }

    func testConfirmPin_replacesTheSentinelAndMarksItSynced() {
        let message = seedMessage(id: 12, channelId: channelId)
        pin(message)
        XCTAssertEqual(pinRow(tid: 12)?.sync, .pendingPin)
        XCTAssertEqual(pinRow(tid: 12)?.serverPinId, PinnedMessageDTO.unknownServerPinId)

        let until = Date(timeIntervalSince1970: 4_000_000_000)
        ctx.confirmPin(
            messageTid: 12,
            channelId: channelId,
            serverPinId: 8_800,
            pinnedUntil: until,
            scope: .forMe
        )
        try? ctx.save()

        let row = pinRow(tid: 12)
        XCTAssertEqual(row?.serverPinId, 8_800)
        XCTAssertEqual(row?.sync, .synced)
        XCTAssertEqual(row?.retryCount, 0)
        XCTAssertEqual(row?.scope, .forMe)
        XCTAssertEqual(row?.pinnedUntil?.bridgeDate, until)
        XCTAssertEqual(MessageDTO.fetch(id: 12, context: ctx)?.pinDetails?.isPinned, true)
    }

    func testDeletePin_dropsTheRowAndTheMirror() {
        let message = seedMessage(id: 20, channelId: channelId)
        pin(message)?.serverPinId = 3_000
        try? ctx.save()

        ctx.deletePin(serverPinId: 3_000, messageId: 20, channelId: channelId)
        try? ctx.save()

        XCTAssertNil(pinRow(tid: 20))
        XCTAssertNil(MessageDTO.fetch(id: 20, context: ctx)?.pinDetails)
    }

    /// An unpin can name a pin this device never stored — a personal pin from another device, or
    /// a row a batch delete swept.
    func testDeletePin_fallsBackToMessageIdWhenThePinIdIsUnknownHere() {
        let message = seedMessage(id: 21, channelId: channelId)
        pin(message)   // still carries the sentinel, no server id
        try? ctx.save()

        ctx.deletePin(serverPinId: 6_000, messageId: 21, channelId: channelId)
        try? ctx.save()

        XCTAssertNil(pinRow(tid: 21))
        XCTAssertNil(MessageDTO.fetch(id: 21, context: ctx)?.pinDetails)
    }

    // MARK: - Reconcile

    func testReconcilePins_deletesWhatTheServerDidNotReport_withItsMirror() {
        let kept = seedMessage(id: 30, channelId: channelId)
        let dropped = seedMessage(id: 31, channelId: channelId)
        pin(kept)?.serverPinId = 10
        pin(dropped)?.serverPinId = 11
        markSynced()

        ctx.reconcilePins(channelId: channelId, keeping: [10])
        try? ctx.save()

        XCTAssertNotNil(pinRow(tid: 30))
        XCTAssertNil(pinRow(tid: 31))
        XCTAssertEqual(MessageDTO.fetch(id: 30, context: ctx)?.pinDetails?.isPinned, true)
        XCTAssertNil(
            MessageDTO.fetch(id: 31, context: ctx)?.pinDetails,
            "a swept pin must not leave the bubble marked"
        )
    }

    /// The server has not been told about a pending pin, so its absence from the server's answer
    /// is not evidence against it. This is what makes an offline pin survive to be sent.
    func testReconcilePins_neverDeletesAPendingPin() {
        let message = seedMessage(id: 40, channelId: channelId)
        pin(message)   // .pendingPin
        try? ctx.save()

        ctx.reconcilePins(channelId: channelId, keeping: [])
        try? ctx.save()

        XCTAssertNotNil(pinRow(tid: 40))
        XCTAssertEqual(pinRow(tid: 40)?.sync, .pendingPin)
    }

    /// And however stale it looks. A pin taken offline days ago is still an intent the user
    /// expressed and the server has never seen — the same contract a pending reaction has.
    func testReconcilePins_neverDeletesAStalePendingPin() {
        let message = seedMessage(id: 41, channelId: channelId)
        let row = pin(message)
        row?.lastAttemptAt = Int64(Date().addingTimeInterval(-7 * 24 * 3600).timeIntervalSince1970 * 1000)
        row?.retryCount = 12
        try? ctx.save()

        ctx.reconcilePins(channelId: channelId, keeping: [])
        try? ctx.save()

        XCTAssertNotNil(pinRow(tid: 41), "a queued pin is not garbage, however many attempts it has cost")
    }

    /// Nor a queued *unpin*: dropping it would resurrect the pin on the next sweep, because the
    /// server still reports it.
    func testReconcilePins_neverDeletesAPendingUnpin() {
        let message = seedMessage(id: 42, channelId: channelId)
        let row = pin(message)
        row?.serverPinId = 500
        row?.sync = .synced
        try? ctx.save()

        ctx.unpinMessage(id: 42, tid: message.tid, channelId: channelId)
        try? ctx.save()
        XCTAssertEqual(pinRow(tid: 42)?.sync, .pendingUnpin)

        // The server still reports pin 500 — it has not been told about the removal yet.
        ctx.reconcilePins(channelId: channelId, keeping: [500])
        try? ctx.save()

        XCTAssertEqual(pinRow(tid: 42)?.sync, .pendingUnpin, "the queued removal must survive")
    }

    func testReconcilePins_sweepsALegacyRowWithNoServerId() {
        let message = seedMessage(id: 42, channelId: channelId)
        pin(message)?.serverPinId = 0
        markSynced()

        ctx.reconcilePins(channelId: channelId, keeping: [55])
        try? ctx.save()

        XCTAssertNil(pinRow(tid: 42))
    }

    func testReconcilePins_touchesOnlyTheGivenChannel() {
        seedChannel(id: 99)
        let mine = seedMessage(id: 50, channelId: channelId)
        let other = seedMessage(id: 51, channelId: 99)
        pin(mine)?.serverPinId = 1
        pin(other)?.serverPinId = 2
        markSynced()

        ctx.reconcilePins(channelId: channelId, keeping: [])
        try? ctx.save()

        XCTAssertNil(pinRow(tid: 50))
        XCTAssertNotNil(pinRow(tid: 51, channelId: 99))
    }

    /// A lapsed pin the server has also dropped has to be swept too — which is why the reconcile
    /// reads through the maintenance fetch rather than the display request.
    func testReconcilePins_alsoSweepsExpiredRows() {
        let message = seedMessage(id: 52, channelId: channelId)
        let row = pin(message, until: Date().addingTimeInterval(-60))
        row?.serverPinId = 3
        markSynced()

        ctx.reconcilePins(channelId: channelId, keeping: [])
        try? ctx.save()

        XCTAssertNil(pinRow(tid: 52))
    }

    // MARK: - message.pin ingest

    /// Nil pin details is not "unpinned": locally built messages, notification payloads and any
    /// pre-pin-API server payload all carry nil, so treating it as unpinned would wipe good
    /// state on every such write.
    func testApplyPinDetails_nilLeavesPinStateUntouched() {
        let message = seedMessage(id: 60, channelId: channelId)
        pin(message)?.serverPinId = 20
        markSynced()

        ctx.applyPinDetails(nil, to: message)
        try? ctx.save()

        XCTAssertNotNil(pinRow(tid: 60))
        XCTAssertEqual(message.pinDetails?.isPinned, true)
    }

    func testApplyPinState_unpinnedDropsTheRowAndTheMirror() {
        let message = seedMessage(id: 61, channelId: channelId)
        pin(message)?.serverPinId = 21
        markSynced()

        ctx.applyPinState(isPinned: false, pinnedUntil: nil, scope: .forAll, to: message)
        try? ctx.save()

        XCTAssertNil(pinRow(tid: 61))
        XCTAssertNil(message.pinDetails)
    }

    /// A stale message page landing right after an optimistic pin must not wipe it before its
    /// ack arrives — the same guard, for the same reason, as the pending-delete check.
    func testApplyPinState_unpinnedIsIgnoredWhileThePinIsStillInFlight() {
        let message = seedMessage(id: 62, channelId: channelId)
        pin(message)   // .pendingPin
        try? ctx.save()

        ctx.applyPinState(isPinned: false, pinnedUntil: nil, scope: .forAll, to: message)
        try? ctx.save()

        XCTAssertNotNil(pinRow(tid: 62))
        XCTAssertEqual(message.pinDetails?.isPinned, true)
    }

    /// The message payload carries no pin id and no `pinnedBy`, so it may mark the bubble but
    /// must never invent a row — one with `serverPinId == 0` would sort to the head of the
    /// banner and then be swept by the next reconcile.
    func testApplyPinState_pinnedSetsTheMirrorButCreatesNoPinRow() {
        let message = seedMessage(id: 63, channelId: channelId)
        let until = Date(timeIntervalSince1970: 4_000_000_000)

        ctx.applyPinState(isPinned: true, pinnedUntil: until, scope: .forMe, to: message)
        try? ctx.save()

        XCTAssertEqual(message.pinDetails?.isPinned, true)
        XCTAssertEqual(message.pinDetails?.pinnedUntil?.bridgeDate, until)
        XCTAssertEqual(
            PinnedMessageDTO.count(channelId: channelId, context: ctx), 0,
            "the sweep and the pin events are what create rows"
        )
    }

    func testApplyPinState_pinnedRefreshesAnExistingRow() {
        let message = seedMessage(id: 64, channelId: channelId)
        pin(message, scope: .forAll)?.serverPinId = 22
        markSynced()

        let until = Date(timeIntervalSince1970: 4_000_000_000)
        ctx.applyPinState(isPinned: true, pinnedUntil: until, scope: .forMe, to: message)
        try? ctx.save()

        let row = pinRow(tid: 64)
        XCTAssertEqual(row?.scope, .forMe)
        XCTAssertEqual(row?.pinnedUntil?.bridgeDate, until)
        XCTAssertEqual(row?.serverPinId, 22, "the pin id survives a payload refresh")
    }

    /// `syncPin` clears the mirror when there is no pin row; `applyPinDetails` runs after it and
    /// re-asserts the server's answer. The residual "mirror set, no row" is what a personal pin
    /// from another device looks like, and what the window before the sweep lands looks like.
    func testMessageWrite_withServerPinState_leavesTheMirrorSetWithNoRow() {
        let message = seedMessage(id: 65, channelId: channelId)
        ctx.syncPin(for: message)
        ctx.applyPinState(isPinned: true, pinnedUntil: nil, scope: .forAll, to: message)
        try? ctx.save()

        XCTAssertEqual(
            message.pinDetails?.isPinned, true,
            "syncPin must not undo the more authoritative server signal"
        )
        XCTAssertEqual(PinnedMessageDTO.count(channelId: channelId, context: ctx), 0)
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
