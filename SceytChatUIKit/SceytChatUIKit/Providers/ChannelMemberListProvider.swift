//
//  ChannelMemberListProvider.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class ChannelMemberListProvider: Provider {

    public static var queryLimit = UInt(10)
    public static var queryOrder = MemberListOrder.firstName
    public static var queryType = MemberListQueryType.all

    let channelId: ChannelId

    public required init(channelId: ChannelId) {
        self.channelId = channelId
        super.init()
    }

    open lazy var query: MemberListQuery = {
        .Builder(channelId: channelId)
        .order(Self.queryOrder)
        .limit(Self.queryLimit)
        .queryType(Self.queryType)
        .build()
    }()

    open func loadMembers() {
        if !query.hasNext || query.loading {
            return
        }
        query.loadNext { _, members, _ in
            guard let members = members
            else { return }
            self.store(members: members)
        }
    }

    open func store(members: [Member]) {
        database.write {
            $0.createOrUpdate(
                members: members, channelId: self.channelId)
        } completion: { error in
            debugPrint(error as Any)
        }
    }
}
