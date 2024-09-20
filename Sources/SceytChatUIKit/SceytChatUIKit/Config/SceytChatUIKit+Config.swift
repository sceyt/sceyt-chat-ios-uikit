//
//  SceytChatUIKit+Config.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

extension Double {
    var hours: Double { self * 3600 }
    var days: Double { self * 24.hours }
    var weeks: Double { self * 7.days }
    var months: Double { self * 30.days }
}

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
        public var database: Database {
            return _database
        }
        
        public var storageConfig: StorageConfig = StorageConfig(storageDirectory: {
            if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
                return URL(fileURLWithPath: path)
            }
            return nil
        }(),
                                                                dataModelName: "SceytChatModel",
                                                                databaseFilename: "chatdb",
                                                                databaseFileDirectory: {
            if let path = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first {
                return URL(fileURLWithPath: path)
            }
            return nil
        }(),
                                                                userDefaults: UserDefaults.standard)
        
        private lazy var _database: Database = {
            if let directory = storageConfig.databaseFileDirectory {
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                } catch {
                    print("Error creating directory: \(error.localizedDescription)")
                }
                let dbUrl = directory.appendingPathComponent(storageConfig.databaseFilename)
                return PersistentContainer(storeType: .sqLite(databaseFileUrl: dbUrl))
            } else {
                return PersistentContainer(storeType: .inMemory)
            }
        }()
        
        // MARK: - Chat Constants
        
        public var messageEditTimeout: TimeInterval = 1.hours
        public var avatarResizeConfig: ResizeConfig = .low
        public var imageAttachmentResizeConfig: ResizeConfig = .medium
        public var videoAttachmentResizeConfig: VideoResizeConfig = .medium
        
        
        
        
        
        
        
        
        
        
        
        
        // MARK: - Log Level
        public enum LogLevel: Int {
            case none
            case fatal
            case error
            case warning
            case info
            case verbose
        }
        
        public func setLogLevel(_ level: LogLevel) {
            ChatClient.setLogLevel(SceytChat.LogLevel(rawValue: level.rawValue) ?? .none)
        }
        
        // MARK: - Chat Avatar
        public var chatUserDefaultAvatar = UserDefaultAvatarType(
            activeState: .avatar,
            inactiveState: .avatar,
            deletedState: .deletedUser
        )
        public var chatChannelDefaultAvatar = ChannelDefaultAvatarType()
        
                
        // MARK: - Chat Configuration
        public var mentionSymbol = "@"
        public var mentionUserURI = "sceyt://" // "sceyt://userid"
        
        public var jpegDataCompressionQuality = CGFloat(0.8)
        
        
        public var defaultEmojis = ["👍", "😍", "❤️", "🤝", "😂", "😏"]
        public var maxAllowedEmojisCount: UInt = 6
        public var contextMenuContentViewScale = CGAffineTransform(scaleX: 0.95, y: 0.95)
        
        // MARK: - Chat Constants
        public var maximumAttachmentsAllowed = 20
        public var maximumMessagesToSelect = 30
        public var minAutoDownloadSize = 3_000_000
        public var calculateFileChecksum: Bool = true
        public var displayScale = UIScreen.main.traitCollection.displayScale
        
        public var recentReactionsLimit = 30
        public var recentRowLimit = 2
    }
}

// MARK: - Avatar Types
public extension SceytChatUIKit.Config {
    
    struct UserDefaultAvatarType {
        public var activeState: UIImage?
        public var inactiveState: UIImage?
        public var deletedState: UIImage?
        
        public var initialsBuilderAppearance: InitialsBuilderAppearance
        
        public var generateFromInitials: Bool
        
        public init(
            activeState: UIImage? = nil,
            inactiveState: UIImage? = nil,
            deletedState: UIImage? = nil,
            initialsBuilderAppearance: InitialsBuilderAppearance = .init(),
            generateFromInitials: Bool = true) {
                self.activeState = activeState
                self.inactiveState = inactiveState
                self.deletedState = deletedState
                self.initialsBuilderAppearance = initialsBuilderAppearance
                self.generateFromInitials = generateFromInitials
            }
    }
    
    struct ChannelDefaultAvatarType {
        public var `public`: UIImage?
        public var `private`: UIImage?
        public var direct: UIImage?
        
        public var initialsBuilderAppearance: InitialsBuilderAppearance = .init()
        
        public var generateFromInitials: Bool = true
        
        public init(
            public: UIImage? = nil,
            private: UIImage? = nil,
            direct: UIImage? = nil,
            initialsBuilderAppearance: InitialsBuilderAppearance = .init(),
            generateFromInitials: Bool = true) {
                self.`public` = `public`
                self.`private` = `private`
                self.direct = direct
                self.initialsBuilderAppearance = initialsBuilderAppearance
                self.generateFromInitials = generateFromInitials
            }
    }
}

