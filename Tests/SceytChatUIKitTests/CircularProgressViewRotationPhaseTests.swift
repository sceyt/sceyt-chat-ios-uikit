//
//  CircularProgressViewRotationPhaseTests.swift
//  SceytChatUIKitTests
//
//  The transfer ring's spin is re-installed whenever its view is rebuilt or its animations
//  are cleared. Its phase is taken from the media clock, not from the moment it was
//  installed, so a re-installed spin continues at the angle the arc was already at instead
//  of snapping back to 12 o'clock mid-transfer.
//

@testable import SceytChatUIKit
import QuartzCore
import XCTest

final class CircularProgressViewRotationPhaseTests: XCTestCase {

    private let duration: TimeInterval = 2

    private func makeView() -> CircularProgressView {
        let view = CircularProgressView()
        view.rotationDuration = duration
        view.removeRotateZAnimation()
        view.createRotateZAnimation()
        return view
    }

    private func spin(of view: CircularProgressView) throws -> CABasicAnimation {
        try XCTUnwrap(view.layer.animation(forKey: "rotationAnimation") as? CABasicAnimation,
                      "the ring has no spin installed")
    }

    /// Where the spin is, as a fraction of a turn, `elapsed` seconds after it was installed.
    private func phase(_ animation: CABasicAnimation, elapsed: TimeInterval) -> Double {
        ((elapsed + animation.timeOffset) / duration).truncatingRemainder(dividingBy: 1)
    }

    /// Distance between two phases on the circle, so 0.99 and 0.01 count as close.
    private func distance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 1)
        return min(d, 1 - d)
    }

    func testTheSpinStartsWhereTheSharedClockIs() throws {
        let installedAt = CACurrentMediaTime()
        let animation = try spin(of: makeView())

        let expected = (installedAt / duration).truncatingRemainder(dividingBy: 1)
        XCTAssertLessThan(distance(phase(animation, elapsed: 0), expected), 0.02,
                          "a new spin must start at the clock's angle, not at 12 o'clock")
    }

    /// The reported bug: the ring's view is replaced a quarter of a turn into the spin.
    /// The new one must be at a quarter turn too, not back at the start.
    func testAReinstalledSpinContinuesAtTheSameAngle() throws {
        let first = try spin(of: makeView())
        let quarterTurn = duration / 4
        RunLoop.main.run(until: Date().addingTimeInterval(quarterTurn))

        let second = try spin(of: makeView())

        let whereTheFirstIsNow = phase(first, elapsed: quarterTurn)
        let whereTheSecondStarts = phase(second, elapsed: 0)
        XCTAssertLessThan(distance(whereTheFirstIsNow, whereTheSecondStarts), 0.05,
                          "re-installing the spin moved the arc: \(whereTheFirstIsNow) → \(whereTheSecondStarts)")
    }

    func testClearingAnimationsAndReinstallingKeepsTheAngle() throws {
        let view = makeView()
        let first = try spin(of: view)
        let elapsed = duration * 0.3
        RunLoop.main.run(until: Date().addingTimeInterval(elapsed))

        // What `clearTransferOverlay` and the next `rotateZ = true` do in a live cell. The
        // setter's re-install is gated on `setupDone()`, which an unwindowed view never
        // reaches, so the installer is called directly.
        view.layer.removeAllAnimations()
        view.createRotateZAnimation()
        let second = try spin(of: view)

        XCTAssertLessThan(distance(phase(first, elapsed: elapsed), phase(second, elapsed: 0)), 0.05)
    }
}
