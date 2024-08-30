//
//  Config.swift
//  SceytDemoApp
//
//  Created by Hovsep Keropyan on 28.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChatUIKit

let users = ["zoe", "thomas", "ethan", "charlie", "william", "michael", "james", "john", "lily", "david", "grace", "emma", "olivia", "ben", "emily", "isabella", "sophia", "alice", "jacob", "harry"]

struct Config {
    static let sceytApiURL = "https://us-ohio-api.sceyt.com"
    static let sceytAppId = "8lwox2ge93"
    static let genToken = "https://tlnig20qy7.execute-api.us-east-2.amazonaws.com/dev/user/genToken?user="
}

extension Config {
    enum UserDefaultsKeys {
        static let clientIdKey = "__demoapp__client__uuid__"
        static let currentUserIdKey = "__demoapp__currentUserIdKey__"
        static let chatToken = "__demoapp_chat_token__"
    }
    @UserDefaultsConfig(UserDefaultsKeys.clientIdKey, defaultValue: UUID().uuidString)
    static var clientId: String?
    
    @UserDefaultsConfig(UserDefaultsKeys.currentUserIdKey)
    static var currentUserId: String?
    
    @UserDefaultsConfig(UserDefaultsKeys.chatToken)
    static var chatToken: String?
}

@propertyWrapper
struct UserDefaultsConfig<T> {
    let key: String
    let defaultValue: T?

    init(_ key: String, defaultValue: T? = nil) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T? {
        get { return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}


func configureSceytChatUIKit() {
    if let currentUserId = Config.currentUserId {
        SceytChatUIKit.shared.currentUserId = currentUserId
    }
    SceytChatUIKit.initialize(apiUrl: Config.sceytApiURL, appId: Config.sceytAppId, clientId: Config.clientId!)
    SceytChatUIKit.shared.config.storageDirectory = URL(fileURLWithPath: FileStorage.default.storagePath)
    SceytChatUIKit.shared.config.setLogLevel(.verbose)
    
//    SCTUIKitComponents.theme = TestTheme.self
    SceytChatUIKit.shared.theme.primaryAccent = .green
    // Set customized Subclass for formatters
    Formatters.userDisplayName = UserDisplayNameFormatter()
}
//import UIKit
//
//public struct TestTheme: SceytChatUIKitThemeProtocol {
//    typealias Light = SceytChatUIKitTheme.Light
//    typealias Dark = SceytChatUIKitTheme.Dark
//    public static var primaryAccent: UIColor = .green
//    public static var secondaryAccent: UIColor = UIColor(light: Light.secondaryAccent, dark: Dark.secondaryAccent)
//    public static var tertiaryAccent: UIColor = UIColor(light: Light.tertiaryAccent, dark: Dark.tertiaryAccent)
//    public static var quaternaryAccent: UIColor = UIColor(light: Light.quaternaryAccent, dark: Dark.quaternaryAccent)
//    public static var quinaryAccent: UIColor = UIColor(light: Light.quinaryAccent, dark: Dark.quinaryAccent)
//    
//    public static var surface1: UIColor = UIColor(light: Light.surface1, dark: Dark.surface1)
//    public static var surface2: UIColor = UIColor(light: Light.surface2, dark: Dark.surface2)
//    public static var surface3: UIColor = UIColor(light: Light.surface3, dark: Dark.surface3)
//    public static var surface3Dark: UIColor = Dark.surface3
//    
//    public static var background: UIColor = UIColor(light: Light.background, dark: Dark.background)
//    public static var backgroundMuted: UIColor = UIColor(light: Light.background, dark: Dark.surface1)
//    public static var backgroundTertiary: UIColor = UIColor(light: Light.surface1, dark: Dark.background)
//    public static var backgroundDark: UIColor = Dark.background
//    public static var borders: UIColor = UIColor(light: Light.borders, dark: Dark.borders)
//    public static var iconInactive: UIColor = UIColor(light: Light.iconInactive, dark: Dark.iconInactive)
//    public static var iconSecondary: UIColor = UIColor(light: Light.iconSecondary, dark: Dark.iconSecondary)
//    public static var overlayBackground50: UIColor = UIColor(light: Light.overlayBackground50, dark: Dark.overlayBackground50)
//    public static var overlayBackground40: UIColor = UIColor(light: Light.overlayBackground40, dark: Dark.overlayBackground40)
//    public static var overlayBackgroundMixed: UIColor = UIColor(light: Light.overlayBackground40, dark: Dark.overlayBackground50)
//    
//    public static var primaryText: UIColor = UIColor(light: Light.primaryText, dark: Dark.primaryText)
//    public static var secondaryText: UIColor = UIColor(light: Light.secondaryText, dark: Dark.secondaryText)
//    public static var footnoteText: UIColor = UIColor(light: Light.footnoteText, dark: Dark.footnoteText)
//    public static var textOnPrimary: UIColor = UIColor(light: Light.textOnPrimary, dark: Dark.textOnPrimary)
//    
//    public static var bubbleOutgoing: UIColor = UIColor(light: Light.bubbleOutgoing, dark: Dark.bubbleOutgoing)
//    public static var bubbleOutgoingX: UIColor = UIColor(light: Light.bubbleOutgoingX, dark: Dark.bubbleOutgoingX)
//    public static var bubbleIncoming: UIColor = UIColor(light: Light.bubbleIncoming, dark: Dark.bubbleIncoming)
//    public static var bubbleIncomingX: UIColor = UIColor(light: Light.bubbleIncomingX, dark: Dark.bubbleIncomingX)
//    
//    public static var stateError: UIColor = UIColor(light: Light.stateError, dark: Dark.stateError)
//    public static var stateSuccess: UIColor = UIColor(light: Light.stateSuccess, dark: Dark.stateSuccess)
//    public static var stateAttention: UIColor = UIColor(light: Light.stateAttention, dark: Dark.stateAttention)
//}
//
