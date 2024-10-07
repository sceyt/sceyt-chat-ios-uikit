//
//  ChatChannelMember.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import CoreData

public class ChatChannelMember: ChatUser {

    public let roleName: String?

    public init(dto: MemberDTO) {
        roleName = dto.role?.name
        if let user = dto.user {
            super.init(dto: user)
        } else {
            super.init(id: "")
        }
    }
    
    public init(
        id: UserId,
        roleName: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        username: String? = nil,
        avatarUrl: String? = nil,
        metadataDict: [String: String]? = nil,
        blocked: Bool = false,
        presence: ChatUser.Presence = .init(state: .online),
        activityState: ChatUser.State = .active
    ) {
        self.roleName = roleName
        super.init(
            id: id,
            firstName: firstName,
            lastName: lastName,
            username: username,
            avatarUrl: avatarUrl,
            metadataDict: metadataDict,
            blocked: blocked,
            presence: presence,
            activityState: activityState
        )
    }
    
    public convenience init(
        user: ChatUser,
        roleName: String? = nil
    ) {
        self.init(
            id: user.id,
            roleName: roleName,
            firstName: user.firstName,
            lastName: user.lastName,
            username: user.username,
            avatarUrl: user.avatarUrl,
            metadataDict: user.metadataDict,
            blocked: user.blocked,
            presence: user.presence,
            activityState: user.state
        )
    }
    
    public convenience init(member: Member) {
        self.init(
            id: member.id,
            roleName: member.role,
            firstName: member.firstName,
            lastName: member.lastName,
            username: member.username,
            avatarUrl: member.avatarUrl,
            metadataDict: member.metadataMap,
            blocked: member.blocked,
            presence: .init(
                state: .init(rawValue: member.presence.state),
                status: member.presence.status,
                lastActiveAt: member.presence.lastActiveAt),
            activityState: .init(rawValue: member.state))
        //MARK: db RENAME
    }
    
    public convenience init(user: User, roleName: String) {
        self.init(
            id: user.id,
            roleName: roleName,
            firstName: user.firstName,
            lastName: user.lastName,
            username: user.username,
            avatarUrl: user.avatarUrl,
            metadataDict: user.metadataMap,
            blocked: user.blocked,
            presence: .init(
                state: .init(rawValue: user.presence.state),
                status: user.presence.status,
                lastActiveAt: user.presence.lastActiveAt),
            activityState: .init(rawValue: user.state))
    }
}
