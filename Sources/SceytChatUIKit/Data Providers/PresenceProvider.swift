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

public final class PresenceProvider: DataProvider, NSCopying {
    
    public typealias Handler = (UserPresence) -> Void
    
    public static let `default` = PresenceProvider()
    
    private var scheduler: Scheduler?
    private var schedulerQueue = DispatchQueue(label: "com.sceytchat.uikit.presence_provider")
    /// Polled users, most recently subscribed first, so the cap below evicts the users that
    /// subscribed longest ago instead of an arbitrary `Set` element that may still be on screen.
    @Atomic private var userIds = [UserId]()
    private(set) var isStartedChecking = false
    @Atomic private(set) var iSuspended = false
    @Atomic private var cache = Cache<UserId, Handler>()
    
    static var subscriptionCheckInterval = TimeInterval(4)
    /// Must exceed the number of rows a list shows at once: a subscribed user pushed past the cap
    /// keeps its handler but is no longer polled, so its row silently stops updating.
    static var maxCheckableUsersCount = 30

    @Published public var presences: Set<UserPresence>?
    
    public let userProvider = Components.userProvider.init()
    
    private override init() {
        super.init()
    }
    
    public static func subscribe(userId: UserId, handler: @escaping Handler) {
        `default`.subscribe(userId: userId, handler: handler)
    }
    
    public func subscribe(userId: UserId, handler: @escaping Handler) {
        cache[userId] = handler
        start(userIds: [userId])
    }
    
    public static func unsubscribe(userId: UserId) {
        `default`.unsubscribe(userId: userId)
    }
    
    public func unsubscribe(userId: UserId) {
        cache[userId] = nil
        stop(userIds: [userId])
    }
    
    public func presence(userId: UserId) -> UserPresence? {
        userPresences?.first(where: { $0.userId == userId})
    }
    
    public func start(userIds: [UserId]) {
        guard Self.maxCheckableUsersCount >= 1
        else { return }
        
        let checkable = Array(userIds.prefix(Self.maxCheckableUsersCount))
        _userIds.mutate { current in
            current.removeAll { checkable.contains($0) }
            current = Array((checkable + current).prefix(Self.maxCheckableUsersCount))
        }
        guard !iSuspended else { return }
        if let presences = userPresences {
            let existing = presences.filter { checkable.contains($0.userId) }
            if !existing.isEmpty {
                send(presences: existing)
            }
        }
        
        isStartedChecking = true
        if scheduler == nil {
            startScheduler()
        }
    }
    
    public func stop(userIds: [UserId]) {
        _userIds.mutate { current in
            current.removeAll { userIds.contains($0) }
        }
        guard !iSuspended else { return }
        // Keep the last known presence of stopped users: when the row comes back, `start` replays
        // it immediately instead of the row showing the stored (possibly older) value until the
        // next poll.
        if self.userIds.isEmpty {
            isStartedChecking = false
        }
    }
    
    public func suspend() {
        isStartedChecking = false
        iSuspended = true
    }
    
    public func resume() {
        iSuspended = false
        guard !userIds.isEmpty else { return }
        isStartedChecking = true
        request()
    }
    
    private func startScheduler() {
        scheduler = Scheduler
            .new(deadline: .now(),
                 repeating: .seconds(Int(Self.subscriptionCheckInterval)),
                 callback: {[weak self] s in
                self?.request()
        }, callbackQueue: schedulerQueue)
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
    
    private func send(presence: UserPresence) {
        DispatchQueue.main.async {
            if let handler = self.cache[presence.userId] {
                handler(presence)
            }
        }
    }
    
    private func request() {
        guard self.isStartedChecking else { return }
        getUsers(ids: Array(self.userIds))
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
    
    private func request(userIds: [UserId]) {
        guard self.isStartedChecking else { return }
        getUsers(ids: userIds)
        { [weak self] users in
            guard let self = self,
                  self.isStartedChecking
            else { return }
            
            self.userPresences = self.merging(users.map { UserPresence(user: $0) })
        }
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
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let presence = PresenceProvider()
        presence.userPresences = self.userPresences
        return presence
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
