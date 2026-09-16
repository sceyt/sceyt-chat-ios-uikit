//
//  MessagePinningDisabledTests.swift
//  SceytChatUIKitTests
//
//  `SceytChatUIKit.shared.config.isMessagePinningEnabled` is the feature's master switch, so
//  what matters is that turning it off is *complete*: no writes, no requests, no pin drawn —
//  and that the pins already on disk are left exactly as they were, since the switch can be
//  turned back on.
//
//  The seams reachable without a chat client are covered here. `ChannelViewModel.canPin` /
//  `canUnpin`, `ChannelViewController.updatePinnedMessages` and
//  `ChannelPinnedMessageListViewModel.canUnpin` read the same flag one line into the method;
//  they are not built in unit tests because their initializers register with
//  `SceytChatUIKit.shared.chatClient`. `ChannelPinnedMessagesUITests` drives those.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

private typealias PinScope = PinnedMessageScope

final class MessagePinningDisabledTests: XCTestCase {

    private var mockDB: MockDatabase!
    private var originalDatabase: Database!
    private var originalPinningEnabled: Bool!
    private var ctx: NSManagedObjectContext { mockDB.container.viewContext }

    private let channelId: ChannelId = 910
    private let messageId: MessageId = 9101

    /// Hosts must outlive the test method: a cell whose superview is deallocated stops binding
    /// (`MessageCell.data`'s setter is gated on `superview != nil`).
    private var hosts = [UIView]()

    override func setUp() {
        super.setUp()
        mockDB = MockDatabase()
        originalDatabase = DataProvider.database
        DataProvider.database = mockDB
        originalPinningEnabled = SceytChatUIKit.shared.config.isMessagePinningEnabled
        seedChannel()
    }

    override func tearDown() {
        SceytChatUIKit.shared.config.isMessagePinningEnabled = originalPinningEnabled
        SyncService.cancelAllPinSyncs()
        DataProvider.database = originalDatabase
        mockDB = nil
        hosts.removeAll()
        super.tearDown()
    }

    // MARK: - Helpers

    @discardableResult
    private func seedChannel() -> ChannelDTO {
        let (channel, _) = ChannelDTO.fetchOrCreate(id: channelId, context: ctx)
        channel.createdAt = Date().bridgeDate
        channel.type = "group"
        try? ctx.save()
        return channel
    }

    /// A stored message, so a refused pin can only be the flag's doing — the store refuses a
    /// message it does not hold, which would make the assertions pass for the wrong reason.
    @discardableResult
    private func seedMessage() -> MessageDTO {
        let message = MessageDTO.fetchOrCreate(
            id: messageId, tid: Int64(messageId), channelId: Int64(channelId), context: ctx
        )
        message.id = Int64(messageId)
        message.tid = Int64(messageId)
        message.channelId = Int64(channelId)
        message.body = "hello"
        message.type = "text"
        message.createdAt = Date().bridgeDate
        message.user = UserDTO.fetchOrCreate(id: "me", context: ctx)
        try? ctx.save()
        return message
    }

    private func chatMessage(pinned: Bool = false) -> ChatMessage {
        ChatMessage(
            id: messageId,
            tid: Int64(messageId),
            channelId: channelId,
            body: "hello",
            type: "text",
            createdAt: Date(),
            incoming: false,
            state: .none,
            deliveryStatus: .sent,
            user: ChatUser(id: "me"),
            pinDetails: pinned ? PinDetails(isPinned: true) : nil
        )
    }

    @discardableResult
    private func storePinDirectly() -> PinnedMessageDTO? {
        let dto = ctx.pinMessage(
            id: messageId,
            tid: Int64(messageId),
            channelId: channelId,
            scope: .forAll,
            pinnedAt: Date(),
            pinnedUntil: nil,
            pinnedBy: "me"
        )
        try? ctx.save()
        return dto
    }

    private func pinRowCount() -> Int {
        ctx.refreshAllObjects()
        return PinnedMessageDTO.count(channelId: channelId, context: ctx)
    }

