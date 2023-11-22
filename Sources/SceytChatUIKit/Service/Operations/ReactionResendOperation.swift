//
//  ReactionResendOperation.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 13.06.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class ReactionResendOperation: AsyncOperation {
    let provider: ChannelMessageProvider
    let reaction: ChatMessage.Reaction
    public init(provider: ChannelMessageProvider,
                reaction: ChatMessage.Reaction) {
        self.provider = provider
        self.reaction = reaction
        super.init(String(provider.channelId))
    }
    
    override open func main() {
        addReaction { [weak self] in
            self?.complete()
        }
    }
    
    private func addReaction(_ completion: @escaping () -> Void) {
        let mid = reaction.messageId
        let key = reaction.key
        logger.verbose("SyncService: Resending Reaction with messageId \(mid), key: \(key)")
        provider.addReactionToMessage(
            id: reaction.messageId,
            key: reaction.key,
            score: UInt16(reaction.score),
            reason: reaction.reason,
            storeForResend: false) { error in
                logger.errorIfNotNil(error, "SyncService: Resending Reaction with messageId \(mid), key: \(key)")
                completion()
            }
    }
}
