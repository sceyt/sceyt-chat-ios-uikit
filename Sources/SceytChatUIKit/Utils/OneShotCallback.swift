//
//  OneShotCallback.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation

/// Forwards a callback at most once, whichever thread calls it.
///
/// `Database.write` and `Database.performWriteTask` report completion from a `defer` that runs
/// *before* `save()`, so a save failure invokes their completion twice. Wrap anything that must
/// not be repeated — a network request, enqueuing work — in one of these.
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
