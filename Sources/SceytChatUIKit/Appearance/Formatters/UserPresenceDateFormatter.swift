//
//  UserPresenceDateFormatter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class UserPresenceDateFormatter: UserFormatting {
    
    public init() {}
    
    lazy var weekDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    open lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
    
    open lazy var dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter
    }()
    
    open lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        formatter.dateStyle = .short
        return formatter
    }()
    
    open func format(_ user: ChatUser) -> String {
        switch user.presence.state {
        case .online:
            return L10n.User.Presence.online
        case .away:
            return L10n.User.Presence.away
        case .dnd:
            return L10n.User.Presence.dnd
        default:
            if let lastActiveAt = user.presence.lastActiveAt {
                return dateAgo(lastActiveAt)
            }
            return ""
        }
    }
    
    private func dateAgo(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            if let minuteAgo = calendar.date(byAdding: .minute, value: -60, to: Date()), minuteAgo < date {
                let diff = Calendar.current.dateComponents([.minute], from: date, to: Date()).minute ?? 0
                if diff <= 1 {
                    return L10n.User.Last.Seen.minAgo(1)
                }
                return L10n.User.Last.Seen.minsAgo(diff)
            } else {
                return L10n.User.Last.seen(timeFormatter.string(from: date))
            }
        } else if calendar.isDateInYesterday(date) {
            return L10n.User.Last.Seen.at(L10n.User.Last.Seen.yesterday, timeFormatter.string(from: date))
        } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()), weekAgo < date {
            return L10n.User.Last.Seen.at(weekDayFormatter.string(from: date), timeFormatter.string(from: date))
        }
        return L10n.User.Last.seen(dateFormatter.string(from: date))
    }
}
