//
//  AvatarInitialsFormatter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class AvatarInitialsFormatter: StringFormatting {

    public init() {}
    
    open func format(_ initials: String) -> String {

        let words = initials.components(separatedBy: " ")
            .compactMap { $0.isEmpty ? nil : $0 }
        if words.count > 1 {
            if let first = initials.first {
                if first.isEmoji {
                    return String(first)
                }
                if let second = words[1].first {
                    return String([first, second]).uppercased()
                }
            }
        } else if words.count == 1 {
            return initials.substring(toIndex: 1).uppercased()
        }
        return " "
    }
}
