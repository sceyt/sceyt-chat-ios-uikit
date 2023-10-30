//
//  Scheduler.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

public final class Scheduler {
    private var timer: DispatchSourceTimer!
    private init(timer: DispatchSourceTimer) {
        self.timer = timer
    }
    
    @discardableResult
    public static func new(deadline: DispatchTime = .now(),
                           repeating interval: DispatchTimeInterval = .never,
                           leeway: DispatchTimeInterval = .nanoseconds(0),
                           callback: ((Scheduler) -> Void)? = nil,
                           callbackQueue: DispatchQueue = .main
    ) -> Scheduler  {
        
        let queue = DispatchQueue(label: "com.sceytchat.uikit.scheduler", attributes: .concurrent)
        let timerSource = DispatchSource.makeTimerSource(queue: queue)
        timerSource.schedule(deadline: deadline, repeating: interval, leeway: leeway)
        var s: Scheduler? = Scheduler(timer: timerSource)
        timerSource.setEventHandler(handler: {
            if callback == nil {
                s?.stop()
                s = nil
            } else if let _s = s {
                callbackQueue.async {
                    callback?(_s)
                }
            }
        })
        timerSource.resume()
        return s!
    }
    
    public func stop() {
        guard let timerSource = timer else { return }
        if !timerSource.isCancelled {
            timerSource.cancel()
        }
        timer = nil
    }
    
    public var isCancelled: Bool {
        timer?.isCancelled ?? true
    }
    
    public func resume() {
        timer?.resume()
    }

    public func suspend() {
        timer?.suspend()
    }
    
    deinit {
        stop()
    }
    
}
