//
//  Atomic.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

@propertyWrapper
public final class Atomic<T> {
    private let lock = NSRecursiveLock()
    private var value: T

    public var wrappedValue: T {
        get {
            var currentValue: T!
            mutate { currentValue = $0 }
            return currentValue
        }
        set {
            mutate { $0 = newValue }
        }
    }

    public func mutate(_ changes: (_ value: inout T) -> Void) {
        lock.lock()
        changes(&value)
        lock.unlock()
    }

    public init(wrappedValue value: T) {
        self.value = value
    }
}
