//
//  UnreadBadgeCountTests.swift
//  SceytChatUIKitTests
//
//  Tier 1 unit tests for the scroll-down badge count:
//  `ChannelViewController.badgeCount(raw:seenUnreadCount:)` and
//  `ChannelViewController.countsAsSeenUnread(_:lastDisplayedMessageId:)`.
//
//  The badge shows `newMessageCount − unread messages already reached`,
//  floored at zero: every incoming unread message that has ever entered the
//  viewport stays subtracted, so the badge means "unread messages still
//  waiting below you" and does not re-inflate while the displayed-marker
//  flush is in flight. When the server ACKs, the same channel update lowers
//  `newMessageCount` and advances `lastDisplayedMessageId`, and the confirmed
//  ids are pruned from the seen set so they are not double-subtracted.
//

import SceytChat
@testable import SceytChatUIKit
import XCTest

final class UnreadBadgeCountTests: XCTestCase {

    // MARK: - badgeCount

    /// The reported bug: 32 unread, 18 already reached → show 32 − 18 = 14.
    func test_badgeCount_subtractsSeenUnread() {
        XCTAssertEqual(ChannelViewController.badgeCount(raw: 32, seenUnreadCount: 18), 14)
    }

    /// More seen than the raw count knows about (ACK lowered raw before the
    /// seen set was pruned) — the subtraction floors at zero, it must never wrap.
    func test_badgeCount_floorsAtZero() {
        XCTAssertEqual(ChannelViewController.badgeCount(raw: 3, seenUnreadCount: 14), 0)
    }

    func test_badgeCount_nothingSeen_showsRaw() {
        XCTAssertEqual(ChannelViewController.badgeCount(raw: 10, seenUnreadCount: 0), 10)
    }

    func test_badgeCount_everythingSeen_isZero() {
        XCTAssertEqual(ChannelViewController.badgeCount(raw: 10, seenUnreadCount: 10), 0)
    }

    func test_badgeCount_noUnread_staysZero() {
        XCTAssertEqual(ChannelViewController.badgeCount(raw: 0, seenUnreadCount: 5), 0)
        XCTAssertEqual(ChannelViewController.badgeCount(raw: 0, seenUnreadCount: 0), 0)
    }

    /// A negative count would trap on `UInt64(_:)` — fall back to raw instead.
    func test_badgeCount_negativeSeen_showsRaw() {
        XCTAssertEqual(ChannelViewController.badgeCount(raw: 7, seenUnreadCount: -1), 7)
    }

    // MARK: - countsAsSeenUnread

    private func message(
        id: MessageId,
        incoming: Bool = true,
        markers: [(user: String, name: String)] = []) -> ChatMessage {
            .init(
                id: id,
                channelId: 1,
                incoming: incoming,
                userMarkers: markers.map {
                    .init(messageId: id,
                          createdAt: .init(timeIntervalSince1970: 0),
                          name: $0.name,
                          user: .init(id: $0.user))
                },
                user: .init(id: "bob")
            )
        }

    func test_countsAsSeenUnread_incomingNewerThanWatermark_counts() {
        XCTAssertTrue(
            ChannelViewController.countsAsSeenUnread(message(id: 10), lastDisplayedMessageId: 5)
        )
    }

    /// The user's own messages are never unread — they must not be subtracted.
    func test_countsAsSeenUnread_outgoing_doesNotCount() {
        XCTAssertFalse(
            ChannelViewController.countsAsSeenUnread(message(id: 10, incoming: false), lastDisplayedMessageId: 5)
        )
    }

    /// Messages at or below the confirmed displayed watermark have left the
    /// server's unread count — subtracting them again would double-count.
    func test_countsAsSeenUnread_atOrBelowWatermark_doesNotCount() {
        XCTAssertFalse(
            ChannelViewController.countsAsSeenUnread(message(id: 5), lastDisplayedMessageId: 5)
        )
        XCTAssertFalse(
            ChannelViewController.countsAsSeenUnread(message(id: 4), lastDisplayedMessageId: 5)
        )
    }

    /// An incoming message already carrying my confirmed `displayed` marker
    /// has left the server's unread count even if the channel watermark lags —
    /// it must not enter the seen set.
    func test_countsAsSeenUnread_withMyDisplayedMarker_doesNotCount() {
        // Pin the current user for the duration of the test — the chat client
        // is not connected here, so `currentUserId` resolves via UserDefaults.
        let previousUserId = UserDefaults.currentUserId
        let me = "unread-badge-tests-me"
        UserDefaults.currentUserId = me
        defer { UserDefaults.currentUserId = previousUserId }

        XCTAssertFalse(
            ChannelViewController.countsAsSeenUnread(
                message(id: 10, markers: [(me, "displayed")]),
                lastDisplayedMessageId: 5
            )
        )
        XCTAssertTrue(
            ChannelViewController.countsAsSeenUnread(
                message(id: 10, markers: [("someone-else", "displayed")]),
                lastDisplayedMessageId: 5
            )
        )
    }

    // MARK: - hasDisplayedFromMe (the marker check the seen set relies on)

    /// `hasDisplayedFromMe` is true exactly when `userMarkers` carries a
    /// confirmed `displayed` marker from the CURRENT user — someone else's
    /// marker, or my marker of another kind, must not exclude the message.
    func test_hasDisplayedFromMe_matchesOnlyMyDisplayedMarker() {
        let previousUserId = UserDefaults.currentUserId
        let me = "unread-badge-tests-me"
        UserDefaults.currentUserId = me
        defer { UserDefaults.currentUserId = previousUserId }

        XCTAssertTrue(message(id: 1, markers: [(me, "displayed")]).hasDisplayedFromMe)
        XCTAssertFalse(message(id: 1, markers: [("someone-else", "displayed")]).hasDisplayedFromMe)
        XCTAssertFalse(message(id: 1, markers: [(me, "received")]).hasDisplayedFromMe)
        XCTAssertFalse(message(id: 1, markers: []).hasDisplayedFromMe)
    }
}
