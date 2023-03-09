//
//  MessagesListSeparator.swift
//  SceytChatUIKit
//

import Foundation

public protocol MessagesListSeparator {

    func format( _ date: Date) -> String
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

    open func format(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.Message.List.separatorToday
        }
        return "\(monthFormatter.string(from: date)) \(dayFormatter.string(from: date))"
    }
}
