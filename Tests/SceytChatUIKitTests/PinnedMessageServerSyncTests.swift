//
//  PinnedMessageServerSyncTests.swift
//  SceytChatUIKitTests
//
//  Covers the server-backed half of pinned messages: the scope bridge to the SDK's `PinType`,
//  the snapshot built straight from an SDK message, the provider's optimistic-write /
//  confirm / roll-back cycle, the two sync operations, and `SyncService`'s per-channel guard.
//
//  Two SDK facts shape what is reachable here, and both are the reason the production code is
//  split the way it is:
//
//  1. `SceytChat.PinnedMessage` and `SceytChat.PinDetails` declare `init` unavailable, so only
//     the SDK can build one. Every method that takes one delegates to a value-typed core
//     (`storePin(message:channelId:serverPinId:…)`, `applyPinState(…)`, `confirm(…)`) and it is
//     the core that is tested.
//  2. `SceytChat.Message` *can* be built via `Message.Builder`, and `ChannelOperator` is
//     subclassable — so the request/rollback paths are reachable through `MockChannelOperator`.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

// `PinnedMessage` is ambiguous in this file: the SDK has `SceytChat.PinnedMessage` (the server's
// pin record) and the UIKit has its own row snapshot of the same name. `PinnedMessageScope` is
// what the UIKit exports for exactly this — module-qualifying does not work, because the module
// `SceytChatUIKit` and the class `SceytChatUIKit` share a name.
private typealias PinScope = PinnedMessageScope
private typealias PinRecord = PinnedMessageRecord

final class PinnedMessageServerSyncTests: XCTestCase {

    private var mockDB: MockDatabase!
    private var originalDatabase: Database!
    private var ctx: NSManagedObjectContext { mockDB.container.viewContext }

    private let channelId: ChannelId = 77

    override func setUp() {
        super.setUp()
        mockDB = MockDatabase()
        originalDatabase = DataProvider.database
        DataProvider.database = mockDB
        seedChannel(id: channelId)
    }

    override func tearDown() {
        SyncService.cancelAllPinSyncs()
        DataProvider.database = originalDatabase
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
        createdAt: Date = Date()
    ) -> MessageDTO {
        let message = MessageDTO.fetchOrCreate(id: id, tid: tid, channelId: Int64(channelId), context: ctx)
        message.id = Int64(id)
        message.tid = tid == 0 ? Int64(id) : tid
        message.channelId = Int64(channelId)
        message.body = "hello"
        message.type = "text"
        message.createdAt = createdAt.bridgeDate
        message.user = UserDTO.fetchOrCreate(id: "me", context: ctx)
        try? ctx.save()
        return message
    }

    @discardableResult
    private func pin(_ message: MessageDTO, scope: PinScope = .forAll, until: Date? = nil) -> PinnedMessageDTO? {
        let dto = ctx.pinMessage(
            id: MessageId(message.id),
            tid: message.tid,
            channelId: ChannelId(message.channelId),
            scope: scope,
            pinnedAt: Date(),
            pinnedUntil: until,
            pinnedBy: "me"
        )
        try? ctx.save()
        return dto
    }

    private func pinRow(tid: Int64) -> PinnedMessageDTO? {
        PinnedMessageDTO.fetch(messageTid: tid, channelId: channelId, context: ctx)
    }

    /// Waits until every queued database write has landed.
    ///
    /// `sendPinSystemMessage` writes asynchronously from inside `confirm`'s completion, so
    /// counting the rows straight afterwards is a race. `Database.write` funnels onto one serial
    /// context, so a no-op write completing proves everything before it has too.
    private func flushDatabaseWrites() {
        let done = expectation(description: "writes drained")
        mockDB.write({ _ in }, completion: { _ in done.fulfill() })
        wait(for: [done], timeout: 5)
    }

    /// How many "X pinned" system messages the channel holds for `messageId`.
    ///
    /// Matched on the parent link the same way `sendPinSystemMessage` writes it, so this counts
    /// exactly the rows the user would see in the conversation.
    private func systemPinMessageCount(targeting messageId: MessageId) -> Int {
        flushDatabaseWrites()
        ctx.refreshAllObjects()
        let request = MessageDTO.fetchRequest()
        request.predicate = NSPredicate(
            format: "channelId == %lld AND type == %@",
            Int64(channelId), ChatMessage.MessageType.system
        )
        return MessageDTO.fetch(request: request, context: ctx)
            .filter { $0.body == ChatMessage.SystemMessageType.pinnedMessage }
            .filter { $0.parent?.id == Int64(messageId) }
            .count
    }

    /// `PinnedMessagesCompletion` reports a `SceytError`, so a bare `NSError` will not do.
    private func sdkError() -> SceytError { SceytError(domain: "SceytChat", code: 1, userInfo: nil) }

    /// Runs operations on a serial queue and waits **without blocking the main thread**.
    ///
    /// `addOperations(_:waitUntilFinished: true)` cannot be used here: these operations write
    /// through `Database`, whose completions are delivered on the main queue, so a blocked main
    /// thread means the write never completes and the operation never finishes. `wait(for:)`
    /// pumps the runloop instead, which is the whole point.
    private func run(_ operations: [Operation], timeout: TimeInterval = 20) {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let done = expectation(description: "operations finished")
        let barrier = BlockOperation { done.fulfill() }
        operations.forEach { barrier.addDependency($0) }
        queue.addOperations(operations + [barrier], waitUntilFinished: false)
        wait(for: [done], timeout: timeout)
    }

    // MARK: - Scope <-> PinType

    func testScope_mapsToTheSdkPinType() {
        XCTAssertEqual(PinScope.forAll.pinType, .shared,
                       "a pin for everyone is the server's shared scope")
        XCTAssertEqual(PinScope.forMe.pinType, .personal,
                       "a personal pin is the server's personal scope")
    }

    func testSdkPinType_mapsToScope() {
        XCTAssertEqual(PinScope(.shared), .forAll)
        XCTAssertEqual(PinScope(.personal), .forMe)
    }

