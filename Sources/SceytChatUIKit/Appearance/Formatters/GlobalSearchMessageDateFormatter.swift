//
//  GlobalSearchMessageDateFormatter.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation

open class GlobalSearchMessageDateFormatter: DateFormatting {

    public init() {}

    open lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    open lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        return formatter
    }()

    open func format(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return timeFormatter.string(from: date)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return dateFormatter.string(from: date)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
