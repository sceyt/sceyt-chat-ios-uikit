//
//  ChannelMemberListProvider.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class ChannelMemberListProvider: Provider {

    public var queryLimit = SceytChatUIKit.shared.config.queryLimits.channelMemberListQueryLimit
    public var queryOrder = MemberListOrder.username
    public var queryType = MemberListQueryType.all

    let channelId: ChannelId
    private var loadedPage: Int = 0
    private var lastLoadedMemberId: UserId?
    public required init(channelId: ChannelId) {
        self.channelId = channelId
        super.init()
    }

    open lazy var query: MemberListQuery = {
        .Builder(channelId: channelId)
        .order(queryOrder)
        .limit(queryLimit)
        .queryType(queryType)
        .build()
    }()

    open func loadMembers() {
        if !query.hasNext || query.loading {
            return
        }
        query.loadNext { _, members, _ in
            guard let members = members,
                  !members.isEmpty
            else { return }
            self.loadedPage += 1
            self.store(members: members)
            self.lastLoadedMemberId = members.max(by: {
                $0.id < $1.id
            })?.id
        }
    }

    open func store(members: [Member]) {
        let predicate = deleteMembersPredicate(members: members)
        database.write {
            if let predicate {
                $0.deleteMembers(predicate: predicate)
            }
            $0.createOrUpdate(
                members: members, channelId: self.channelId)
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
        }
    }
    
    private func deleteMembersPredicate(members: [Member]) -> NSPredicate? {
        if !members.isEmpty {
            let ids = members.map { $0.id }
            if members.count < queryLimit {
                if let lastLoadedMemberId {
                    return NSPredicate(format: "user.id > %@ AND (channelId == %lld) AND (NOT (user.id IN %@))", lastLoadedMemberId, channelId, ids)
                } else {
                    return NSPredicate(format: "(channelId == %lld) AND (NOT (user.id IN %@))", channelId, ids)
                }
                
            }
            if let lastLoadedMemberId {
                return NSPredicate(format: "(user.id > %@ AND user.id <= %@) AND (channelId == %lld) AND (NOT (user.id IN %@))", lastLoadedMemberId, ids.last!, channelId, ids)
            } else {
                let max = ids.max() ?? ids.last!
                return NSPredicate(format: "(user.id <= %@) AND (channelId == %lld) AND (NOT (user.id IN %@))", max, channelId, ids)
            }
            
        }
        return nil
    }
}
