//
//  SceytChatUIKitAccessibilityIdentifiers.swift
//  SceytChatUIKit
//
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

extension SceytChatUIKit {

    /// A central, namespaced registry of `accessibilityIdentifier` values used by
    /// the UIKit views.
    ///
    /// Keeping the identifiers in one place means UI tests and the views that they
    /// drive share a single source of truth — a renamed identifier is a compile-time
    /// change in both places rather than a silently broken string match. The values
    /// double as real accessibility identifiers, so they also benefit assistive
    /// technologies.
    public enum AccessibilityIdentifiers {

        public enum ChannelList {
            public static let tableView = "channelList.tableView"
            public static let newChannelButton = "channelList.newChannelButton"
            public static let searchBar = "channelList.searchBar"
            public static let emptyView = "channelList.emptyView"

            public enum Cell {
                /// Base identifier shared by every channel cell.
                public static let root = "channelCell"

                /// Per-row identifier so a specific channel can be addressed
                /// directly, e.g. `app.cells["channelCell.42"]`.
                public static func identifier(for id: ChannelId) -> String {
                    "\(root).\(id)"
                }

                public static let avatar = "channelCell.avatar"
                public static let subject = "channelCell.subject"
                public static let message = "channelCell.message"
                public static let date = "channelCell.date"
                public static let unreadBadge = "channelCell.unreadBadge"
                public static let mentionBadge = "channelCell.mentionBadge"
                public static let muteIcon = "channelCell.muteIcon"
                public static let pinIcon = "channelCell.pinIcon"
                public static let ticks = "channelCell.ticks"
            }
        }

        /// The message composer (input bar) on the open-channel screen.
        public enum MessageInput {
            /// The text view where a new message is composed.
            public static let inputField = "messageInput.inputField"
            /// The button that sends the composed message. Hidden until the
            /// composer holds non-whitespace text.
            public static let sendButton = "messageInput.sendButton"
        }
    }
}
