//
//  ChannelSwipeActionsConfiguration.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelSwipeActionsConfiguration {
    
    public typealias Handler = (UIContextualAction, UIView, Actions, @escaping (Bool) -> Void) -> Void
    
    open class func trailingSwipeActionsConfiguration(
        for chatChannel: ChatChannel,
        handler: @escaping Handler
    ) -> UISwipeActionsConfiguration? {
        let actions = trailingActions(chatChannel: chatChannel)
        let contextualActions: [UIContextualAction] = actions.compactMap { action in
            switch action {
            case .delete:
                return UIContextualAction(appearance: Appearance.deleteContextualAction) {
                        handler($0, $1, .delete, $2)
                    }
            case .leave:
                return UIContextualAction(appearance: Appearance.leaveContextualAction) {
                    handler($0, $1, .leave, $2)
                }
            case .mute:
                return UIContextualAction(appearance: Appearance.muteContextualAction) {
                    handler($0, $1, .mute, $2)
                }
            case .unmute:
                return UIContextualAction(appearance: Appearance.unmuteContextualAction) {
                    handler($0, $1, .unmute, $2)
                }
            default:
                return nil
            }
        }
        return contextualActions.isEmpty ? nil : UISwipeActionsConfiguration(actions: contextualActions)
    }
    
    open class func leadingSwipeActionsConfiguration(
        for chatChannel: ChatChannel,
        handler: @escaping Handler
    ) -> UISwipeActionsConfiguration? {
        let actions = leadingActions(chatChannel: chatChannel)
        let contextualActions: [UIContextualAction] = actions.compactMap { action in
            switch action {
            case .read:
                return UIContextualAction(appearance: Appearance.readContextualAction) {
                    handler($0, $1, .read, $2)
                }
            case .unread:
                return UIContextualAction(appearance: Appearance.unreadContextualAction) {
                    handler($0, $1, .unread, $2)
                }
            case .pin:
                return UIContextualAction(appearance: Appearance.pinContextualAction) {
                    handler($0, $1, .pin, $2)
                }
            case .unpin:
                return UIContextualAction(appearance: Appearance.unpinContextualAction) {
                    handler($0, $1, .unpin, $2)
                }
            default:
                return nil
            }
        }
        return contextualActions.isEmpty ? nil : UISwipeActionsConfiguration(actions: contextualActions)
    }
    
    open class func trailingActions(chatChannel: ChatChannel) -> [Actions] {
        var actions: [Actions] = []
        switch chatChannel.channelType {
        case .direct:
            actions += [.delete]
        default:
            if chatChannel.userRole == "owner" {
                actions += [.delete, .leave]
            } else {
                actions += [.leave]
            }
        }
        actions += [chatChannel.muted ? .unmute : .mute]
        return actions
    }
    
    open class func leadingActions(chatChannel: ChatChannel) -> [Actions] {
        var actions: [Actions] = []
        if (chatChannel.unread || chatChannel.newMessageCount > 0) {
            actions += [.read]
        } else {
            actions += [.unread]
        }
        if chatChannel.pinnedAt != nil {
            actions += [.unpin]
        } else {
            actions += [.pin]
        }
        return actions
    }
    
    public enum Actions {
        case delete
        case leave
        case read
        case unread
        case mute
        case unmute
        case pin
        case unpin
    }
}

public extension UIContextualAction {
    
    convenience init(appearance: ContextualActionAppearance, handler: @escaping Handler) {
        self.init(style: .destructive, title: appearance.title, handler: handler)
        self.image = appearance.image
        self.backgroundColor = appearance.backgroundColor
    }
}
