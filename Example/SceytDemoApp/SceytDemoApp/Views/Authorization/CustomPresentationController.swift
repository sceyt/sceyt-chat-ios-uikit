//
//  CustomPresentationController.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 14.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChatUIKit

class CustomPresentationController: EmojiViewPresentationController {
    
    override var smallHeightRatio: CGFloat { 332 / 812 }
    open private(set) var directionY: CGFloat = 0
    
    private var originHeight: CGFloat = 0
    private var velocity: CGFloat = 0
    
    override func panAction(_ pan: UIPanGestureRecognizer) {
        
        guard let containerView, let presentedView else { return }
        
        let endPoint = pan.translation(in: pan.view)
        
        switch pan.state {
        case .began:
            originHeight = presentedView.frame.size.height
        case .changed:
            let velocity = pan.velocity(in: pan.view?.superview)
            
            presentedView.frame.origin.y = endPoint.y + containerView.frame.size.height - (containerView.frame.size.height) * smallHeightRatio - topAnchor
            
            presentedView.frame.origin.y = max(presentedView.frame.origin.y, 0) + topAnchor
            presentedView.frame.size.height = originHeight - endPoint.y
            self.velocity = velocity.y
            if presentedView.frame.height <= 280 {
                presentedViewController.dismiss(animated: true, completion: nil)
            }
        case .ended:
            if velocity < 0 {
                changeState(to: .small)
            } else {
                presentedViewController.dismiss(animated: true, completion: nil)
            }
        default:
            break
        }
    }
    
    override func changeState(to state: EmojiPickerViewController.State) {
        let frame = frameFor(state: state)
        guard frame != .zero else { return }
        guard let presentedView = presentedView else { return }
        
        let initialFrame = presentedView.frame
        let frameChangeInterval: TimeInterval = 1.0 / TimeInterval(UIScreen.main.maximumFramesPerSecond)
        let totalDuration: TimeInterval = 0.1
        let totalSteps = Int(totalDuration / frameChangeInterval)
        
        var currentStep = 0
        
        Timer.scheduledTimer(withTimeInterval: frameChangeInterval, repeats: true) { timer in
            guard currentStep < totalSteps else {
                timer.invalidate()
                return
            }
            
            DispatchQueue.main.async {
                let progress = CGFloat(currentStep) / CGFloat(totalSteps)
                let newX = initialFrame.origin.x + (frame.origin.x - initialFrame.origin.x) * progress
                let newY = initialFrame.origin.y + (frame.origin.y - initialFrame.origin.y) * progress
                let newWidth = initialFrame.size.width + (frame.size.width - initialFrame.size.width) * progress
                let newHeight = initialFrame.size.height + (frame.size.height - initialFrame.size.height) * progress
                
                presentedView.frame = CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
                
            }
            currentStep += 1
        }
        self.state = state
    }
}
