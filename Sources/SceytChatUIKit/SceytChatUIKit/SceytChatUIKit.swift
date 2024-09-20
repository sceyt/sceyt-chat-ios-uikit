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
    public var theme = SceytChatUIKit.Theme()
    public var formatters = SceytChatUIKit.Formatters()
    
    public var chatClient: ChatClient {
        ChatClient.shared
    }
    
    public var database: Database {
        return _database
    }
    
    private lazy var _database: Database = {
        if let directory = config.storageConfig.databaseFileDirectory {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                print("Error creating directory: \(error.localizedDescription)")
            }
            let dbUrl = directory.appendingPathComponent(config.storageConfig.databaseFilename)
            return PersistentContainer(storeType: .sqLite(databaseFileUrl: dbUrl))
        } else {
            return PersistentContainer(storeType: .inMemory)
        }
    }()
    

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
    
    public func connect(token: String) {
        chatClient.connect(token: token)
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
                database: database,
                chatClient: chatClient
            )
    }()
    
    public var currentUserId: UserId?
}
