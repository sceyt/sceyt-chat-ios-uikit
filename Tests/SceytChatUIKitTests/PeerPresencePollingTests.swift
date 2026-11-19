//
//  PeerPresencePollingTests.swift
//  SceytChatUIKitTests
//
//  Bug: with a direct chat open, the peer's "last seen" in the header stopped updating
//  (e.g. the peer opens the chat from a push and comes online) until the user went back
//  to the channel list and reopened the chat.
//
//  The chat header only changes when `ChannelViewModel.subscribeToPeerPresence`'s handler
//  runs. `PresenceProvider` polls subscribed users every `subscriptionCheckInterval`
//  (4 s) and hands each result to the subscribers of that user. These tests pin what must
//  hold for the user of an open direct chat:
//
//  1. it is polled every 4 seconds while the chat is open;
//  2. another screen subscribing the same user — the channel list behind the chat
//     re-binds that channel's cell as soon as a message is sent — must not take the
//     chat's updates away (it used to: one handler slot per user, last writer won);
//  3. another screen unsubscribing the same user must not stop polling it or silence
//     the chat;
//  4. the 30-user polling cap must not evict it because other rows subscribed later.
//

import XCTest
import SceytChat
@testable import SceytChatUIKit

final class PeerPresencePollingTests: XCTestCase {

    private let provider = PresenceProvider.default
    private var owners = [AnyObject]()

    /// Stands in for the open chat's `ChannelViewModel`.
    private let chat = Owner()
    /// Stands in for the channel-list cell showing the same channel behind the chat.
    private let listCell = Owner()

    override func tearDown() {
        ([chat, listCell] + owners).forEach { provider.unsubscribe(owner: $0) }
        owners = []
        super.tearDown()
    }

    // MARK: - Helpers

    private final class Owner {}

    private func makeOwner() -> Owner {
        let owner = Owner()
        owners.append(owner)
        return owner
    }

    /// A unique id per test: `PresenceProvider.default` is a process-wide singleton.
    private func makeId(_ label: String) -> UserId {
        "\(label)-\(UUID().uuidString)"
    }

    /// `User` has no public initializer; build one through the ObjC runtime.
    private func makeUser(id: UserId) -> User {
        let type = NSClassFromString("SCTUser") as! NSObject.Type
        let user = type.init()
        user.setValue(id, forKey: "id")
        return user as! User
    }

