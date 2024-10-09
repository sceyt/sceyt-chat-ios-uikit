//
//  MessageInputViewController+VoiceRecorderView+DotView.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension MessageInputViewController.VoiceRecorderView {
    open class DotView: View {
        public lazy var appearance = Components.messageInputVoiceRecorderView.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.recordingIndicatorColor
        }
        
        open override func layoutSubviews() {
            super.layoutSubviews()
            layer.cornerRadius = height / 2
        }
        
        open func stopAnimating() {
            layer.removeAnimation(forKey: "pulsating")
        }
        
        open func startAnimating() {
            stopAnimating()
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 1
            animation.toValue = 0
            animation.duration = 0.5
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.isRemovedOnCompletion = false
            layer.add(animation, forKey: "pulsating")
        }
    }
}
