//
//  ChatChannelMember.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat
import CoreData

public class ChatChannelMember: ChatUser {

    public let roleName: String?

    public init(dto: MemberDTO) {
        roleName = dto.role?.name
        super.init(dto: dto.user!)
    }
    
    public init(
        id: UserId,
        roleName: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        avatarUrl: URL? = nil,
        metadata: String? = nil,
        blocked: Bool = false,
        presence: ChatUser.Presence = .init(state: .online),
        activityState: ChatUser.ActivityState = .active
    ) {
        self.roleName = roleName
        super.init(
            id: id,
            firstName: firstName,
            lastName: lastName,
            avatarUrl: avatarUrl,
            metadata: metadata,
            blocked: blocked,
            presence: presence,
            activityState: activityState
        )
    }
    
    public convenience init(member: Member) {
        self.init(
            id: member.id,
            roleName: member.role,
            firstName: member.firstName,
            lastName: member.lastName,
            avatarUrl: member.avatarUrl,
            metadata: member.metadata,
            blocked: member.blocked,
            presence: .init(
                state: .init(rawValue: member.presence.state),
                status: member.presence.status,
                lastActiveAt: member.presence.lastActiveAt),
            activityState: .init(rawValue: member.activityState))
    }
}
