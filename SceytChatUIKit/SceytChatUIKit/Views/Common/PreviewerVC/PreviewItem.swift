//
//  PreviewItem.swift
//  SceytChatUIKit
//

import UIKit

public enum PreviewItem: Equatable {
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
