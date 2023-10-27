//
//  VideoAssetDurationFormatter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class VideoAssetDurationFormatter: TimeIntervalFormatter {
    public init() {}

    open func format(_ timeInterval: TimeInterval) -> String {
        guard
            !timeInterval.isNaN,
            timeInterval > 0
        else { return "00:00" }

        let interval = Int(timeInterval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        if hours == 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
