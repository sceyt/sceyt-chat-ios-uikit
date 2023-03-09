//
//  DefaultChannelProfileAttachmentTimestamp.swift
//  SceytChatUIKit
//

import Foundation

open class DefaultChannelProfileFileTimestamp: TimestampFormatter {

    public init() {}
    
    open lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("dd/MM/yy")
        return formatter
    }()

    open func format(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
