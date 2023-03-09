//
//  ChatUser.swift
//  SceytChatUIKit
//

import CoreData
import Foundation
import SceytChat

public class ChatUser {
    public var id: UserId
    public var firstName: String?
    public var lastName: String?
    public var avatarUrl: URL?
    public var metadata: String?
    public var blocked: Bool
    public var presence: Presence
    public var activityState: ActivityState

    public init(dto: UserDTO) {
        id = dto.id
        firstName = dto.firstName
        lastName = dto.lastName
        avatarUrl = dto.avatarUrl
        metadata = dto.metadata
        blocked = dto.blocked
        activityState = .init(rawValue: Int(dto.activityState))!
        presence = .init(state: .init(rawValue: Int(dto.presenceState))!,
                         status: dto.presenceStatus,
                         lastActiveAt: dto.presenceLastActiveAt)
    }

    public init(
        id: UserId,
        firstName: String? = nil,
        lastName: String? = nil,
        avatarUrl: URL? = nil,
        metadata: String? = nil,
        blocked: Bool = false,
        presence: ChatUser.Presence = .init(state: .online),
        activityState: ChatUser.ActivityState = .active)
    {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.avatarUrl = avatarUrl
        self.metadata = metadata
        self.blocked = blocked
        self.presence = presence
        self.activityState = activityState
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
            activityState: .init(rawValue: user.activityState))
    }
}

public extension ChatUser {
    enum ActivityState {
        case active
        case inactive
        case deleted

        public init(rawValue: UserActivityState) {
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
    }

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
    }
}

extension ChatUser: Equatable {
    
    public static func == (lhs: ChatUser, rhs: ChatUser) -> Bool {
        lhs.id == rhs.id
    }
    
}
