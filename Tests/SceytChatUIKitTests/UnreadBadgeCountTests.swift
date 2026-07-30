//
//  UnreadBadgeCountTests.swift
//  SceytChatUIKitTests
//
//  Tier 1 unit tests for the scroll-down badge count:
//  `ChannelViewController.unseenIncomingCount(visiblePaths:sectionItemCounts:isUnseenIncoming:)`
//  and `ChannelViewController.badgeCount(raw:visibleUnseen:isShowingNewestMessage:)`.
//
//  The badge shows `newMessageCount - visible unseen incoming messages`,
//  floored at zero: the channel's unread count minus the incoming messages the
//  user can see right now that don't yet carry their confirmed `displayed`
//  marker (`hasDisplayedFromMe`). Once the server ACKs a marker it also lowers
//  `newMessageCount`, so a marked message must leave the subtracted set — the
//  seen-marker exclusions below are that rule.
//

@testable import SceytChatUIKit
import XCTest

final class UnreadBadgeCountTests: XCTestCase {

    private func paths(_ pairs: [(Int, Int)]) -> [IndexPath] {
        pairs.map { IndexPath(item: $0.1, section: $0.0) }
    }

    /// All messages incoming and unseen — most cases probe the walk itself.
    private func unseen(_ visible: [(Int, Int)],
                        counts: [Int]) -> Int? {
        ChannelViewController.unseenIncomingCount(
            visiblePaths: paths(visible),
            sectionItemCounts: counts,
            isUnseenIncoming: { _ in true }
        )
    }

    /// `excluded` lists the (section, item) pairs that must not be counted —
    /// either the current user's own messages, or incoming messages already
    /// carrying the user's confirmed `displayed` marker.
    private func unseen(_ visible: [(Int, Int)],
                        counts: [Int],
                        excluded: Set<[Int]>) -> Int? {
        ChannelViewController.unseenIncomingCount(
            visiblePaths: paths(visible),
            sectionItemCounts: counts,
            isUnseenIncoming: { !excluded.contains([$0.section, $0.item]) }
        )
    }

    // MARK: - unseenIncomingCount

    func test_unseenIncomingCount_allUnseen_countsEveryVisibleCell() {
        XCTAssertEqual(unseen([(0, 0), (0, 1), (0, 2)], counts: [5]), 3)
    }

    func test_unseenIncomingCount_spansSections() {
        XCTAssertEqual(unseen([(0, 4), (1, 0), (1, 1)], counts: [5, 3]), 3)
    }

    /// The user's own messages on screen are never unread, so they must not be
    /// subtracted from the badge.
    func test_unseenIncomingCount_skipsOutgoingMessages() {
        XCTAssertEqual(
            unseen([(0, 0), (0, 1), (0, 2), (0, 3)],
                   counts: [8],
                   excluded: [[0, 1], [0, 3]]),
            2
        )
    }

    /// A visible incoming message that already carries my confirmed `displayed`
    /// marker has left the server's unread count — subtracting it again would
    /// double-count it.
    func test_unseenIncomingCount_skipsMessagesWithMyDisplayedMarker() {
        XCTAssertEqual(
            unseen([(0, 0), (0, 1), (0, 2)],
                   counts: [5],
                   excluded: [[0, 0]]),
            2
        )
    }

    /// Everything on screen is either outgoing or already marked → subtract
    /// nothing, the badge shows the raw count.
    func test_unseenIncomingCount_allExcluded_isZero() {
        XCTAssertEqual(
            unseen([(0, 0), (0, 1)], counts: [4], excluded: [[0, 0], [0, 1]]),
            0
        )
    }

    /// A visible path outside the snapshot means the layout and the snapshot
    /// are briefly out of step — the count is unknowable, not zero.
    func test_unseenIncomingCount_pathOutOfBounds_isNil() {
        XCTAssertNil(unseen([(0, 0), (1, 0)], counts: [5]))
        XCTAssertNil(unseen([(0, 5)], counts: [5]))
    }

