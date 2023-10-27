//
//  SCTUIKitConfig.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

typealias Config = SCTUIKitConfig

public struct SCTUIKitConfig {
    
    public static func initialize(apiUrl: String, appId: String, clientId: String = "") {
        ChatClient.initialize(apiUrl: apiUrl, appId: appId, clientId: clientId)
        ChatClient.connectionTimeout = 10
        ChatClient.setCompletionHandler(queue: DispatchQueue.main)
        ChatClient.setDelegate(queue: DispatchQueue.main)
        ChatClient.networkAwareReconnection = true
        channelEventHandler.startEventHandler()
    }
    
    public static var isConnected: Bool {
        chatClient.connectionState == .connected
    }
    
    public static func connect(accessToken: String) {
        chatClient.connect(token: accessToken)
    }
    
    public static func reconnect() -> Bool {
        chatClient.reconnect()
    }
    
    public static func disconnect() {
        chatClient.disconnect()
    }
    
    public static func registerDevicePushToken(_ pushToken: Data, completion: ((Error?) -> Void)?) {
        chatClient.registerDevicePushToken(pushToken, completion: completion)
    }
    
    public static func unregisterDevicePushToken(_ pushToken: Data, completion: ((Error?) -> Void)? ) {
        chatClient.unregisterDevicePushToken(completion: completion)
    }
    
    public static var channelEventHandler: ChannelEventHandler = {
        Components.channelEventHandler
            .init(
                database: Config.database,
                chatClient: ChatClient.shared
            )
    }()
    
    public static var currentUserId: UserId?
    
    public static var syncChannelsAfterConnect: Bool = false
}

public extension SCTUIKitConfig {
    
    enum LogLevel: Int {
        case none
        case fatal
        case error
        case warning
        case info
        case verbose
    }
    
    static func setLogLevel(_ level: LogLevel) {
        ChatClient.setLogLevel(SceytChat.LogLevel(rawValue: level.rawValue) ?? .none)
    }
}

public extension SCTUIKitConfig {
    
    static var chatUserDefaultAvatar = UserDefaultAvatarType(
        activeState: Assets.avatar.image,
        inactiveState: Assets.avatar.image,
        deletedState: .deletedUser
    )
    static var chatChannelDefaultAvatar = ChannelDefaultAvatarType()
    
    typealias OptionItem = (title: String, timeInterval: TimeInterval)
    static var muteItems = [
        OptionItem(title: L10n.Channel.Profile.Mute.oneHour, timeInterval: 60 * 60),
        OptionItem(title: L10n.Channel.Profile.Mute.hours(2), timeInterval: 2 * 60 * 60),
        OptionItem(title: L10n.Channel.Profile.Mute.oneDay, timeInterval: 24 * 60 * 60),
        OptionItem(title: L10n.Channel.Profile.Mute.forever, timeInterval: 0)
    ]
    static var autoDeleteItems = [
        OptionItem(title: L10n.Channel.Profile.AutoDelete.off, timeInterval: 0),
        OptionItem(title: L10n.Channel.Profile.AutoDelete.oneMin, timeInterval: 60),
        OptionItem(title: L10n.Channel.Profile.AutoDelete.oneHour, timeInterval: 60 * 60),
        OptionItem(title: L10n.Channel.Profile.AutoDelete.oneDay, timeInterval: 24 * 60 * 60)
    ]
    
    static var channelURIPrefix = "@"
    
    static var privateChannel = "group"
    static var broadcastChannel = "broadcast"
    static var directChannel = "direct"
    
}

public extension SCTUIKitConfig {
    
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

public extension SCTUIKitConfig {
    
    static var storageDirectory: URL? = {
        if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            return URL(fileURLWithPath: path)
        }
        return nil
    }()
    
    static var dbFilename = "chatdb"
    
    static var database: Database = {
        if let storageDirectory = storageDirectory {
            do {
                try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            } catch {
                
            }
            let dbUrl = storageDirectory.appendingPathComponent(dbFilename)
            return PersistentContainer(storeType: .sqLite(databaseFileUrl: dbUrl))
        } else {
            return PersistentContainer(storeType: .inMemory)
        }
    }()
    
    static var mentionSymbol = "@"
    static var mentionUserURI = "sceyt://" // "sceyt://userid"
    
    static var jpegDataCompressionQuality = CGFloat(0.8)
    
    static var channelURIMinLength = 5
    static var channelURIMaxLength = 50
    static var channelURIRegex = "^[a-zA-Z0-9_]*$"
    static var channelRoleSubscriber = "subscriber"
    static var groupRoleParticipant = "participant"
    static var chatRoleOwner = "owner"
    static var chatRoleAdmin = "admin"
    
    static var defaultEmojis = ["👍", "😍", "❤️", "🤝", "😂", "😏"]
    static var maxAllowedEmojisCount: UInt = 6
    static var contextMenuContentViewScale = CGAffineTransform(scaleX: 0.95, y: 0.95)
}

public extension SCTUIKitConfig {
    static var messagePossibleEditIn: TimeInterval = 3600
    static var maximumImageSize: CGFloat = 750
    static var maximumImageAttachmentSize: CGFloat = 1080
    static var maximumAttachmentsAllowed = 20
    static var maximumMessagesToSelect = 30
    static var minAutoDownloadSize = 3_000_000
    static var calculateFileChecksum: Bool = true
    static var calculateChecksumMaxBytes = 3_000_000
    static var displayScale = UIScreen.main.traitCollection.displayScale
}

public extension SCTUIKitConfig {
    static var userDefaults = UserDefaults.standard
    static var recentReactionsLimit = 30
    static var recentRowLimit = 2
}
