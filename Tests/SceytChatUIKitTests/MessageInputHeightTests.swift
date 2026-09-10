//
//  MessageInputHeightTests.swift
//  SceytChatUIKitTests
//
//  Reported (Sept 2026): opening a channel that holds a reply draft showed the reply preview
//  animating in — the bar grew over 0.25s a beat after the push transition had settled.
//
//  The bar itself never animates: it sets its own constraints, forces a layout and reports a
//  height through `onContentHeightUpdate`, and the *parent* wraps that in `UIView.animate`.
//  A draft restore now runs that report synchronously, which only works if reporting reaches a
//  fixed point — the deferred `.contentSizeUpdate` delivery (the subscription is
//  `receive(on:)`-bound, so it always lands a main-queue hop late) has to recompute the height a
//  synchronous settle already installed and be dropped by the parent's equality guard.
//
//  `update(height:)` rounds *up*, so with fractional line heights one pass is not enough: the
//  measured sequence for a four-line body is 109 → 110 → 110 → 110…, i.e. the second pass reaches
//  the fixed point and everything after it is a no-op. That is why the restore iterates
//  (`ChannelViewController.settleInputContentHeight()`), and it is what these tests pin down at
//  the bar's own boundary.
//

@testable import SceytChatUIKit
import SceytChat
import UIKit
import XCTest

final class MessageInputHeightTests: XCTestCase {

    /// Hosts must outlive the test method: the bar reads `view.bounds.height` when it reports,
    /// and a view whose superview went away has no height to report.
    private var hosts = [UIView]()

    private let channelId: ChannelId = 700
    private let hostWidth: CGFloat = 390

    // MARK: Fixture

    /// The bar hosted the way `ChannelViewController` hosts it: pinned leading/trailing/bottom
    /// with an external height constraint that is the sole authority on its height
    /// (`ChannelViewController.swift` pins it and owns `messageInputViewHeightConstraint`).
    private func makeInput() -> (
        input: MessageInputViewController,
        host: UIView,
        height: NSLayoutConstraint
    ) {
        let input = MessageInputViewController()
        let host = UIView(frame: .init(x: 0, y: 0, width: hostWidth, height: 400))
        hosts.append(host)
        host.addSubview(input.view)
        let height = input.view.heightAnchor.constraint(
            equalToConstant: MessageInputViewController.Style.small.preferredMinHeight)
        NSLayoutConstraint.activate([
            input.view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            input.view.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            input.view.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            height
        ])
        host.setNeedsLayout()
        host.layoutIfNeeded()
        return (input, host, height)
    }

    /// Stands in for the parent's `onContentHeightUpdate`, including its equality guard —
    /// which is what makes a redundant report a no-op — and its `completion` contract.
    private final class HeightRecorder {
        var heights = [CGFloat]()
        var count: Int { heights.count }
        func reset() { heights.removeAll() }
    }

    private func install(
        _ recorder: HeightRecorder,
        on input: MessageInputViewController,
        host: UIView,
        height: NSLayoutConstraint
    ) {
        input.onContentHeightUpdate = { [weak host] reported, completion in
            // Mirrors `ChannelViewController`: an unchanged height is dropped entirely,
            // completion included.
            guard reported != height.constant else { return }
            recorder.heights.append(reported)
            height.constant = reported
            host?.setNeedsLayout()
            host?.layoutIfNeeded()
            completion?()
        }
    }

    private func makeModel(body: String = "The message being replied to") -> MessageLayoutModel {
        MessageLayoutModel(
            channel: ChatChannel(id: channelId, type: "group", uri: "input-height"),
            message: ChatMessage(
                id: 7001,
                tid: 7001,
                channelId: channelId,
                body: body,
                type: "text",
                createdAt: Date(),
                incoming: true,
                deliveryStatus: .sent,
                user: ChatUser(id: "other")
            ),
            appearance: MessageCell.appearance
        )
    }

    private func setBody(_ text: String, on input: MessageInputViewController) {
        input.inputTextView.attributedText = NSAttributedString(
            string: text,
            attributes: [.font: UIFont.systemFont(ofSize: 16)])
        input.view.setNeedsLayout()
        input.view.layoutIfNeeded()
    }

    /// One report, the way the deferred `.contentSizeUpdate` delivery makes it.
    private func settle(_ input: MessageInputViewController) {
        input.view.layoutIfNeeded()
        input.update(height: input.inputTextView.contentSize.height)
    }

    /// Mirrors `ChannelViewController.settleInputContentHeight()`: iterate to the fixed point.
    /// Returns how many passes actually moved the bar.
    @discardableResult
    private func settleToFixedPoint(
        _ input: MessageInputViewController,
        height: NSLayoutConstraint
    ) -> Int {
        var settled = height.constant
        for pass in 0 ..< 3 {
            settle(input)
            if height.constant == settled { return pass }
            settled = height.constant
        }
        return 3
    }

