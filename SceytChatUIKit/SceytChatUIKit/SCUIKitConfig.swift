//
//  SCUIKitConfig.swift
//  SceytChatConfig
//
//

import UIKit
import SceytChat

typealias Config = SCUIKitConfig

public struct SCUIKitConfig {
    
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
}

public extension SCUIKitConfig {
    
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

public extension SCUIKitConfig {
    
    static var chatUserDefaultAvatar = UserDefaultAvatarType(deletedState: .deletedUser)
    static var chatChannelDefaultAvatar = ChannelDefaultAvatarType()
    
    typealias Mute = (title: String, timeInterval: TimeInterval)
    static var muteItems = [
        Mute(title: L10n.Channel.Profile.Mute.oneHour, timeInterval: 60 * 60),
        Mute(title: L10n.Channel.Profile.Mute.hours(2), timeInterval: 2 * 60 * 60),
        Mute(title: L10n.Channel.Profile.Mute.oneDay, timeInterval: 24 * 60 * 60),
        Mute(title: L10n.Channel.Profile.Mute.forever, timeInterval: 0)
    ]
    
    static var channelURIPrefix = "sceyt.com/"
}

public extension SCUIKitConfig {
    
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

public extension SCUIKitConfig {
    
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
    
    static var defaultEmojis = ["😎", "😂", "👌🏻", "😍", "👍🏻", "😏"]
}

public extension SCUIKitConfig {
    static var maximumImageSize: CGFloat = 750
    static var maximumImageAttachmentSize: CGFloat = 1080
}
