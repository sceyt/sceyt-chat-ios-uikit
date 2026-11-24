//
//  MessageOrderClockSkewTests.swift
//  SceytChatUIKitTests
//
//  "I receive a message, then send one, and my sent message shows ABOVE the one I received"
//  (2026-11-24, WAAF-3796). Device log: the phone clock was ~18.7 s behind the server.
//
//  The chat list sorts by `createdAt ASC, id ASC`. A received message carries the server's
//  `createdAt`; a sent message is stored by `storePending` with the phone's `createdAt`, and
//  `MessageDTO.map(_:)` keeps that value when the ack brings the server's. So a behind phone
//  clock puts the sent message above the received one, permanently.
//
//  Fix design: `sent_message_order_solution.md` (WAAFI repo).
//    Part 1 — a server-confirmed write (`id > 0`, real date) replaces `createdAt`.
//    Part 2 — `storePending` stores `max(phone createdAt, newest list row + 1 ms)`.
//
//  Tests marked [BUG] reproduce the current behaviour and FAIL until the fix lands.
//  Tests marked [GUARD] pass today and must keep passing after the fix.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

final class MessageOrderClockSkewTests: XCTestCase {

    private var mockDB: MockDatabase!
    private var originalDatabase: Database!

    private let channelId: ChannelId = 740_045
    private let ownTid = 6_138_740_543_640_829_955
    private let receivedId: MessageId = 884_559_669_371_215_872
    private let sentServerId: MessageId = 884_559_685_129_216_000
    private let olderId: MessageId = 884_554_580_795_465_728

    /// Real (server) time the scenario starts at.
    private let t0 = Date(timeIntervalSince1970: 1_795_000_000)
    /// The device log's skew: the phone clock is this far behind the server.
    private let phoneBehind: TimeInterval = 18.7

    private var ctx: NSManagedObjectContext { mockDB.container.viewContext }

    override func setUp() {
        super.setUp()
        originalDatabase = DataProvider.database
        mockDB = MockDatabase()
        DataProvider.database = mockDB
        _ = ChannelDTO.fetchOrCreate(id: channelId, context: ctx)
        try? ctx.save()
    }

