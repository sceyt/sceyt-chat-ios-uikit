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
                                                          reactionListQueryLimit: 30)
        
        public var presenceConfig: PresenceConfig = PresenceConfig(defaultPresenceState: .online,
                                                                   defaultPresenceStatus: "")
        
        public var hardDeleteMessageForAll: Bool = false

        public var muteChannelNotificationOptions: [IntervalOption] = [
            IntervalOption(title: L10n.Channel.Info.Mute.oneHour, timeInterval: 1.hours),
            IntervalOption(title: L10n.Channel.Info.Mute.hours(8), timeInterval: 8.hours),
            IntervalOption(title: L10n.Channel.Info.Mute.forever, timeInterval: 0)
        ]
        
        public var messageAutoDeleteOptions: [IntervalOption] = [
            IntervalOption(title: L10n.Channel.Info.AutoDelete.oneDay, timeInterval: 1.days),
            IntervalOption(title: L10n.Channel.Info.AutoDelete.oneWeek, timeInterval: 1.weeks),
            IntervalOption(title: L10n.Channel.Info.AutoDelete.oneMonth, timeInterval: 1.months),
            IntervalOption(title: L10n.Channel.Info.Mute.forever, timeInterval: 0)
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
        
        public var syncChannelsAfterConnect: Bool = true
        
        public var channelListOrder: ChannelListOrder = .lastMessage
        
        public var defaultAvatarBackgroundColors: [UIColor] = [
            SceytChatUIKit.shared.theme.colors.accent,
            SceytChatUIKit.shared.theme.colors.accent2,
            SceytChatUIKit.shared.theme.colors.accent3,
            SceytChatUIKit.shared.theme.colors.accent4,
            SceytChatUIKit.shared.theme.colors.accent5
        ]
        
        
        // MARK: - Database Configuration
        public var storageConfig: StorageConfig = StorageConfig(storageDirectory: {
            if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
                return URL(fileURLWithPath: path)
            }
            return nil
        }(),
                                                                dataModelName: "SceytChatModel",
                                                                enableDatabase: true,
                                                                databaseFilename: "chatdb",
                                                                databaseFileDirectory: {
            if let path = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first {
                return URL(fileURLWithPath: path)
            }
            return nil
        }(),
                                                                userDefaults: UserDefaults.standard)

        
        // MARK: - Chat Configuration
        public var messageEditTimeout: TimeInterval = 1.hours
        public var avatarResizeConfig: ResizeConfig = .low
        public var imageAttachmentResizeConfig: ResizeConfig = .medium
        public var videoAttachmentResizeConfig: VideoResizeConfig = .medium
        public var attachmentSelectionLimit: Int = 20
        public var messageMultiselectLimit: Int = 30
        public var messageReactionPerUserLimit: UInt = 6 {
            didSet {
                if messageReactionPerUserLimit < 1 || messageReactionPerUserLimit > 6 {
                    fatalError("Invalid value for messageReactionPerUserLimit: \(messageReactionPerUserLimit). It must be between 1 and 6.")
                }
            }
        }
        public var mentionTriggerPrefix: String = "@"
        public var preventDuplicateAttachmentUpload: Bool = false
        public var messageBubbleTransformScale = CGAffineTransform(scaleX: 0.95, y: 0.95)
        public var defaultReactions = ["👍", "😍", "❤️", "🤝", "😂", "😏"]
    }
}
