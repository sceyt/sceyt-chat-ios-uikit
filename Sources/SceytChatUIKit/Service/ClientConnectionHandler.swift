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
        if state == .connected,
           SceytChatUIKit.shared.config.syncChannelsAfterConnect {
            SyncService.syncChannels()
            
            if !SceytChatUIKit.shared.chatClient.user.id.isEmpty {
                UserDefaults.currentUserId = SceytChatUIKit.shared.chatClient.user.id
            }
        }
    }
}
