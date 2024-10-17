//
//  String+Extensions.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 16.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

extension Optional where Wrapped == String {
    var isBlank: Bool {
        (self ?? "").trimmedWhitespacesAndNewlines.isEmpty
    }
    
    var isNotBlank: Bool {
        !isBlank
    }
    
    var orEmpty: String { self ?? "" }
    
    var trimmedWhitespacesAndNewlines: String { orEmpty.trimmedWhitespacesAndNewlines }
}

extension Optional where Wrapped: Collection {
    var isEmpty: Bool {
        if let self { return self.isEmpty }
        return true
    }
}

extension String {
    var isBlank: Bool { trimmedWhitespacesAndNewlines.isEmpty }
    var isNotBlank: Bool { !isBlank }
}
extension String {
    var trimmedWhitespacesAndNewlines: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
