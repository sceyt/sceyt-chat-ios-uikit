//
//  Atomic.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

/// Safe to share: every access to the value takes its lock.
@propertyWrapper
public final class Atomic<T>: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var value: T

    /// A read takes the lock once; a write — including an in-place one such as
    /// `dict[key] = value`, `set.insert(x)` or `array.append(x)` through the wrapper —
    /// holds the lock for the whole read-modify-write via `_modify`, so concurrent
    /// in-place writes can't overwrite each other.
    public var wrappedValue: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            value = newValue
        }
        _modify {
            lock.lock()
            defer { lock.unlock() }
            yield &value
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
