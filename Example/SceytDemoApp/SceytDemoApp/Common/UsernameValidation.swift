//
//  UsernameValidation.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 16.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation
import UIKit

enum UsernameValidation {
    case tooShort
    case tooLong
    case invalidCharacter
    
    var description: String {
        switch self {
        case .tooShort:
            "Username must be at least 3"
        case .tooLong:
            "Username length must be less than 20 characters"
        case .invalidCharacter:
            "Use a-z, 0-9, and underscores only"
        }
    }
    
    static var attributedDescription: NSAttributedString {
        let fullText = "Use a-z, 0-9 and underscores. Username length must be 3 to 20 characters."
        let attributedText = NSMutableAttributedString(string: fullText)
        
        let fullTextAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: .init(13), weight: .regular),
            .foregroundColor: UIColor.secondaryText.light
        ]
        
        attributedText.addAttributes(fullTextAttributes, range: NSRange(location: 0, length: fullText.count))
        
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: .init(13), weight: .bold),
            .foregroundColor: UIColor.secondaryText.light
        ]
        
        let rangesToBold = [
            ("a-z", fullText),
            ("0-9", fullText),
            ("underscores", fullText),
            ("3 to 20", fullText)
        ]
        
        for (substring, fullText) in rangesToBold {
            if let range = fullText.range(of: substring) {
                let nsRange = NSRange(range, in: fullText)
                attributedText.addAttributes(boldAttributes, range: nsRange)
            }
        }
        return attributedText
    }
    
    static func validateUsername(_ username: String) -> UsernameValidation? {
        if username.count < 3 {
            return .tooShort
        }
        if username.count > 20 {
            return .tooLong
        }
        
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
        let lowercasedUsername = username.lowercased()
        if lowercasedUsername.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return .invalidCharacter
        }
        return nil
    }
}
