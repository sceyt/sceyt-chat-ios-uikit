//
//  CoreDataDate.swift
//  SceytChatUIKit
//

import Foundation

public typealias CDDate = NSDate

internal extension CDDate {
    var bridgeDate: Date {
        Date(timeIntervalSince1970: timeIntervalSince1970)
    }
}

internal extension Date {
    var bridgeDate: CDDate {
        CDDate(timeIntervalSince1970: timeIntervalSince1970)
    }
}