    func test_unseenIncomingCount_noVisiblePaths_isZero() {
        XCTAssertEqual(unseen([], counts: [5]), 0)
    }

    // MARK: - badgeCount

    /// The reported bug: 10 unread, 5 unseen on screen → show 10 − 5 = 5.
    func test_badgeCount_subtractsVisibleUnseen() {
        XCTAssertEqual(
            ChannelViewController.badgeCount(raw: 10, visibleUnseen: 5, isShowingNewestMessage: true),
            5
        )
    }

    /// More unseen on screen than the raw count knows about — the subtraction
    /// floors at zero, it must never wrap.
    func test_badgeCount_floorsAtZero() {
        XCTAssertEqual(
            ChannelViewController.badgeCount(raw: 3, visibleUnseen: 14, isShowingNewestMessage: true),
            0
        )
    }

    func test_badgeCount_nothingUnseenVisible_showsRaw() {
        XCTAssertEqual(
            ChannelViewController.badgeCount(raw: 10, visibleUnseen: 0, isShowingNewestMessage: true),
            10
        )
    }

    /// Nothing laid out yet — "unknown" must not read as zero seen.
    func test_badgeCount_unknownVisible_fallsBackToRaw() {
        XCTAssertEqual(
            ChannelViewController.badgeCount(raw: 10, visibleUnseen: nil, isShowingNewestMessage: true),
            10
        )
    }

    /// Jumped to a search result with an unloaded gap toward the newest end —
    /// the visible messages are old ones, subtracting them would under-report.
    func test_badgeCount_newestMessageNotLoaded_fallsBackToRaw() {
        XCTAssertEqual(
            ChannelViewController.badgeCount(raw: 10, visibleUnseen: 5, isShowingNewestMessage: false),
            10
        )
    }

    func test_badgeCount_noUnread_staysZero() {
        XCTAssertEqual(
            ChannelViewController.badgeCount(raw: 0, visibleUnseen: 5, isShowingNewestMessage: true),
            0
        )
        XCTAssertEqual(
            ChannelViewController.badgeCount(raw: 0, visibleUnseen: nil, isShowingNewestMessage: false),
            0
        )
    }

    /// A negative count would trap on `UInt64(_:)` — fall back instead.
    func test_badgeCount_negativeVisible_fallsBackToRaw() {
        XCTAssertEqual(
            ChannelViewController.badgeCount(raw: 7, visibleUnseen: -1, isShowingNewestMessage: true),
            7
        )
    }

    // MARK: - hasDisplayedFromMe (the marker check the walk relies on)

    /// `hasDisplayedFromMe` is true exactly when `userMarkers` carries a
    /// confirmed `displayed` marker from the CURRENT user — someone else's
    /// marker, or my marker of another kind, must not exclude the message.
    func test_hasDisplayedFromMe_matchesOnlyMyDisplayedMarker() {
        // Pin the current user for the duration of the test — the chat client
        // is not connected here, so `currentUserId` resolves via UserDefaults.
        let previousUserId = UserDefaults.currentUserId
        let me = "unread-badge-tests-me"
        UserDefaults.currentUserId = me
        defer { UserDefaults.currentUserId = previousUserId }

        func message(markers: [(user: String, name: String)]) -> ChatMessage {
            .init(
                id: 1,
                channelId: 1,
                incoming: true,
                userMarkers: markers.map {
                    .init(messageId: 1,
                          createdAt: .init(timeIntervalSince1970: 0),
                          name: $0.name,
                          user: .init(id: $0.user))
                },
                user: .init(id: "bob")
            )
        }

        XCTAssertTrue(message(markers: [(me, "displayed")]).hasDisplayedFromMe)
        XCTAssertFalse(message(markers: [("someone-else", "displayed")]).hasDisplayedFromMe)
        XCTAssertFalse(message(markers: [(me, "received")]).hasDisplayedFromMe)
        XCTAssertFalse(message(markers: []).hasDisplayedFromMe)
    }
}