    /// Feeds one poll result for `userId` through the provider's real delivery path and
    /// waits until it reached the subscribers (delivery is async on main).
    private func deliverPollResult(for userId: UserId) {
        provider.send(presence: UserPresence(user: makeUser(id: userId)))
        drainMainQueue()
    }

    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }

    // MARK: - 1. Polled every 4 seconds while the chat is open

    func test_openDirectChat_peerIsPolledEveryFourSeconds() {
        let peer = makeId("peer")

        provider.subscribe(userId: peer, owner: chat, priority: .pinned) { _ in }

        XCTAssertEqual(PresenceProvider.subscriptionCheckInterval, 4)
        XCTAssertTrue(provider.isStartedChecking)
        XCTAssertTrue(provider.polledUserIds.contains(peer),
                      "The open chat's peer must be in the 4-second poll")
    }

    // MARK: - 2. Channel list re-subscribing the same peer

    /// Sending a message moves the channel to the top of the list behind the chat; its
    /// cell gets new `data`, and `ChannelCell.subscribeForPresence` subscribes the peer
    /// again.
    func test_channelListCellSubscribingSamePeer_chatStillReceivesPresenceUpdates() {
        let peer = makeId("peer")
        var chatHeaderUpdates = 0
        var listCellUpdates = 0

        provider.subscribe(userId: peer, owner: chat, priority: .pinned) { _ in chatHeaderUpdates += 1 }
        provider.subscribe(userId: peer, owner: listCell) { _ in listCellUpdates += 1 }

        deliverPollResult(for: peer)

        XCTAssertEqual(chatHeaderUpdates, 1,
                       "The open chat's header must still get the peer's presence after the list cell subscribes the same user")
        XCTAssertEqual(listCellUpdates, 1,
                       "The list cell must get it too")
    }

    // MARK: - 3. Another screen unsubscribing the same peer

    /// `UserCell`, `SelectableUserCell`, `CallChatMemberCell` and `VideoPostMentionCell`
    /// unsubscribe from inside their first presence callback; `CreateChatContactCell`
    /// on reuse.
    func test_otherScreenUnsubscribingSamePeer_peerStaysPolled() {
        let peer = makeId("peer")
        let contactRow = makeOwner()

        provider.subscribe(userId: peer, owner: chat, priority: .pinned) { _ in }
        provider.subscribe(userId: peer, owner: contactRow) { _ in }
        provider.unsubscribe(userId: peer, owner: contactRow)

        XCTAssertTrue(provider.polledUserIds.contains(peer),
                      "The open chat's peer must keep being polled after another screen unsubscribes it")
    }

    func test_otherScreenUnsubscribingSamePeer_chatStillReceivesPresenceUpdates() {
        let peer = makeId("peer")
        let contactRow = makeOwner()
        var chatHeaderUpdates = 0

        provider.subscribe(userId: peer, owner: chat, priority: .pinned) { _ in chatHeaderUpdates += 1 }
        provider.subscribe(userId: peer, owner: contactRow) { _ in }
        provider.unsubscribe(userId: peer, owner: contactRow)

        deliverPollResult(for: peer)

        XCTAssertEqual(chatHeaderUpdates, 1,
                       "The open chat must still get the peer's presence after another screen unsubscribes it")
    }

    /// The one-shot cells unsubscribe from inside the handler, mid-delivery.
    func test_subscriberUnsubscribingInsideItsHandler_otherSubscribersStillGetTheUpdate() {
        let peer = makeId("peer")
        let oneShotRow = makeOwner()
        var chatHeaderUpdates = 0
        var oneShotUpdates = 0

        provider.subscribe(userId: peer, owner: oneShotRow) { [provider] _ in
            oneShotUpdates += 1
            provider.unsubscribe(userId: peer, owner: oneShotRow)
        }
        provider.subscribe(userId: peer, owner: chat, priority: .pinned) { _ in chatHeaderUpdates += 1 }

        deliverPollResult(for: peer)
        deliverPollResult(for: peer)

        XCTAssertEqual(oneShotUpdates, 1)
        XCTAssertEqual(chatHeaderUpdates, 2)
        XCTAssertTrue(provider.polledUserIds.contains(peer))
    }

    // MARK: - 4. Polling cap

    /// Only the `maxCheckableUsersCount` most recently subscribed users are polled. Rows
    /// subscribing after the chat opened (list behind it, members, contacts) used to push
    /// the chat's peer out.
    func test_manyLaterSubscriptions_openChatPeerIsNotEvictedFromPolling() {
        let peer = makeId("peer")
        provider.subscribe(userId: peer, owner: chat, priority: .pinned) { _ in }

        let row = makeOwner()
        for i in 0..<PresenceProvider.maxCheckableUsersCount {
            provider.subscribe(userId: makeId("row\(i)"), owner: row) { _ in }
        }

        XCTAssertTrue(provider.polledUserIds.contains(peer),
                      "The open chat's peer must stay in the 4-second poll regardless of the cap")
    }

    func test_cap_stillLimitsNormalSubscriptions() {
        let row = makeOwner()
        let oldest = makeId("oldest")
        provider.subscribe(userId: oldest, owner: row) { _ in }
        for i in 0..<PresenceProvider.maxCheckableUsersCount {
            provider.subscribe(userId: makeId("row\(i)"), owner: row) { _ in }
        }

        XCTAssertFalse(provider.polledUserIds.contains(oldest))
    }

    // MARK: - Ownership

    func test_sameOwnerResubscribing_replacesItsHandler() {
        let peer = makeId("peer")
        var firstHandlerUpdates = 0
        var secondHandlerUpdates = 0

        provider.subscribe(userId: peer, owner: listCell) { _ in firstHandlerUpdates += 1 }
        provider.subscribe(userId: peer, owner: listCell) { _ in secondHandlerUpdates += 1 }

        deliverPollResult(for: peer)

        XCTAssertEqual(firstHandlerUpdates, 0)
        XCTAssertEqual(secondHandlerUpdates, 1)
    }

    /// A chat that closes without unsubscribing must not stay polled forever.
    func test_deallocatedOwner_isNoLongerPolledOrNotified() {
        let peer = makeId("peer")
        var updates = 0
        var owner: Owner? = Owner()
        provider.subscribe(userId: peer, owner: owner!, priority: .pinned) { _ in updates += 1 }
        XCTAssertTrue(provider.polledUserIds.contains(peer))

        owner = nil

        XCTAssertFalse(provider.polledUserIds.contains(peer))
        deliverPollResult(for: peer)
        XCTAssertEqual(updates, 0)
    }

    func test_unsubscribeOwner_endsAllItsSubscriptions() {
        let peer = makeId("peer")
        let other = makeId("other")
        provider.subscribe(userId: peer, owner: chat, priority: .pinned) { _ in }
        provider.subscribe(userId: other, owner: chat) { _ in }

        provider.unsubscribe(owner: chat)

        XCTAssertFalse(provider.polledUserIds.contains(peer))
        XCTAssertFalse(provider.polledUserIds.contains(other))
        XCTAssertTrue(provider.handlers(for: peer).isEmpty)
    }

    func test_unsubscribeOnlySubscriber_removesPeerFromPollAndHandlers() {
        let peer = makeId("peer")
        provider.subscribe(userId: peer, owner: listCell) { _ in }
        XCTAssertTrue(provider.polledUserIds.contains(peer))
        XCTAssertEqual(provider.handlers(for: peer).count, 1)

        provider.unsubscribe(userId: peer, owner: listCell)

        XCTAssertFalse(provider.polledUserIds.contains(peer))
        XCTAssertTrue(provider.handlers(for: peer).isEmpty)
    }
}
