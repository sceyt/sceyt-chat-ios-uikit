//
//  ChatUser.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import CoreData
import Foundation
import SceytChat

public class ChatUser {
    public var id: UserId
    public var firstName: String?
    public var lastName: String?
    public var avatarUrl: String?
    public var metadata: String?
    public var blocked: Bool
    public var presence: Presence
    public var state: State

    public init(dto: UserDTO) {
        id = dto.id
        firstName = dto.firstName
        lastName = dto.lastName
        avatarUrl = dto.avatarUrl
        metadata = dto.metadata
        blocked = dto.blocked
        state = .init(rawValue: Int(dto.state))!
        presence = .init(state: .init(rawValue: Int(dto.presenceState))!,
                         status: dto.presenceStatus,
                         lastActiveAt: dto.presenceLastActiveAt)
    }

    public init(
        id: UserId,
        firstName: String? = nil,
        lastName: String? = nil,
        avatarUrl: String? = nil,
        metadata: String? = nil,
        blocked: Bool = false,
        presence: ChatUser.Presence = .init(state: .online),
        activityState: ChatUser.State = .active)
    {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.avatarUrl = avatarUrl
        self.metadata = metadata
        self.blocked = blocked
        self.presence = presence
        self.state = activityState
    }

    public convenience init(user: User) {
        self.init(
            id: user.id,
            firstName: user.firstName,
            lastName: user.lastName,
            avatarUrl: user.avatarUrl,
            metadata: user.metadata,
            blocked: user.blocked,
            presence: .init(
                state: .init(rawValue: user.presence.state),
                status: user.presence.status,
                lastActiveAt: user.presence.lastActiveAt),
            activityState: .init(rawValue: user.state)) //MARK: db RENAME
    }
}

public extension ChatUser {
    
    enum State: Int {
        case active
        case inactive
        case deleted

        public init(rawValue: UserState) {
            switch rawValue {
            case .active:
                self = .active
            case .inactive:
                self = .inactive
            case .deleted:
                self = .deleted
            @unknown default:
                self = .active
            }
        }

        public init?(rawValue: Int) {
            switch rawValue {
            case 0:
                self = .active
            case 1:
                self = .inactive
            case 2:
                self = .deleted
            default:
                return nil
            }
        }
    }
}

public extension ChatUser {
    
    struct Presence {
        public var state: State
        public var status: String?
        public var lastActiveAt: Date?
        
        public init(
            state: State,
            status: String? = nil,
            lastActiveAt: Date? = nil
        ) {
            self.state = state
            self.status = status
            self.lastActiveAt = lastActiveAt
        }
        
        public init(presence: SceytChat.Presence) {
            state = .init(rawValue: presence.state)
            status = presence.status
            lastActiveAt = presence.lastActiveAt
        }
    }

    
}

public extension ChatUser.Presence {
    
    enum State: String {
        case offline
        case online
        case invisible
        case away
        case dnd

        public init(rawValue: PresenceState) {
            switch rawValue {
            case .offline:
                self = .offline
            case .online:
                self = .online
            case .invisible:
                self = .invisible
            case .away:
                self = .away
            case .DND:
                self = .dnd
            @unknown default:
                self = .offline
            }
        }

        public init?(rawValue: Int) {
            switch rawValue {
            case 0:
                self = .offline
            case 1:
                self = .online
            case 2:
                self = .invisible
            case 3:
                self = .away
            case 4:
                self = .dnd
            default:
                return nil
            }
        }
        
        public var presenceState: PresenceState {
            switch self {
            case .offline:
                return .offline
            case .online:
                return .online
            case .invisible:
                return .invisible
            case .away:
                return .away
            case .dnd:
                return .DND
            @unknown default:
                return .offline
            }
        }
    }
}
 
infix operator !~= : ComparisonPrecedence

extension ChatUser: Equatable {
    
    public static func == (lhs: ChatUser, rhs: ChatUser) -> Bool {
        lhs.id == rhs.id
    }
    
    public static func ~= (lhs: ChatUser, rhs: ChatUser) -> Bool {
        lhs == rhs &&
        lhs.firstName == rhs.firstName &&
        lhs.lastName == rhs.lastName &&
        lhs.avatarUrl == rhs.avatarUrl &&
        lhs.metadata == rhs.metadata &&
        lhs.blocked == rhs.blocked &&
        lhs.state == rhs.state &&
        lhs.presence.state == rhs.presence.state &&
        lhs.presence.status == rhs.presence.status &&
        lhs.presence.lastActiveAt == rhs.presence.lastActiveAt
    }
    
    public static func !~= (lhs: ChatUser, rhs: ChatUser) -> Bool {
         !(lhs ~= rhs)
    }
}
