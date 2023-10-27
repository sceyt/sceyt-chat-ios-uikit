//
//  ChecksumAlg.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 12.08.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import zlib

public struct ChecksumAlg {
    
    public static func crc32(data: Data) -> UInt {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            log.verbose("[CHECKSUM] CALC \(timeElapsed) s. for bytes: \(data.count)")
        }
        let checksum = data.withUnsafeBytes {
            zlib.crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(data.count))
        }
        return checksum
    }
    
}
