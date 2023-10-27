//
//  Crypto.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import CommonCrypto

public struct Crypto {

    static func hash(value: String) -> String? {
        if #available(iOS 13.0, *) {
            return value.data(using: .utf8)?.sha256.hexadecimal
        } else {
            return value.data(using: .utf8)?.md5.hexadecimal
        }
    }
    
    static func hash(value: String) -> Int64 {
        guard let data = value.data(using: .utf8)
        else { return 0 }
        
        let hash: Data
        if #available(iOS 13.0, *) {
            hash = data.sha256
        } else {
            hash = data.md5
        }
        return hash.withUnsafeBytes { pointer in
            pointer.load(as: Int64.self)
        }
    }
}

extension Data {
    var hexadecimal: String {
        map { String(format: "%02x", $0) }
            .joined()
    }

    @available(iOS, deprecated: 13.0, message: "'CC_MD5' was deprecated in iOS 13.0: This function is cryptographically broken and should not be used in security contexts. Clients should migrate to SHA256 (or stronger).")
    var md5: Data {
        withUnsafeBytes { dataBuffer in
            var digest = Data(count: Int(CC_MD5_DIGEST_LENGTH))
            digest.withUnsafeMutableBytes { digestBuffer in
                _ = CC_MD5(dataBuffer.baseAddress, CC_LONG(dataBuffer.count), digestBuffer.baseAddress)
            }
            return digest
        }
    }

    var sha256: Data {
        withUnsafeBytes { dataBuffer in
            var digest = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
            digest.withUnsafeMutableBytes { digestBuffer in
                _ = CC_SHA256(dataBuffer.baseAddress, CC_LONG(dataBuffer.count), digestBuffer.baseAddress)
            }
            return digest
        }
    }
}
