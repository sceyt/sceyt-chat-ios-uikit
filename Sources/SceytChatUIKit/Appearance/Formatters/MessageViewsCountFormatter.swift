//
//  MessageViewsCountFormatter.swift
//  SceytChatUIKit
//
//  Created by Duc on 20/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class MessageViewsCountFormatter: UIntFormatting {
    
    public init() {}

    open func format(_ count: UInt64) -> String {
        let suffixes = ["", "k", "m", "b", "t"]
        var idx = 0
        var d = Double(count)
        while idx < 4 && abs(d) >= 1000.0 {
            d *= 0.001
            idx += 1
        }
        
        let short = String(format: "%.2f", d).trimmingCharacters(in: .init(charactersIn: "0")).trimmingCharacters(in: .init(charactersIn: ",.")) + suffixes[idx]
        return short.isEmpty ? "0" : short
    }
}
