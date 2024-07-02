//
//  ChannelVC+DisplayedTimer.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 20.06.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//


import UIKit

extension ChannelVC {
    
    open class DisplayedTimer: NSObject {
        
        public var timeInterval: TimeInterval = 0.1
        public private(set) var timer: Timer?
        public private(set) var isStarted = false
        
        public init(timeInterval: TimeInterval = 0.1) {
            self.timeInterval = timeInterval
        }
        
        open func start(fire: @escaping ((DisplayedTimer) -> Void)) {
            isStarted = true
            timer?.invalidate()
            timer = Timer(
                timeInterval: timeInterval,
                repeats: true,
                block: { [weak self] timer in
                    if let self {
                        fire(self)
                    }
            })
            RunLoop.main.add(timer!, forMode: .common)
        }
        
        open func stop() {
            isStarted = false
            if timer?.isValid == true {
                timer?.invalidate()
                timer = nil
            }
        }
    }
}
