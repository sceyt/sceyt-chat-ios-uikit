//
//  MessageDateSeparatorFormatter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class MessageDateSeparatorFormatter: DateFormatting {

    public init() {}
    
    open lazy var dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("d")
        return formatter
    }()

    open lazy var monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter
    }()
    
    open lazy var yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    open func format(_ date: Date) -> String {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let dateYear = calendar.component(.year, from: date)
        
        if calendar.isDateInToday(date) {
            return L10n.Message.List.bordersToday
        }
        var format = "\(monthFormatter.string(from: date)) \(dayFormatter.string(from: date))"
        if dateYear < currentYear {
            format += ", \(yearFormatter.string(from: date))"
        }
        return format
    }
}
