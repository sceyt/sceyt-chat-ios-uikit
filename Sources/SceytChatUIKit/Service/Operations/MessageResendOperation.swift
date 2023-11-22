//
//  MessageResendOperation.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 30.06.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
//
//open class MessageResendOperation: AsyncOperation {
//    let sender: ChannelMessageSender
//    let provider: ChannelMessageProvider
//    let message: ChatMessage
//    public init(sender: ChannelMessageSender,
//                message: ChatMessage) {
//        self.sender = sender
//        self.message = message
//        self.provider = ChannelMessageProvider(channelId: message.channelId)
//        super.init(String(sender.channelId) + String(message.tid))
//    }
//    
//    override open func main() {
//        send { [weak self] in
//            self?.complete()
//        }
//    }
//    
//    private func send(_ completion: @escaping () -> Void) {
//        let tid = message.tid
//        logger.verbose("SyncService: Resending Message with tid \(tid)")
//        sender.resendMessage(message) { error in
//            logger.errorIfNotNil(error, "SyncService: Response Resending Message with tid \(tid)")
//            if error?.isChannelNotExists == true {
//                logger.errorIfNotNil(error, "SyncService: Response Channel not exist delete Message with tid \(tid)")
//                self.provider.deletePending(message: tid)
//            }
//            completion()
//        }
//    }
//}

