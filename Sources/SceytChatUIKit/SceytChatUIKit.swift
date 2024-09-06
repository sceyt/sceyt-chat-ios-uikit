//
//  SceytChatUIKit.swift
//
//
//  Created by Arthur Avagyan on 07.08.24.
//

import Foundation
import SceytChat

public class SceytChatUIKit {
    
    private init() {}
    
    public static let shared = SceytChatUIKit()
    
    public lazy var config = SceytChatUIKit.Config()
    public var theme: SceytChatUIKit.ThemeProtocol = SceytChatUIKit.Theme()
    public var formatters = SceytChatUIKit.Formatters()
    
    public static func initialize(apiUrl: String, appId: String, clientId: String = "") {
        ChatClient.initialize(apiUrl: apiUrl, appId: appId, clientId: clientId)
        ChatClient.connectionTimeout = 10
        ChatClient.setCompletionHandler(queue: DispatchQueue.main)
        ChatClient.setDelegate(queue: DispatchQueue.main)
        ChatClient.networkAwareReconnection = true
        shared.channelEventHandler.startEventHandler()
    }
    
    public var isConnected: Bool {
        chatClient.connectionState == .connected
    }
    
    public func connect(accessToken: String) {
        chatClient.connect(token: accessToken)
    }
    
    public func reconnect() -> Bool {
        chatClient.reconnect()
    }
    
    public func disconnect() {
        chatClient.disconnect()
    }
    
    public func registerDevicePushToken(_ pushToken: Data, completion: ((Error?) -> Void)?) {
        chatClient.registerDevicePushToken(pushToken, completion: completion)
    }
    
    public func unregisterDevicePushToken(_ pushToken: Data, completion: ((Error?) -> Void)? ) {
        chatClient.unregisterDevicePushToken(completion: completion)
    }
    
    public lazy var channelEventHandler: ChannelEventHandler = {
        Components.channelEventHandler
            .init(
                database: config.database,
                chatClient: ChatClient.shared
            )
    }()
    
    public var currentUserId: UserId?
}
