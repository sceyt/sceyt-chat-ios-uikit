//
//  HardDeleteReconciliationTests.swift
//  SceytChatUIKitTests
//
//  A message hard-deleted on the server stays in the DB forever when its delete event is
//  missed: a server page used to be upserted only. A page now deletes the stored rows it proves
//  are gone (`deleteMessagesMissing(from:)`), and `ChannelMessageProvider.pageReconciliation`
//  decides what each kind of page proves.
//
//  Ids are snowflake-sized like production; the scenario of the device logs (2026-11-25) is
//  `testInSpanRowsMissingFromPageAreDeleted`.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

final class HardDeleteReconciliationTests: XCTestCase {

    private var database: MockDatabase!
    private var originalDatabase: Database!

    private let channelId: ChannelId = 740_045_987_712_462_848
    private let otherChannelId: ChannelId = 740_045_987_712_000_000
    private let base: MessageId = 884_971_000_000_000_000

    override func setUp() {
        super.setUp()
        database = MockDatabase()
        originalDatabase = DataProvider.database
        DataProvider.database = database
        let ctx = database.backgroundPerformContext
        ctx.performAndWait {
            _ = ChannelDTO.fetchOrCreate(id: channelId, context: ctx)
            _ = ChannelDTO.fetchOrCreate(id: otherChannelId, context: ctx)
            try? ctx.save()
        }
    }

