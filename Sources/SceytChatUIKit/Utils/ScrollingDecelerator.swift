//
//  ScrollingDecelerator.swift
//  SceytChatUIKit
//
//  Created by Duc on 29/09/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public final class ScrollingDecelerator {
    public weak var scrollView: UIScrollView?
    public var scrollingAnimation: TimerAnimation?
    public let threshold: CGFloat = 0.5

    public init(scrollView: UIScrollView) {
        self.scrollView = scrollView
    }

    public func decelerate(by deceleration: ScrollingDeceleration) {
        guard let scrollView = scrollView else { return }
        let velocity = CGPoint(x: deceleration.velocity.x, y: deceleration.velocity.y * 1000 * threshold)
        let timingParameters = TimingParameters(initialContentOffset: scrollView.contentOffset,
                                                initialVelocity: velocity,
                                                decelerationRate: deceleration.decelerationRate.rawValue,
                                                threshold: threshold)
        scrollingAnimation = TimerAnimation(duration: timingParameters.duration) { [weak scrollView] progress in
            let point = timingParameters.point(at: progress * timingParameters.duration)
            guard let scrollView = scrollView else { return }
            if deceleration.velocity.y < 0 {
                scrollView.contentOffset.y = max(point.y, 0)
            } else {
                scrollView.contentOffset.y = max(0, min(point.y, scrollView.contentSize.height - scrollView.frame.height))
            }
        }
    }

    public func invalidateIfNeeded() {
        guard scrollView?.isUserInteracted == true else { return }
        scrollingAnimation?.invalidate()
        scrollingAnimation = nil
    }

    public struct TimingParameters {
        public let initialContentOffset: CGPoint
        public let initialVelocity: CGPoint
        public let decelerationRate: CGFloat
        public let threshold: CGFloat

        public var duration: TimeInterval {
            guard decelerationRate < 1
                && decelerationRate > 0
                && initialVelocity.length != 0 else { return 0 }

            let dCoeff = 1000 * CoreGraphics.log(decelerationRate)
            return TimeInterval(CoreGraphics.log(-dCoeff * threshold / initialVelocity.length) / dCoeff)
        }

        public func point(at time: TimeInterval) -> CGPoint {
            guard decelerationRate < 1
                && decelerationRate > 0
                && initialVelocity != .zero else { return .zero }

            let dCoeff = 1000 * CoreGraphics.log(decelerationRate)
            return initialContentOffset + (pow(decelerationRate, CGFloat(1000 * time)) - 1) / dCoeff * initialVelocity
        }
    }

    public final class TimerAnimation {
        public typealias Animations = (_ progress: Double) -> Void
        public typealias Completion = (_ isFinished: Bool) -> Void

        public weak var displayLink: CADisplayLink?
        private(set) var isRunning: Bool
        private let duration: TimeInterval
        private let animations: Animations
        private let completion: Completion?
        private let firstFrameTimestamp: CFTimeInterval

        public init(duration: TimeInterval, animations: @escaping Animations, completion: Completion? = nil) {
            self.duration = duration
            self.animations = animations
            self.completion = completion
            firstFrameTimestamp = CACurrentMediaTime()
            isRunning = true
            let displayLink = CADisplayLink(target: self, selector: #selector(step))
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
        }

        public func invalidate() {
            guard isRunning else { return }
            isRunning = false
            stopDisplayLink()
            completion?(false)
        }

        @objc private func step(displayLink: CADisplayLink) {
            guard isRunning else { return }
            let elapsed = CACurrentMediaTime() - firstFrameTimestamp
            if elapsed >= duration
                || duration == 0
            {
                animations(1)
                isRunning = false
                stopDisplayLink()
                completion?(true)
            } else {
                animations(elapsed / duration)
            }
        }

        private func stopDisplayLink() {
            displayLink?.isPaused = true
            displayLink?.invalidate()
            displayLink = nil
        }
    }
}

// MARK: - ScrollingDeceleration

public final class ScrollingDeceleration {
    public let velocity: CGPoint
    public let decelerationRate: UIScrollView.DecelerationRate

    public init(velocity: CGPoint, decelerationRate: UIScrollView.DecelerationRate) {
        self.velocity = velocity
        self.decelerationRate = decelerationRate
    }
}

// MARK: - CGPoint

private extension CGPoint {
    var length: CGFloat {
        return sqrt(x * x + y * y)
    }

    static func * (lhs: CGFloat, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs * rhs.x, y: lhs * rhs.y)
    }
}

// MARK: - UIScrollView

private extension UIScrollView {
    // Indicates that the scrolling is caused by user.
    var isUserInteracted: Bool {
        return isTracking || isDragging || isDecelerating
    }
}
