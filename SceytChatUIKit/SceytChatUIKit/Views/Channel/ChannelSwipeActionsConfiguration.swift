//
//  ChannelSwipeActionsConfiguration.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelSwipeActionsConfiguration {
    
    public typealias Handler = (UIContextualAction, UIView, Actions, @escaping (Bool) -> Void) -> Void
    
    open class func trailingSwipeActionsConfiguration(
        for chatChannel: ChatChannel,
        handler: @escaping Handler
    ) -> UISwipeActionsConfiguration? {
        let actions = trailingActions(chatChannel: chatChannel)
        var deleteAction: UIContextualAction {
            UIContextualAction(appearance: Appearance.deleteContextualAction) {
                handler($0, $1, .delete, $2)
            }
        }
        
        var leaveAction: UIContextualAction {
            UIContextualAction(appearance: Appearance.leaveContextualAction) {
                handler($0, $1, .leave, $2)
            }
        }

        var contextualActions = [UIContextualAction]()
        actions.forEach { action in
            switch action {
            case .delete:
                contextualActions.append(deleteAction)
            case .leave:
                contextualActions.append(leaveAction)
            default:
                break
            }
        }
        return contextualActions.isEmpty ? nil : UISwipeActionsConfiguration(actions: contextualActions)
    }
    
    open class func leadingSwipeActionsConfiguration(
        for chatChannel: ChatChannel,
        handler: @escaping Handler
    ) -> UISwipeActionsConfiguration? {
        let actions = leadingActions(chatChannel: chatChannel)
        var readAction: UIContextualAction {
            UIContextualAction(appearance: Appearance.readContextualAction) {
                handler($0, $1, .read, $2)
            }
        }
        
        var unreadAction: UIContextualAction {
            UIContextualAction(appearance: Appearance.unreadContextualAction) {
                handler($0, $1, .unread, $2)
            }
        }
        
        switch actions {
        case .read:
            return .init(actions: [readAction])
        case .unread:
            return .init(actions: [unreadAction])
        default:
            return nil
        }
    }
    
    open class func trailingActions(chatChannel: ChatChannel) -> [Actions] {
        switch chatChannel.type {
        case .direct:
            return [.delete]
        default:
            if chatChannel.roleName == "owner" {
                return [.delete, .leave]
            }
        }
        return [.leave]
    }
    
    open class func leadingActions(chatChannel: ChatChannel) -> Actions {
        return chatChannel.markedAsUnread ? .read : .unread
    }
    
    public enum Actions {
        case delete
        case leave
        case read
        case unread
    }
}

public extension UIContextualAction {
    
    convenience init(appearance: ContextualActionAppearance, handler: @escaping Handler) {
        self.init(style: .destructive, title: appearance.title, handler: handler)
        self.image = appearance.image
        self.backgroundColor = appearance.backgroundColor
    }
}
