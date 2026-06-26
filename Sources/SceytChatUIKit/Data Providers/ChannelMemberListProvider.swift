//
//  ChannelMemberListProvider.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class ChannelMemberListProvider: DataProvider {

    public var queryLimit = SceytChatUIKit.shared.config.queryLimits.channelMemberListQueryLimit
    public var queryOrder = MemberListOrder.username
    public var queryType = MemberListQueryType.all

    let channelId: ChannelId

    // Separate loading states for each role
    private var ownerLoading = false
    private var adminLoading = false
    private var othersLoading = false

    // Track if there are more items to load for each role
    private var ownerHasNext = true
    private var adminHasNext = true
    private var othersHasNext = true

    // Separate queries for each role type
    private lazy var ownerQuery: MemberListQuery = {
        MemberListQuery.Builder(channelId: channelId)
            .order(queryOrder)
            .limit(UInt(queryLimit))
            .queryRole(SceytChatUIKit.shared.config.memberRolesConfig.owner)
            .build()
    }()

    private lazy var adminQuery: MemberListQuery = {
        MemberListQuery.Builder(channelId: channelId)
            .order(queryOrder)
            .limit(UInt(queryLimit))
            .queryRole(SceytChatUIKit.shared.config.memberRolesConfig.admin)
            .build()
    }()

    private lazy var othersQuery: MemberListQuery = {
        let channelType = try? database.read {
            ChannelDTO.fetch(id: self.channelId, context: $0)?.type
        }.get()
        let role = channelType == SceytChatUIKit.shared.config.channelTypesConfig.broadcast
            ? SceytChatUIKit.shared.config.memberRolesConfig.subscriber
            : SceytChatUIKit.shared.config.memberRolesConfig.participant
        return MemberListQuery.Builder(channelId: channelId)
            .order(queryOrder)
            .limit(UInt(queryLimit))
            .queryRole(role)
            .build()
    }()

    public required init(channelId: ChannelId) {
        self.channelId = channelId
        super.init()
    }

    open lazy var query: MemberListQuery = {
        .Builder(channelId: channelId)
        .order(queryOrder)
        .limit(UInt(queryLimit))
        .queryType(queryType)
        .build()
    }()

    open func loadMembers() {
        loadOwners()
        loadAdmins()
        loadOthers()
    }

    open func loadOwners() {
        guard !ownerLoading, ownerHasNext, !ownerQuery.loading else {
            return
        }

        ownerLoading = true
        ownerQuery.loadNext { [weak self] _, members, _ in
            guard let self = self else {
                return
            }

            let count = members?.count ?? 0
            self.ownerLoading = false

            // If we received fewer members than requested, there are no more to load
            if count < self.queryLimit {
                self.ownerHasNext = false
            }

            guard let members = members, !members.isEmpty else {
                self.ownerHasNext = false
                return
            }

            self.store(members: members)
        }
    }

    open func loadAdmins() {
        guard !adminLoading, adminHasNext, !adminQuery.loading else {
            return
        }

        adminLoading = true
        adminQuery.loadNext { [weak self] _, members, _ in
            guard let self = self else {
                return
            }

            let count = members?.count ?? 0
            self.adminLoading = false

            // If we received fewer members than requested, there are no more to load
            if count < self.queryLimit {
                self.adminHasNext = false
            }

            guard let members = members, !members.isEmpty else {
                self.adminHasNext = false
                return
            }

            self.store(members: members)
        }
    }

    open func loadOthers() {
        guard !othersLoading, othersHasNext, !othersQuery.loading else {
            return
        }

        othersLoading = true
        othersQuery.loadNext { [weak self] _, members, _ in
            guard let self = self else {
                return
            }

            let count = members?.count ?? 0
            self.othersLoading = false

            // If we received fewer members than requested, there are no more to load
            if count < self.queryLimit {
                self.othersHasNext = false
            }

            guard let members = members, !members.isEmpty else {
                self.othersHasNext = false
                return
            }

            self.store(members: members)
        }
    }

    open func store(members: [Member]) {
        database.write { [weak self] context in
            guard let self else { return }
            context.createOrUpdate(members: members, channelId: self.channelId)
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }
}