    override func tearDown() {
        DataProvider.database = originalDatabase
        mockDB = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    /// A message as the server delivers it (received event, sync page, or send ack).
    /// `incoming`, `createdAt` and `deliveryStatus` are read-only on the SDK type and are set
    /// through KVC, the way the SDK's own decoder fills them.
    private func serverMessage(
        id: MessageId,
        tid: Int = 0,
        incoming: Bool,
        createdAt: Date,
        body: String,
        status: MessageDeliveryStatus = .sent
    ) -> Message {
        let message = Message.Builder()
            .id(id)
            .tid(tid == 0 ? Int(id) : tid)
            .type("text")
            .body(body)
            .build()
        message.setValue(incoming, forKey: "incoming")
        message.setValue(createdAt, forKey: "createdAt")
        message.setValue(status.rawValue, forKey: "deliveryStatus")
        return message
    }

    /// The outgoing message as `storePending` receives it: no server id, the phone's clock.
    private func pendingMessage(phoneCreatedAt: Date, body: String = "2") -> Message {
        let message = Message.Builder()
            .tid(ownTid)
            .type("text")
            .body(body)
            .build()
        message.setValue(false, forKey: "incoming")
        message.setValue(phoneCreatedAt, forKey: "createdAt")
        message.setValue(MessageDeliveryStatus.pending.rawValue, forKey: "deliveryStatus")
        return message
    }

    /// The send ack for `pendingMessage`: same tid, server id, the server's clock.
    private func ackMessage(serverCreatedAt: Date, body: String = "2") -> Message {
        serverMessage(id: sentServerId, tid: ownTid, incoming: false, createdAt: serverCreatedAt, body: body)
    }

    private func write(_ messages: Message...) {
        let writer = mockDB.backgroundPerformContext
        writer.performAndWait {
            for message in messages {
                writer.createOrUpdate(message: message, channelId: channelId)
            }
            try? writer.save()
        }
    }

    private func storePending(_ message: Message, file: StaticString = #filePath, line: UInt = #line) {
        let done = expectation(description: "storePending")
        ChannelMessageProvider(channelId: channelId).storePending(message: message) { error in
            XCTAssertNil(error, file: file, line: line)
            done.fulfill()
        }
        wait(for: [done], timeout: defaultWaitTimeout)
    }

    /// Rows in the order the chat list shows them (top → bottom): `LazyMessagesObserver`'s
    /// predicate and sort descriptors.
    private func listOrder() -> [MessageDTO] {
        ctx.refreshAllObjects()
        let request = MessageDTO.fetchRequest()
        request.predicate = LazyMessagesObserver.listPredicate(channelId: channelId)
        request.sortDescriptors = [
            .init(keyPath: \MessageDTO.createdAt, ascending: true),
            .init(keyPath: \MessageDTO.id, ascending: true)
        ]
        return (try? ctx.fetch(request)) ?? []
    }

    private func bodies() -> [String] { listOrder().map { $0.body } }

    private func ownRow() -> MessageDTO? {
        listOrder().first { $0.tid == Int64(ownTid) }
    }

    private func channelLastMessageBody() -> String? {
        ctx.refreshAllObjects()
        return ChannelDTO.fetch(id: channelId, context: ctx)?.lastMessage?.body
    }

    // MARK: - Part 1: the ack replaces the phone time with the server time

    /// [BUG] The server-confirmed time must be stored. Today `map(_:)` keeps the phone time.
    func testAck_storesServerCreatedAt() {
        let phoneNow = t0.addingTimeInterval(-phoneBehind)
        write(pendingMessage(phoneCreatedAt: phoneNow))
        let serverTime = t0.addingTimeInterval(0.4)
        write(ackMessage(serverCreatedAt: serverTime))

        XCTAssertEqual(
            ownRow()?.createdAt.bridgeDate.timeIntervalSince1970 ?? 0,
            serverTime.timeIntervalSince1970,
            accuracy: 0.001,
            "after the ack the sent message must carry the server's createdAt, not the phone's"
        )
    }

    /// [BUG] The reported case, values from the device log: phone 18.7 s behind, a message is
    /// received, then one is sent. After the ack the sent message must be below the received one.
    func testPhoneBehind_afterAck_sentMessageIsBelowReceived() {
        write(serverMessage(id: olderId, incoming: true, createdAt: t0.addingTimeInterval(-1200), body: "Hjjj"))
        write(serverMessage(id: receivedId, incoming: true, createdAt: t0, body: "Message 1"))

        // 3.8 s later (real time) the user sends; the phone stamps it 18.7 s early.
        let realSendTime = t0.addingTimeInterval(3.8)
        write(pendingMessage(phoneCreatedAt: realSendTime.addingTimeInterval(-phoneBehind)))
        write(ackMessage(serverCreatedAt: realSendTime.addingTimeInterval(0.4)))

        XCTAssertEqual(bodies(), ["Hjjj", "Message 1", "2"])
    }

    /// [BUG] Phone clock AHEAD: we send first, a peer's message reaches the server 0.6 s later.
    /// Server order is [ours, peer's]; with the phone time kept ours stays below forever.
    func testPhoneAhead_afterAck_orderFollowsServer() {
        let phoneAhead: TimeInterval = 20
        write(pendingMessage(phoneCreatedAt: t0.addingTimeInterval(phoneAhead)))
        write(serverMessage(id: receivedId, incoming: true, createdAt: t0.addingTimeInterval(1), body: "Message 1"))
        write(ackMessage(serverCreatedAt: t0.addingTimeInterval(0.4)))

        XCTAssertEqual(bodies(), ["2", "Message 1"])
    }

    /// [BUG] A message stored with a wrong (phone) time before the fix is corrected by the next
    /// server write of it — a sync page or a reconnect reload.
    func testLaterServerWrite_correctsAlreadyWrongCreatedAt() {
        write(serverMessage(id: receivedId, incoming: true, createdAt: t0, body: "Message 1"))
        // Already confirmed (id > 0) but carrying the phone time, as rows stored today do.
        write(serverMessage(id: sentServerId, tid: ownTid, incoming: false,
                            createdAt: t0.addingTimeInterval(-15), body: "2"))
        XCTAssertEqual(bodies(), ["2", "Message 1"], "precondition: the wrong order is stored")

        write(serverMessage(id: sentServerId, tid: ownTid, incoming: false,
                            createdAt: t0.addingTimeInterval(4), body: "2"))

        XCTAssertEqual(bodies(), ["Message 1", "2"])
    }

    /// [GUARD] An unconfirmed write (`id == 0`: storing a pending row again, a resend built from
    /// the local copy) must never replace the stored time.
    func testUnconfirmedWrite_doesNotReplaceCreatedAt() {
        let stored = t0
        write(pendingMessage(phoneCreatedAt: stored))
        write(pendingMessage(phoneCreatedAt: t0.addingTimeInterval(-60)))

        XCTAssertEqual(ownRow()?.createdAt.bridgeDate.timeIntervalSince1970 ?? 0,
                       stored.timeIntervalSince1970, accuracy: 0.001)
    }

    /// [GUARD] A confirmed write carrying no real date (zero / epoch) must never replace the
    /// stored time.
    func testConfirmedWriteWithEmptyDate_doesNotReplaceCreatedAt() {
        write(serverMessage(id: sentServerId, tid: ownTid, incoming: false, createdAt: t0, body: "2"))
        write(serverMessage(id: sentServerId, tid: ownTid, incoming: false,
                            createdAt: Date(timeIntervalSince1970: 0), body: "2"))

        XCTAssertEqual(ownRow()?.createdAt.bridgeDate.timeIntervalSince1970 ?? 0,
                       t0.timeIntervalSince1970, accuracy: 0.001)
    }

    /// [GUARD] The channel's last message after the ack is the sent message (ids compare).
    func testAck_channelLastMessageIsSentMessage() {
        write(serverMessage(id: receivedId, incoming: true, createdAt: t0, body: "Message 1"))
        write(pendingMessage(phoneCreatedAt: t0.addingTimeInterval(3.8 - phoneBehind)))
        write(ackMessage(serverCreatedAt: t0.addingTimeInterval(4.2)))

        XCTAssertEqual(channelLastMessageBody(), "2")
    }

    // MARK: - Part 2: a pending message is stored at the bottom of the list

    /// [BUG] While pending (before any ack) the new message must already be at the bottom.
    func testStorePending_phoneBehind_messageIsAtBottom() {
        write(serverMessage(id: olderId, incoming: true, createdAt: t0.addingTimeInterval(-1200), body: "Hjjj"))
        write(serverMessage(id: receivedId, incoming: true, createdAt: t0, body: "Message 1"))

        storePending(pendingMessage(phoneCreatedAt: t0.addingTimeInterval(3.8 - phoneBehind)))

        XCTAssertEqual(bodies(), ["Hjjj", "Message 1", "2"])
    }

    /// [BUG] While pending, the channel list must show the new message as the last message.
    /// Today the pending row (`id == 0`) is compared by `createdAt` and loses to the received one.
    func testStorePending_phoneBehind_becomesChannelLastMessage() {
        write(serverMessage(id: receivedId, incoming: true, createdAt: t0, body: "Message 1"))

        storePending(pendingMessage(phoneCreatedAt: t0.addingTimeInterval(3.8 - phoneBehind)))

        XCTAssertEqual(channelLastMessageBody(), "2")
    }

    /// [BUG] Full flow with the behind clock: the message must not move when the ack arrives —
    /// it is at the bottom while pending and stays there.
    func testSendFlow_phoneBehind_noReorderOnAck() {
        write(serverMessage(id: receivedId, incoming: true, createdAt: t0, body: "Message 1"))

        storePending(pendingMessage(phoneCreatedAt: t0.addingTimeInterval(3.8 - phoneBehind)))
        let whilePending = bodies()
        write(ackMessage(serverCreatedAt: t0.addingTimeInterval(4.2)))
        let afterAck = bodies()

        XCTAssertEqual(whilePending, ["Message 1", "2"], "pending message must start at the bottom")
        XCTAssertEqual(afterAck, ["Message 1", "2"], "ack must not move the message")
    }

    /// [GUARD] With a correct clock the pending row keeps the phone's time (no adjustment).
    func testStorePending_phoneClockCorrect_keepsPhoneTime() {
        write(serverMessage(id: receivedId, incoming: true, createdAt: t0, body: "Message 1"))
        let phoneNow = t0.addingTimeInterval(5)

        storePending(pendingMessage(phoneCreatedAt: phoneNow))

        XCTAssertEqual(ownRow()?.createdAt.bridgeDate.timeIntervalSince1970 ?? 0,
                       phoneNow.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(bodies(), ["Message 1", "2"])
    }

    /// [GUARD] In an empty channel the pending row keeps the phone's time.
    func testStorePending_emptyChannel_keepsPhoneTime() {
        let phoneNow = t0

        storePending(pendingMessage(phoneCreatedAt: phoneNow))

        XCTAssertEqual(ownRow()?.createdAt.bridgeDate.timeIntervalSince1970 ?? 0,
                       phoneNow.timeIntervalSince1970, accuracy: 0.001)
    }

    /// [BUG] Two sends in a row with a behind clock land below the received message, in send order.
    func testStorePending_twoSends_keepSendOrder() {
        write(serverMessage(id: receivedId, incoming: true, createdAt: t0, body: "Message 1"))

        storePending(pendingMessage(phoneCreatedAt: t0.addingTimeInterval(1 - phoneBehind), body: "first"))
        let second = Message.Builder().tid(ownTid + 1).type("text").body("second").build()
        second.setValue(false, forKey: "incoming")
        second.setValue(t0.addingTimeInterval(2 - phoneBehind), forKey: "createdAt")
        storePending(second)

        XCTAssertEqual(bodies(), ["Message 1", "first", "second"])
    }
}
