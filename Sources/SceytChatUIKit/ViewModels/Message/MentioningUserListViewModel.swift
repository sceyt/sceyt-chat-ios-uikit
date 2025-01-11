//
//  MentioningUserListViewModel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import Combine

open class MentioningUserListViewModel: NSObject {

    public let channelId: ChannelId
    public let provider: ChannelMemberListProvider
    public lazy var defaultPredicate = NSPredicate(format: "channelId == %lld AND user.id != %@", channelId, SceytChatUIKit.shared.currentUserId ?? "")
    
    @Published public var event: Event?
    public var isSearching = false

    public private(set) lazy var memberObserver: DatabaseObserver<MemberDTO, ChatChannelMember> = {
        DatabaseObserver<MemberDTO, ChatChannelMember>(
            request: MemberDTO.fetchRequest()
                .fetch(predicate: defaultPredicate)
                .sort(descriptors: [
                    .init(keyPath: \MemberDTO.user?.firstName, ascending: false),
                    .init(keyPath: \MemberDTO.user?.lastName, ascending: false),
                    .init(keyPath: \MemberDTO.user?.id, ascending: false)
                ]),
            context: SceytChatUIKit.shared.database.viewContext
        ) { $0.convert() }
    }()

    public required init(channelId: ChannelId) {
        self.channelId = channelId
        provider = Components.channelMemberListProvider.init(channelId: channelId)
        provider.queryLimit = 50
        super.init()
    }

    open func startDatabaseObserver() {
        memberObserver.onDidChange = {[weak self] in
            self?.onDidChangeEvent(items: $0)
        }
        do {
            try memberObserver.startObserver()
        } catch {
            logger.errorIfNotNil(error, "observer.startObserver")
        }
    }

    open func onDidChangeEvent(items: DBChangeItemPaths) {
        if isSearching {
            event = .reload
        } else {
            event = .change(items)
        }
    }

    open func member(at indexPath: IndexPath) -> ChatChannelMember? {
        memberObserver.item(at: indexPath)
    }

    open var numberOfMembers: Int {
        memberObserver.items.count
    }

    open func loadMembers() {
        provider.loadMembers()
    }
    
    open func setPredicate(query: String) {
        isSearching = true
        if query.isEmpty {
            try? memberObserver.update(predicate: defaultPredicate)
        } else {
            let firstName: String
            let lastName: String?
            if let index = query.firstIndex(of: " ") {
                var _index = index
                query.formIndex(&_index, offsetBy: 1)
                firstName = String(query[query.startIndex ..< index])
                lastName = String(query[_index ..< query.endIndex])
            } else {
                firstName = query
                lastName = nil
            }
            var predicate = defaultPredicate.and(predicate: .init(format: "user.firstName BEGINSWITH[c] %@", firstName))
            if let lastName, !lastName.isEmpty {
                predicate = predicate.and(predicate: .init(format: "user.lastName BEGINSWITH[c] %@", lastName))
            }
            try? memberObserver.update(predicate: predicate)
        }
        isSearching = false
    }
}

public extension MentioningUserListViewModel {

    enum Event {
        case change(DBChangeItemPaths)
        case reload
    }
}
