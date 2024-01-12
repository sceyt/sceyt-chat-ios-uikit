//
//  MessagesListSeparator.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

public protocol MessagesListSeparator {

    func format( _ date: Date, showYear: Bool) -> String
}

open class DefaultMessagesListSeparator: MessagesListSeparator {

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

    open func format(_ date: Date, showYear: Bool = false) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.Message.List.separatorToday
        }
        var format = "\(monthFormatter.string(from: date)) \(dayFormatter.string(from: date))"
        if showYear {
            format += ", \(yearFormatter.string(from: date))"
        }
        return format
    }
}
