//
//  Provider.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class Provider: NSObject {
    
    public static var chatClient = ChatClient.shared
    
    public static var database = Config.database
    
    public var chatClient: ChatClient { Self.chatClient }
    
    public var database: Database { Self.database }
    
    override init() {
        super.init()
    }
}

