//
//  DefaultAttachmentTimestampFormatter.swift
//  SceytChatUIKit
//

import Foundation

open class DefaultAttachmentTimestampFormatter: TimestampFormatter {
    
    public init() {}

    open lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("dd.MM.yy HH:mm")
        return formatter
    }()

    open func format(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}
