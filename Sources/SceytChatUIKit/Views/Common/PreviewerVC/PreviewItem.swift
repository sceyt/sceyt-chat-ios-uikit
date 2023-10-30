//
//  PreviewItem.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public enum PreviewItem: Equatable, Hashable {
    case attachment(ChatMessage.Attachment)
    
    public var attachment: ChatMessage.Attachment {
        switch self {
        case let .attachment(attachment):
            return attachment
        }
    }
    
    public var senderTitle: String {
        switch self  {
        case let .attachment(attachment):
            if me == attachment.userId {
                return L10n.User.current
            } else if let user = attachment.user {
                return Formatters.userDisplayName.format(user)
            } else {
                return ""
            }
        }
    }
}
