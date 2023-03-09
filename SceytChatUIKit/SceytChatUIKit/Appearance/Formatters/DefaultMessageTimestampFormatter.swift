//
//  DefaultMessageTimestampFormatter.swift
//  SceytChatUIKit
//

import Foundation

open class DefaultMessageTimestampFormatter: TimestampFormatter {

    public init() {}
    
    open lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        return formatter
    }()

    open func format(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

}
