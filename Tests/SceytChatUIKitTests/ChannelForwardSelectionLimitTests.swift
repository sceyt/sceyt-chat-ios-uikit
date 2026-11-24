//
//  ChannelForwardSelectionLimitTests.swift
//  SceytChatUIKitTests
//
//  The Forward destination picker caps how many chats can be selected at once
//  (`config.forwardChannelSelectionLimit`). Both selection entry points — the main
//  channel list and the search results list — funnel through
//  `ChannelForwardViewModel.select(_:)`, so the cap lives there.
//
//  Two things have to stay true at the cap:
//  1. A further selection is rejected without growing `selectedChannels`, and announces
//     itself via `.selectionLimitReached` so the screen can tell the user.
//  2. Deselect still works. The toggle must not be gated by the cap, or a user who fills
//     every slot can never change their mind.
//

@testable import SceytChatUIKit
import Combine
import SceytChat
import XCTest

final class ChannelForwardSelectionLimitTests: XCTestCase {

    private var viewModel: ChannelForwardViewModel!
    private var subscriptions = Set<AnyCancellable>()
    private var savedLimit: Int!

    override func setUp() {
        super.setUp()
        savedLimit = SceytChatUIKit.shared.config.forwardChannelSelectionLimit
        viewModel = ChannelForwardViewModel(handler: { _ in })
    }

    override func tearDown() {
        SceytChatUIKit.shared.config.forwardChannelSelectionLimit = savedLimit
        subscriptions.removeAll()
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func channel(_ id: ChannelId) -> ChatChannel {
        ChatChannel(id: id, type: "group", uri: "forward-limit-\(id)")
    }

    /// Collects every event the view model emits for the duration of the test.
    private func recordEvents() -> () -> [ChannelForwardViewModel.Event] {
        var events = [ChannelForwardViewModel.Event]()
        viewModel.event
            .sink { events.append($0) }
            .store(in: &subscriptions)
        return { events }
    }

    private func limitReachedValues(
        in events: [ChannelForwardViewModel.Event]
    ) -> [Int] {
        events.compactMap {
            if case let .selectionLimitReached(limit) = $0 { return limit }
            return nil
        }
    }

    // MARK: - Tests

    func test_defaultLimitIsTen() {
        XCTAssertEqual(SceytChatUIKit.shared.config.forwardChannelSelectionLimit, 10)
    }

    func test_selectionStopsAtLimitAndAnnouncesIt() {
        SceytChatUIKit.shared.config.forwardChannelSelectionLimit = 10
        let events = recordEvents()

        (1...11).forEach { viewModel.select(channel(ChannelId($0))) }

        XCTAssertEqual(viewModel.selectedChannels.count, 10,
                       "the 11th chat must not be added")
        XCTAssertFalse(viewModel.isSelected(channel(11)),
                       "the rejected chat must not read back as selected, so its checkbox stays off")
        XCTAssertEqual(limitReachedValues(in: events()), [10],
                       "exactly one .selectionLimitReached(10), carrying the limit for the alert")
        XCTAssertFalse(viewModel.canSelectMore)
    }

    func test_deselectWorksAtTheLimitAndFreesASlot() {
        SceytChatUIKit.shared.config.forwardChannelSelectionLimit = 3
        (1...3).forEach { viewModel.select(channel(ChannelId($0))) }
        XCTAssertFalse(viewModel.canSelectMore)

        // Tapping a selected row at the cap must toggle it off, not be swallowed by the guard.
        viewModel.select(channel(2))
        XCTAssertFalse(viewModel.isSelected(channel(2)))
        XCTAssertEqual(viewModel.selectedChannels.count, 2)

        let events = recordEvents()
        viewModel.select(channel(99))
        XCTAssertTrue(viewModel.isSelected(channel(99)),
                      "the freed slot must be usable again")
        XCTAssertEqual(viewModel.selectedChannels.count, 3)
        XCTAssertTrue(limitReachedValues(in: events()).isEmpty)
    }

    func test_reselectingAnAlreadySelectedChannelNeverConsumesASlot() {
        SceytChatUIKit.shared.config.forwardChannelSelectionLimit = 5
        let target = channel(1)

        viewModel.select(target)
        viewModel.select(target) // off
        viewModel.select(target) // on again

        XCTAssertTrue(viewModel.isSelected(target))
        XCTAssertEqual(viewModel.selectedChannels.count, 1)
    }

    func test_zeroOrNegativeLimitMeansUnlimited() {
        for limit in [0, -1] {
            SceytChatUIKit.shared.config.forwardChannelSelectionLimit = limit
            let unlimitedViewModel = ChannelForwardViewModel(handler: { _ in })
            var events = [ChannelForwardViewModel.Event]()
            var localSubscriptions = Set<AnyCancellable>()
            unlimitedViewModel.event.sink { events.append($0) }.store(in: &localSubscriptions)

            (1...50).forEach { unlimitedViewModel.select(channel(ChannelId($0))) }

            XCTAssertEqual(unlimitedViewModel.selectedChannels.count, 50, "limit \(limit)")
            XCTAssertTrue(unlimitedViewModel.canSelectMore, "limit \(limit)")
            XCTAssertTrue(limitReachedValues(in: events).isEmpty, "limit \(limit)")
        }
    }

    func test_selectionLimitReadsFromConfigAtCallTime() {
        SceytChatUIKit.shared.config.forwardChannelSelectionLimit = 2
        XCTAssertEqual(viewModel.selectionLimit, 2)

        SceytChatUIKit.shared.config.forwardChannelSelectionLimit = 7
        XCTAssertEqual(viewModel.selectionLimit, 7,
                       "the knob must stay overridable at runtime, not be captured at init")
    }
}
