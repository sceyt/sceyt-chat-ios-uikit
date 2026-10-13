//
//  SceytChatUIKit+Config.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

extension SceytChatUIKit {
    public class Config {
        
        public var queryLimits: QueryLimits = QueryLimits(channelListQueryLimit: 20,
                                                          channelMemberListQueryLimit: 30,
                                                          userListQueryLimit: 30,
                                                          messageListQueryLimit: 50,
                                                          attachmentListQueryLimit: 20,
                                                          reactionListQueryLimit: 30,
                                                          pollVotersListQueryLimit: 30,
                                                          pinnedMessageListQueryLimit: 30)
        
        public var presenceConfig: PresenceConfig = PresenceConfig(defaultPresenceState: .online,
                                                                   defaultPresenceStatus: "")
        
        public var hardDeleteMessageForAll: Bool = false

        public var muteChannelNotificationOptions: [IntervalOption] = [
            IntervalOption(title: L10n.Channel.Info.Mute.oneHour, timeInterval: 1.hours),
            IntervalOption(title: L10n.Channel.Info.Mute.hours(8), timeInterval: 8.hours),
            IntervalOption(title: L10n.Channel.Info.Mute.forever, timeInterval: 0)
        ]
        
        public var messageAutoDeleteOptions: [IntervalOption] = [
            IntervalOption(title: L10n.Channel.Info.AutoDelete.off, timeInterval: 0),
            IntervalOption(title: L10n.Channel.Info.AutoDelete.oneDay, timeInterval: 1.days * 1000),
            IntervalOption(title: L10n.Channel.Info.AutoDelete.oneWeek, timeInterval: 1.weeks * 1000),
            IntervalOption(title: L10n.Channel.Info.AutoDelete.oneMonth, timeInterval: 1.months * 1000)
        ]

        
        // MARK: - Channel Configuration
        public var channelTypesConfig: ChannelTypesConfig = ChannelTypesConfig(direct: "direct",
                                                                               group: "group",
                                                                               broadcast: "broadcast")
        public var memberRolesConfig: MemberRolesConfig = MemberRolesConfig(owner: "owner",
                                                                            admin: "admin",
                                                                            participant: "participant",
                                                                            subscriber: "subscriber")
        public var channelURIConfig: ChannelURIConfig = ChannelURIConfig(prefix: "@",
                                                                         minLength: 5,
                                                                         maxLength: 50,
                                                                         regex: "^[a-zA-Z0-9_]*$")
        
        public var channelInviteDeepLinkConfig: ChannelInviteDeepLinkConfig?
        
        public var syncChannelsAfterConnect: Bool = true

        /// Master switch for the pinned-messages feature.
        ///
        /// While `false` the SDK behaves as though pinning does not exist:
        ///
        /// - the message context menu offers neither Pin nor Unpin — `ChannelViewModel.canPin(model:)`
        ///   and `canUnpin(model:)` both refuse, and `ChannelPinnedMessageListViewModel.canUnpin(_:)`
        ///   with them;
        /// - the banner under the navigation bar never appears and the pinned-messages screen never
        ///   opens (`ChannelViewController.updatePinnedMessages(_:)`, `showPinnedMessageList()`);
        /// - no pin is drawn beside a bubble's timestamp (`MessageCell.InfoView.showsPin(for:)`), and
        ///   the info row measures without one;
        /// - nothing about pins is read, written or synced: the pin observer never starts
        ///   (`ChannelViewModel.startPinnedMessageObserver()`), the channel-open sweep and the
        ///   pending-intent drain are skipped (`SyncService.syncChannelPins(channelId:)`,
        ///   `sendPendingPins()`), the server's `didPinMessages` / `didUnpinMessages` events are
        ///   ignored, and `ChannelPinnedMessageProvider.pin`/`unpin` complete with
        ///   `ChannelPinnedMessageProvider.PinningError.pinningDisabled` instead of writing.
        ///
        /// Set it before the first conversation opens — flipping it while one is on screen leaves
        /// that screen with whatever it has already built (the observer it did or did not start).
        ///
        /// State on disk is left alone, deliberately: pins already stored stay stored, invisible,
        /// and pin intents queued before the switch are not sent while this is `false` — they go
        /// out if it is turned back on, rather than being dropped behind the user's back.
        ///
        /// Two things this cannot switch off, because they are ordinary messages on the server:
        /// an "X pinned: …" system message another member's client already posted still renders,
        /// and `pinDetails` still arrives on the messages it belongs to. Only the UI and the
        /// pin-specific storage go quiet.
        public var isMessagePinningEnabled: Bool = true

        /// Whether pinning a message for everyone also sends the client's own "X pinned: …"
        /// system message into the conversation.
        ///
        /// No effect while `isMessagePinningEnabled` is `false`: no pin is taken, so nothing
        /// announces one.
        ///
        /// Since pins replicate through the server, other members already learn about a pin from
        /// `ChannelDelegate.channel(_:didPinMessages:)` — this message is the visible audit trail
        /// in the timeline, not the delivery mechanism.
        ///
        /// Kept `true` because that is the behaviour shipped so far. **Set it to `false` if your
        /// backend generates its own pin system message**, or members will see the notice twice.
        public var sendsPinSystemMessage: Bool = true

        public var showGroupsInCommon: Bool = false

        public var mutualGroupChannelTypes: [String] = [ChatChannel.ChannelType.group.rawValue]

        public var channelListOrder: ChannelListOrder = .lastMessage
        
        public var defaultAvatarBackgroundColors: [UIColor] = [
            SceytChatUIKit.shared.theme.colors.accent,
            SceytChatUIKit.shared.theme.colors.accent2,
            SceytChatUIKit.shared.theme.colors.accent3,
            SceytChatUIKit.shared.theme.colors.accent4,
            SceytChatUIKit.shared.theme.colors.accent5
        ]
        
        
        // MARK: - Database Configuration
        public var storageConfig: StorageConfig = .init()

        
        // MARK: - Chat Configuration
        public var messageEditTimeout: TimeInterval = 2.hours
        public var avatarResizeConfig: ResizeConfig = .low
        public var imageAttachmentResizeConfig: ResizeConfig = .medium
        public var videoAttachmentResizeConfig: VideoResizeConfig = .medium
        public var attachmentSelectionLimit: Int = 20
        public var messageMultiselectLimit: Int = 30
        /// Maximum number of destination chats selectable at once on the Forward screen.
        /// Set to 0 or less for no limit.
        public var forwardChannelSelectionLimit: Int = 10
        public var maximumMessageLength: Int = 5000
        public var messageReactionPerUserLimit: UInt = 6 {
            didSet {
                if messageReactionPerUserLimit < 1 || messageReactionPerUserLimit > 6 {
                    fatalError("Invalid value for messageReactionPerUserLimit: \(messageReactionPerUserLimit). It must be between 1 and 6.")
                }
            }
        }
        /// The maximum number of different reactions displayed on a message cell.
        /// Reactions beyond this limit are hidden; the trailing count still reflects all reactions.
        /// Set a value less than or equal to 0 to show all reactions.
        public var maxDisplayedReactionsCount: Int = 3
        public var mentionTriggerPrefix: String = "@"
        public var preventDuplicateAttachmentUpload: Bool = false
        public var messageBubbleTransformScale = CGAffineTransform(scaleX: 0.95, y: 0.95)
        public var defaultReactions = ["👍", "😍", "❤", "🤝", "😂", "😏"]
        public var voiceRecorderConfig: VoiceRecorderConfig = .init()
    }
}
