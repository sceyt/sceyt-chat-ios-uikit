//
//  CircularProgressView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2021 Sceyt LLC. All rights reserved.
//

import UIKit

open class CircularProgressView: View {

    open var progressLayer = CAShapeLayer()
    open var trackLayer = CAShapeLayer()
    open var progressColor = appearance.progressColor {
        didSet {
            progressLayer.strokeColor = progressColor?.cgColor
        }
    }
    open var trackColor = appearance.trackColor {
        didSet {
            trackLayer.strokeColor = trackColor?.cgColor
        }
    }
    open var contentInsets: UIEdgeInsets = .zero
    open var animationDuration: TimeInterval = 0
    open var rotationDuration: TimeInterval = 0
    
    private var isSetupDone = false
    
    open var rotateZ = true {
        didSet {
            if isSetupDone {
                if rotateZ {
                    createRotateZAnimation()
                } else {
                    removeRotateZAnimation()
                }
            }
        }
    }
    
    open var isHiddenProgress: Bool {
        set {
            trackLayer.isHidden = newValue
            progressLayer.isHidden = newValue
        }
        get {
            trackLayer.isHidden && progressLayer.isHidden
        }
    }

    open override func setupAppearance() {
        super.setupAppearance()
    
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = appearance.trackColor?.cgColor
        trackLayer.lineWidth = 3.0
        trackLayer.strokeEnd = 1.0

        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = appearance.progressColor?.cgColor
        progressLayer.lineWidth = 3.0
        progressLayer.strokeEnd = 0.0
        progressLayer.lineCap = .round
        layer.addSublayer(trackLayer)
        layer.addSublayer(progressLayer)
    }

    open override func setupDone() {
        super.setupDone()
        isSetupDone = true
        if rotateZ {
            createRotateZAnimation()
        }
    }

    open var progress: CGFloat = 0 {
        didSet {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.duration = animationDuration
            animation.fromValue = oldValue
            animation.toValue = progress
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            progressLayer.strokeEnd = progress
            progressLayer.add(animation, forKey: "animateprogress")
        }
    }
    
    open func createRotateZAnimation() {
        func perform() {
            guard layer.animation(forKey: "rotationAnimation") == nil else { return }
            
            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.duration = rotationDuration
            animation.toValue = CGFloat.pi * 2
            animation.isCumulative = true
            animation.repeatCount = .infinity
            animation.isRemovedOnCompletion = false
            layer.add(animation, forKey: "rotationAnimation")
        }
        if Thread.isMainThread {
            perform()
        } else {
            DispatchQueue.main.async { perform() }
        }
    }
    
    open func removeRotateZAnimation() {
        layer.removeAnimation(forKey: "rotationAnimation")
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.width / 2
        let rect = frame.inset(by: contentInsets)
        let path = UIBezierPath(arcCenter: CGPoint(x: contentInsets.left + rect.width / 2, y: contentInsets.top + rect.height / 2),
                                radius: (rect.width - 1.5) / 2,
                                startAngle: CGFloat(-0.5 * .pi),
                                endAngle: CGFloat(1.5 * .pi),
                                clockwise: true)
            .cgPath
        trackLayer.path = path
        progressLayer.path = path
    }
}
