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
        SCTUIKitConfig.currentUserId = currentUserId
    }
    SCTUIKitConfig.initialize(apiUrl: Config.sceytApiURL, appId: Config.sceytAppId, clientId: Config.clientId!)
    SCTUIKitConfig.storageDirectory = URL(fileURLWithPath: FileStorage.default.storagePath)
    SCTUIKitConfig.setLogLevel(.verbose)
    
    // Set customized Subclass for formatters
    Formatters.userDisplayName = UserDisplayNameFormatter()
}
