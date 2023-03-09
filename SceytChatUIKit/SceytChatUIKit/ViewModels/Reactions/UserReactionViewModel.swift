//
//  UserReactionViewModel.swift
//  SceytChatUIKit
//

public struct UserReactionViewModel {

    private let reactions: [ChatMessage.Reaction]

    public init(reactions: [ChatMessage.Reaction]) {
        self.reactions = reactions
    }

    public func numberOfRows() -> Int {
        reactions.count
    }

    public func user(at indexPath: IndexPath) -> ChatUser {
        reactions[indexPath.item].user
    }

    public func reactionKey(at indexPath: IndexPath) -> String {
        reactions[indexPath.item].key
    }

    public func reaction(at indexPath: IndexPath) -> ChatMessage.Reaction {
        reactions[indexPath.item]
    }

}