    func testScopeAndPinType_roundTrip() {
        for scope in [PinScope.forAll, .forMe] {
            XCTAssertEqual(PinScope(scope.pinType), scope)
        }
        for pinType in [PinType.shared, .personal] {
            XCTAssertEqual(PinScope(pinType).pinType, pinType)
        }
    }

    // MARK: - serverPinId

    func testHasServerPinId_isFalseForZeroAndTheSentinel() {
        let row = pin(seedMessage(id: 1, channelId: channelId))!

        row.serverPinId = 0
        XCTAssertFalse(row.hasServerPinId, "0 is a row written before the server pin API")

        row.serverPinId = PinnedMessageDTO.unknownServerPinId
        XCTAssertFalse(row.hasServerPinId, "the sentinel is a pin still in flight")

        row.serverPinId = 1
        XCTAssertTrue(row.hasServerPinId)
    }

    func testSentinelIsIntMax_soAnInFlightPinSortsAsTheNewest() {
        XCTAssertEqual(PinnedMessageDTO.unknownServerPinId, Int64.max,
                       "the value is load-bearing: see defaultSortDescriptors")
    }

    /// The banner and the standalone pinned-messages screen read the pins in one order:
    /// oldest pin first, newest last — the conversation's own direction, which is what puts
    /// the newest pin at the bottom of the list and at the end of the banner's walk.
    ///
    /// Every tiebreaker sorts the same way as the leading key: one left descending would
    /// leave the rows that tie on `serverPinId` in an unstable order, which is what makes
    /// the FRC emit phantom `.move` events.
    func testDefaultSortDescriptors_readOldestPinFirst_tiebreakersIncluded() {
        XCTAssertTrue(PinnedMessageDTO.defaultSortDescriptors.allSatisfy { $0.ascending },
                      "oldest pin first, tiebreakers included")
    }

    func testFetchRequest_isOneOrderAndOnePredicateForBothScreens() {
        let banner = PinnedMessageDTO.fetchRequest(channelId: channelId)
        let list = PinnedMessageDTO.fetchRequest(channelId: channelId)

        XCTAssertEqual(banner.sortDescriptors, PinnedMessageDTO.defaultSortDescriptors)
        XCTAssertEqual(list.sortDescriptors, PinnedMessageDTO.defaultSortDescriptors,
                       "the list reads the pins in the banner's order, not its reverse")
        // Compared with the expiry cutoff redacted: `unexpiredPredicate()` stamps `Date()`
        // into the predicate, so two requests built a microsecond apart are never equal
        // outright — the clause that matters is that both carry the same one.
        XCTAssertEqual(Self.redactingExpiryCutoff(list.predicate),
                       Self.redactingExpiryCutoff(banner.predicate),
                       "one predicate for both: the screens must agree on which pins are live")
    }

    /// `channelId == 77 AND (pinnedUntil == nil OR pinnedUntil > CAST(<now>, "NSDate")) AND …`
    /// with `<now>` taken out, so two predicates built at different instants can be compared.
    private static func redactingExpiryCutoff(_ predicate: NSPredicate?) -> String {
        guard let predicate else { return "nil" }
        return predicate.predicateFormat.replacingOccurrences(
            of: "CAST\\([0-9.]+, \"NSDate\"\\)",
            with: "CAST(<now>, \"NSDate\")",
            options: .regularExpression
        )
    }

    func testPinMessage_stampsTheSentinelAndTheAttemptTime() {
        let before = Int64(Date().timeIntervalSince1970 * 1000)
        let row = pin(seedMessage(id: 2, channelId: channelId))

        XCTAssertEqual(row?.serverPinId, PinnedMessageDTO.unknownServerPinId)
        XCTAssertEqual(row?.sync, .pendingPin)
        XCTAssertGreaterThanOrEqual(row?.lastAttemptAt ?? 0, before,
                                    "reconcilePins measures the grace window off this")
    }

    func testPinMessage_doesNotOverwriteAnAlreadyKnownServerPinId() {
        let message = seedMessage(id: 3, channelId: channelId)
        pin(message)?.serverPinId = 4_000
        try? ctx.save()

        pin(message)   // pin again, e.g. changing the scope
        XCTAssertEqual(pinRow(tid: 3)?.serverPinId, 4_000,
                       "a re-pin must not throw away the id the server already gave us")
    }

    func testFetchAllExcludingServerPinIds_returnsTheReconcileCandidates() {
        pin(seedMessage(id: 4, channelId: channelId))?.serverPinId = 10
        pin(seedMessage(id: 5, channelId: channelId))?.serverPinId = 11
        pin(seedMessage(id: 6, channelId: channelId))?.serverPinId = 12
        try? ctx.save()

        let candidates = PinnedMessageDTO.fetchAll(
            channelId: channelId,
            excludingServerPinIds: [10, 12],
            context: ctx
        )
        XCTAssertEqual(candidates.map(\.serverPinId), [11])
    }

    func testFetchAllExcludingServerPinIds_seesExpiredRowsToo() {
        let row = pin(seedMessage(id: 7, channelId: channelId), until: Date().addingTimeInterval(-60))
        row?.serverPinId = 20
        try? ctx.save()

        XCTAssertEqual(
            PinnedMessageDTO.fetchAll(channelId: channelId, excludingServerPinIds: [], context: ctx).count, 1,
            "a lapsed pin the server also dropped has to be sweepable"
        )
    }

    // MARK: - Snapshot from an SDK message

    func testAttachmentSnapshot_fromAnSdkAttachment() {
        let attachment = Attachment.Builder(url: "https://x/y.jpg", type: "image")
            .name("y.jpg")
            .metadata("{}")
            .build()
        let snapshot = PinnedMessageDTO.AttachmentSnapshot(attachment)

        XCTAssertEqual(snapshot.type, "image")
        XCTAssertEqual(snapshot.name, "y.jpg")
        XCTAssertEqual(snapshot.url, "https://x/y.jpg")
        XCTAssertEqual(snapshot.metadata, "{}")
    }

