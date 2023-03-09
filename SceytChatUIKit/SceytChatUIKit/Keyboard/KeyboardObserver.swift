//
//  KeyboardObserver.swift
//  SceytChatUIKit
//

import UIKit

public final class KeyboardObserver {

    private var observers = [NSObjectProtocol]()
    private var object: Any?
    private var queue: OperationQueue?

    public init(object: Any? = nil, queue: OperationQueue? = nil) {
        self.object = object
        self.queue = queue
    }

    @discardableResult
    public func willShow(_ callback: @escaping (_ notification: Notification) -> Void) -> Self {
        observers.append(
           observer(forName: UIResponder.keyboardWillShowNotification, callback)
        )
        return self
    }

    @discardableResult
    public func didShow(_ callback: @escaping (_ notification: Notification) -> Void) -> Self {
        observers.append(
            observer(forName: UIResponder.keyboardDidShowNotification, callback)
        )
        return self
    }

    @discardableResult
    public func willHide(_ callback: @escaping (_ notification: Notification) -> Void) -> Self {
        observers.append(
            observer(forName: UIResponder.keyboardWillHideNotification, callback)
        )
        return self
    }

    @discardableResult
    public func didHide(_ callback: @escaping (_ notification: Notification) -> Void) -> Self {
        observers.append(
            observer(forName: UIResponder.keyboardDidHideNotification, callback)
        )
        return self
    }

    @discardableResult
    public func willChangeFrame(_ callback: @escaping (_ notification: Notification) -> Void) -> Self {
        observers.append(
            observer(forName: UIResponder.keyboardWillChangeFrameNotification, callback)
        )
        return self
    }

    @discardableResult
    public func didChangeFrame(_ callback: @escaping (_ notification: Notification) -> Void) -> Self {
        observers.append(
            observer(forName: UIResponder.keyboardDidChangeFrameNotification, callback)
        )
        return self
    }

    private func observer(forName: Notification.Name, _ callback: @escaping (_ notification: Notification) -> Void) -> NSObjectProtocol {
        NotificationCenter
            .default
            .addObserver(forName: forName,
                         object: object,
                         queue: queue) {
            callback($0)
        }
    }
}
