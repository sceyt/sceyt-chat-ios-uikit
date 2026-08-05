//
//  OptimisticUnreadCountTests.swift
//  SceytChatUIKitTests
//
//  Covers the optimistic unread-count path: storing a pending "displayed" marker
//  drops ChannelDTO.newMessageCount at once (offline included), and a server channel
//  write whose count predates those markers is clamped instead of restoring the badge.
//  Once the server's displayed watermark passes a marked message, server values apply
//  verbatim again.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

final class OptimisticUnreadCountTests: XCTestCase {

    private var mockDB: MockDatabase!
    private var ctx: NSManagedObjectContext { mockDB.container.viewContext }
    private var savedUserId: String?

    private let channelId: ChannelId = 1

    override func setUp() {
        super.setUp()
        mockDB = MockDatabase()
        savedUserId = UserDefaults.currentUserId
        UserDefaults.currentUserId = "me"
    }

    override func tearDown() {
        UserDefaults.currentUserId = savedUserId
        mockDB = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Channel with 10 unread: server watermark 100, incoming messages 101...110,
    /// message 110 is the channel's last message.
    @discardableResult
    private func seedChannel(newMessageCount: Int64 = 10,
                             lastDisplayedMessageId: Int64 = 100,
                             messageIds: ClosedRange<Int64> = 101...110) -> ChannelDTO {
        let (channel, _) = ChannelDTO.fetchOrCreate(id: channelId, context: ctx)
        channel.type = "group"
        channel.uri = "test-uri"
        var last: MessageDTO?
        for id in messageIds {
            last = seedMessage(id: id, incoming: true)
        }
        channel.lastMessage = last
        channel.newMessageCount = newMessageCount
        channel.lastDisplayedMessageId = lastDisplayedMessageId
        try? ctx.save()
        return channel
    }

    @discardableResult
    private func seedMessage(id: Int64, incoming: Bool) -> MessageDTO {
        let message = MessageDTO.fetchOrCreate(id: MessageId(id), context: ctx)
        message.id = id
        message.channelId = Int64(channelId)
        message.incoming = incoming
        message.createdAt = Date(timeIntervalSince1970: TimeInterval(id)).bridgeDate
        message.user = UserDTO.fetchOrCreate(id: incoming ? "other" : "me", context: ctx)
        return message
    }

    private func markDisplayed(_ ids: [Int64]) {
        ctx.update(messagePendingMarkers: ids.map { MessageId($0) }, markerName: DefaultMarker.displayed.rawValue)
        try? ctx.save()
    }

    /// Replicates what `update(messageSelfMarkers:)` does on a marker ack: the pending
    /// name is cleared and a confirmed self MarkerDTO is stored on the message.
    private func ackDisplayed(_ ids: [Int64]) {
        ctx.delete(messagePendingMarkers: ids.map { MessageId($0) }, markerName: DefaultMarker.displayed.rawValue)
        for id in ids {
            guard let message = MessageDTO.fetch(id: MessageId(id), context: ctx) else { continue }
            let marker = MarkerDTO.fetchOrCreate(messageId: MessageId(id),
                                                 name: DefaultMarker.displayed.rawValue,
                                                 userId: "me",
                                                 context: ctx)
            marker.createdAt = Date().bridgeDate
            marker.message = message
            if message.userMarkers == nil {
                message.userMarkers = .init()
            }
            message.userMarkers?.insert(marker)
        }
        try? ctx.save()
    }

    /// A channel payload as the server would push it: possibly stale count and watermark.
    private func serverWrite(newMessageCount: UInt64, lastDisplayedMessageId: UInt64) {
        ctx.createOrUpdate(channel: ChatChannel(id: channelId,
                                                type: "group",
                                                newMessageCount: newMessageCount,
                                                lastDisplayedMessageId: MessageId(lastDisplayedMessageId),
                                                uri: "test-uri",
                                                userRole: "participant"))
        try? ctx.save()
    }

    private var unreadCount: Int64 {
        ChannelDTO.fetch(id: channelId, context: ctx)?.newMessageCount ?? -1
    }

    // MARK: - Store-time decrement

    func testStoringDisplayedMarkers_dropsTheCountAtOnce() {
        seedChannel()

        markDisplayed([101, 102, 103])

        XCTAssertEqual(unreadCount, 7, "Viewed messages must not wait for the server ack")
    }

    func testDisplayingTheLastMessage_zeroesTheCount() {
        seedChannel()

        // Scroll-to-bottom marks only the last message id; the server clears
        // everything <= its watermark, so nothing unread can remain.
        markDisplayed([110])

        XCTAssertEqual(unreadCount, 0)
    }

    func testNonDisplayedMarkers_doNotTouchTheCount() {
        seedChannel()

        ctx.update(messagePendingMarkers: [101, 102, 103], markerName: DefaultMarker.received.rawValue)
        try? ctx.save()

        XCTAssertEqual(unreadCount, 10)
    }

    func testStoringTheSameMarkersTwice_decrementsOnce() {
        seedChannel()

        markDisplayed([101, 102, 103])
        markDisplayed([101, 102, 103])

        XCTAssertEqual(unreadCount, 7, "Resends and repeated visibility sweeps must be idempotent")
    }

    func testOutgoingMessages_areNotCounted() {
        seedChannel()
        seedMessage(id: 105, incoming: false)
        try? ctx.save()

        markDisplayed([105])

        XCTAssertEqual(unreadCount, 10)
    }

    func testMessagesAtOrBelowTheServerWatermark_areNotCounted() {
        seedChannel()
        seedMessage(id: 99, incoming: true)
        try? ctx.save()

        markDisplayed([99, 100])

        XCTAssertEqual(unreadCount, 10, "The server count never included messages <= its watermark")
    }

    // MARK: - Stale server writes

    func testStaleServerWrite_doesNotRestoreTheCount() {
        seedChannel()
        markDisplayed([101, 102, 103])

        serverWrite(newMessageCount: 10, lastDisplayedMessageId: 100)

        XCTAssertEqual(unreadCount, 7, "A count that predates the pending markers must be clamped")
    }

    func testStaleServerWriteAfterAck_doesNotRestoreTheCount() {
        seedChannel()
        markDisplayed([101, 102, 103])

        // The marker send is acked (pending rows gone, self markers stored), but the
        // server's unread-count push has not arrived yet.
        ackDisplayed([101, 102, 103])
        serverWrite(newMessageCount: 10, lastDisplayedMessageId: 100)

        XCTAssertEqual(unreadCount, 7, "Confirmed self markers must keep protecting until the watermark catches up")
    }

    func testNewMessagesWhilePending_stillIncrementTheCount() {
        seedChannel()
        markDisplayed([101, 102, 103])
        seedMessage(id: 111, incoming: true)
        try? ctx.save()

        serverWrite(newMessageCount: 11, lastDisplayedMessageId: 100)

        XCTAssertEqual(unreadCount, 8, "11 on the server minus the 3 locally displayed")
    }

    func testServerZero_appliesVerbatim() {
        seedChannel()
        markDisplayed([101, 102, 103])

        serverWrite(newMessageCount: 0, lastDisplayedMessageId: 110)

        XCTAssertEqual(unreadCount, 0)
    }

    // MARK: - Convergence

    func testServerWatermarkCatchingUp_appliesTheServerCountVerbatim() {
        seedChannel()
        markDisplayed([101, 102, 103])

        serverWrite(newMessageCount: 7, lastDisplayedMessageId: 103)

        XCTAssertEqual(unreadCount, 7, "Marked messages at or below the server watermark must drop out of the clamp")
    }

    func testConvergenceAfterAck_laterServerValuesApplyVerbatim() {
        seedChannel()
        markDisplayed([101, 102, 103])
        ackDisplayed([101, 102, 103])

        serverWrite(newMessageCount: 7, lastDisplayedMessageId: 103)
        XCTAssertEqual(unreadCount, 7)

        // From here on the server is the sole authority again.
        serverWrite(newMessageCount: 5, lastDisplayedMessageId: 105)
        XCTAssertEqual(unreadCount, 5)
    }

    // MARK: - Aggregation

    func testTotalUnreadMessageCount_sumsOptimisticValues() {
        seedChannel()

        markDisplayed([101, 102, 103])

        XCTAssertEqual(ChannelDTO.totalUnreadMessageCount(types: [], context: ctx), 7)
    }
}