    override func tearDown() {
        DataProvider.database = originalDatabase
        database = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    private func id(_ n: Int) -> MessageId { base + MessageId(n) * 1_000 }

    private func serverMessage(_ id: MessageId) -> Message {
        let message = Message.Builder().id(id).tid(Int(id)).type("text").body("m\(id)").build()
        message.setValue(true, forKey: "incoming")
        message.setValue(Date(timeIntervalSince1970: 1_795_000_000 + Double(id - base) / 1_000), forKey: "createdAt")
        message.setValue(MessageDeliveryStatus.sent.rawValue, forKey: "deliveryStatus")
        return message
    }

    /// Stores server rows `ns` in `channel`, then lets `customize` adjust the stored DTOs.
    private func seed(_ ns: [Int], channel: ChannelId? = nil, customize: ((MessageId, MessageDTO) -> Void)? = nil) {
        let ctx = database.backgroundPerformContext
        let channel = channel ?? channelId
        ctx.performAndWait {
            for n in ns {
                let dto = ctx.createOrUpdate(message: serverMessage(id(n)), channelId: channel)
                customize?(id(n), dto)
            }
            try! ctx.save()
        }
    }

    private func seedPending(tid: Int) {
        let ctx = database.backgroundPerformContext
        ctx.performAndWait {
            let message = Message.Builder().tid(tid).type("text").body("pending").build()
            message.setValue(false, forKey: "incoming")
            message.setValue(Date(timeIntervalSince1970: 1_795_000_000), forKey: "createdAt")
            ctx.createOrUpdate(message: message, channelId: channelId)
            try! ctx.save()
        }
    }

    private func storedIds(channel: ChannelId? = nil) -> [MessageId] {
        let ctx = database.backgroundPerformContext
        var ids = [MessageId]()
        ctx.performAndWait {
            let request = MessageDTO.fetchRequest()
            request.predicate = NSPredicate(format: "channelId == %lld AND id > 0", Int64(channel ?? channelId))
            ids = ((try? ctx.fetch(request)) ?? []).map { MessageId($0.id) }.sorted()
        }
        return ids
    }

    private func pendingCount() -> Int {
        let ctx = database.backgroundPerformContext
        var count = 0
        ctx.performAndWait {
            let request = MessageDTO.fetchRequest()
            request.predicate = NSPredicate(format: "channelId == %lld AND id == 0", Int64(channelId))
            count = (try? ctx.count(for: request)) ?? 0
        }
        return count
    }

    @discardableResult
    private func reconcile(
        page ns: [Int],
        newestStored: Int,
        reachedOldest: Bool = false,
        reachedNewest: Bool = false
    ) -> [MessageId] {
        let ctx = database.backgroundPerformContext
        var deleted = [MessageId]()
        ctx.performAndWait {
            deleted = ctx.deleteMessagesMissing(from: MessagePageReconciliation(
                channelId: channelId,
                serverIds: Set(ns.map(id)),
                newestStoredIdBeforeRequest: id(newestStored),
                reachedOldest: reachedOldest,
                reachedNewest: reachedNewest
            ))
            try! ctx.save()
        }
        return deleted.sorted()
    }

    // MARK: - deleteMessagesMissing(from:)

    func testInSpanRowsMissingFromPageAreDeleted() {
        seed(Array(1...10))
        let deleted = reconcile(page: [1, 2, 3, 5, 6, 7, 9, 10], newestStored: 10)
        XCTAssertEqual(deleted, [id(4), id(8)])
        XCTAssertEqual(storedIds(), [1, 2, 3, 5, 6, 7, 9, 10].map(id))
    }

    func testRowsOutsidePageAreKeptWhenEdgesAreNotReached() {
        seed(Array(1...10))
        let deleted = reconcile(page: [4, 5, 6], newestStored: 10)
        XCTAssertEqual(deleted, [])
        XCTAssertEqual(storedIds(), Array(1...10).map(id))
    }

    func testReachedNewestDeletesRowsAboveThePage() {
        // The newest message was hard-deleted: its id is above the latest page's max.
        seed(Array(1...10))
        let deleted = reconcile(page: [5, 6, 7, 8], newestStored: 10, reachedNewest: true)
        XCTAssertEqual(deleted, [id(9), id(10)])
    }

    func testRowsStoredAfterTheRequestAreKept() {
        // 9 and 10 arrived by event while the request was in flight.
        seed(Array(1...10))
        let deleted = reconcile(page: [5, 6, 7, 8], newestStored: 8, reachedNewest: true)
        XCTAssertEqual(deleted, [])
        XCTAssertEqual(storedIds(), Array(1...10).map(id))
    }

    func testRowStoredAfterTheRequestInsideTheSpanIsKept() {
        seed([1, 2, 3, 5, 6])
        // 4 lands (out of id order) after the request was sent.
        let deleted = reconcile(page: [1, 2, 3, 5, 6], newestStored: 3)
        XCTAssertEqual(deleted, [])
    }

    func testReachedOldestDeletesRowsBelowThePage() {
        seed(Array(1...10))
        let deleted = reconcile(page: [4, 5, 6], newestStored: 10, reachedOldest: true)
        XCTAssertEqual(deleted, [id(1), id(2), id(3)])
        XCTAssertEqual(storedIds(), Array(4...10).map(id))
    }

    func testPendingRowsAreKept() {
        seed(Array(1...5))
        seedPending(tid: 777)
        reconcile(page: [1, 5], newestStored: 5, reachedOldest: true, reachedNewest: true)
        XCTAssertEqual(pendingCount(), 1)
        XCTAssertEqual(storedIds(), [id(1), id(5)])
    }

    func testThreadRepliesAndUnlistedRowsAreKept() {
        seed(Array(1...5)) { id, dto in
            if id == self.id(2) { dto.repliedInThread = true }
            if id == self.id(3) { dto.unlisted = true }
        }
        let deleted = reconcile(page: [1, 5], newestStored: 5)
        XCTAssertEqual(deleted, [id(4)])
        XCTAssertEqual(storedIds(), [1, 2, 3, 5].map(id))
    }

    func testOtherChannelsAreUntouched() {
        seed(Array(1...5))
        seed([3, 4].map { $0 + 100 }, channel: otherChannelId)
        reconcile(page: [1, 5], newestStored: 200, reachedOldest: true, reachedNewest: true)
        XCTAssertEqual(storedIds(channel: otherChannelId), [id(103), id(104)])
    }

    func testEmptyPageDeletesNothing() {
        seed(Array(1...5))
        let deleted = reconcile(page: [], newestStored: 5, reachedOldest: true, reachedNewest: true)
        XCTAssertEqual(deleted, [])
        XCTAssertEqual(storedIds().count, 5)
    }

    /// Also pins `MessageDTO.lastMessage(predicate:)`, which used to return an arbitrary row.
    func testDeletedLastMessageMovesChannelLastMessage() {
        seed(Array(1...5))
        let ctx = database.backgroundPerformContext
        ctx.performAndWait {
            let channel = ChannelDTO.fetchOrCreate(id: channelId, context: ctx).0
            channel.lastMessage = MessageDTO.fetch(id: id(5), context: ctx)
            do { try ctx.save() } catch { XCTFail("save: \(error)") }
        }
        reconcile(page: [1, 2, 3, 4], newestStored: 5, reachedNewest: true)
        ctx.performAndWait {
            let channel = ChannelDTO.fetch(id: channelId, context: ctx)
            XCTAssertNotNil(channel)
            XCTAssertEqual(channel?.lastMessage.map { MessageId($0.id) }, id(4))
        }
    }

    // MARK: - ChannelMessageProvider.pageReconciliation

    private func page(_ count: Int) -> [Message] {
        (1...count).map { serverMessage(id($0)) }
    }

    func testLatestPageReachesNewest() {
        let provider = ChannelMessageProvider(channelId: channelId)
        let r = provider.pageReconciliation(source: .prevBefore, anchor: ChannelMessageProvider.latestPageAnchor, limit: 50, messages: page(50), hasMore: false, newestStoredId: id(60))
        XCTAssertEqual(r?.reachedNewest, true)
        XCTAssertEqual(r?.reachedOldest, false)
    }

    func testOlderPageBeforeARealIdDoesNotReachNewest() {
        let provider = ChannelMessageProvider(channelId: channelId)
        let r = provider.pageReconciliation(source: .prevBefore, anchor: id(60), limit: 50, messages: page(50), hasMore: false, newestStoredId: id(60))
        XCTAssertEqual(r?.reachedNewest, false)
        XCTAssertEqual(r?.reachedOldest, false)
    }

    func testShortPrevPageReachesOldest() {
        let provider = ChannelMessageProvider(channelId: channelId)
        let r = provider.pageReconciliation(source: .prev, anchor: nil, limit: 50, messages: page(10), hasMore: false, newestStoredId: id(60))
        XCTAssertEqual(r?.reachedOldest, true)
        XCTAssertEqual(r?.reachedNewest, false)
    }

    func testShortNextPageReachesNewest() {
        let provider = ChannelMessageProvider(channelId: channelId)
        let r = provider.pageReconciliation(source: .nextAfter, anchor: id(1), limit: 50, messages: page(10), hasMore: false, newestStoredId: id(60))
        XCTAssertEqual(r?.reachedNewest, true)
        XCTAssertEqual(r?.reachedOldest, false)
    }

    func testShortNearPageProvesNoEdge() {
        let provider = ChannelMessageProvider(channelId: channelId)
        let r = provider.pageReconciliation(source: .near, anchor: id(5), limit: 50, messages: page(10), hasMore: false, newestStoredId: id(60))
        XCTAssertEqual(r?.reachedNewest, false)
        XCTAssertEqual(r?.reachedOldest, false)
    }

    func testNothingToReconcileForEmptyPageThreadOrEmptyChannel() {
        let provider = ChannelMessageProvider(channelId: channelId)
        XCTAssertNil(provider.pageReconciliation(source: .prev, anchor: nil, limit: 50, messages: [], hasMore: false, newestStoredId: id(60)))
        XCTAssertNil(provider.pageReconciliation(source: .prev, anchor: nil, limit: 50, messages: page(5), hasMore: false, newestStoredId: nil))
        let thread = ChannelMessageProvider(channelId: channelId, threadMessageId: id(1))
        XCTAssertNil(thread.pageReconciliation(source: .prev, anchor: nil, limit: 50, messages: page(5), hasMore: false, newestStoredId: id(60)))
        XCTAssertNil(thread.newestStoredMessageId())
    }

    func testShortLatestPageReachesBothEnds() {
        let provider = ChannelMessageProvider(channelId: channelId)
        let r = provider.pageReconciliation(source: .prevBefore, anchor: ChannelMessageProvider.latestPageAnchor, limit: 50, messages: page(10), hasMore: false, newestStoredId: id(60))
        XCTAssertEqual(r?.reachedNewest, true)
        XCTAssertEqual(r?.reachedOldest, true)
    }

    func testFullNextPageDoesNotReachNewest() {
        let provider = ChannelMessageProvider(channelId: channelId)
        for source in [ChannelMessageProvider.PageSource.next, .nextAfter] {
            let r = provider.pageReconciliation(source: source, anchor: id(1), limit: 50, messages: page(50), hasMore: false, newestStoredId: id(60))
            XCTAssertEqual(r?.reachedNewest, false, "\(source)")
            XCTAssertEqual(r?.reachedOldest, false, "\(source)")
        }
    }

    func testFullPrevPageWithoutAnchorProvesNoEdge() {
        let provider = ChannelMessageProvider(channelId: channelId)
        let r = provider.pageReconciliation(source: .prev, anchor: nil, limit: 50, messages: page(50), hasMore: false, newestStoredId: id(60))
        XCTAssertEqual(r?.reachedNewest, false)
        XCTAssertEqual(r?.reachedOldest, false)
    }

    /// A page short of `limit` while the query still reports more: the server capped the page
    /// below our limit. Treating it as the end would wipe all history past it.
    func testShortPageWithMoreOnServerProvesNoEdge() {
        let provider = ChannelMessageProvider(channelId: channelId)
        let prev = provider.pageReconciliation(source: .prev, anchor: nil, limit: 50, messages: page(30), hasMore: true, newestStoredId: id(60))
        XCTAssertEqual(prev?.reachedOldest, false)
        let next = provider.pageReconciliation(source: .nextAfter, anchor: id(1), limit: 50, messages: page(30), hasMore: true, newestStoredId: id(60))
        XCTAssertEqual(next?.reachedNewest, false)
    }

    /// The latest page proves the newest edge from its anchor alone, whatever `hasMore` says.
    func testLatestPageReachesNewestEvenWithMoreOlderPages() {
        let provider = ChannelMessageProvider(channelId: channelId)
        let r = provider.pageReconciliation(source: .prevBefore, anchor: ChannelMessageProvider.latestPageAnchor, limit: 50, messages: page(50), hasMore: true, newestStoredId: id(60))
        XCTAssertEqual(r?.reachedNewest, true)
        XCTAssertEqual(r?.reachedOldest, false)
    }

    // MARK: - pageReconciler (what each load method uses)

    /// The snapshot is read when the reconciler is made (before the request), not when the page
    /// arrives, so a row stored while the request is in flight is never reconciled away.
    func testReconcilerSnapshotsNewestIdBeforeTheRequest() {
        seed(Array(1...5))
        let provider = ChannelMessageProvider(channelId: channelId)
        let reconcile = provider.pageReconciler(source: .prevBefore, anchor: ChannelMessageProvider.latestPageAnchor, limit: 50)
        seed([6]) // arrives by event while the request is in flight
        let r = reconcile([1, 2, 3, 4].map { serverMessage(id($0)) }, true)
        XCTAssertEqual(r?.newestStoredIdBeforeRequest, id(5))
        XCTAssertEqual(r?.reachedNewest, true)
        XCTAssertEqual(r?.serverIds, Set([1, 2, 3, 4].map(id)))

        let ctx = database.backgroundPerformContext
        ctx.performAndWait {
            ctx.deleteMessagesMissing(from: r!)
            try! ctx.save()
        }
        XCTAssertEqual(storedIds(), [1, 2, 3, 4, 6].map(id))
    }

    func testThreadReconcilerProducesNothing() {
        seed(Array(1...5))
        let thread = ChannelMessageProvider(channelId: channelId, threadMessageId: id(1))
        let reconcile = thread.pageReconciler(source: .prev, anchor: nil, limit: 50)
        XCTAssertNil(reconcile([serverMessage(id(2))], false))
    }

    // MARK: - Other row kinds

    /// A soft delete stays in the server page (state `deleted`), so its row is never reconciled
    /// away; the upsert turns it into the tombstone. (Storing a deleted-state message through
    /// `store` runs a batch delete that merges into the real shared database, which the mock
    /// cannot host, so the reconciliation step is tested on its own.)
    func testSoftDeletedRowInThePageIsKept() {
        seed(Array(1...3)) { id, dto in
            if id == self.id(2) { dto.state = Int16(ChatMessage.State.deleted.intValue) }
        }
        let deleted = reconcile(page: [1, 2, 3], newestStored: 3, reachedOldest: true, reachedNewest: true)
        XCTAssertEqual(deleted, [])
        XCTAssertEqual(storedIds(), [1, 2, 3].map(id))
    }

    func testDeletedRowDropsItsPin() {
        seed(Array(1...5))
        let ctx = database.backgroundPerformContext
        ctx.performAndWait {
            XCTAssertNotNil(ctx.pinMessage(id: id(3), tid: Int64(id(3)), channelId: channelId, scope: .forAll,
                                           pinnedAt: Date(), pinnedUntil: nil, pinnedBy: "me"))
            try! ctx.save()
        }
        reconcile(page: [1, 2, 4, 5], newestStored: 5)
        ctx.performAndWait {
            let request = PinnedMessageDTO.fetchRequest()
            request.predicate = NSPredicate(format: "messageId == %lld", Int64(id(3)))
            XCTAssertEqual((try? ctx.count(for: request)) ?? -1, 0)
        }
    }

    // MARK: - newestStoredMessageId

    func testNewestStoredIdIgnoresPendingAndOtherChannels() {
        seed([1, 2, 3])
        seed([50], channel: otherChannelId)
        seedPending(tid: 999)
        XCTAssertEqual(ChannelMessageProvider(channelId: channelId).newestStoredMessageId(), id(3))
    }

    func testNewestStoredIdIsNilForEmptyChannel() {
        seed([50], channel: otherChannelId)
        XCTAssertNil(ChannelMessageProvider(channelId: channelId).newestStoredMessageId())
    }

    // MARK: - MessageDTO.lastMessage

    func testLastMessageBreaksCreatedAtTieById() {
        let ctx = database.backgroundPerformContext
        ctx.performAndWait {
            let same = Date(timeIntervalSince1970: 1_795_000_100)
            for n in [7, 9, 8] {
                let message = serverMessage(id(n))
                message.setValue(same, forKey: "createdAt")
                ctx.createOrUpdate(message: message, channelId: channelId)
            }
            try! ctx.save()
            let last = MessageDTO.lastMessage(predicate: NSPredicate(format: "channelId == %lld", Int64(channelId)), context: ctx)
            XCTAssertEqual(last.map { MessageId($0.id) }, id(9))
        }
    }

    func testStoreWithoutReconciliationDeletesNothing() {
        seed(Array(1...10))
        let provider = ChannelMessageProvider(channelId: channelId)
        let done = expectation(description: "stored")
        provider.store(messages: [1, 5].map { serverMessage(id($0)) }) { error in
            XCTAssertNil(error)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(storedIds(), Array(1...10).map(id))
    }

    // MARK: - store(messages:reconciliation:) end to end

    func testStoreUpsertsPageAndDeletesMissingRowsInOneWrite() {
        seed(Array(1...10))
        let provider = ChannelMessageProvider(channelId: channelId)
        let pageMessages = [1, 2, 3, 5, 6, 7, 8].map { serverMessage(id($0)) }
        let reconciliation = provider.pageReconciliation(
            source: .prevBefore, anchor: ChannelMessageProvider.latestPageAnchor, limit: 50,
            messages: pageMessages, hasMore: false, newestStoredId: id(10)
        )
        let done = expectation(description: "stored")
        provider.store(messages: pageMessages, reconciliation: reconciliation) { error in
            XCTAssertNil(error)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        // 4 missing in span; 9, 10 above the latest page.
        XCTAssertEqual(storedIds(), [1, 2, 3, 5, 6, 7, 8].map(id))
    }
}
