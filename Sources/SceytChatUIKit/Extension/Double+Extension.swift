//
//  Notification.Name+Extension.swift
//  SceytChatUIKit
//
//  Created by Duc on 21/06/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

extension Double {
    var hours: Double { self * 3600 }
    var days: Double { self * 24.hours }
    var weeks: Double { self * 7.days }
    var months: Double { self * 30.days }
}
