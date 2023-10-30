//
//  Collection+Extension.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public extension Collection where Index == Int {
    
    func chunked(into size: Index.Stride) -> [SubSequence] {
        stride(
            from: startIndex,
            to: endIndex,
            by: size
        )
        .map { index in
            let end = self.index(
                index,
                offsetBy: size,
                limitedBy: self.endIndex
            ) ?? endIndex
            return self[index ..< end]
        }
    }
    
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Sequence where Iterator.Element: Hashable {
    var unique: [Iterator.Element] {
        var seen: [Iterator.Element: Bool] = [:]
        return self.filter { seen.updateValue(true, forKey: $0) == nil }
    }
}
