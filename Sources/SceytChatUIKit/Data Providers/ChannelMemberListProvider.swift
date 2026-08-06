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

    /// Loads owners, admins and other members.
    /// - Parameter completion: Called once all three role loads have finished, with the members
    /// loaded and stored across all of them and the first error, if any.
    open func loadMembers(completion: (([Member]?, Error?) -> Void)? = nil) {
        guard let completion else {
            loadOwners()
            loadAdmins()
            loadOthers()
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var loadedMembers = [Member]()
        var firstError: Error?

        let accumulate: ([Member]?, Error?) -> Void = { members, error in
            lock.lock()
            if let members {
                loadedMembers.append(contentsOf: members)
            }
            if firstError == nil {
                firstError = error
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        loadOwners(completion: accumulate)
        group.enter()
        loadAdmins(completion: accumulate)
        group.enter()
        loadOthers(completion: accumulate)

        group.notify(queue: .main) {
            completion(loadedMembers, firstError)
        }
    }

    /// Loads the next page of channel owners.
    /// - Parameter completion: Called with the loaded members and the error, if any. Called with
    /// `(nil, nil)` when the load is skipped because a load is already in progress or there is
    /// nothing more to load.
    open func loadOwners(completion: (([Member]?, Error?) -> Void)? = nil) {
        guard !ownerLoading, ownerHasNext, !ownerQuery.loading else {
            completion?(nil, nil)
            return
        }

        ownerLoading = true
        ownerQuery.loadNext { [weak self] _, members, error in
            guard let self = self else {
                completion?(members, error)
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
                completion?(members, error)
                return
            }

            self.store(members: members) { storeError in
                completion?(members, error ?? storeError)
            }
        }
    }

    /// Loads the next page of channel admins.
    /// - Parameter completion: Called with the loaded members and the error, if any. Called with
    /// `(nil, nil)` when the load is skipped because a load is already in progress or there is
    /// nothing more to load.
    open func loadAdmins(completion: (([Member]?, Error?) -> Void)? = nil) {
        guard !adminLoading, adminHasNext, !adminQuery.loading else {
            completion?(nil, nil)
            return
        }

        adminLoading = true
        adminQuery.loadNext { [weak self] _, members, error in
            guard let self = self else {
                completion?(members, error)
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
                completion?(members, error)
                return
            }

            self.store(members: members) { storeError in
                completion?(members, error ?? storeError)
            }
        }
    }

    /// Loads the next page of the remaining channel members (participants or subscribers).
    /// - Parameter completion: Called with the loaded members and the error, if any. Called with
    /// `(nil, nil)` when the load is skipped because a load is already in progress or there is
    /// nothing more to load.
    open func loadOthers(completion: (([Member]?, Error?) -> Void)? = nil) {
        guard !othersLoading, othersHasNext, !othersQuery.loading else {
            completion?(nil, nil)
            return
        }

        othersLoading = true
        othersQuery.loadNext { [weak self] _, members, error in
            guard let self = self else {
                completion?(members, error)
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
                completion?(members, error)
                return
            }

            self.store(members: members) { storeError in
                completion?(members, error ?? storeError)
            }
        }
    }

    open func store(members: [Member], completion: ((Error?) -> Void)? = nil) {
        database.write { [weak self] context in
            guard let self else { return }
            context.createOrUpdate(members: members, channelId: self.channelId)
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
            completion?(error)
        }
    }
}
