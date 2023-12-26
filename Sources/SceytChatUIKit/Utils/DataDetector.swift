//
//  DataDetector.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreServices

open class DataDetector {
    
    public class func getLinks(text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))

        return matches.compactMap {
            guard $0.url?.scheme != "mailto",
                  let range = Range($0.range, in: String(text)),
                  let url = URL(string: String(text[range]))
            else { return nil }
            return url
        }
    }
    
    public class func matches(
        text: String,
        types: NSTextCheckingResult.CheckingType = .link) -> [NSTextCheckingResult] {
        guard let detector = try? NSDataDetector(types: types.rawValue) else { return [] }
        return detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
    }

    public class func containsLink(text: String) -> Bool {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return false }
        return detector.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) != nil
    }
    
    public class func matches(text: String) -> [NSTextCheckingResult] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        return detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
    }
}

public extension DataDetector {
    
    class func setAttributes(
        _ attributes: [NSAttributedString.Key: Any]?,
        string: NSMutableAttributedString,
        matches types: NSTextCheckingResult.CheckingType) {
            let matches = matches(text: string.string, types: types)
            for match in matches {
                string.setAttributes(attributes, range: match.range)
            }
    }
    
    class func addAttributes(
        _ attributes: [NSAttributedString.Key: Any],
        string: NSMutableAttributedString,
        matches types: NSTextCheckingResult.CheckingType) {
            let matches = matches(text: string.string, types: types)
            for match in matches {
                string.addAttributes(attributes, range: match.range)
            }
    }
}