    /// Runs `body` and waits for its completion, returning the error it reported.
    private func awaitCompletion(
        _ body: (@escaping (Error?) -> Void) -> Void
    ) -> Error? {
        let done = expectation(description: "completed")
        var reported: Error?
        body { error in
            reported = error
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        return reported
    }

    private func isPinningDisabled(_ error: Error?) -> Bool {
        if case ChannelPinnedMessageProvider.PinningError.pinningDisabled? = error { return true }
        return false
    }

    // MARK: - The property itself

    func testPinningIsEnabledByDefault() {
        XCTAssertTrue(
            SceytChatUIKit.shared.config.isMessagePinningEnabled,
            "the switch ships on — turning the feature off must be the integrator's decision"
        )
    }

    // MARK: - Provider: the data layer refuses

    func testPin_storesTheIntentWhileEnabled() {
        SceytChatUIKit.shared.config.isMessagePinningEnabled = true
        seedMessage()
        let provider = MockPinnedMessageProvider(channelId: channelId)

        let error = awaitCompletion { completion in
            provider.pin(message: chatMessage(), scope: .forAll) { completion($0) }
        }

        XCTAssertFalse(isPinningDisabled(error), "precondition: the flag is on, nothing to refuse")
        XCTAssertEqual(pinRowCount(), 1, "the pin is stored as an intent, then sent")
        XCTAssertEqual(provider.mockOperator.pinnedIds, [[NSNumber(value: messageId)]])
    }

    func testPin_isRefusedAndWritesNothingWhileDisabled() {
        SceytChatUIKit.shared.config.isMessagePinningEnabled = false
        seedMessage()
        let provider = MockPinnedMessageProvider(channelId: channelId)

        let error = awaitCompletion { completion in
            provider.pin(message: chatMessage(), scope: .forAll) { completion($0) }
        }

        XCTAssertTrue(
            isPinningDisabled(error),
            "a refusal must be reported, not swallowed as success: \(error.map { "\($0)" } ?? "nil")"
        )
        XCTAssertEqual(pinRowCount(), 0, "nothing may be written while the feature is off")
        XCTAssertTrue(provider.mockOperator.pinnedIds.isEmpty, "and nothing may be sent")
    }

    func testUnpin_isRefusedAndLeavesTheStoredPinInPlaceWhileDisabled() {
        seedMessage()
        XCTAssertNotNil(storePinDirectly(), "precondition: a pin taken before the switch")
        XCTAssertEqual(pinRowCount(), 1)

        SceytChatUIKit.shared.config.isMessagePinningEnabled = false
        let provider = MockPinnedMessageProvider(channelId: channelId)

        let error = awaitCompletion { completion in
            provider.unpin(message: chatMessage(pinned: true)) { completion($0) }
        }

        XCTAssertTrue(isPinningDisabled(error))
        XCTAssertEqual(
            pinRowCount(), 1,
            "an existing pin is left on disk untouched — the switch can be turned back on"
        )
        XCTAssertTrue(provider.mockOperator.unpinnedIds.isEmpty, "and no unpin is sent")
    }

    // MARK: - Sync: no sweep, no drain

    func testSyncChannelPins_isSkippedWhileDisabled() {
        SceytChatUIKit.shared.config.isMessagePinningEnabled = false

        let done = expectation(description: "refused")
        SyncService.syncChannelPins(channelId: channelId) { started in
            XCTAssertFalse(started, "no sweep may be started while the feature is off")
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
    }

    func testSyncChannelPins_leavesStoredPinsAloneWhileDisabled() {
        seedMessage()
        storePinDirectly()
        SceytChatUIKit.shared.config.isMessagePinningEnabled = false

        let done = expectation(description: "refused")
        SyncService.syncChannelPins(channelId: channelId) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(
            pinRowCount(), 1,
            "a skipped sweep must not be read as \"the server has no pins\" and reconcile them away"
        )
    }

    // MARK: - The bubble's pin mark

    func testShowsPin_isFalseWhileDisabled() {
        let pinned = chatMessage(pinned: true)

        SceytChatUIKit.shared.config.isMessagePinningEnabled = true
        XCTAssertTrue(MessageCell.InfoView.showsPin(for: pinned), "precondition")

        SceytChatUIKit.shared.config.isMessagePinningEnabled = false
        XCTAssertFalse(MessageCell.InfoView.showsPin(for: pinned))
    }

    /// `showsPin(for:)` is the one rule for both the render and the measure, so the info row
    /// must not reserve the pin's slot either — a reserved slot the render never fills is a
    /// visible gap in front of the timestamp.
    func testInfoViewMeasure_reservesNoPinSlotWhileDisabled() {
        let channel = ChatChannel(id: channelId, type: "group", uri: "pin-flag")
        let pinned = chatMessage(pinned: true)
        let unpinned = chatMessage(pinned: false)
        let measure: (ChatMessage) -> CGFloat = {
            MessageCell.InfoView.measure(
                channel: channel, message: $0, appearance: MessageCell.appearance
            ).width
        }

        SceytChatUIKit.shared.config.isMessagePinningEnabled = true
        XCTAssertGreaterThan(measure(pinned), measure(unpinned), "precondition: the pin has a slot")

        SceytChatUIKit.shared.config.isMessagePinningEnabled = false
        XCTAssertEqual(
            measure(pinned), measure(unpinned), accuracy: 0.01,
            "a pinned message must measure as an unpinned one while the feature is off"
        )
    }

    func testBoundCell_drawsNoPinWhileDisabled() {
        SceytChatUIKit.shared.config.isMessagePinningEnabled = false

        let model = MessageLayoutModel(
            channel: ChatChannel(id: channelId, type: "group", uri: "pin-flag"),
            message: chatMessage(pinned: true),
            appearance: MessageCell.appearance
        )
        let cell = ChannelViewController.OutgoingMessageCell(
            frame: .init(x: 0, y: 0, width: 390, height: 200)
        )
        let host = UIView(frame: .init(x: 0, y: 0, width: 390, height: 200))
        hosts.append(host)
        host.addSubview(cell)
        cell.data = model
        host.setNeedsLayout()
        host.layoutIfNeeded()

        XCTAssertTrue(cell.infoView.pinView.isHidden, "no pin beside the timestamp")
    }
}