    // MARK: The action bar

    func test_addReply_reportsTheActionBarHeightOnceAndSynchronously() {
        let (input, host, height) = makeInput()
        let recorder = HeightRecorder()
        install(recorder, on: input, host: host, height: height)

        let before = height.constant
        input.addReply(layoutModel: makeModel())

        XCTAssertEqual(recorder.count, 1, "the reveal must report exactly one height, inline")
        XCTAssertEqual(
            recorder.heights.first,
            before + MessageInputViewController.Layouts.actionViewHeight,
            "the reported height must be the bar plus the 56pt action row")
        XCTAssertFalse(input.actionView.isHidden)
    }

    func test_addReply_reportsNothingWhenTheActionBarIsAlreadyShowing() {
        let (input, host, height) = makeInput()
        let recorder = HeightRecorder()
        install(recorder, on: input, host: host, height: height)

        input.addReply(layoutModel: makeModel())
        recorder.reset()

        // Swapping the replied-to message keeps the same 56pt row, so nothing moves.
        input.addReply(layoutModel: makeModel(body: "A different message"))

        XCTAssertEqual(recorder.count, 0, "re-targeting a visible action bar must not move it")
    }

    // MARK: Idempotence — the property the non-animated restore rests on

    func test_settlingAMultiLineBody_reachesAFixedPointThenReportsNothing() {
        let (input, host, height) = makeInput()
        let recorder = HeightRecorder()
        install(recorder, on: input, host: host, height: height)

        setBody("line one\nline two\nline three\nline four", on: input)
        let before = height.constant
        let passes = settleToFixedPoint(input, height: height)

        XCTAssertGreaterThan(
            height.constant, before,
            "four lines must be taller than the collapsed bar")
        XCTAssertLessThan(
            passes, 3,
            "the height must reach a fixed point inside the restore's iteration budget")
        XCTAssertGreaterThan(
            passes, 1,
            "documents why the restore iterates: `ceil` leaves a point for a second pass")

        // This is exactly what the deferred `.contentSizeUpdate` delivery recomputes.
        recorder.reset()
        settle(input)
        XCTAssertEqual(
            recorder.count, 0,
            "once settled, a further report recomputes the same height and must be dropped")
    }

    func test_settlingAOneLineBody_leavesTheBarWhereItIs() {
        let (input, host, height) = makeInput()
        let recorder = HeightRecorder()
        install(recorder, on: input, host: host, height: height)

        setBody("Hi", on: input)
        let passes = settleToFixedPoint(input, height: height)

        XCTAssertEqual(passes, 0, "one line needs no correction at all")
        XCTAssertEqual(
            height.constant,
            MessageInputViewController.Style.small.preferredMinHeight,
            "one line must stay at the collapsed height")

        recorder.reset()
        settle(input)
        XCTAssertEqual(recorder.count, 0, "and a further report must be dropped")
    }

    func test_settlingAReplyDraft_reportsTheActionBarAndTheBodyWithNothingLeftOver() {
        let (input, host, height) = makeInput()
        let recorder = HeightRecorder()
        install(recorder, on: input, host: host, height: height)

        // The restore order: body first, then the action bar, then the settle.
        setBody("line one\nline two\nline three", on: input)
        input.addReply(layoutModel: makeModel())
        settleToFixedPoint(input, height: height)

        let settled = height.constant
        XCTAssertGreaterThan(
            settled,
            MessageInputViewController.Style.small.preferredMinHeight
                + MessageInputViewController.Layouts.actionViewHeight,
            "the settled bar must carry both the action row and the grown text")

        recorder.reset()
        settle(input)
        XCTAssertEqual(recorder.count, 0, "nothing must be left for the deferred delivery")
        XCTAssertEqual(height.constant, settled, "and the bar must not move again")
    }

    // MARK: The completion contract

    func test_removingTheActionBarWithASynchronousCompletion_hidesItAndDoesNotStick() {
        let (input, host, height) = makeInput()
        let recorder = HeightRecorder()
        install(recorder, on: input, host: host, height: height)

        input.addReply(layoutModel: makeModel())
        XCTAssertFalse(input.actionView.isHidden)

        // `removeActionView()` hides the bar and clears its re-entrancy flag only from inside
        // the completion — which the non-animated path invokes itself, synchronously.
        input.removeActionView()
        XCTAssertTrue(input.actionView.isHidden, "the completion must have run")
        XCTAssertNil(input.currentState)

        // Proves `isRemovingActionView` came back to false: a second reveal/removal round
        // still works. It would be stuck if the completion had never fired.
        input.addReply(layoutModel: makeModel(body: "Another one"))
        XCTAssertFalse(input.actionView.isHidden)
        input.removeActionView()
        XCTAssertTrue(input.actionView.isHidden)
    }
}
