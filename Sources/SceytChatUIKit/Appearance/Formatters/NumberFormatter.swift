//
//  NumberFormatter.swift
//  SceytChatUIKit
//
//  Created by Duc on 20/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

public protocol NumberFormatter {
    func short(_ count: Int) -> String
}

open class DefaultNumberFormatter: NumberFormatter {
    public init() {}

    open func short(_ count: Int) -> String {
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
