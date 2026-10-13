//
//  ClientConnectionHandler.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 10.01.25
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class ClientConnectionHandler: NSObject, ChatClientDelegate {

    public static let `default` = Components.clientConnectionHandler.init()

    required public override init() {
        super.init()
    }

    open func chatClient(_ chatClient: ChatClient, didChange state: ConnectionState, error: SceytError?) {
        if state == .connected {
            if SceytChatUIKit.shared.config.syncChannelsAfterConnect {
                SyncService.syncChannels()
            } else {
                // A sync is what normally replays stored message deletes; without it they would
                // never reach the server.
                SyncService.sendPendingMessageDeletes()
                // Same for messages still waiting to go out — including the ones whose
                // attachments `AttachmentTransfer` parked in `.pending` because the upload was
                // attempted while offline. Resending is what restarts those uploads.
                SyncService.sendPendingMessages()
            }

            if !SceytChatUIKit.shared.chatClient.user.id.isEmpty {
                UserDefaults.currentUserId = SceytChatUIKit.shared.chatClient.user.id
            }
        }
    }
}