    func testAttachmentSnapshot_fromAStoredAttachment() {
        let dto = AttachmentDTO.insertNewObject(into: ctx)
        dto.type = "video"
        dto.name = "clip.mp4"
        dto.filePath = "/tmp/clip.mp4"
        dto.url = "https://x/clip.mp4"
        dto.metadata = "{\"d\":3}"

        let snapshot = PinnedMessageDTO.AttachmentSnapshot(dto)
        XCTAssertEqual(snapshot.type, "video")
        XCTAssertEqual(snapshot.name, "clip.mp4")
        XCTAssertEqual(snapshot.filePath, "/tmp/clip.mp4")
        XCTAssertEqual(snapshot.url, "https://x/clip.mp4")
        XCTAssertEqual(snapshot.metadata, "{\"d\":3}")
    }

    /// The ordering rule is shared with `ChatMessage.init(dto:)`. If the two ever disagree, the
    /// pinned preview and the bubble show different attachments for the same message.
    func testAttachmentSnapshotPick_prefersFilePathThenUrlThenType() {
        func snapshot(type: String, filePath: String? = nil, url: String? = nil)
            -> PinnedMessageDTO.AttachmentSnapshot {
            .init(type: type, name: nil, filePath: filePath, url: url, metadata: nil)
        }

        XCTAssertNil(PinnedMessageDTO.AttachmentSnapshot.pick(from: []))

        // Both carry a file path: lowest path wins.
        XCTAssertEqual(
            PinnedMessageDTO.AttachmentSnapshot.pick(from: [
                snapshot(type: "image", filePath: "/b"),
                snapshot(type: "image", filePath: "/a")
            ])?.filePath, "/a"
        )
        // No file paths, both carry urls: lowest url wins.
        XCTAssertEqual(
            PinnedMessageDTO.AttachmentSnapshot.pick(from: [
                snapshot(type: "image", url: "https://b"),
                snapshot(type: "image", url: "https://a")
            ])?.url, "https://a"
        )
        // Neither: lowest type wins.
        XCTAssertEqual(
            PinnedMessageDTO.AttachmentSnapshot.pick(from: [
                snapshot(type: "video"),
                snapshot(type: "file")
            ])?.type, "file"
        )
        XCTAssertEqual(
            PinnedMessageDTO.AttachmentSnapshot.pick(from: [snapshot(type: "image", filePath: "/only")])?.filePath,
            "/only"
        )
    }

    func testSenderSnapshot_fromAStoredUserAndFromAChatUser() {
        let dto = UserDTO.fetchOrCreate(id: "u1", context: ctx)
        dto.firstName = "Ada"
        dto.lastName = "Lovelace"
        dto.username = "ada"
        dto.avatarUrl = "https://x/a.png"

        let fromDTO = PinnedMessageDTO.SenderSnapshot(dto)
        XCTAssertEqual(fromDTO.id, "u1")
        XCTAssertEqual(fromDTO.firstName, "Ada")
        XCTAssertEqual(fromDTO.lastName, "Lovelace")
        XCTAssertEqual(fromDTO.username, "ada")
        XCTAssertEqual(fromDTO.avatarUrl, "https://x/a.png")

        let fromChatUser = PinnedMessageDTO.SenderSnapshot(
            ChatUser(id: "u2", firstName: "Grace", lastName: "Hopper", username: "grace", avatarUrl: nil)
        )
        XCTAssertEqual(fromChatUser.id, "u2")
        XCTAssertEqual(fromChatUser.firstName, "Grace")
        XCTAssertNil(fromChatUser.avatarUrl)
    }

    func testApplySnapshotFromSdkMessage_copiesBodyTypeStateAndAttachment() {
        let message = Message.Builder()
            .id(500)
            .tid(500)
            .body("from the wire")
            .type("text")
            .attachments([Attachment.Builder(url: "https://x/p.jpg", type: "image").name("p.jpg").build()])
            .build()

        let row = PinnedMessageDTO.insertNewObject(into: ctx)
        row.applySnapshot(from: message, channelId: channelId)

        XCTAssertEqual(row.channelId, Int64(channelId))
        XCTAssertEqual(row.messageId, 500)
        XCTAssertEqual(row.body, "from the wire")
        XCTAssertEqual(row.messageType, "text")
        // Compared with a tolerance: the date round-trips through Core Data's own storage, which
        // does not preserve sub-millisecond precision.
        XCTAssertEqual(
            row.messageCreatedAt?.bridgeDate.timeIntervalSince1970 ?? 0,
            message.createdAt.timeIntervalSince1970,
            accuracy: 0.001,
            "the pin's sort-and-render date is the message's own createdAt"
        )
        XCTAssertEqual(row.attachmentType, "image")
        XCTAssertEqual(row.attachmentName, "p.jpg")
        XCTAssertEqual(row.attachmentUrl, "https://x/p.jpg")
        XCTAssertGreaterThan(row.snapshotUpdatedAt, 0)
    }

    /// The rule is `MessageDTO.map(_:)`'s: `(incoming || tid == 0) ? id : tid`.
    ///
    /// The `tid == 0` arm is not reachable through `Message.Builder`, which generates a tid when
    /// one is not supplied — it is covered by `storePin` resolving the tid from a local row.
    func testApplySnapshotFromSdkMessage_derivesTheTidTheSameWayMessageDtoDoes() {
        // Outgoing with a tid: the tid identifies it.
        let outgoing = Message.Builder().id(600).tid(6_000).build()
        let outgoingRow = PinnedMessageDTO.insertNewObject(into: ctx)
        outgoingRow.applySnapshot(from: outgoing, channelId: channelId)
        XCTAssertEqual(outgoingRow.messageTid, 6_000)

        // An explicit tid — what `storePin` passes when a local row already knows it — wins.
        let explicitRow = PinnedMessageDTO.insertNewObject(into: ctx)
        explicitRow.applySnapshot(from: outgoing, channelId: channelId, messageTid: 9_999)
        XCTAssertEqual(explicitRow.messageTid, 9_999)
    }

