//
//  CircularProgressViewForegroundTests.swift
//  SceytChatUIKitTests
//
//  The ring's spin is an infinite animation, and anything that clears the layer's
//  animations ends it for good — UIKit's `prepareForReuse` strips a reused cell's whole
//  subtree, and on its way to the background the app reloads Channel Info (iOS toggles
//  the trait collection to snapshot it). The ring must put its own spin back whenever
//  it should still be spinning, instead of freezing until someone sets `rotateZ` again.
//

@testable import SceytChatUIKit
import QuartzCore
import UIKit
import XCTest

final class CircularProgressViewForegroundTests: XCTestCase {

    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: .init(x: 0, y: 0, width: 100, height: 100))
    }

    override func tearDown() {
        window = nil
        super.tearDown()
    }

    private func spinKeyPath(of view: CircularProgressView) -> String? {
        (view.layer.animation(forKey: "rotationAnimation") as? CABasicAnimation)?.keyPath
    }

    private func makeSpinningView() -> CircularProgressView {
        let view = CircularProgressView()
        view.rotationDuration = 2
        window.addSubview(view) // reaches setupDone(), which installs the spin
        return view
    }

    private func spinRunLoop() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }

    /// What a reused cell's `prepareForReuse` does to every ring in its subtree.
    func testASpinRemovedFromUnderTheRingComesBack() {
        let view = makeSpinningView()
        view.layer.removeAllAnimations()
        XCTAssertNil(view.layer.animation(forKey: "rotationAnimation"))

        spinRunLoop()

        XCTAssertEqual(spinKeyPath(of: view), "transform.rotation.z",
                       "the ring stayed frozen after its spin was removed")
    }

    func testAStoppedRingIsNotRevived() {
        let view = makeSpinningView()
        view.rotateZ = false

        spinRunLoop()

        XCTAssertNil(view.layer.animation(forKey: "rotationAnimation"))
    }

    func testARingOutOfTheWindowIsNotRevived() {
        let view = makeSpinningView()
        view.removeFromSuperview()
        view.layer.removeAllAnimations()

        spinRunLoop()

        XCTAssertNil(view.layer.animation(forKey: "rotationAnimation"))
    }

    /// A removal the ring did not heal (it was out of a window) is healed on the way back.
    func testMovingBackIntoAWindowReinstallsTheSpin() {
        let view = makeSpinningView()
        view.removeFromSuperview()
        view.layer.removeAllAnimations()
        spinRunLoop()

        window.addSubview(view)

        XCTAssertEqual(spinKeyPath(of: view), "transform.rotation.z")
    }

    /// A removal in the background is not healed there; becoming active heals it.
    func testBecomingActiveReinstallsAMissingSpin() {
        let view = makeSpinningView()
        view.layer.removeAnimation(forKey: "rotationAnimation")

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        XCTAssertEqual(spinKeyPath(of: view), "transform.rotation.z")
    }

    func testBecomingActiveLeavesANonSpinningRingAlone() {
        let view = makeSpinningView()
        view.rotateZ = false

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        XCTAssertNil(view.layer.animation(forKey: "rotationAnimation"))
    }
}

/// Channel Info builds its attachments container cell with `init()` (never dequeued), so
/// the cell's own setup must still run on that path.
final class ChannelInfoContainerCellInitTests: XCTestCase {
    func testPlainInitRunsTheCellSetup() {
        let cell = ChannelInfoViewController.ContainerCell()
        XCTAssertEqual(cell.selectionStyle, .none)
        XCTAssertEqual(cell.backgroundColor, .clear)
        XCTAssertNil(cell.reuseIdentifier)
    }
}
