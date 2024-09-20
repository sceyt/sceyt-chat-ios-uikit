//
//  ChannelMemberListViewModel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import Combine

open class ChannelMemberListViewModel: NSObject {

    public let channel: ChatChannel
    public let filterMembersByRole: String?
    public let provider: ChannelMemberListProvider
    public let channelProvider: ChannelProvider
    
    public var addTitle: String {
        if shouldShowOnlyAdmins {
            return L10n.Channel.Add.Admins.title
        } else if channel.channelType == .broadcast {
            return L10n.Channel.Add.Subscribers.title
        } else {
            return  L10n.Channel.Add.Members.title
        }
    }
    
    public var addRole: String {
        if filterMembersByRole == SceytChatUIKit.shared.config.memberRolesConfig.admin {
            return SceytChatUIKit.shared.config.memberRolesConfig.admin
        } else if channel.channelType == .broadcast {
            return SceytChatUIKit.shared.config.memberRolesConfig.subscriber
        } else {
            return SceytChatUIKit.shared.config.memberRolesConfig.participant
        }
    }
    
    @Published public var event: Event?
    
    public var isSearching = false
    
    public lazy var defaultPredicate: NSPredicate = {
        var predicate = NSPredicate(format: "channelId == %lld", channel.id)
        if let filterMembersByRole {
            predicate = predicate.and(predicate: .init(format: "role.name == %@", filterMembersByRole))
        }
        return predicate
    }()

    public private(set) lazy var memberObserver: DatabaseObserver<MemberDTO, ChatChannelMember> = {
        return DatabaseObserver<MemberDTO, ChatChannelMember>(
            request: MemberDTO.fetchRequest()
                .fetch(predicate: defaultPredicate)
                .sort(descriptors: [
                    .init(keyPath: \MemberDTO.user?.firstName, ascending: true),
                    .init(keyPath: \MemberDTO.user?.lastName, ascending: true),
                    .init(keyPath: \MemberDTO.channelId, ascending: true)
                ]),
            context: SceytChatUIKit.shared.database.viewContext
        ) { $0.convert() }
    }()

    public required init(channel: ChatChannel,
                         filterMembersByRole: String? = nil) {
        self.channel = channel
        self.filterMembersByRole = filterMembersByRole
        provider = Components.channelMemberListProvider.init(channelId: channel.id)
        channelProvider = Components.channelProvider.init(channelId: channel.id)
        super.init()
    }
    
    open var canAddMembers: Bool {
        switch channel.channelType {
        case .direct:
            return false
        case .private:
            if shouldShowOnlyAdmins {
                return channel.userRole == SceytChatUIKit.shared.config.memberRolesConfig.owner || channel.userRole == SceytChatUIKit.shared.config.memberRolesConfig.admin
            }
            return true
        default:
            return channel.userRole == SceytChatUIKit.shared.config.memberRolesConfig.owner || channel.userRole == SceytChatUIKit.shared.config.memberRolesConfig.admin
        }
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

    open var shouldShowOnlyAdmins: Bool {
        filterMembersByRole == SceytChatUIKit.shared.config.memberRolesConfig.admin
    }
    
    open func onDidChangeEvent(items: DBChangeItemPaths) {
        guard !isSearching
        else {
            event = .reload
            return
        }
        event = .change(.init(changes: items, section: canAddMembers ? 1 : 0))
    }

    open func member(at indexPath: IndexPath) -> ChatChannelMember? {
        return memberObserver.item(at: .init(row: indexPath.row, section: 0))
    }
    
    open var numberOfSections: Int {
        canAddMembers ? 2 : 1
    }

    open func numberOfItems(section: Int) -> Int {
        switch (section, canAddMembers) {
        case (0, true):
            return 1
        case (1, true), (0, false):
            return memberObserver.numberOfItems(in: 0)
        default:
            return 0
            
        }
    }
    
    var numberOfMembers: Int {
        memberObserver.numberOfItems(in: 0)
    }

    open func loadMembers() {
        provider.loadMembers()
    }

    open func canChangeMemberRoleToOwner(memberAt indexPath: IndexPath) -> Bool {
        var isCurrentUserOwner: Bool {
            channel.userRole == "owner"
        }
        
        guard let member = member(at: indexPath) else { return false }
        return isCurrentUserOwner && member.id != me
    }

    open func changeOwner(
        memberAt indexPath: IndexPath,
        completion: @escaping (Error?) -> Void) {
            guard let member = member(at: indexPath) else { return }
            channelProvider
                .changeOwner(
                    newOwnerId: member.id,
                    completion: completion
                )
        }

    open func kick(memberAt indexPath: IndexPath, completion: @escaping (Error?) -> Void) {
        guard let member = member(at: indexPath) else { return }
        channelProvider
            .kick(
                members: [member.id],
                completion: completion
            )
    }

    open func block(memberAt indexPath: IndexPath, completion: @escaping (Error?) -> Void) {
        guard let member = member(at: indexPath) else { return }
        channelProvider
            .block(
                members: [member.id],
                completion: completion
            )
    }

    open func setRole(
        name: String,
        memberAt indexPath: IndexPath,
        completion: @escaping (Error?) -> Void) {
            guard let member = member(at: indexPath) else { return }
            channelProvider.setRole(
                name: name,
                userId: member.id,
                completion: completion
            )
    }
    
    open func createChannel(userAt indexPath: IndexPath, completion: ((ChatChannel?, Error?) -> Void)? = nil) {
        guard let m = member(at: indexPath), m.id != me else {
            return
        }
        
        let members = [ChatChannelMember(user: m, roleName: SceytChatUIKit.shared.config.memberRolesConfig.owner),
                       ChatChannelMember(id: me, roleName: SceytChatUIKit.shared.config.memberRolesConfig.owner)]
        ChannelCreator()
            .createLocalChannel(type: SceytChatUIKit.shared.config.channelTypesConfig.direct,
                                members: members) { channel, error in
                completion?(channel, error)
            }
    }
    
    @objc
    open func search(query: String) {
        isSearching = true
        var predicate = NSPredicate(format: "channelId == %lld", channel.id)
        if let filterMembersByRole {
            predicate = predicate.and(predicate: .init(format: "role.name == %@", filterMembersByRole))
        }
        predicate = predicate.and(predicate: .init(format: "user.firstName CONTAINS[c] %@ OR user.lastName CONTAINS[c] %@", query, query))
        do {
            try memberObserver.update(predicate: predicate)
            provider.loadMembers()
        } catch {
            logger.errorIfNotNil(error, "")
        }
    }
    
    open func cancelSearch() {
        guard isSearching else { return }
        do {
            try memberObserver.update(predicate: defaultPredicate)
            provider.loadMembers()
        } catch {
            logger.errorIfNotNil(error, "")
        }
        isSearching = false
    }
}

public extension ChannelMemberListViewModel {

    enum Event {
        case reload
        case change(ChangeItemPaths)
    }
    
    struct ChangeItemPaths {
        
        public var inserts = [IndexPath]()
        public var updates = [IndexPath]()
        public var deletes = [IndexPath]()
        public var moves = [(from: IndexPath, to: IndexPath)]()
        
        public init(changes: DBChangeItemPaths, section: Int = 1) {
            
            inserts = changes.inserts.map { .init(row: $0.row, section: section) }
            updates = changes.updates.map { .init(row: $0.row, section: section) }
            deletes = changes.deletes.map { .init(row: $0.row, section: section) }
            moves = changes.moves.map { (.init(row: $0.from.row, section: section), .init(row: $0.to.row, section: section)) }
        }
    }
}
