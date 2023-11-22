//
//  AsyncOperation.swift
//  SceytChatUIKit
//
//  Created by Duc on 11/06/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class AsyncOperation: Operation {
    public let uuid: String
    
    public init(_ uuid: String = UUID().uuidString) {
        self.uuid = uuid
    }
    
    private let queue = DispatchQueue(label: "com.sceytchat.uikit.AsyncOperation", attributes: .concurrent)
    
    override public var isAsynchronous: Bool {
        return true
    }
    
    public var timeout: TimeInterval = 0
    
    private var scheduler: Scheduler?
    
    private var _isExecuting: Bool = false
    override public private(set) var isExecuting: Bool {
        get {
            return queue.sync { () -> Bool in
                _isExecuting
            }
        }
        set {
            willChangeValue(forKey: "isExecuting")
            queue.sync(flags: [.barrier]) {
                _isExecuting = newValue
            }
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    private var _isFinished: Bool = false
    override public private(set) var isFinished: Bool {
        get {
            return queue.sync { () -> Bool in
                _isFinished
            }
        }
        set {
            willChangeValue(forKey: "isFinished")
            queue.sync(flags: [.barrier]) {
                _isFinished = newValue
            }
            didChangeValue(forKey: "isFinished")
        }
    }
    
    private var _isCancelled: Bool = false
    override public var isCancelled: Bool {
        _isCancelled
    }
    
    override public func start() {
        logger.debug("[AsyncOperation] Started \(uuid)")
        guard !isCancelled else {
            complete()
            return
        }
        
        isFinished = false
        isExecuting = true
        
        main()
        
        if timeout > 0 {
            scheduler = Scheduler.new(deadline: .now() + timeout,
                                      callback: { [weak self] _ in
                guard let self
                    else { return }
                    if self.isExecuting {
                        self.cancel()
                    }
            }, callbackQueue: .global())
        }
    }
    
    override open func main() {
        fatalError("[AsyncOperation] Subclasses must implement `main` without overriding super.")
    }
    
    open func complete() {
        logger.debug("[AsyncOperation] Completed \(uuid)")
        scheduler?.stop()
        isExecuting = false
        isFinished = true
    }
    
    override open func cancel() {
        logger.debug("[AsyncOperation] Cancelled \(uuid)")
        scheduler?.stop()
        _isCancelled = true
        super.cancel()
    }
}
