//
//  Provider.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class Provider: NSObject {
    
    public static var chatClient = SceytChatUIKit.shared.chatClient
    
    public static var database = SceytChatUIKit.shared.database
    
    public var chatClient: ChatClient { Self.chatClient }
    
    public var database: Database { Self.database }
    
    override init() {
        super.init()
    }
}

public extension Provider {
    
    func refreshAllObjects(resetStalenessInterval: Bool = true, completion: (() -> Void)? = nil) {
        database.refreshAllObjects(resetStalenessInterval: resetStalenessInterval, completion: completion)
    }
    
    static func refreshAllObjects(resetStalenessInterval: Bool = true, completion: (() -> Void)? = nil) {
        database.refreshAllObjects(resetStalenessInterval: resetStalenessInterval, completion: completion)
    }
}

