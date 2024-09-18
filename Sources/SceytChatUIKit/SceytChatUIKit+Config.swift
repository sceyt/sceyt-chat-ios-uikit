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
    public struct Config {
        
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
        
        // MARK: - Option Items
        public typealias OptionItem = (title: String, timeInterval: TimeInterval)
        public var muteItems = [
            OptionItem(title: L10n.Channel.Profile.Mute.oneHour, timeInterval: 60 * 60),
            OptionItem(title: L10n.Channel.Profile.Mute.hours(2), timeInterval: 2 * 60 * 60),
            OptionItem(title: L10n.Channel.Profile.Mute.oneDay, timeInterval: 24 * 60 * 60),
            OptionItem(title: L10n.Channel.Profile.Mute.forever, timeInterval: 0)
        ]
        public var autoDeleteItems = [
            OptionItem(title: L10n.Channel.Profile.AutoDelete.off, timeInterval: 0),
            OptionItem(title: L10n.Channel.Profile.AutoDelete.oneMin, timeInterval: 60),
            OptionItem(title: L10n.Channel.Profile.AutoDelete.oneHour, timeInterval: 60 * 60),
            OptionItem(title: L10n.Channel.Profile.AutoDelete.oneDay, timeInterval: 24 * 60 * 60)
        ]
        
        // MARK: - Channel Property Configuration
        public var channelURIPrefix = "@"
        
        public var privateChannel = "group"
        public var broadcastChannel = "broadcast"
        public var directChannel = "direct"
        
        public var syncChannelsAfterConnect: Bool = true
        
        public var shouldHardDeleteMessageForAll: Bool = false
        
        // MARK: - Database Configuration
        public var storageDirectory: URL? = {
            if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
                return URL(fileURLWithPath: path)
            }
            return nil
        }()
        
        public var dbFilename = "chatdb"
        
        public var dbFileDirectory: URL? = {
            if let path = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first {
                return URL(fileURLWithPath: path)
            }
            return nil
        }()
        
        public lazy var database: Database = {
            if let directory = dbFileDirectory {
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                } catch {
                    
                }
                let dbUrl = directory.appendingPathComponent(dbFilename)
                return PersistentContainer(storeType: .sqLite(databaseFileUrl: dbUrl))
            } else {
                return PersistentContainer(storeType: .inMemory)
            }
        }()
        
        // MARK: - Chat Configuration
        public var mentionSymbol = "@"
        public var mentionUserURI = "sceyt://" // "sceyt://userid"
        
        public var jpegDataCompressionQuality = CGFloat(0.8)
        
        public var channelURIMinLength = 5
        public var channelURIMaxLength = 50
        public var channelURIRegex = "^[a-zA-Z0-9_]*$"
        public var channelRoleSubscriber = "subscriber"
        public var groupRoleParticipant = "participant"
        public var chatRoleOwner = "owner"
        public var chatRoleAdmin = "admin"
        
        public var defaultEmojis = ["👍", "😍", "❤️", "🤝", "😂", "😏"]
        public var maxAllowedEmojisCount: UInt = 6
        public var contextMenuContentViewScale = CGAffineTransform(scaleX: 0.95, y: 0.95)
        
        // MARK: - Chat Constants
        public var messagePossibleEditIn: TimeInterval = 3600
        public var maximumImageSize: CGFloat = 750
        public var maximumImageAttachmentSize: CGFloat = 1080
        public var maximumAttachmentsAllowed = 20
        public var maximumMessagesToSelect = 30
        public var minAutoDownloadSize = 3_000_000
        public var calculateFileChecksum: Bool = true
        public var displayScale = UIScreen.main.traitCollection.displayScale
        
        public var userDefaults = UserDefaults.standard
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

