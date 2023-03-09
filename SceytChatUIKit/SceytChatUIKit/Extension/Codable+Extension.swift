//
//  Codable+Extension.swift
//  SceytChatUIKit
//

import Foundation

extension Encodable {
    
    func jsonString() throws -> String {
        let data = try JSONEncoder().encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }
}
