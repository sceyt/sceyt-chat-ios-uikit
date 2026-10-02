//
//  ChannelSyncMissingChannelsTests.swift
//  SceytChatUIKitTests
//
//  Covers the confirm-before-delete step of the channel-list sync: the policy that reads the
//  server's answer about one missing channel, and `DeleteChannelsOperation`, which deletes only
//  what that answer confirmed.
//
//  Two limits shape what is reachable here:
//
//  1. `SceytChat.Channel` declares `init` unavailable, so the server half is reached through a
//     stub `MissingChannelsVerifier` and the policy is tested on its value-typed inputs.
//  2. `delete(channelIds:context:)` runs an `NSBatchDeleteRequest` that merges into
//     `SceytChatUIKit.shared.database`, whose coordinator differs from `MockDatabase`'s — so the
//     tests override it to record what reaches it.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

/// A `SceytError` with a chosen `type`, so the policy's SDK error classification can be tested
/// without a server.
private final class MockSceytError: SceytError {

    private let mockType: String

    init(type: String) {
        self.mockType = type
        super.init(domain: "SceytChat", code: 0, userInfo: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var type: String { mockType }
}

/// Answers with a fixed list of gone ids, either at once or when the test releases it.
private final class StubVerifier: MissingChannelsVerifier {

    var gone: [ChannelId] = []
    var holdsAnswer = false
    var onVerify: (() -> Void)?

    private(set) var received = [[ChannelId]]()
    private(set) var pendingAnswer: (() -> Void)?

    func verify(channelIds: [ChannelId], completion: @escaping ([ChannelId]) -> Void) {
        received.append(channelIds)
        let gone = self.gone
        guard holdsAnswer else {
            completion(gone)
            return
        }
        pendingAnswer = { completion(gone) }
        onVerify?()
    }
}

/// Records the ids that reach the delete step and removes them row by row.
private final class RecordingDeleteChannelsOperation: DeleteChannelsOperation {

    private(set) var deletedIds: [ChannelId]?

    override func delete(channelIds ids: [ChannelId], context: NSManagedObjectContext) throws {
        deletedIds = ids
        ChannelDTO.fetch(ids: ids, context: context).forEach { context.delete($0) }
    }
}

final class ChannelSyncMissingChannelsTests: XCTestCase {

    private var mockDB: MockDatabase!
    private var ctx: NSManagedObjectContext { mockDB.container.viewContext }
    private var verifier: StubVerifier!
    private let queue = OperationQueue()

    override func setUp() {
        super.setUp()
        mockDB = MockDatabase()
        verifier = StubVerifier()
    }

    override func tearDown() {
        ProtectedChannels.channelIds.forEach { ProtectedChannels.release(channelId: $0) }
        verifier = nil
        mockDB = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func seedChannels(_ ids: [ChannelId], unsynched: Bool = false) {
        for id in ids {
            let (channel, _) = ChannelDTO.fetchOrCreate(id: id, context: ctx)
            channel.createdAt = Date().bridgeDate
            channel.type = "group"
            channel.unsynched = unsynched
        }
        try? ctx.save()
    }

    private func makeOperation(keep: [ChannelId]) -> RecordingDeleteChannelsOperation {
        RecordingDeleteChannelsOperation(database: mockDB, channelIds: keep, verifier: verifier)
    }

    private func run(_ operation: DeleteChannelsOperation) {
        let done = expectation(description: "operation finished")
        operation.completionBlock = { done.fulfill() }
        queue.addOperation(operation)
        wait(for: [done], timeout: 5)
    }

    /// Starts the operation and returns once the verifier is holding its answer.
    private func startHeld(_ operation: DeleteChannelsOperation) -> XCTestExpectation {
        verifier.holdsAnswer = true
        let asked = expectation(description: "verifier asked")
        verifier.onVerify = { asked.fulfill() }
        let done = expectation(description: "operation finished")
        operation.completionBlock = { done.fulfill() }
        queue.addOperation(operation)
        wait(for: [asked], timeout: 5)
        return done
    }

    /// Read through a fresh context so the answer comes from the store, not a stale row cache.
    private func storedChannelIds() -> Set<ChannelId> {
        let context = mockDB.container.newBackgroundContext()
        var ids = Set<ChannelId>()
        context.performAndWait {
            ids = Set(ChannelDTO.fetch(request: ChannelDTO.fetchRequest(), context: context).map { ChannelId($0.id) })
        }
        return ids
    }

    // MARK: - Policy

    func testPolicy_activeChannel_exists() {
        XCTAssertEqual(MissingChannelPolicy.status(hidden: false, archived: false, userRole: "owner"), .exists)
    }

    func testPolicy_channelTheListWouldNotShow_isGone() {
        XCTAssertEqual(MissingChannelPolicy.status(hidden: true, archived: false, userRole: "owner"), .gone)
        XCTAssertEqual(MissingChannelPolicy.status(hidden: false, archived: true, userRole: "owner"), .gone)
        XCTAssertEqual(MissingChannelPolicy.status(hidden: false, archived: false, userRole: nil), .gone)
        XCTAssertEqual(MissingChannelPolicy.status(hidden: false, archived: false, userRole: ""), .gone)
    }

    func testPolicy_permanentErrors_areGone() {
        XCTAssertEqual(MissingChannelPolicy.status(error: MockSceytError(type: "NotFound")), .gone)
        XCTAssertEqual(MissingChannelPolicy.status(error: MockSceytError(type: "NotAllowed")), .gone)
        XCTAssertEqual(MissingChannelPolicy.status(error: MockSceytError(type: "BadParam")), .gone)
        XCTAssertEqual(
            MissingChannelPolicy.status(error: NSError(domain: "SceytChat", code: SceytChatError.channelNotExists.rawValue)),
            .gone
        )
        XCTAssertEqual(
            MissingChannelPolicy.status(error: NSError(domain: "SceytChat", code: SceytChatError.notAllowed.rawValue)),
            .gone
        )
    }

    func testPolicy_inconclusiveErrors_areUnknown() {
        XCTAssertEqual(MissingChannelPolicy.status(error: MockSceytError(type: "TooManyRequests")), .unknown)
        XCTAssertEqual(MissingChannelPolicy.status(error: MockSceytError(type: "InternalError")), .unknown)
        XCTAssertEqual(MissingChannelPolicy.status(error: MockSceytError(type: "Authentication")), .unknown)
        XCTAssertEqual(
            MissingChannelPolicy.status(error: NSError(domain: "SceytChat", code: SceytChatError.networkConnection.rawValue)),
            .unknown
        )
        XCTAssertEqual(
            MissingChannelPolicy.status(error: NSError(domain: "SceytChat", code: SceytChatError.requestTimeout.rawValue)),
            .unknown
        )
        XCTAssertEqual(MissingChannelPolicy.status(error: NSError(domain: "Other", code: 42)), .unknown)
    }

    // MARK: - DeleteChannelsOperation

    /// The bug: a channel the offset shift skipped, but the server still has, used to be deleted.
    func testChannelSkippedBySync_butNotConfirmedGone_isKept() {
        seedChannels([1, 2, 3])
        let operation = makeOperation(keep: [1, 2])

        run(operation)

        XCTAssertEqual(verifier.received, [[3]])
        XCTAssertNil(operation.deletedIds)
        XCTAssertEqual(storedChannelIds(), [1, 2, 3])
    }

    func testOnlyConfirmedChannelsAreDeleted() {
        seedChannels([1, 2, 3, 4, 5])
        verifier.gone = [3, 5]
        let operation = makeOperation(keep: [1])

        run(operation)

        XCTAssertEqual(verifier.received.map { Set($0) }, [[2, 3, 4, 5]])
        XCTAssertEqual(operation.deletedIds.map { Set($0) }, [3, 5])
        XCTAssertEqual(storedChannelIds(), [1, 2, 4])
    }

    func testVerifierIsAskedOnlyAboutMissingSyncedChannels() {
        seedChannels([1, 3, 4])
        seedChannels([2], unsynched: true)
        ProtectedChannels.protect(channelId: 3)
        let operation = makeOperation(keep: [1])

        run(operation)

        XCTAssertEqual(verifier.received, [[4]])
    }

    func testNoMissingChannels_skipsVerifier() {
        seedChannels([1, 2])
        let operation = makeOperation(keep: [1, 2])

        run(operation)

        XCTAssertTrue(verifier.received.isEmpty)
        XCTAssertNil(operation.deletedIds)
    }

    func testChannelArrivingWhileVerifying_isNotDeleted() {
        seedChannels([1, 3])
        verifier.gone = [3]
        let operation = makeOperation(keep: [1])
        let done = startHeld(operation)

        seedChannels([9])
        verifier.pendingAnswer?()
        wait(for: [done], timeout: 5)

        XCTAssertEqual(operation.deletedIds, [3])
        XCTAssertEqual(storedChannelIds(), [1, 9])
    }

    func testChannelProtectedWhileVerifying_isNotDeleted() {
        seedChannels([1, 3])
        verifier.gone = [3]
        let operation = makeOperation(keep: [1])
        let done = startHeld(operation)

        ProtectedChannels.protect(channelId: 3)
        verifier.pendingAnswer?()
        wait(for: [done], timeout: 5)

        XCTAssertNil(operation.deletedIds)
        XCTAssertEqual(storedChannelIds(), [1, 3])
    }

    func testCancelledWhileVerifying_deletesNothing() {
        seedChannels([1, 3])
        verifier.gone = [3]
        let operation = makeOperation(keep: [1])
        let done = startHeld(operation)

        operation.cancel()
        verifier.pendingAnswer?()
        wait(for: [done], timeout: 5)

        XCTAssertNil(operation.deletedIds)
        XCTAssertEqual(storedChannelIds(), [1, 3])
    }

    /// Set when the sync returned no channels at all, where an offset shift is impossible.
    func testUnconfirmedMode_deletesEveryMissingChannelWithoutAsking() {
        seedChannels([1, 2, 3])
        let operation = makeOperation(keep: [1])
        operation.confirmsMissingChannels = false

        run(operation)

        XCTAssertTrue(verifier.received.isEmpty)
        XCTAssertEqual(operation.deletedIds.map { Set($0) }, [2, 3])
        XCTAssertEqual(storedChannelIds(), [1])
    }
}
