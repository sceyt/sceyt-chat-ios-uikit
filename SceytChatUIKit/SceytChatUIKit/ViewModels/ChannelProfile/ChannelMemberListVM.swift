//
//  ChannelMemberListVM.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class ChannelMemberListVM: NSObject {

    public let channel: ChatChannel
    public let filterMembersByRole: String?
    public let provider: ChannelMemberListProvider
    public let channelProvider: ChannelProvider
    
    @Published open var event: Event?

    public private(set) lazy var memberObserver: DatabaseObserver<MemberDTO, ChatChannelMember> = {
        var predicate = NSPredicate(format: "ANY channels.id == %lld", channel.id)
        if let filterMembersByRole {
            predicate = predicate.and(predicate: .init(format: "role.name == %@", filterMembersByRole))
        }
        return DatabaseObserver<MemberDTO, ChatChannelMember>(
            request: MemberDTO.fetchRequest()
                .fetch(predicate: predicate)
                .sort(descriptors: [.init(keyPath: \MemberDTO.user?.firstName, ascending: true)]),
            context: Config.database.viewContext
        ) { $0.convert() }
    }()

    public required init(channel: ChatChannel,
                         filterMembersByRole: String? = nil) {
        self.channel = channel
        self.filterMembersByRole = filterMembersByRole
        provider = ChannelMemberListProvider(channelId: channel.id)
        channelProvider = ChannelProvider(channelId: channel.id)
        super.init()
    }
    
    var canAddMembers: Bool {
        channel.roleName == "owner" || channel.roleName == "admin"
    }

    open func startDatabaseObserver() {
        memberObserver.onDidChange = {[weak self] in
            self?.onDidChangeEvent(items: $0)
        }
        do {
            try memberObserver.startObserver()
        } catch {
            debugPrint("observer.startObserver", error)
        }
    }

    open var shouldShowOnlyAdmins: Bool {
        filterMembersByRole == "admin"
    }
    
    open func onDidChangeEvent(items: DBChangeItemPaths) {
        event = .change(.init(changes: items, section: canAddMembers ? 1 : 0))
    }

    open func member(at indexPath: IndexPath) -> ChatChannelMember? {
        return memberObserver.item(at: .init(row: indexPath.row, section: 0))
    }
    
    open var numberOfSection: Int {
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
            channel.roleName == "owner"
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
}

public extension ChannelMemberListVM {

    enum Event {
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
