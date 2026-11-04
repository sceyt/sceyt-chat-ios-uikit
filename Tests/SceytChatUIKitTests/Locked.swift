//
//  Locked.swift
//  SceytChatUIKitTests
//
//  A value a callback sets on one thread and a test reads on another. A captured `var`
//  does the same with no synchronization: a data race Thread Sanitizer reports.
//

import Foundation

final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    var wrapped: Value {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }

    func mutate(_ change: (inout Value) -> Void) {
        lock.lock(); defer { lock.unlock() }
        change(&value)
    }
}
