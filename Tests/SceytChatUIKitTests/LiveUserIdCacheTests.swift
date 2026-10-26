//
//  LiveUserIdCacheTests.swift
//  SceytChatUIKitTests
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//
//  `SceytChatUIKit.currentUserId` takes the live user id from `LiveUserIdCache`
//  instead of copying the native user on every read. These tests count the
//  reads of the client, so "cached" is asserted rather than assumed, and pin
//  the cases where the cache must not answer for the client.
//

import XCTest
import SceytChat
@testable import SceytChatUIKit

final class LiveUserIdCacheTests: XCTestCase {

    /// Stands in for the chat client: a user id that can change, and a count of
    /// how often it was asked.
    private final class FakeClient {
        var userId: UserId = ""
        var reads = 0
        var onRead: (() -> Void)?

        func read() -> UserId {
            reads += 1
            let id = userId
            onRead?()
            return id
        }
    }

    private var client: FakeClient!
    private var cache: LiveUserIdCache!

    override func setUp() {
        super.setUp()
        client = FakeClient()
        cache = LiveUserIdCache { [unowned client = client!] in client.read() }
    }

    func test_enabled_asksTheClientOnce() {
        client.userId = "me"
        cache.enable()

        for _ in 0..<100 {
            XCTAssertEqual(cache.value, "me")
        }
        XCTAssertEqual(client.reads, 1)
    }

    /// Without an observer nothing would clear the cache, so until it is
    /// enabled every read must go to the client.
    func test_notEnabled_alwaysAsksTheClient() {
        client.userId = "me"

        XCTAssertEqual(cache.value, "me")
        client.userId = "other"
        XCTAssertEqual(cache.value, "other")
        XCTAssertEqual(client.reads, 2)
    }

    func test_invalidate_picksUpTheNewUser() {
        client.userId = "outgoing"
        cache.enable()
        XCTAssertEqual(cache.value, "outgoing")

        client.userId = "incoming" // authenticated as another account
        XCTAssertEqual(cache.value, "outgoing", "cached until the state change arrives")

        cache.invalidate()
        XCTAssertEqual(cache.value, "incoming")
        XCTAssertEqual(cache.value, "incoming")
        XCTAssertEqual(client.reads, 2)
    }

    /// Before the first authentication the client has no user; caching that
    /// would hide the user authentication is about to fill in.
    func test_emptyId_isNotCached() {
        cache.enable()
        XCTAssertEqual(cache.value, "")
        XCTAssertEqual(cache.value, "")
        XCTAssertEqual(client.reads, 2)

        client.userId = "me"
        XCTAssertEqual(cache.value, "me")
        XCTAssertEqual(cache.value, "me")
        XCTAssertEqual(client.reads, 3)
    }

    func test_refreshed_asksTheClientAndCachesTheAnswer() {
        client.userId = "outgoing"
        cache.enable()
        XCTAssertEqual(cache.value, "outgoing")

        client.userId = "incoming"
        XCTAssertEqual(cache.refreshed(), "incoming")
        XCTAssertEqual(cache.value, "incoming")
        XCTAssertEqual(client.reads, 2)
    }

    /// A read that fetched the outgoing id, then lost the race to an
    /// invalidation, must not store that id over the invalidation.
    func test_readRacingAnInvalidation_doesNotStoreTheStaleId() {
        client.userId = "outgoing"
        cache.enable()
        client.onRead = { [unowned self] in
            // The client was read; the account switches before the result is stored.
            client.onRead = nil
            client.userId = "incoming"
            cache.invalidate()
        }

        XCTAssertEqual(cache.value, "outgoing", "the read itself returns what it fetched")
        XCTAssertEqual(cache.value, "incoming", "but did not cache it")
    }

    func test_enable_dropsWhatWasCachedBefore() {
        client.userId = "outgoing"
        cache.enable()
        XCTAssertEqual(cache.value, "outgoing")

        client.userId = "incoming"
        cache.enable() // SceytChatUIKit.initialize called again
        XCTAssertEqual(cache.value, "incoming")
    }
}
