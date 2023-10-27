//
//  CoreDataDate.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
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
