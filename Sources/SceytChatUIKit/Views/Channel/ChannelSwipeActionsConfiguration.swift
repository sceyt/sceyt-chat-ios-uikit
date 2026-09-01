//
//  ChannelSwipeActionsConfiguration.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelSwipeActionsConfiguration: NSObject {
    
    public typealias Handler = (UIContextualAction, UIView, Actions, @escaping (Bool) -> Void) -> Void
    
    @available(*, deprecated, message: "The channel list renders its own in-cell swipe actions so they can survive a channel reorder; UIKit can neither carry an open swipe across a row move nor re-open one. Override trailingActions(chatChannel:) to change which actions a channel offers, or ChannelListViewController.onSwipeAction(_:channel:) to change what they do. Set ChannelListViewController.usesNativeSwipeActions = true to keep this UIKit implementation.")
    open class func trailingSwipeActionsConfiguration(
        for chatChannel: ChatChannel,
        handler: @escaping Handler
    ) -> UISwipeActionsConfiguration? {
        let contextualActions = trailingActionItems(chatChannel: chatChannel).map { item in
            UIContextualAction(appearance: item.appearance) { handler($0, $1, item.action, $2) }
        }
        return contextualActions.isEmpty ? nil : UISwipeActionsConfiguration(actions: contextualActions)
    }
    
    @available(*, deprecated, message: "The channel list renders its own in-cell swipe actions so they can survive a channel reorder; UIKit can neither carry an open swipe across a row move nor re-open one. Override leadingActions(chatChannel:) to change which actions a channel offers, or ChannelListViewController.onSwipeAction(_:channel:) to change what they do. Set ChannelListViewController.usesNativeSwipeActions = true to keep this UIKit implementation.")
    open class func leadingSwipeActionsConfiguration(
        for chatChannel: ChatChannel,
        handler: @escaping Handler
    ) -> UISwipeActionsConfiguration? {
        let contextualActions = leadingActionItems(chatChannel: chatChannel).map { item in
            UIContextualAction(appearance: item.appearance) { handler($0, $1, item.action, $2) }
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
    
    public enum Actions: Equatable, CaseIterable {
        case delete
        case leave
        case read
        case unread
        case mute
        case unmute
        case pin
        case unpin

        /// Stable, locale-independent name, used to build accessibility
        /// identifiers. Deliberately not derived from the localized title.
        public var identifierName: String {
            switch self {
            case .delete: return "delete"
            case .leave: return "leave"
            case .read: return "read"
            case .unread: return "unread"
            case .mute: return "mute"
            case .unmute: return "unmute"
            case .pin: return "pin"
            case .unpin: return "unpin"
            }
        }
    }
}

public extension ChannelSwipeActionsConfiguration {

    /// One resolved swipe action: what it does, plus how it looks.
    struct ActionItem {
        public let action: Actions
        public let appearance: ContextualActionAppearance

        public init(action: Actions, appearance: ContextualActionAppearance) {
            self.action = action
            self.appearance = appearance
        }
    }

    /// The single `Actions` -> appearance mapping, shared by the in-cell swipe
    /// buttons and the deprecated `UIContextualAction` path, so the two cannot
    /// drift apart.
    class func appearance(for action: Actions) -> ContextualActionAppearance {
        switch action {
        case .delete: return Appearance.deleteContextualAction
        case .leave: return Appearance.leaveContextualAction
        case .read: return Appearance.readContextualAction
        case .unread: return Appearance.unreadContextualAction
        case .mute: return Appearance.muteContextualAction
        case .unmute: return Appearance.unmuteContextualAction
        case .pin: return Appearance.pinContextualAction
        case .unpin: return Appearance.unpinContextualAction
        }
    }

    /// Resolved trailing actions, in the order `trailingActions(chatChannel:)`
    /// returned them.
    ///
    /// Unlike the deprecated `UISwipeActionsConfiguration` factories — which
    /// `compactMap`ped a fixed `switch` and so silently dropped anything not on
    /// their side — nothing is filtered here: whatever
    /// `trailingActions(chatChannel:)` returns is what gets rendered.
    class func trailingActionItems(chatChannel: ChatChannel) -> [ActionItem] {
        trailingActions(chatChannel: chatChannel)
            .map { ActionItem(action: $0, appearance: appearance(for: $0)) }
    }

    /// Resolved leading actions, in the order `leadingActions(chatChannel:)`
    /// returned them.
    class func leadingActionItems(chatChannel: ChatChannel) -> [ActionItem] {
        leadingActions(chatChannel: chatChannel)
            .map { ActionItem(action: $0, appearance: appearance(for: $0)) }
    }
}

public extension UIContextualAction {
    
    convenience init(appearance: ContextualActionAppearance, handler: @escaping Handler) {
        self.init(style: .destructive, title: appearance.title, handler: handler)
        self.image = appearance.image
        self.backgroundColor = appearance.backgroundColor
    }
}
