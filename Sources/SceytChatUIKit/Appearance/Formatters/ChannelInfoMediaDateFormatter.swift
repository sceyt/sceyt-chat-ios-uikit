//
//  ChannelInfoMediaDateFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 05.09.24.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class ChannelInfoMediaDateFormatter: DateFormatting {
    
    public init() {}
    
    open lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        return formatter
    }()
    
    open func format(_ date: Date) -> String {
        dateFormatter.dateFormat = "dd.MM.yy, HH:mm"
        return dateFormatter.string(from: date)
    }
}