    /// `storePin` prefers the local row's tid, because the server does not always echo an
    /// outgoing message's — this is the arm the builder cannot reach.
    func testStorePin_prefersTheLocalRowsTidOverTheMessagePayloads() {
        seedMessage(id: 610, tid: 61_000, channelId: channelId)

        let row = ctx.storePin(
            message: Message.Builder().id(610).tid(999).build(),
            channelId: channelId,
            serverPinId: 33,
            pinnedBy: ChatUser(id: "bob"),
            pinnedUntil: nil,
            scope: .forAll
        )
        try? ctx.save()

        XCTAssertEqual(row?.messageTid, 61_000,
                       "the local row's tid is the one the pin table is keyed by")
    }

    /// `Message.user` imports as non-optional, but the SDK fills it from the connected client's
    /// own user — nil for a message built before connecting. That must be a missing sender, not
    /// a crash.
    func testApplySnapshotFromSdkMessage_toleratesAMissingSender() {
        let row = PinnedMessageDTO.insertNewObject(into: ctx)
        row.applySnapshot(from: Message.Builder().id(602).build(), channelId: channelId)
        XCTAssertNotNil(row, "building the snapshot must not trap on a nil user")
    }

    func testStorePin_recordsWhoPinnedItAndPersistsThatUser() {
        ctx.storePin(
            message: Message.Builder().id(700).tid(700).body("x").type("text").build(),
            channelId: channelId,
            serverPinId: 31,
            pinnedBy: ChatUser(id: "bob", firstName: "Bob"),
            pinnedUntil: nil,
            scope: .forAll
        )
        try? ctx.save()

        XCTAssertEqual(pinRow(tid: 700)?.pinnedByUserId, "bob")
        XCTAssertEqual(
            UserDTO.fetch(id: "bob", context: ctx)?.firstName, "Bob",
            "the pinning user is persisted so a \"pinned by X\" label can resolve"
        )
    }

    func testStorePin_carriesTheExpiryAndLeavesPinnedAtAlone() {
        let message = seedMessage(id: 701, channelId: channelId)
        let pinnedAt = Date(timeIntervalSince1970: 1_000)
        _ = ctx.pinMessage(
            id: 701, tid: message.tid, channelId: channelId,
            scope: .forAll, pinnedAt: pinnedAt, pinnedUntil: nil, pinnedBy: "me"
        )
        try? ctx.save()

        let until = Date(timeIntervalSince1970: 4_000_000_000)
        ctx.storePin(
            message: Message.Builder().id(701).tid(0).body("x").type("text").build(),
            channelId: channelId,
            serverPinId: 32,
            pinnedBy: ChatUser(id: "bob"),
            pinnedUntil: until,
            scope: .forMe
        )
        try? ctx.save()

        let row = pinRow(tid: 701)
        XCTAssertEqual(row?.pinnedUntil?.bridgeDate, until)
        XCTAssertEqual(row?.scope, .forMe)
        XCTAssertEqual(
            row?.pinnedAt?.bridgeDate, pinnedAt,
            "the SDK sends no pin timestamp, so an existing local one must survive"
        )
    }

    func testConfirmPin_isANoOpWhenThereIsNoRow() {
        ctx.confirmPin(messageTid: 12_345, channelId: channelId, serverPinId: 1, pinnedUntil: nil, scope: .forAll)
        try? ctx.save()
        XCTAssertEqual(PinnedMessageDTO.count(channelId: channelId, context: ctx), 0,
                       "confirming an unknown pin must not conjure a row")
    }

    // MARK: - Provider: query

    func testCreateDefaultQuery_isAllScopesDescendingAtTheConfiguredLimit() {
        let provider = ChannelPinnedMessageProvider(channelId: channelId)
        let query = provider.createDefaultQuery()

        XCTAssertEqual(query.channelId, channelId)
        XCTAssertEqual(query.limit, SceytChatUIKit.shared.config.queryLimits.pinnedMessageListQueryLimit)
        XCTAssertEqual(query.pinType, .all,
                       "a scope filter would make every personal pin look server-deleted")
        XCTAssertEqual(query.order, .desc,
                       "the newest pins must land first — the banner opens on that end")
    }

    func testDefaultPinnedMessageQueryLimit_isRaisedAboveTheSdkDefaultOfTen() {
        XCTAssertEqual(SceytChatUIKit.shared.config.queryLimits.pinnedMessageListQueryLimit, 30)
    }

    // MARK: - Provider: flush, confirm, roll back

    func testFlushPendingPin_sendsTheIdExpiryAndScope() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let message = seedMessage(id: 800, channelId: channelId)
        let until = Date(timeIntervalSince1970: 4_000_000_000)
        let record = pin(message, scope: .forMe, until: until)!.convert()

