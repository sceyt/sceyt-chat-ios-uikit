//
//  ChannelTimestampFormatter.swift
//  SceytChatUIKit
//

import Foundation

open class DefaultChannelTimestampFormatter: TimestampFormatter {

    public init() {}
    
    open lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        return formatter
    }()

    open lazy var weekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    open lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("dd/MM/yy")
        return formatter
    }()

    open func format(_ date: Date) -> String {

        let calendar = Calendar.current
        let date1 = calendar.startOfDay(for: date)
        let date2 = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.day], from: date1, to: date2)

        guard let day = components.day else { return "" }
        let dateString: String
        switch day {
        case 7...:
            dateString = dateFormatter.string(from: date)
        case 1..<7:
            dateString = weekFormatter.string(from: date)
        default:
            dateString = timeFormatter.string(from: date)
        }
        return dateString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
