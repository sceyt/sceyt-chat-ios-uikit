//
//  MessageInfoDateFormatter.swift
//  SceytChatUIKit
//
//  Created by Duc on 31/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class MessageInfoDateFormatter: DateFormatting {
    
    public init() {}
    
    open lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        return formatter
    }()
    
    open lazy var weekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter
    }()
    
    open lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        return formatter
    }()
    
    open func format(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return L10n.Message.List.bordersToday
        }
        
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
