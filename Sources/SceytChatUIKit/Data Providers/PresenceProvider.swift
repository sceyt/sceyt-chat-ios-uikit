//
//  PresenceProvider.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import Combine

/// Polls the presence of subscribed users every `subscriptionCheckInterval` seconds and hands
/// each result to every live subscriber of that user.
///
/// Subscriptions are keyed by user *and* owner, so several screens can watch one user at once:
/// the open chat and the channel-list cell behind it each get their own updates, and one of them
/// unsubscribing leaves the other untouched. A user stays polled while at least one owner is
/// subscribed. Owners are held weakly, so a subscription ends on its own when its owner goes away.
public final class PresenceProvider: DataProvider, NSCopying {

    public typealias Handler = (UserPresence) -> Void

    public enum Priority {
        /// Polled while among the `maxCheckableUsersCount` most recently subscribed users.
        case normal
        /// Always polled, outside the cap — for a user whose presence is the point of the
        /// screen, like the peer in the header of an open direct chat.
        case pinned
    }

    public static let `default` = PresenceProvider()

    private var scheduler: Scheduler?
    private var schedulerQueue = DispatchQueue(label: "com.sceytchat.uikit.presence_provider")

    /// Guards `subscriptions` and `recentUserIds`: subscriptions come from main, polls run on
    /// `schedulerQueue`.
    private let lock = NSRecursiveLock()
    /// Subscribers per user, keyed by owner identity.
    private var subscriptions = [UserId: [ObjectIdentifier: Subscription]]()
    /// Subscribed users, most recently subscribed first, so the cap below evicts the users that
    /// subscribed longest ago instead of an arbitrary one that may still be on screen.
    private var recentUserIds = [UserId]()

    private(set) var isStartedChecking = false
    @Atomic private(set) var iSuspended = false

    static var subscriptionCheckInterval = TimeInterval(4)
    /// Must exceed the number of rows a list shows at once: a subscribed user pushed past the cap
    /// keeps its handlers but is no longer polled, so its row silently stops updating.
    /// `.pinned` subscriptions don't count towards it.
    static var maxCheckableUsersCount = 30

    @Published public var presences: Set<UserPresence>?

    public let userProvider = Components.userProvider.init()

    private override init() {
        super.init()
    }

    // MARK: - Subscribing

    public static func subscribe(
        userId: UserId,
        owner: AnyObject,
        priority: Priority = .normal,
        handler: @escaping Handler
    ) {
        `default`.subscribe(userId: userId, owner: owner, priority: priority, handler: handler)
    }

    /// Delivers `userId`'s presence to `handler` on main until `owner` unsubscribes or is
    /// deallocated. Subscribing the same user again with the same owner replaces its handler.
    public func subscribe(
        userId: UserId,
        owner: AnyObject,
        priority: Priority = .normal,
        handler: @escaping Handler
    ) {
        lock.lock()
        subscriptions[userId, default: [:]][ObjectIdentifier(owner)] = Subscription(
            owner: owner,
            handler: handler,
            isPinned: priority == .pinned
        )
        recentUserIds.removeAll { $0 == userId }
        recentUserIds.insert(userId, at: 0)
        let known = userPresences?.first { $0.userId == userId }
        lock.unlock()

        guard !iSuspended else { return }
        // Replay the last known presence to this subscriber only: the row shows it right away
        // instead of the stored (possibly older) value until the next poll.
        if let known {
            deliver(known, ownerId: ObjectIdentifier(owner))
        }
        isStartedChecking = true
        if scheduler == nil {
            startScheduler()
        }
    }

    public static func unsubscribe(userId: UserId, owner: AnyObject) {
        `default`.unsubscribe(userId: userId, owner: owner)
    }

    /// Ends `owner`'s subscription to `userId`; other owners keep theirs.
    public func unsubscribe(userId: UserId, owner: AnyObject) {
        lock.lock()
        removeSubscription(userId: userId, ownerId: ObjectIdentifier(owner))
        lock.unlock()
        stopCheckingIfIdle()
    }

    public static func unsubscribe(owner: AnyObject) {
        `default`.unsubscribe(owner: owner)
    }

    /// Ends every subscription `owner` holds.
    public func unsubscribe(owner: AnyObject) {
        let ownerId = ObjectIdentifier(owner)
        lock.lock()
        for userId in Array(subscriptions.keys) {
            removeSubscription(userId: userId, ownerId: ownerId)
        }
        lock.unlock()
        stopCheckingIfIdle()
    }

    public func presence(userId: UserId) -> UserPresence? {
        userPresences?.first(where: { $0.userId == userId})
    }

    /// The users the next poll asks about: every pinned user, then the most recently subscribed
    /// others up to `maxCheckableUsersCount`.
    var polledUserIds: [UserId] {
        lock.lock()
        defer { lock.unlock() }
        pruneReleasedOwners()
        let pinned = Set(subscriptions.compactMap { userId, subscribers in
            subscribers.values.contains { $0.isPinned } ? userId : nil
        })
        let others = recentUserIds
            .filter { !pinned.contains($0) }
            .prefix(max(0, Self.maxCheckableUsersCount))
        return recentUserIds.filter { pinned.contains($0) } + others
    }

