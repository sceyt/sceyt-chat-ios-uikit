//
//  CircularProgressView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2021 Sceyt LLC. All rights reserved.
//

import UIKit
import Combine

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
    private var appDidBecomeActiveObserver: AnyCancellable?
    
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
        // A spin taken off while the app is in the background is not re-installed there
        // (see `rotateZAnimationDidStop`); bring it back once the app is active again.
        appDidBecomeActiveObserver = NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.ensureRotateZAnimation()
            }
    }

    open override func didMoveToWindow() {
        super.didMoveToWindow()
        // Removals while the ring was out of a window are not healed; heal on the way back.
        ensureRotateZAnimation()
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

    /// Applies a value without the stroke-fill animation.
    ///
    /// Assigning `progress` always animates from whatever it held before, which is right
    /// while the ring is on screen and wrong while it is not: nothing resets the stored
    /// value when the ring is hidden, so seeding a new transfer plays the previous one
    /// rewinding from 100% over the first frames after the ring is shown again.
    open func setProgressWithoutAnimation(_ newValue: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let duration = animationDuration
        animationDuration = 0
        progress = newValue
        animationDuration = duration
        progressLayer.removeAnimation(forKey: "animateprogress")
        CATransaction.commit()
    }
    
    open func createRotateZAnimation() {
        func perform() {
            guard layer.animation(forKey: "rotationAnimation") == nil else { return }
            
            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.duration = rotationDuration
            // Phase-locked to the media clock rather than to the moment of installation.
            // The spin is re-installed whenever the ring's view is rebuilt (a cell reload,
            // the attachment stack recreating its views) or its animations are cleared, and
            // counting from install time made each of those snap the arc back to 12 o'clock
            // mid-transfer. With the offset, a re-installed spin lands on the angle the
            // previous one would have reached.
            if rotationDuration > 0 {
                animation.timeOffset = CACurrentMediaTime()
                    .truncatingRemainder(dividingBy: rotationDuration)
            }
            animation.fromValue = 0
            animation.toValue = CGFloat.pi * 2
            animation.isCumulative = true
            animation.repeatCount = .infinity
            animation.isRemovedOnCompletion = false
            // Told when the spin is taken off the layer, whoever does it — see
            // `rotateZAnimationDidStop`.
            animation.delegate = RotateZAnimationStopObserver(owner: self)
            layer.add(animation, forKey: "rotationAnimation")
        }
        if Thread.isMainThread {
            perform()
        } else {
            DispatchQueue.main.async { perform() }
        }
    }
    
    /// Re-installs a spin that was taken off a ring that should still be spinning.
    ///
    /// The spin is an infinite animation, and anything that clears the layer's animations
    /// ends it for good: UIKit's `prepareForReuse` strips every animation in a reused
    /// cell's subtree, and owners clear their overlays with `removeAllAnimations()`. Core
    /// Animation reports every such removal here, whoever made it, so a spinning ring
    /// heals itself instead of freezing until someone happens to set `rotateZ` again. The
    /// phase lock in `createRotateZAnimation` keeps the arc where it was. In the
    /// background the re-install waits for `didBecomeActive`.
    func rotateZAnimationDidStop() {
        // Next turn of the run loop: the caller may be stopping the spin on purpose and
        // about to set `rotateZ = false`.
        DispatchQueue.main.async { [weak self] in
            guard let self, UIApplication.shared.applicationState != .background else { return }
            self.ensureRotateZAnimation()
        }
    }

    /// Installs the spin if this ring should be spinning and currently is not.
    open func ensureRotateZAnimation() {
        guard isSetupDone, rotateZ, window != nil else { return }
        createRotateZAnimation()
    }

    open func removeRotateZAnimation() {
        layer.removeAnimation(forKey: "rotationAnimation")
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        let rect = bounds.inset(by: contentInsets)
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

/// Forwards the spin's stop to its ring without the animation retaining the ring
/// (`CAAnimation.delegate` is strong, and the ring's layer retains the animation).
private final class RotateZAnimationStopObserver: NSObject, CAAnimationDelegate {
    weak var owner: CircularProgressView?

    init(owner: CircularProgressView) {
        self.owner = owner
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        owner?.rotateZAnimationDidStop()
    }
}
