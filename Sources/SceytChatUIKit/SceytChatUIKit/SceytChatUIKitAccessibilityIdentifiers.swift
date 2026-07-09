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

        /// The open-channel (conversation) screen driven by `ChannelViewController`.
        public enum Channel {
            /// The (mirrored) collection view that renders the message list.
            public static let collectionView = "channel.collectionView"
            /// The channel name shown in the navigation-bar header.
            public static let titleLabel = "channel.title"
            /// The subtitle (member count / status) shown under the title.
            public static let subtitleLabel = "channel.subtitle"
            /// The floating "scroll to bottom" button.
            public static let scrollDownButton = "channel.scrollDownButton"

            /// A single message row inside the conversation list.
            public enum Cell {
                /// Base identifier shared by every message cell.
                public static let root = "messageCell"

                /// Per-row identifier so a specific message can be addressed
                /// directly, e.g. `app.cells["messageCell.42"]`.
                public static func identifier(for id: MessageId) -> String {
                    "\(root).\(id)"
                }

                /// The label rendering the message body text.
                public static let body = "messageCell.body"
                /// The timestamp label.
                public static let date = "messageCell.date"
                /// The "New messages" separator shown on the last displayed message.
                public static let unreadSeparator = "messageCell.unreadSeparator"
                /// The quoted reply preview; tapping it scrolls to the parent message.
                public static let replyView = "messageCell.replyView"
            }
        }
    }
}
