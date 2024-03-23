//
//  Codable+Extension.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

extension Decodable {
    init(jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        self = try JSONDecoder().decode(Self.self, from: data)
    }
}

extension Encodable {
    
    func jsonString() throws -> String {
        let data = try JSONEncoder().encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }
}
