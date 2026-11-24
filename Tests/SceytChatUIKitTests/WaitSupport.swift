//
//  WaitSupport.swift
//  SceytChatUIKitTests
//
//  Shared by the test classes' `waitUntil` helpers, which poll a condition while the main
//  run loop turns.
//

import Foundation

/// The default timeout of every wait for something that must happen (`waitUntil` and XCTest
/// expectations). A passing wait returns as soon as its condition holds, so this only bounds
/// a failure. 30 s: slow CI runners were seen taking over 10 s for work that takes
/// milliseconds locally (a 5.7 s gap between two adjacent statements, about one database
/// write a second). Waits that check something does *not* happen keep their own short time.
let defaultWaitTimeout: TimeInterval = 30

/// Called once a wait's deadline has passed: gives the main queue a few more short turns
/// (≤ 0.25 s) to deliver work that is already queued there. A runner stall can use up the
/// whole wait and leave the completion queued on main, so the last check would fail just
/// before the work the test waited for lands.
func drainMainQueueAfterDeadline(until condition: () -> Bool) {
    for _ in 0..<5 where !condition() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
}
