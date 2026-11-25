//
//  OneShotCallback.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation

/// Forwards a callback at most once, whichever thread calls it.
///
/// A guard for callbacks that must not repeat: a network request, enqueuing work.
///
/// `Database.write` and `Database.performWriteTask` report completion exactly once (they once
/// reported it from a `defer` that ran before `save()`, so a failed save reported it twice; that
/// is fixed). Callers that start a request from a write's completion keep this wrapper as a cheap
/// safety net against a `Database` implementation that repeats it. It is not needed just to chain
/// writes.
public final class OneShotCallback<Value> {

    private let lock = NSLock()
    private var callback: ((Value) -> Void)?

    public init(_ callback: ((Value) -> Void)?) {
        self.callback = callback
    }

    public func fire(_ value: Value) {
        lock.lock()
        let callback = self.callback
        self.callback = nil
        lock.unlock()
        callback?(value)
    }
}

public typealias OneShotCompletion = OneShotCallback<Error?>
