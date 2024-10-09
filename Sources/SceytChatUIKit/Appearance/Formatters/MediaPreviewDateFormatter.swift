//
//  MediaPreviewDateFormatter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class MediaPreviewDateFormatter: DateFormatting {
    
    public init() {}

    open lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy • HH:mm"
        return formatter
    }()

    open func format(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}
