//
//  TimestampFormatter.swift
//  SceytChatUIKit
//

import Foundation

public protocol TimestampFormatter {

    func format(_ date: Date) -> String
}

public protocol TimeIntervalFormatter {

    func format(_ timeInterval: TimeInterval) -> String
}
