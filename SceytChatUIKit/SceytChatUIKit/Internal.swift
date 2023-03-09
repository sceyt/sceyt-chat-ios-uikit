//
//  Internal.swift
//  SceytChatUIKit
//

import Foundation

internal func instance<T>(of type: T) -> T {
    ClassRepository.default.instance(of: type) ?? type
}
