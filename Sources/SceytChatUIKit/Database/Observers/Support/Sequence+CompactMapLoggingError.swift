//
//  Sequence+CompactMapLoggingError.swift
//  SceytChatUIKit
//
//  Created by Sargis Mkhitaryan on 03.06.26.
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation

extension Sequence {
    func compactMapLoggingError<ElementOfResult>(_ transform: (Element) throws -> ElementOfResult?) -> [ElementOfResult] {
        compactMap {
            do {
                return try transform($0)
            } catch {
                logger.warn("\(error)")
                return nil
            }
        }
    }
}
