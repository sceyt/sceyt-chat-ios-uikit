//
//  LogDateFormatter.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 23.09.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

open class LogDateFormatter: DateFormatting {
    
    public init() {}
    
    open lazy var formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter
    }()

    open func format(_ date: Date) -> String {
        formatter.string(from: date)
    }
}