        let done = expectation(description: "flushed")
        provider.flushPendingPin(record) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(provider.mockOperator.pinnedIds, [[NSNumber(value: 800)]])
        XCTAssertEqual(provider.mockOperator.lastPinTill, until)
        XCTAssertEqual(provider.mockOperator.lastPinType, .personal,
                       "a personal pin must go out as the server's personal scope")
    }

    func testFlushPendingPin_skipsAMessageWithNoServerId() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let pending = seedMessage(id: 0, tid: 900, channelId: channelId)
        let record = pin(pending)!.convert()

        let done = expectation(description: "skipped")
        provider.flushPendingPin(record) { error in
            XCTAssertNil(error)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertTrue(provider.mockOperator.pinnedIds.isEmpty,
                      "there is nothing to send for a message the server has never seen")
        XCTAssertNotNil(pinRow(tid: 900), "and the optimistic row must be left alone")
    }

    /// A failed attempt must leave the intent on disk. Rolling the pin back would make it
    /// flicker in and vanish, and would lose an instruction the user gave.
    func testFlushPendingPin_onFailure_keepsTheIntentAndCountsTheAttempt() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        provider.mockOperator.pinError = sdkError()
        let message = seedMessage(id: 801, channelId: channelId)
        let record = pin(message)!.convert()

        let done = expectation(description: "attempted")
        provider.flushPendingPin(record) { error in
            XCTAssertNotNil(error, "the caller still learns the attempt failed")
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        ctx.refreshAllObjects()
        let row = pinRow(tid: 801)
        XCTAssertEqual(row?.sync, .pendingPin, "the intent survives for the next sync")
        XCTAssertEqual(row?.retryCount, 1)
        XCTAssertEqual(
            MessageDTO.fetch(id: 801, context: ctx)?.pinDetails?.isPinned, true,
            "and the bubble stays marked — the user's pin has not been undone"
        )
    }

    /// A server that acks without returning the pin gives us no id to record, so the intent has
    /// to stay queued rather than be treated as done.
    func testFlushPendingPin_whenTheAckCarriesNoPin_keepsTheIntent() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let message = seedMessage(id: 802, channelId: channelId)
        let record = pin(message)!.convert()

        let done = expectation(description: "attempted")
        provider.flushPendingPin(record) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        ctx.refreshAllObjects()
        XCTAssertEqual(pinRow(tid: 802)?.sync, .pendingPin)
    }

    /// Offline is not a rejection and not an error: the pin stays visible and stays queued.
    func testFlushPendingPin_offline_keepsThePendingRowAndSendsNothing() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        provider.isConnected = false
        let message = seedMessage(id: 808, channelId: channelId)
        let record = pin(message)!.convert()

        let done = expectation(description: "skipped")
        provider.flushPendingPin(record) { error in
            XCTAssertNil(error, "being offline is not an error the caller has to handle")
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertTrue(provider.mockOperator.pinnedIds.isEmpty, "nothing can be sent while offline")
        ctx.refreshAllObjects()
        let row = pinRow(tid: 808)
        XCTAssertNotNil(row, "the optimistic pin must survive")
        XCTAssertEqual(row?.sync, .pendingPin, "and stay queued for the next sync")
        XCTAssertEqual(
            MessageDTO.fetch(id: 808, context: ctx)?.pinDetails?.isPinned, true,
            "the bubble keeps its pin, so the user sees the action took effect"
        )
    }

    func testCanReachServer_followsTheConnectionState() {
        let provider = ChannelPinnedMessageProvider(channelId: channelId)
        XCTAssertEqual(provider.canReachServer, DataProvider.chatClient.connectionState == .connected)
    }

    func testConfirm_stampsTheServerAnswerOnTheRow() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let message = seedMessage(id: 804, channelId: channelId)
        let record = pin(message)!.convert()
        let until = Date(timeIntervalSince1970: 4_000_000_000)

        let done = expectation(description: "confirmed")
        provider.confirm(record, serverPinId: 7_777, pinnedUntil: until, scope: .forMe) { error in
            XCTAssertNil(error)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        ctx.refreshAllObjects()
        let row = pinRow(tid: 804)
        XCTAssertEqual(row?.serverPinId, 7_777)
        XCTAssertEqual(row?.sync, .synced)
        XCTAssertEqual(row?.scope, .forMe)
        XCTAssertEqual(row?.pinnedUntil?.bridgeDate, until)
    }

    // MARK: - The "X pinned" system message

    /// Posted from the server's ack, not from the tap — so a pin taken offline announces itself
    /// when it is actually pinned, which is the whole point of the change.
    func testConfirmingAForAllPin_postsTheSystemMessage() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let message = seedMessage(id: 820, channelId: channelId)
        let record = pin(message, scope: .forAll)!.convert()

        let done = expectation(description: "confirmed")
        provider.confirm(record, serverPinId: 10, pinnedUntil: nil, scope: .forAll) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(systemPinMessageCount(targeting: 820), 1)
    }

    /// A personal pin is invisible to the other members, so announcing it would be wrong.
    func testConfirmingAForMePin_postsNoSystemMessage() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let message = seedMessage(id: 821, channelId: channelId)
        let record = pin(message, scope: .forMe)!.convert()

        let done = expectation(description: "confirmed")
        provider.confirm(record, serverPinId: 11, pinnedUntil: nil, scope: .forMe) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(systemPinMessageCount(targeting: 821), 0)
    }

    /// The retry can land more than once for the same intent — a lost ack, a duplicate sweep.
    /// Only the ack that completed it may announce it.
    func testConfirmingTheSamePinTwice_postsTheSystemMessageOnce() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let message = seedMessage(id: 822, channelId: channelId)
        let record = pin(message, scope: .forAll)!.convert()

        for index in 0 ..< 2 {
            let done = expectation(description: "confirmed \(index)")
            provider.confirm(record, serverPinId: 12, pinnedUntil: nil, scope: .forAll) { _ in done.fulfill() }
            wait(for: [done], timeout: 5)
        }

        XCTAssertEqual(
            systemPinMessageCount(targeting: 822), 1,
            "a second ack for an already-synced pin must not announce it again"
        )
    }

    /// A failed attempt has not pinned anything, so there is nothing to announce yet.
    func testAFailedPinAttempt_postsNoSystemMessage() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        provider.mockOperator.pinError = sdkError()
        let message = seedMessage(id: 823, channelId: channelId)
        let record = pin(message, scope: .forAll)!.convert()

        let done = expectation(description: "attempted")
        provider.flushPendingPin(record) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(systemPinMessageCount(targeting: 823), 0)
    }

    func testConfirmingAForAllPin_postsNothingWhenTheFlagIsOff() {
        let original = SceytChatUIKit.shared.config.sendsPinSystemMessage
        SceytChatUIKit.shared.config.sendsPinSystemMessage = false
        defer { SceytChatUIKit.shared.config.sendsPinSystemMessage = original }

        let provider = MockPinnedMessageProvider(channelId: channelId)
        let message = seedMessage(id: 824, channelId: channelId)
        let record = pin(message, scope: .forAll)!.convert()

        let done = expectation(description: "confirmed")
        provider.confirm(record, serverPinId: 13, pinnedUntil: nil, scope: .forAll) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(systemPinMessageCount(targeting: 824), 0)
    }

    // MARK: - Provider: unpin

    func testUnpinningASyncedPin_queuesTheRemovalThenClearsItOnTheAck() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let message = seedMessage(id: 805, channelId: channelId)
        let row = pin(message)
        row?.serverPinId = 900
        row?.sync = .synced
        try? ctx.save()

        let done = expectation(description: "unpinned")
        provider.unpin(message: message.convert()) { error in
            XCTAssertNil(error)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(provider.mockOperator.unpinnedIds, [[NSNumber(value: 805)]])
        ctx.refreshAllObjects()
        XCTAssertNil(pinRow(tid: 805), "the ack is what finally deletes the row")
    }

    func testUnpinningASyncedPin_onFailure_keepsTheRemovalQueued() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        provider.mockOperator.unpinError = sdkError()
        let message = seedMessage(id: 806, channelId: channelId)
        let row = pin(message)
        row?.serverPinId = 901
        row?.sync = .synced
        try? ctx.save()

        let done = expectation(description: "unpin failed")
        provider.unpin(message: message.convert()) { error in
            XCTAssertNotNil(error)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        ctx.refreshAllObjects()
        XCTAssertEqual(pinRow(tid: 806)?.sync, .pendingUnpin, "the removal stays queued for the next sync")
        XCTAssertEqual(pinRow(tid: 806)?.retryCount, 1)
        XCTAssertEqual(ctx.pinnedMessages(channelId: channelId).count, 0, "but stays out of the UI")
    }

    func testUnpinningASyncedPin_offline_queuesTheRemovalAndSendsNothing() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        provider.isConnected = false
        let message = seedMessage(id: 807, channelId: channelId)
        let row = pin(message)
        row?.serverPinId = 902
        row?.sync = .synced
        try? ctx.save()

        let done = expectation(description: "queued")
        provider.unpin(message: message.convert()) { error in
            XCTAssertNil(error)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertTrue(provider.mockOperator.unpinnedIds.isEmpty)
        ctx.refreshAllObjects()
        XCTAssertEqual(pinRow(tid: 807)?.sync, .pendingUnpin)
        XCTAssertEqual(ctx.pinnedMessages(channelId: channelId).count, 0)
    }

    /// Unpinning a pin that never reached the server sends nothing at all.
    func testUnpinningAPendingPin_sendsNothing() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let message = seedMessage(id: 810, channelId: channelId)
        pin(message)

        let done = expectation(description: "cancelled")
        provider.unpin(message: message.convert()) { error in
            XCTAssertNil(error)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertTrue(
            provider.mockOperator.unpinnedIds.isEmpty,
            "the server never knew about this pin, so there is nothing to unpin there"
        )
        ctx.refreshAllObjects()
        XCTAssertNil(pinRow(tid: 810))
    }

    func testUnpinAStoredPin_usesItsSnapshotRatherThanAMessageRow() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let message = seedMessage(id: 811, channelId: channelId)
        let row = pin(message)
        row?.serverPinId = 903
        row?.sync = .synced
        try? ctx.save()
        let record = pinRow(tid: 811)!.convert()

        let done = expectation(description: "unpinned")
        provider.unpin(record) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(provider.mockOperator.unpinnedIds, [[NSNumber(value: 811)]])
        ctx.refreshAllObjects()
        XCTAssertNil(pinRow(tid: 811))
    }

    // MARK: - Draining the queue

    /// `flushPendingIntent` is what `PinResendOperation` calls; it has to pick the direction from
    /// the record's own state.
    func testFlushPendingIntent_sendsAPinForAPendingPinRecord() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let message = seedMessage(id: 830, channelId: channelId)
        let record = pin(message)!.convert()

        let done = expectation(description: "flushed")
        provider.flushPendingIntent(record) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(provider.mockOperator.pinnedIds, [[NSNumber(value: 830)]])
        XCTAssertTrue(provider.mockOperator.unpinnedIds.isEmpty)
    }

    func testFlushPendingIntent_sendsAnUnpinForAPendingUnpinRecord() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let message = seedMessage(id: 831, channelId: channelId)
        let row = pin(message)
        row?.serverPinId = 910
        row?.sync = .synced
        try? ctx.save()
        ctx.unpinMessage(id: 831, tid: message.tid, channelId: channelId)
        try? ctx.save()
        let record = PinnedMessageDTO.fetch(messageTid: 831, channelId: channelId, context: ctx)!.convert()

        let done = expectation(description: "flushed")
        provider.flushPendingIntent(record) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(provider.mockOperator.unpinnedIds, [[NSNumber(value: 831)]])
        XCTAssertTrue(provider.mockOperator.pinnedIds.isEmpty)
    }

    func testFlushPendingIntent_ignoresASyncedRecord() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let message = seedMessage(id: 832, channelId: channelId)
        let row = pin(message)
        row?.serverPinId = 911
        row?.sync = .synced
        try? ctx.save()
        let record = pinRow(tid: 832)!.convert()

        let done = expectation(description: "flushed")
        provider.flushPendingIntent(record) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertTrue(provider.mockOperator.pinnedIds.isEmpty)
        XCTAssertTrue(provider.mockOperator.unpinnedIds.isEmpty)
    }

    func testFetchPendingPins_findsIntentsAcrossChannels() {
        seedChannel(id: 88)
        let mine = seedMessage(id: 840, channelId: channelId)
        let other = seedMessage(id: 841, channelId: 88)
        pin(mine)
        _ = ctx.pinMessage(
            id: 841, tid: other.tid, channelId: 88,
            scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
        )
        try? ctx.save()

        let done = expectation(description: "fetched")
        var records = [PinnedMessageRecord]()
        ChannelPinnedMessageProvider.fetchPendingPins { records = $0; done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(Set(records.map(\.messageTid)), [840, 841])
    }

    func testMakePendingPinOperations_buildsOnePerIntent() {
        let a = seedMessage(id: 850, channelId: channelId)
        let b = seedMessage(id: 851, channelId: channelId)
        pin(a)
        pin(b)

        let done = expectation(description: "built")
        var operations = [PinResendOperation]()
        SyncService.makePendingPinOperations { operations = $0; done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(operations.count, 2)
    }

    func testMakePendingPinOperations_canBeScopedToOneChannel() {
        seedChannel(id: 89)
        let mine = seedMessage(id: 860, channelId: channelId)
        let other = seedMessage(id: 861, channelId: 89)
        pin(mine)
        _ = ctx.pinMessage(
            id: 861, tid: other.tid, channelId: 89,
            scope: .forAll, pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"
        )
        try? ctx.save()

        let done = expectation(description: "built")
        var operations = [PinResendOperation]()
        SyncService.makePendingPinOperations(channelId: channelId) { operations = $0; done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(operations.count, 1, "the channel-open sweep only drains its own channel")
        XCTAssertEqual(operations.first?.record.messageTid, 860)
    }

    func testMakePendingPinOperations_isEmptyWithNothingQueued() {
        let done = expectation(description: "built")
        var operations = [PinResendOperation]()
        SyncService.makePendingPinOperations { operations = $0; done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertTrue(operations.isEmpty)
    }

    /// The resend operation must finish even with no connection, or the serial queue stalls and
    /// every later intent is stuck behind it.
    func testPinResendOperation_finishesWhenOffline() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let message = seedMessage(id: 870, channelId: channelId)
        let record = pin(message)!.convert()

        let operation = PinResendOperation(provider: provider, record: record)
        run([operation])

        XCTAssertTrue(operation.isFinished)
        ctx.refreshAllObjects()
        XCTAssertEqual(pinRow(tid: 870)?.sync, .pendingPin, "and the intent is still there to retry")
    }

    func testPinResendOperation_finishesWhenCancelled() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let message = seedMessage(id: 871, channelId: channelId)
        let record = pin(message)!.convert()

        let operation = PinResendOperation(provider: provider, record: record)
        operation.cancel()
        run([operation])

        XCTAssertTrue(operation.isFinished)
    }

    // MARK: - Provider: store and reconcile

    func testStoreEmptyPage_isANoOpAndStillCallsBack() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let done = expectation(description: "stored")
        provider.store(pinnedMessages: []) { error in
            XCTAssertNil(error)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(PinnedMessageDTO.count(channelId: channelId, context: ctx), 0)
    }

    func testProviderReconcile_dropsWhatIsNotInTheKeepSet() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        pin(seedMessage(id: 810, channelId: channelId))?.serverPinId = 40
        pin(seedMessage(id: 811, channelId: channelId))?.serverPinId = 41
        PinnedMessageDTO.fetchAll(context: ctx).forEach { $0.sync = .synced }
        try? ctx.save()

        let done = expectation(description: "reconciled")
        provider.reconcile(serverPinIds: [40]) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        ctx.refreshAllObjects()
        XCTAssertNotNil(pinRow(tid: 810))
        XCTAssertNil(pinRow(tid: 811))
    }


    // MARK: - Operations

    func testReconcileOperation_appliesItsKeepSet() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        pin(seedMessage(id: 820, channelId: channelId))?.serverPinId = 50
        pin(seedMessage(id: 821, channelId: channelId))?.serverPinId = 51
        PinnedMessageDTO.fetchAll(context: ctx).forEach { $0.sync = .synced }
        try? ctx.save()

        let operation = ReconcilePinnedMessagesOperation(channelId: channelId, provider: provider)
        operation.addPin(serverPinIds: [50])

        run([operation])

        ctx.refreshAllObjects()
        XCTAssertNotNil(pinRow(tid: 820))
        XCTAssertNil(pinRow(tid: 821))
    }

    func testReconcileOperation_accumulatesKeepIdsAcrossCalls() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let operation = ReconcilePinnedMessagesOperation(channelId: channelId, provider: provider)
        operation.addPin(serverPinIds: [1, 2])
        operation.addPin(serverPinIds: [2, 3])
        XCTAssertEqual(operation.serverPinIds, [1, 2, 3])
    }

    /// The single most important behaviour in the whole sweep: a cancelled reconcile must delete
    /// nothing. It is what stops a dropped connection from wiping every local pin.
    func testCancelledReconcileOperation_deletesNothingAndStillFinishes() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        pin(seedMessage(id: 830, channelId: channelId))?.serverPinId = 60
        PinnedMessageDTO.fetchAll(context: ctx).forEach { $0.sync = .synced }
        try? ctx.save()

        let operation = ReconcilePinnedMessagesOperation(channelId: channelId, provider: provider)
        operation.cancel()

        run([operation])

        XCTAssertTrue(operation.isFinished, "a cancelled operation must still finish, or the queue wedges")
        ctx.refreshAllObjects()
        XCTAssertNotNil(pinRow(tid: 830), "an abandoned sweep must never delete a pin")
    }

    func testFetchOperation_failsWithoutAConnectionRatherThanReportingAnEmptyServer() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let operation = FetchAllPinnedMessagesOperation(
            query: provider.createDefaultQuery(),
            provider: provider
        )

        run([operation])

        XCTAssertTrue(operation.isFinished)
        switch operation.result {
        case .failure:
            break   // expected: reporting success here would reconcile every pin away
        default:
            XCTFail("an unconnected fetch must not report success, got \(String(describing: operation.result))")
        }
    }

    /// A fetch cancelled *before* it starts finishes with no result at all —
    /// `AsyncOperation.start()` short-circuits to `complete()` without ever entering `main()`.
    ///
    /// That is safe, and the assertion below is the reason why: a nil result is not a success, so
    /// the seeding block cancels the reconcile exactly as it does for an outright failure. It
    /// must still *finish*, or the queue wedges and the channel's sync slot is never released.
    func testCancelledFetchOperation_finishesWithoutReportingSuccess() {
        let provider = MockPinnedMessageProvider(channelId: channelId)
        let operation = FetchAllPinnedMessagesOperation(
            query: provider.createDefaultQuery(),
            provider: provider
        )
        operation.cancel()

        run([operation])

        XCTAssertTrue(operation.isFinished, "a cancelled operation must still finish")
        if case .success = operation.result {
            XCTFail("a cancelled fetch must never report success")
        }
    }

    /// And the graph built from it prunes nothing.
    func testSyncGraph_withACancelledFetch_leavesEveryPinInPlace() {
        pin(seedMessage(id: 850, channelId: channelId))?.serverPinId = 80
        PinnedMessageDTO.fetchAll(context: ctx).forEach { $0.sync = .synced }
        try? ctx.save()

        let operations = Operations.syncChannelPinOperations(channelId: channelId)
        operations.first?.cancel()
        run(operations)

        XCTAssertEqual(
            PinnedMessageDTO.count(channelId: channelId, context: ctx), 1,
            "a cancelled sweep must not be read as \"the server has no pins\""
        )
    }

    func testSyncGraph_isFetchThenSeedThenReconcile() {
        let operations = Operations.syncChannelPinOperations(channelId: channelId)

        XCTAssertEqual(operations.count, 3)
        XCTAssertTrue(operations[0] is FetchAllPinnedMessagesOperation)
        XCTAssertTrue(operations[2] is ReconcilePinnedMessagesOperation)
        XCTAssertTrue(operations[1].dependencies.contains(operations[0]),
                      "the keep set can only be seeded once every page has landed")
        XCTAssertTrue(operations[2].dependencies.contains(operations[1]),
                      "and the reconcile can only run once it is seeded")
    }

    /// End to end for the safety rule: with no connection the fetch fails, the seeding block
    /// cancels the reconcile, and every local pin survives.
    func testSyncGraph_withAFailedFetch_leavesEveryPinInPlace() {
        pin(seedMessage(id: 840, channelId: channelId))?.serverPinId = 70
        pin(seedMessage(id: 841, channelId: channelId))?.serverPinId = 71
        PinnedMessageDTO.fetchAll(context: ctx).forEach { $0.sync = .synced }
        try? ctx.save()

        let operations = Operations.syncChannelPinOperations(channelId: channelId)
        run(operations)

        ctx.refreshAllObjects()
        XCTAssertEqual(
            PinnedMessageDTO.count(channelId: channelId, context: ctx), 2,
            "a failed sweep must not be read as \"the server has no pins\""
        )
    }

    // MARK: - SyncService

    func testSyncChannelPins_refusesChannelIdZero() {
        let done = expectation(description: "refused")
        SyncService.syncChannelPins(channelId: 0) { started in
            XCTAssertFalse(started)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
    }

    func testSyncChannelPins_runsToCompletionAndPostsItsNotification() {
        let posted = expectation(description: "notified")
        let observer = NotificationCenter.default.addObserver(
            forName: .didFinishChannelPinsSync,
            object: nil,
            queue: nil
        ) { note in
            XCTAssertEqual(note.userInfo?["channelId"] as? ChannelId, self.channelId)
            posted.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let done = expectation(description: "finished")
        SyncService.syncChannelPins(channelId: channelId) { _ in done.fulfill() }
        wait(for: [done, posted], timeout: 20)
    }

    /// The conversation and the pinned list both kick a sweep on open; the second must collapse
    /// rather than run a duplicate.
    func testSyncChannelPins_isGuardedPerChannel() {
        let first = expectation(description: "first finished")
        var secondStarted: Bool?

        SyncService.syncChannelPins(channelId: channelId) { _ in first.fulfill() }
        SyncService.syncChannelPins(channelId: channelId) { started in secondStarted = started }

        XCTAssertEqual(secondStarted, false, "a second sweep for the same channel is a no-op")
        wait(for: [first], timeout: 20)
    }

    /// ...but a different channel must not be blocked, which is why this is a per-channel guard
    /// and not `syncChannels`' single global slot.
    func testSyncChannelPins_doesNotBlockAnotherChannel() {
        seedChannel(id: 78)
        let a = expectation(description: "channel 77 finished")
        let b = expectation(description: "channel 78 finished")

        SyncService.syncChannelPins(channelId: channelId) { _ in a.fulfill() }
        SyncService.syncChannelPins(channelId: 78) { started in
            XCTAssertTrue(started, "a sweep for another channel must be allowed to start")
            b.fulfill()
        }
        wait(for: [a, b], timeout: 20)
    }

    func testCancelPinSync_freesTheSlotImmediately() {
        SyncService.syncChannelPins(channelId: channelId)
        SyncService.cancelPinSync(channelId: channelId)

        let done = expectation(description: "restarted")
        SyncService.syncChannelPins(channelId: channelId) { started in
            XCTAssertTrue(started, "cancelling must release the channel's slot at once")
            done.fulfill()
        }
        wait(for: [done], timeout: 20)
    }

    func testCancelAllPinSyncs_freesEveryChannelsSlot() {
        seedChannel(id: 79)
        SyncService.syncChannelPins(channelId: channelId)
        SyncService.syncChannelPins(channelId: 79)
        SyncService.cancelAllPinSyncs()

        let a = expectation(description: "77 restarted")
        let b = expectation(description: "79 restarted")
        SyncService.syncChannelPins(channelId: channelId) { started in
            XCTAssertTrue(started)
            a.fulfill()
        }
        SyncService.syncChannelPins(channelId: 79) { started in
            XCTAssertTrue(started)
            b.fulfill()
        }
        wait(for: [a, b], timeout: 20)
    }

    /// `cancelSync` runs before the database is wiped on account switch, so it has to take the
    /// pin sweeps down with it — otherwise a page already in flight writes the outgoing
    /// account's pins into the incoming account's store.
    func testCancelSync_alsoAbandonsPinSweeps() {
        SyncService.syncChannelPins(channelId: channelId)
        SyncService.cancelSync()

        let done = expectation(description: "restarted")
        SyncService.syncChannelPins(channelId: channelId) { started in
            XCTAssertTrue(started)
            done.fulfill()
        }
        wait(for: [done], timeout: 20)
    }
}
