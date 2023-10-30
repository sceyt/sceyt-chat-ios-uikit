//
//  TimestampFormatter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

public protocol TimestampFormatter {

    func format(_ date: Date) -> String
}

public protocol TimeIntervalFormatter {

    func format(_ timeInterval: TimeInterval) -> String
}
