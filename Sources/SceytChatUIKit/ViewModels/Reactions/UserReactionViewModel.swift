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
    
    public private(set) lazy var reactionObserver: DatabaseObserver<ReactionDTO, ChatMessage.Reaction> = {
        var predicate = NSPredicate(format: "message.id == %lld", messageId)
        if let reactionKey {
            predicate = predicate.and(predicate: .init(format: "key == %@", reactionKey))
        }
        return DatabaseObserver<ReactionDTO, ChatMessage.Reaction>(
            request: ReactionDTO.fetchRequest()
                .sort(descriptors: [.init(keyPath: \ReactionDTO.key, ascending: false)])
                .fetch(predicate: predicate),
            context: Config.database.viewContext
        ) { $0.convert() }
    }()

    public init(messageId: MessageId, reactionKey: String?) {
        self.messageId = messageId
        self.reactionKey = reactionKey
        var queryBuilder = ReactionListQuery
            .Builder(messageId: messageId)
            .limit(30)
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
        if reactionObserver.isEmpty || items.inserts.isEmpty {
            event = .reloadData
            return
        }
        event = .insert(items.inserts)
    }

    open func numberOfItems(in section: Int) -> Int {
        reactionObserver.numberOfItems(in: section)
    }

    open func cellModel(at indexPath: IndexPath) -> (ChatUser?, String)? {
        if let item = reactionObserver.item(at: indexPath) {
            return (item.user, item.key)
        }
        return nil
    }

    open func reaction(at indexPath: IndexPath) -> ChatMessage.Reaction? {
        reactionObserver.item(at: indexPath)
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
