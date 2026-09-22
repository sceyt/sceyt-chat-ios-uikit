//
//  NewestInsertFadeTests.swift
//  SceytChatUIKitTests
//
//  Tests for `ChannelViewController.shouldFadeInNewestInsert(...)` — the policy
//  deciding whether the message landing at the newest edge fades in (alpha 0 -> 1)
//  on top of the slide.
//
//  The point of pinning this down: the tempting predicate is
//  `deliveryStatus == .pending` ("mine and still sending"), but the `.update`
//  handler parks events that arrive mid-batch and re-diffs them a runloop after
//  the in-flight animation finishes. A quick second send therefore reaches the
//  diff after its ack has already moved the row off `.pending`, so a
//  status-based test drops the fade exactly when the user sends fastest. These
//  cases assert the fade survives every post-`.pending` status.
//

@testable import SceytChatUIKit
import SceytChat
import XCTest

final class NewestInsertFadeTests: XCTestCase {

    private func message(
        incoming: Bool,
        deliveryStatus: ChatMessage.DeliveryStatus,
        id: MessageId = 0
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            tid: 42,
            channelId: 1,
            body: "hi",
            incoming: incoming,
            deliveryStatus: deliveryStatus
        )
    }

    private func shouldFade(_ message: ChatMessage?) -> Bool {
        ChannelViewController.shouldFadeInNewestInsert(
            newestMessage: message,
            animatesNewestInsert: true,
            isEnabled: true
        )
    }

    // MARK: - Own messages fade, at every delivery status

    func test_ownPendingMessage_fades() {
        XCTAssertTrue(shouldFade(message(incoming: false, deliveryStatus: .pending)))
    }

    /// The ack-race case: the row is already `.sent` (and carries a server id) by
    /// the time a parked update is re-diffed. Must still fade.
    func test_ownAlreadyAckedMessage_fades() {
        XCTAssertTrue(shouldFade(message(incoming: false, deliveryStatus: .sent, id: 99)))
        XCTAssertTrue(shouldFade(message(incoming: false, deliveryStatus: .received, id: 99)))
        XCTAssertTrue(shouldFade(message(incoming: false, deliveryStatus: .displayed, id: 99)))
    }

    /// An offline send can be `.failed` before the insert is diffed.
    func test_ownFailedMessage_fades() {
        XCTAssertTrue(shouldFade(message(incoming: false, deliveryStatus: .failed)))
    }

    // MARK: - Incoming messages never fade

    func test_incomingMessage_doesNotFade() {
        XCTAssertFalse(shouldFade(message(incoming: true, deliveryStatus: .received, id: 99)))
        XCTAssertFalse(shouldFade(message(incoming: true, deliveryStatus: .displayed, id: 99)))
        XCTAssertFalse(shouldFade(message(incoming: true, deliveryStatus: .sent, id: 99)))
    }

    // MARK: - Gates

    /// No layout model for the newest key — degrade to no fade rather than
    /// fading an unknown message.
    func test_missingMessage_doesNotFade() {
        XCTAssertFalse(shouldFade(nil))
    }

    /// The fade never runs on a batch the controller is not animating, otherwise
    /// a suppressed batch would jump from invisible straight to opaque.
    func test_nonAnimatedBatch_doesNotFade() {
        XCTAssertFalse(
            ChannelViewController.shouldFadeInNewestInsert(
                newestMessage: message(incoming: false, deliveryStatus: .pending),
                animatesNewestInsert: false,
                isEnabled: true
            )
        )
    }

    func test_disabledByHost_doesNotFade() {
        XCTAssertFalse(
            ChannelViewController.shouldFadeInNewestInsert(
                newestMessage: message(incoming: false, deliveryStatus: .pending),
                animatesNewestInsert: true,
                isEnabled: false
            )
        )
    }
}
