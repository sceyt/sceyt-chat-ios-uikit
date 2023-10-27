//
//  MessageInfoVM.swift
//  SceytChatUIKit
//
//  Created by Duc on 21/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class MessageInfoVM: NSObject {
    public required init(data: MessageLayoutModel) {
        self.data = data
    }
    
    open var data: MessageLayoutModel
    private lazy var read = data.message.userMarkers?.filter { $0.name == DefaultMarker.displayed } ?? []
    private lazy var delivered = data.message.userMarkers?.filter { $0.name == DefaultMarker.received } ?? []
    
    public var numberOfReads: Int { read.count }
    public var numberOfDelivered: Int { delivered.count }
    
    open func readMarker(at indexPath: IndexPath) -> ChatMessage.Marker {
        read[indexPath.row]
    }
    
    open func deliveredMarker(at indexPath: IndexPath) -> ChatMessage.Marker {
        delivered[indexPath.row]
    }
}