    /// The handlers a presence of `userId` is delivered to.
    func handlers(for userId: UserId) -> [Handler] {
        lock.lock()
        defer { lock.unlock() }
        return (subscriptions[userId] ?? [:]).values
            .filter { $0.owner != nil }
            .map(\.handler)
    }

    // MARK: - Suspending

    public func suspend() {
        isStartedChecking = false
        iSuspended = true
    }

    public func resume() {
        iSuspended = false
        guard !polledUserIds.isEmpty else { return }
        isStartedChecking = true
        request()
    }

    // MARK: - Polling

    private func startScheduler() {
        scheduler = Scheduler
            .new(deadline: .now(),
                 repeating: .seconds(Int(Self.subscriptionCheckInterval)),
                 callback: {[weak self] s in
                self?.request()
        }, callbackQueue: schedulerQueue)
    }

    private func stopCheckingIfIdle() {
        guard !iSuspended, polledUserIds.isEmpty else { return }
        isStartedChecking = false
    }

    private var userPresences: Set<UserPresence>? {
        didSet {
            if let presences = userPresences {
                send(presences: presences)
            }
        }
    }

    private func send(presences: Set<UserPresence>) {
        self.presences = presences
        presences.forEach {
            send(presence: $0)
        }
    }

    /// Hands `presence` to every live subscriber of its user, on main.
    func send(presence: UserPresence) {
        deliver(presence, ownerId: nil)
    }

    /// Handlers are looked up on main, right before the call, so a subscriber that unsubscribed
    /// in the meantime isn't called; and they are called outside the lock, so a handler may
    /// unsubscribe itself.
    private func deliver(_ presence: UserPresence, ownerId: ObjectIdentifier?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let handlers: [Handler]
            if let ownerId {
                self.lock.lock()
                let subscription = self.subscriptions[presence.userId]?[ownerId]
                self.lock.unlock()
                handlers = subscription.flatMap { $0.owner != nil ? [$0.handler] : nil } ?? []
            } else {
                handlers = self.handlers(for: presence.userId)
            }
            handlers.forEach { $0(presence) }
        }
    }

    private func request() {
        guard self.isStartedChecking else { return }
        let userIds = polledUserIds
        guard !userIds.isEmpty else { return }
        getUsers(ids: userIds)
        { [weak self] users in
            guard let self = self,
                  self.isStartedChecking
            else { return }
            self.userPresences = self.merging(users.map { UserPresence(user: $0) })
        }
    }

    /// Cached presences with `fresh` replacing the entries for the same users.
    ///
    /// `UserPresence` hashes by `userId` but its `==` also compares the presence, so a plain
    /// `Set.insert`/`update(with:)` could keep two entries for one user; key by id instead.
    private func merging(_ fresh: [UserPresence]) -> Set<UserPresence> {
        var byId = [UserId: UserPresence]()
        userPresences?.forEach { byId[$0.userId] = $0 }
        fresh.forEach { byId[$0.userId] = $0 }
        return Set(byId.values)
    }

    private func getUsers(
        ids: [UserId],
        completion: @escaping ([User]) -> Void) {
            guard chatClient.connectionState == .connected
            else {
                completion([])
                return
            }
            SceytChatUIKit.shared.chatClient.getUsers(ids: ids) {[weak self] users, error in
                self?.store(users: users ?? [])
                DispatchQueue.main.async {
                    completion(users ?? [])
                }
            }
        }

    public func store(users: [User]) {
        userProvider.store(users: users)
    }

    // MARK: - Subscription bookkeeping (call with `lock` held)

    private func removeSubscription(userId: UserId, ownerId: ObjectIdentifier) {
        subscriptions[userId]?[ownerId] = nil
        if subscriptions[userId]?.isEmpty == true {
            subscriptions[userId] = nil
            recentUserIds.removeAll { $0 == userId }
        }
    }

    /// Drops subscriptions whose owner was deallocated without unsubscribing.
    private func pruneReleasedOwners() {
        for (userId, subscribers) in subscriptions {
            for (ownerId, subscription) in subscribers where subscription.owner == nil {
                removeSubscription(userId: userId, ownerId: ownerId)
            }
        }
    }

    public func copy(with zone: NSZone? = nil) -> Any {
        let presence = PresenceProvider()
        presence.userPresences = self.userPresences
        return presence
    }
}

private final class Subscription {
    weak var owner: AnyObject?
    let handler: PresenceProvider.Handler
    let isPinned: Bool

    init(owner: AnyObject, handler: @escaping PresenceProvider.Handler, isPinned: Bool) {
        self.owner = owner
        self.handler = handler
        self.isPinned = isPinned
    }
}

public struct UserPresence: Hashable {

    public let user: User

    public var presence: Presence {
        user.presence
    }

    public var userId: UserId {
        user.id
    }

    public init(user: User) {
        self.user = user
    }

    public func hash(into hasher: inout Swift.Hasher) {
        hasher.combine(userId)
    }

    public static func == (lhs: UserPresence, rhs: UserPresence) -> Bool {
        lhs.userId == rhs.userId &&
        lhs.presence.state == rhs.presence.state &&
        lhs.presence.status == rhs.presence.status &&
        lhs.presence.lastActiveAt == rhs.presence.lastActiveAt
    }
}
