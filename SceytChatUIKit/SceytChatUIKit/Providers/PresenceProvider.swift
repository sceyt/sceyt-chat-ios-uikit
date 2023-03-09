//
//  PresenceProvider.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat
import Combine

public final class PresenceProvider: Provider, NSCopying {
    
    public typealias Handler = (UserPresence) -> Void
    
    public static let `default` = PresenceProvider()
    
    @Atomic private var userIds = Set<UserId>()
    private(set) var isStartedChecking = false
    private var cache = Cache<UserId, Handler>()
    
    static var subscriptionCheckInterval = TimeInterval(4)
    static var maxCheckableUsersCount = 10

    @Published public var presences: Set<UserPresence>?
    
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
        
        let checkable = userIds.prefix(Self.maxCheckableUsersCount)
        let filtered = checkable.filter { !self.userIds.contains($0) }
        
        let newIds = (filtered + self.userIds)
            .prefix(Self.maxCheckableUsersCount)
        self.userIds = Set(newIds)
        
        if let presences = userPresences {
            let existing = presences.filter { checkable.contains($0.userId) }
            if !existing.isEmpty {
                send(presences: existing)
            }
        }
        
        if !isStartedChecking {
            isStartedChecking = true
            request()
        } else {
            request(userIds: filtered)
        }
    }
    
    public func stop() {
        isStartedChecking = false
    }
    
    public func stop(userIds: [UserId]) {
        userIds.forEach { self.userIds.remove($0) }
        if let filtered = userPresences?.filter({ userIds.contains($0.userId) }) {
            userPresences?.subtract(filtered)
        }
      
        if self.userIds.isEmpty {
            isStartedChecking = false
        }
    }
    
    public func resume() {
        guard !userIds.isEmpty else { return }
        isStartedChecking = true
        request()
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
        if let handler = cache[presence.userId] {
            DispatchQueue.main.async {
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
            self.userPresences = Set(
                users.map { UserPresence(user: $0) }
            )
            self.didFinishRequest()
        }
    }
    
    private func request(userIds: [UserId]) {
        guard self.isStartedChecking else { return }
        getUsers(ids: userIds)
        { [weak self] users in
            guard let self = self,
                  self.isStartedChecking
            else { return }
            
            if self.userPresences == nil {
                self.userPresences = .init()
            }
            users.forEach {
                let presence = UserPresence(user: $0)
                self.send(presence: presence)
                if self.userPresences!.update(with: presence) == nil {
                    self.userPresences!.insert(presence)
                }
            }
            
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
            chatClient.getUsers(ids: ids) {[weak self] users, error in
                self?.store(users: users ?? [])
                DispatchQueue.main.async {
                    completion(users ?? [])
                }
            }
        }
    
    public func store(users: [User]) {
        database.write {
            $0.createOrUpdate(users: users)
        }
    }
    
    private func didFinishRequest() {
        DispatchQueue.global(qos: .background)
            .asyncAfter(deadline: .now() + Self.subscriptionCheckInterval) { [weak self] in
                if self?.isStartedChecking == true {
                    self?.request()
                }
            }
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
        lhs.userId == rhs.userId
    }
}
