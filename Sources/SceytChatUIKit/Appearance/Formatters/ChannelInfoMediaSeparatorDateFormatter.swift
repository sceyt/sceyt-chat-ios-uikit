//
//  ChannelInfoMediaSeparatorDateFormatter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class ChannelInfoMediaSeparatorDateFormatter: DateFormatting {

    public init() {}
    
    open lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        return formatter
    }()

    open func format(_ date: Date) -> String {
        dateFormatter.dateFormat = "dd.MM.yy, HH:mm"
        return dateFormatter.string(from: date)
    }
    
    open func header(_ date: Date) -> String {
        dateFormatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return dateFormatter.string(from: date).uppercased()
    }
}
