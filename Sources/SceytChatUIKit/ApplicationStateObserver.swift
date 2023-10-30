//
//  ApplicationStateObserver.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 20.06.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

final class ApplicationStateObserver: NSObject {
    
    override init() {
        super.init()
        addObservers()
    }
    
    private var observers = [NSObjectProtocol]()
    private var object: Any?
    private var queue: OperationQueue?

    public init(object: Any? = nil, queue: OperationQueue? = nil) {
        self.object = object
        self.queue = queue
    }
    
    private(set) var isAppActive = true
    
    private func addObservers() {
      
    }
    
    @discardableResult
    public func willTerminate(_ callback: @escaping (_ notification: Notification) -> Void) -> Self {
        observers.append(
            observer(forName: UIApplication.willTerminateNotification, callback)
        )
        return self
    }
    
    @discardableResult
    public func willResignActive(_ callback: @escaping (_ notification: Notification) -> Void) -> Self {
        observers.append(
            observer(forName: UIApplication.willResignActiveNotification, callback)
        )
        return self
    }
    
    @discardableResult
    public func didBecomeActive(_ callback: @escaping (_ notification: Notification) -> Void) -> Self {
        observers.append(
            observer(forName: UIApplication.didBecomeActiveNotification, callback)
        )
        return self
    }
    
    @discardableResult
    public func didFinishLaunching(_ callback: @escaping (_ notification: Notification) -> Void) -> Self {
        observers.append(
            observer(forName: UIApplication.didFinishLaunchingNotification, callback)
        )
        return self
    }
    
    @discardableResult
    public func willEnterForeground(_ callback: @escaping (_ notification: Notification) -> Void) -> Self {
        observers.append(
            observer(forName: UIApplication.willEnterForegroundNotification, callback)
        )
        return self
    }
    
    @discardableResult
    public func didEnterBackground(_ callback: @escaping (_ notification: Notification) -> Void) -> Self {
        observers.append(
            observer(forName: UIApplication.didEnterBackgroundNotification, callback)
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

