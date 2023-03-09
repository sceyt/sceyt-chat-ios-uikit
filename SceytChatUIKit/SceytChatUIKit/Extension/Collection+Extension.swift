//
//  Collection+Extension.swift
//  SceytChatUIKit
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
}
