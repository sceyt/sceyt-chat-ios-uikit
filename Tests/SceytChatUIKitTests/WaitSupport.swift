//
//  WaitSupport.swift
//  SceytChatUIKitTests
//
//  Shared by the test classes' `waitUntil` helpers, which poll a condition while the main
//  run loop turns.
//

import Foundation

/// The default `waitUntil` timeout. A passing condition returns as soon as it holds, so this
/// only bounds a failure. 10 s, not less: CI runners stall for seconds at a time (a 5.7 s gap
/// between two adjacent statements was logged), and a stall spends the wait on nothing.
let defaultWaitTimeout: TimeInterval = 10

/// Called once a wait's deadline has passed: gives the main queue a few more short turns
/// (≤ 0.25 s) to deliver work that is already queued there. A runner stall can use up the
/// whole wait and leave the completion queued on main, so the last check would fail just
/// before the work the test waited for lands.
func drainMainQueueAfterDeadline(until condition: () -> Bool) {
    for _ in 0..<5 where !condition() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
}
