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
        public var timer: Timer?
        
        open func start(fire: @escaping ((DisplayedTimer) -> Void)) {
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
            if timer?.isValid == true {
                timer?.invalidate()
                timer = nil
            }
        }
    }
}
