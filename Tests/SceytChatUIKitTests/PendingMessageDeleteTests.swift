//
//  PendingMessageDeleteTests.swift
//  SceytChatUIKitTests
//
//  Covers the durable "delete a message that has no server id yet" intent:
//  deleting such a message removes the local row and stores a PendingMessageDeleteDTO in the
//  same transaction, so the request survives a failure, a restart and a late send ack.
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

final class PendingMessageDeleteTests: XCTestCase {

    private var mockDB: MockDatabase!
    private var ctx: NSManagedObjectContext { mockDB.container.viewContext }

    override func setUp() {
        super.setUp()
        mockDB = MockDatabase()
    }

    override func tearDown() {
        mockDB = nil
        super.tearDown()
    }

    // MARK: - Helpers

    @discardableResult
    private func seedChannel(id: ChannelId) -> ChannelDTO {
        let (channel, _) = ChannelDTO.fetchOrCreate(id: id, context: ctx)
        try? ctx.save()
        return channel
    }

    /// Seeds an outgoing message that has not been acked yet: `id == 0`, identified by tid.
    @discardableResult
    private func seedPendingMessage(tid: Int64, channelId: ChannelId) -> MessageDTO {
        let message = MessageDTO.fetchOrCreate(id: 0, tid: tid, channelId: Int64(channelId), context: ctx)
        message.channelId = Int64(channelId)
        message.tid = tid
        message.incoming = false
        message.deliveryStatus = Int16(ChatMessage.DeliveryStatus.pending.intValue)
        message.createdAt = Date().bridgeDate
        message.user = UserDTO.fetchOrCreate(id: "me", context: ctx)
        try? ctx.save()
        return message
    }

    private func records(channelId: ChannelId) -> [PendingMessageDeleteDTO] {
        PendingMessageDeleteDTO.fetchAll(channelId: channelId, context: ctx)
    }

    private func nsError(code: Int) -> Error {
        NSError(domain: "SceytChat", code: code, userInfo: nil)
    }

    // MARK: - Delete type encoding

    func testStoredType_roundTripsEveryDeleteMessageType() {
        let dto = PendingMessageDeleteDTO.fetchOrCreate(messageTid: 1, channelId: 1, context: ctx)

        for type in [DeleteMessageType.deleteForMe, .deleteForEveryone, .deleteHard] {
            dto.type = type
            XCTAssertEqual(dto.type, type, "\(type) must survive a round trip through Core Data")
        }
    }

    /// `DeleteMessageType.deleteHard.rawValue` is 0, which is also Core Data's default for a
    /// missing value — decoding it as a hard delete would be the most destructive possible bug.
    func testStoredType_defaultZeroDecodesAsDeleteForMe() {
        let dto = PendingMessageDeleteDTO.fetchOrCreate(messageTid: 1, channelId: 1, context: ctx)
        dto.deleteType = 0

        XCTAssertEqual(dto.type, .deleteForMe)
        XCTAssertNotEqual(dto.type, .deleteHard)
    }

    // MARK: - fetchOrCreate

    func testFetchOrCreate_returnsTheSameRecordForTheSameTidAndChannel() {
        let first = PendingMessageDeleteDTO.fetchOrCreate(messageTid: 7, channelId: 1, context: ctx)
        let second = PendingMessageDeleteDTO.fetchOrCreate(messageTid: 7, channelId: 1, context: ctx)
        try? ctx.save()

        XCTAssertEqual(first.objectID, second.objectID)
        XCTAssertEqual(records(channelId: 1).count, 1)
    }

    func testFetchOrCreate_collapsesDuplicateRecords() {
        // Two write contexts can insert concurrently before the constraint is enforced.
        for _ in 0..<2 {
            let raw = PendingMessageDeleteDTO.insertNewObject(into: ctx)
            raw.messageTid = 7
            raw.channelId = 1
            raw.createdAt = Int64(Date().timeIntervalSince1970 * 1000)
        }
        try? ctx.save()
        XCTAssertEqual(records(channelId: 1).count, 2, "Precondition: two duplicates seeded")

        _ = PendingMessageDeleteDTO.fetchOrCreate(messageTid: 7, channelId: 1, context: ctx)
        try? ctx.save()

        XCTAssertEqual(records(channelId: 1).count, 1)
    }

    func testFetchOrCreate_keepsChannelsApart() {
        _ = PendingMessageDeleteDTO.fetchOrCreate(messageTid: 7, channelId: 1, context: ctx)
        _ = PendingMessageDeleteDTO.fetchOrCreate(messageTid: 7, channelId: 2, context: ctx)
        try? ctx.save()

        XCTAssertEqual(records(channelId: 1).count, 1)
        XCTAssertEqual(records(channelId: 2).count, 1)
    }

