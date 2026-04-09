//
//  GlobalSearchUserBarViewModel.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit on 07.04.25
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import Foundation
import Combine
import CoreData
import SceytChat

open class GlobalSearchUserBarViewModel: NSObject {

    @Published public var event: Event?

    @Atomic public var users: [ChatUser] = []
    @Atomic var allUsers: [ChatUser] = []
    var searchQuery: String?

    open lazy var channelObserver: LazyDatabaseObserver<ChannelDTO, ChatChannel> = {
        let config = SceytChatUIKit.shared.config.channelTypesConfig
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "unsubscribed == NO"),
            NSPredicate(format: "type IN %@", [config.direct, config.group])
        ])
        return LazyDatabaseObserver<ChannelDTO, ChatChannel>(
            context: SceytChatUIKit.shared.database.backgroundReadOnlyObservableContext,
            sortDescriptors: [.init(keyPath: \ChannelDTO.sortingKey, ascending: false)],
            sectionNameKeyPath: #keyPath(ChannelDTO.pinSectionIdentifier),
            fetchPredicate: predicate
        ) { $0.convert() }
    }()

    public override required init() {
        super.init()
    }

    open func startDatabaseObserver() {
        channelObserver.onDidChange = { [weak self] _, _, _ in
            self?.rebuild()
        }
        channelObserver.startObserver()
    }

    private func rebuild() {
        var channelIds: [Int64] = []
        channelObserver.forEach { _, channel in
            channelIds.append(Int64(channel.id))
            return false
        }

        guard !channelIds.isEmpty else {
            allUsers = []
            applyFilter()
            return
        }

        let currentUserId = SceytChatUIKit.shared.currentUserId ?? ""

        SceytChatUIKit.shared.database.read { context in
            let request = MemberDTO.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "channelId IN %@", channelIds),
                NSPredicate(format: "user.id != %@", currentUserId)
            ])
            let members = MemberDTO.fetch(request: request, context: context)

            var seen = Set<String>()
            var result: [ChatUser] = []
            for member in members {
                guard let userDto = member.user, !seen.contains(userDto.id) else { continue }
                seen.insert(userDto.id)
                result.append(ChatUser(dto: userDto))
            }
            return result
        } completion: { [weak self] fetchResult in
            guard let self else { return }
            allUsers = (try? fetchResult.get()) ?? []
            applyFilter()
        }
    }

    open func search(query: String?) {
        searchQuery = query
        applyFilter()
    }

    public func applyFilter() {
        let query = (searchQuery ?? "")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
        if query.isEmpty {
            users = []
        } else {
            users = allUsers.filter { user in
                let first = user.firstName?.lowercased() ?? ""
                let last = user.lastName?.lowercased() ?? ""
                let username = user.username?.lowercased() ?? ""
                let full = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
                return first.contains(query)
                    || last.contains(query)
                    || username.contains(query)
                    || full.contains(query)
            }
        }
        DispatchQueue.main.async { [weak self] in self?.event = .reload }
    }
}

public extension GlobalSearchUserBarViewModel {
    enum Event {
        case reload
    }
}
