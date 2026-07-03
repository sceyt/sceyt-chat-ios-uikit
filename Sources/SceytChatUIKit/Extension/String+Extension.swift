//
//  String+Extension.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension String {

    subscript(i: Int) -> String {
        return self[i ..< i + 1]
    }
    
    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, count) ..< count]
    }
    
    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    subscript(r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(count, r.lowerBound)), upper: min(count, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}

extension NSAttributedString {

    var isEmpty: Bool { self.length == 0 }
}

extension NSAttributedString {

    func trimWhitespacesAndNewlines() -> NSAttributedString {
        attributedStringByTrimmingCharacterSet(charSet: .whitespacesAndNewlines)
    }
    
    func attributedStringByTrimmingCharacterSet(charSet: CharacterSet) -> NSAttributedString {
        let modifiedString = NSMutableAttributedString(attributedString: self)
        modifiedString.trimCharactersInSet(charSet: charSet)
        return NSAttributedString(attributedString: modifiedString)
    }

    func replacingLineBreaksWithSpacesForPreview() -> NSAttributedString {
        guard !isEmpty else { return self }

        let modifiedString = NSMutableAttributedString(attributedString: self)
        let fullRange = NSRange(location: 0, length: modifiedString.length)
        let pattern = "\\n[ \\t]*\\n[\\s\\S]*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return self
        }

        regex
            .matches(in: modifiedString.string, range: fullRange)
            .reversed()
            .forEach { modifiedString.replaceCharacters(in: $0.range, with: "\n...") }

        return modifiedString
    }

}

extension NSMutableAttributedString {
    
    func addAttributeToEntireString(_ name: NSAttributedString.Key, value: Any) {
        var range: NSRange {
            NSRange(location: 0, length: string.utf16.count)
        }
        enumerateAttribute(name, in: range) { existing, subrange, stop in
            if existing == nil {
                addAttribute(name, value: value, range: subrange)
            }
        }
    }
    
    func trimCharactersInSet(charSet: CharacterSet) {
        var range = (string as NSString).rangeOfCharacter(from: charSet as CharacterSet)
        
        // Trim leading characters from character set.
        while range.length != 0 && range.location == 0 {
            replaceCharacters(in: range, with: "")
            range = (string as NSString).rangeOfCharacter(from: charSet)
        }
        
        // Trim trailing characters from character set.
        range = (string as NSString).rangeOfCharacter(from: charSet, options: .backwards)
        while range.length != 0 && NSMaxRange(range) == length {
            replaceCharacters(in: range, with: "")
            range = (string as NSString).rangeOfCharacter(from: charSet, options: .backwards)
        }
    }
    
    func safeReplaceCharacters(in range: NSRange, with str: String) {
        if range.location >= 0, range.length >= 0, range.location + range.length <= length {
            replaceCharacters(in: range, with: str)
        }
    }
    
    func safeReplaceCharacters(in range: NSRange, with attrString: NSAttributedString) {
        if range.location >= 0, range.length >= 0, range.location + range.length <= length {
            replaceCharacters(in: range, with: attrString)
        }
    }
}

extension NSAttributedString.Key {
    static let mention: NSAttributedString.Key = .init("mention")
}
