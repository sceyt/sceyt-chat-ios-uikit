//
//  UserReactionViewModel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import SceytChat
import Combine

open class UserReactionViewModel: NSObject {

    @Published public var event: Event?

    public let provider: MessageReactionProvider
    public let messageId: MessageId
    public let reactionKey: String?

    public private(set) var reactions: [ChatMessage.Reaction] = []
    private var pendingInserts: (indexPaths: [IndexPath], items: [ChatMessage.Reaction])?

    public private(set) lazy var reactionObserver: DatabaseObserver<ReactionDTO, ChatMessage.Reaction> = {
        var predicate = NSPredicate(format: "message.id == %lld", messageId)
        if let reactionKey {
            predicate = predicate.and(predicate: .init(format: "key == %@", reactionKey))
        }
        return DatabaseObserver<ReactionDTO, ChatMessage.Reaction>(
            request: ReactionDTO.fetchRequest()
                .sort(descriptors: [.init(keyPath: \ReactionDTO.key, ascending: false)])
                .fetch(predicate: predicate),
            context: SceytChatUIKit.shared.database.viewContext
        ) { $0.convert() }
    }()

    public required init(messageId: MessageId, reactionKey: String?) {
        self.messageId = messageId
        self.reactionKey = reactionKey
        var queryBuilder = ReactionListQuery
            .Builder(messageId: messageId)
            .limit(SceytChatUIKit.shared.config.queryLimits.reactionListQueryLimit)
        if let key = reactionKey {
            queryBuilder = queryBuilder.key(key)
        }
        let query = queryBuilder.build()
        provider = Components.messageReactionProvider.init(messageId: messageId, query: query)
        if reactionKey == nil {
            provider.cleanLocalReactionAfterFirstLoad = true
        }
    }

    open func startDatabaseObserver() {
        reactionObserver.onDidChange = { [weak self] in
            self?.onDidChangeEvent(items: $0)
        }
        do {
            try reactionObserver.startObserver()
        } catch {
            logger.errorIfNotNil(error, "observer.startObserver")
        }
    }

    open func onDidChangeEvent(items: DBChangeItemPaths) {
        if reactionObserver.isEmpty || items.inserts.isEmpty || !items.deletes.isEmpty || !items.moves.isEmpty {
            syncReactions()
            event = .reloadData
            return
        }
        let pairs = items.inserts.compactMap { indexPath -> (IndexPath, ChatMessage.Reaction)? in
            guard let item = reactionObserver.item(at: indexPath) else { return nil }
            return (indexPath, item)
        }
        guard !pairs.isEmpty else {
            syncReactions()
            event = .reloadData
            return
        }
        pendingInserts = (indexPaths: pairs.map { $0.0 }, items: pairs.map { $0.1 })
        event = .insert(pairs.map { $0.0 })
    }

    open func applyPendingInserts() -> [IndexPath] {
        guard let pending = pendingInserts else { return [] }
        defer { pendingInserts = nil }
        let sorted = zip(pending.indexPaths, pending.items).sorted { $0.0 < $1.0 }
        var existingUserKeys = Set(reactions.compactMap { r -> String? in
            guard let uid = r.user?.id else { return nil }
            return "\(uid)_\(r.key)"
        })
        var insertedPaths: [IndexPath] = []
        for (indexPath, item) in sorted {
            let userKey = "\(item.user?.id ?? "")_\(item.key)"
            guard !existingUserKeys.contains(userKey) else { continue }
            existingUserKeys.insert(userKey)
            let index = min(indexPath.item, reactions.count)
            reactions.insert(item, at: index)
            insertedPaths.append(indexPath)
        }
        return insertedPaths
    }

    private func syncReactions() {
        reactions = (0..<reactionObserver.numberOfItems(in: 0))
            .compactMap { reactionObserver.item(at: IndexPath(item: $0, section: 0)) }
    }

    open func numberOfItems(in section: Int) -> Int {
        reactions.count
    }

    open func cellModel(at indexPath: IndexPath) -> ChatMessage.Reaction? {
        guard indexPath.item < reactions.count else { return nil }
        return reactions[indexPath.item]
    }

    open func reaction(at indexPath: IndexPath) -> ChatMessage.Reaction? {
        guard indexPath.item < reactions.count else { return nil }
        return reactions[indexPath.item]
    }

    open func loadReactions() {
        provider.loadReactions()
    }

}
public extension UserReactionViewModel {

    enum Event {
        case reloadData
        case insert([IndexPath])
    }
}
