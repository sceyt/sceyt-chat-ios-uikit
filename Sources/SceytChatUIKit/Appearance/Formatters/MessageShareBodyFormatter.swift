//
//  MessageShareBodyFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 01.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

open class MessageShareBodyFormatter: MessageFormatting {
    
    public init() {}
    
    open func format(_ message: ChatMessage) -> String {
        guard let user = message.user else { return  "" }
        
        let body = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return "\(SceytChatUIKit.shared.formatters.userNameFormatter.format(user)) [\(SceytChatUIKit.shared.formatters.mediaPreviewDateFormatter.format(message.createdAt))]\n\(body)"
    }
}