    // MARK: - Atomicity of "remove row + store intent"

    func testAddPendingMessageDelete_removesTheRowAndStoresTheIntentInOneTransaction() {
        seedChannel(id: 1)
        seedPendingMessage(tid: 100, channelId: 1)

        ctx.addPendingMessageDelete(messageTid: 100, channelId: 1, messageId: 0, type: .deleteForEveryone)
        ctx.deleteMessage(tid: 100, channelId: 1)
        try? ctx.save()

        XCTAssertNil(MessageDTO.fetch(tid: 100, channelId: 1, context: ctx), "The row must be gone at once")
        let stored = records(channelId: 1)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.messageTid, 100)
        XCTAssertEqual(stored.first?.type, .deleteForEveryone)
        XCTAssertEqual(stored.first?.retryCount, 0)
        XCTAssertEqual(stored.first?.messageId, 0, "A pending message has no server id yet")
        XCTAssertGreaterThan(stored.first?.createdAt ?? 0, 0)
    }

    func testAddPendingMessageDelete_keepsAKnownServerId() {
        ctx.addPendingMessageDelete(messageTid: 100, channelId: 1, messageId: 555, type: .deleteForMe)
        try? ctx.save()

        XCTAssertEqual(records(channelId: 1).first?.messageId, 555)
    }

    func testRemovePendingMessageDelete_removesOnlyTheMatchingRecord() {
        _ = PendingMessageDeleteDTO.fetchOrCreate(messageTid: 100, channelId: 1, context: ctx)
        _ = PendingMessageDeleteDTO.fetchOrCreate(messageTid: 101, channelId: 1, context: ctx)
        try? ctx.save()

        ctx.removePendingMessageDelete(messageTid: 100, channelId: 1)
        try? ctx.save()

        XCTAssertNil(ctx.pendingMessageDelete(messageTid: 100, channelId: 1))
        XCTAssertNotNil(ctx.pendingMessageDelete(messageTid: 101, channelId: 1))
    }

    // MARK: - Channel scoped tid deletes

    func testDeleteMessageByTid_isScopedToTheChannel() {
        seedChannel(id: 1)
        seedChannel(id: 2)
        seedPendingMessage(tid: 100, channelId: 1)
        seedPendingMessage(tid: 100, channelId: 2)

        ctx.deleteMessage(tid: 100, channelId: 1)
        try? ctx.save()

        XCTAssertNil(MessageDTO.fetch(tid: 100, channelId: 1, context: ctx))
        XCTAssertNotNil(MessageDTO.fetch(tid: 100, channelId: 2, context: ctx),
                        "A message with the same tid in another channel must survive")
    }

    func testDeleteMessageByTid_repicksChannelLastMessage() {
        let channel = seedChannel(id: 1)
        let older = seedPendingMessage(tid: 100, channelId: 1)
        let newer = seedPendingMessage(tid: 101, channelId: 1)
        channel.lastMessage = newer
        try? ctx.save()

        ctx.deleteMessage(tid: 101, channelId: 1)
        try? ctx.save()

        XCTAssertEqual(channel.lastMessage?.tid, older.tid)
    }

    // MARK: - Send ack must not resurrect a deleted message

    func testResolveSendAck_suppressesTheMessageWhenADeleteIsPending() {
        seedChannel(id: 1)
        ctx.addPendingMessageDelete(messageTid: 100, channelId: 1, messageId: 0, type: .deleteForMe)
        try? ctx.save()

        let sent = Message.Builder().id(555).tid(100).build()
        let resolution = ctx.resolveSendAck(sentMessage: sent, channelId: 1)
        try? ctx.save()

        switch resolution {
        case .suppressedByPendingDelete(let tid, let serverMessageId):
            XCTAssertEqual(tid, 100)
            XCTAssertEqual(serverMessageId, 555)
        case .stored:
            XCTFail("The ack must not store a message the user already deleted")
        }
        XCTAssertNil(MessageDTO.fetch(tid: 100, channelId: 1, context: ctx),
                     "The deleted row must not come back")
        XCTAssertNil(MessageDTO.fetch(id: 555, context: ctx))
        XCTAssertEqual(records(channelId: 1).first?.messageId, 555,
                       "The now known server id must be stored so the retry can delete by id")
    }

    func testResolveSendAck_storesTheMessageWhenNoDeleteIsPending() {
        seedChannel(id: 1)

        let sent = Message.Builder().id(556).tid(101).build()
        let resolution = ctx.resolveSendAck(sentMessage: sent, channelId: 1)
        try? ctx.save()

        switch resolution {
        case .stored(let dto):
            XCTAssertEqual(dto.id, 556)
        case .suppressedByPendingDelete:
            XCTFail("Without a stored intent the ack must store the message as usual")
        }
        XCTAssertNotNil(MessageDTO.fetch(id: 556, context: ctx))
    }

    func testCreateOrUpdate_keepsAMessageWithAPendingDeleteUnlisted() {
        seedChannel(id: 1)
        ctx.addPendingMessageDelete(messageTid: 102, channelId: 1, messageId: 0, type: .deleteForMe)
        try? ctx.save()

        // Any other path that stores the message again (multi device echo, message sync).
        let message = Message.Builder().id(557).tid(102).build()
        let dto = ctx.createOrUpdate(message: message, channelId: 1)
        try? ctx.save()

        XCTAssertTrue(dto.unlisted, "A message awaiting its delete must stay out of the message list")
    }

    // MARK: - Retry policy

    func testOutcome_successRemovesTheIntent() {
        let outcome = PendingMessageDeleteRetryPolicy.outcome(error: nil)
        XCTAssertFalse(outcome.isRetry)
        if case .done = outcome {} else { XCTFail("Expected .done, got \(outcome)") }
    }

    /// The server has no such message, so there is nothing left to delete: forget the intent.
    func testOutcome_notFoundDropsTheIntent() {
        let outcome = PendingMessageDeleteRetryPolicy.outcome(error: MockSceytError(type: "NotFound"))
        XCTAssertFalse(outcome.isRetry, "NotFound must not be retried")
        if case .drop = outcome {} else { XCTFail("Expected .drop, got \(outcome)") }
    }

    func testOutcome_terminalCodesDropTheIntent() {
        let terminalCodes: [SceytChatError] = [.channelNotExists, .notAllowed, .badMessageParam, .badMessageAttachmentParam]
        for code in terminalCodes {
            let outcome = PendingMessageDeleteRetryPolicy.outcome(error: nsError(code: code.rawValue))
            XCTAssertFalse(outcome.isRetry, "\(code) must not be retried")
            if case .drop = outcome {} else { XCTFail("Expected .drop for \(code), got \(outcome)") }
        }
    }

    func testOutcome_transientErrorsAreRetried() {
        XCTAssertTrue(PendingMessageDeleteRetryPolicy.outcome(error: nsError(code: 9904)).isRetry,
                      "A connection error must be retried")
        XCTAssertTrue(PendingMessageDeleteRetryPolicy.outcome(error: MockSceytError(type: "InternalError")).isRetry)
        XCTAssertTrue(PendingMessageDeleteRetryPolicy.outcome(error: MockSceytError(type: "TooManyRequests")).isRetry)
    }

    // MARK: - Replay ordering and purging

    func testFetchAll_ordersRecordsOldestFirst() {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        for (index, tid) in [Int64(3), 1, 2].enumerated() {
            let dto = PendingMessageDeleteDTO.fetchOrCreate(messageTid: tid, channelId: 1, context: ctx)
            dto.createdAt = now + Int64(index * 1000)
        }
        try? ctx.save()

        // Replay must follow the order the user deleted in.
        XCTAssertEqual(PendingMessageDeleteDTO.fetchAll(context: ctx).map { $0.messageTid }, [3, 1, 2])
    }

    // MARK: - Channel lifecycle

    /// Exercises the purge `deleteChannel(id:)` performs. `deleteChannel(id:)` itself can't run
    /// here: it merges its changes into `SceytChatUIKit.shared.database`, whose persistent store
    /// coordinator differs from `MockDatabase`'s.
    func testDeleteAllForChannel_purgesOnlyThatChannelsPendingDeletes() {
        seedChannel(id: 1)
        seedChannel(id: 2)
        _ = PendingMessageDeleteDTO.fetchOrCreate(messageTid: 100, channelId: 1, context: ctx)
        _ = PendingMessageDeleteDTO.fetchOrCreate(messageTid: 200, channelId: 2, context: ctx)
        try? ctx.save()

        PendingMessageDeleteDTO.deleteAll(channelId: 1, context: ctx)
        try? ctx.save()

        XCTAssertTrue(records(channelId: 1).isEmpty, "Retrying these would only ever fail")
        XCTAssertEqual(records(channelId: 2).count, 1, "Other channels must be untouched")
    }
}
