//
//  VideoAttachmentProgressPlayButtonTests.swift
//  SceytChatUIKitTests
//
//  Two rules for the transfer overlay a received video draws over its thumbnail:
//
//  1. The ring never runs backwards. Progress reaches the cell from more than one place —
//     the transfer's own stream, `AttachmentStackView.bind`'s floor seed, the status relay
//     reading the transfer's cached percent — each with its own latency, so an older value
//     can land after a newer one. Rendered as an animated `strokeEnd`, that is the bar
//     visibly rewinding a moment before the download finishes and then filling again.
//
//  2. The ring and the play button never share the thumbnail. They are the same size and
//     both centered (their dimensions are pinned to each other), so any overlap is the play
//     glyph drawn straight through a full circle. The play button belongs *after* the ring's
//     shrink-out, not at the start of it.
//

@testable import SceytChatUIKit
import SceytChat
import XCTest

final class VideoAttachmentProgressPlayButtonTests: XCTestCase {

    private var session: MockTransferDataSession!
    private var originalDataSession: SCTDataSession?
    private var temporaryFiles = [String]()

    private let channelId: ChannelId = 401
    private let messageId: MessageId = 4011
    private let attachmentId: AttachmentId = 851_649_417_420_390_778
    private let attachmentUrl = "https://cdn.example/9B7C31/clip.mp4"

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalDataSession = Components.dataSession
        session = MockTransferDataSession()
        Components.dataSession = session
    }

    override func tearDownWithError() throws {
        for path in temporaryFiles {
            try? FileManager.default.removeItem(atPath: path)
        }
        temporaryFiles.removeAll()
        Components.dataSession = originalDataSession
        session = nil
        try super.tearDownWithError()
    }

    // MARK: - Fixtures

    private func makeModel(
        status: ChatMessage.Attachment.TransferStatus = .downloading
    ) -> MessageLayoutModel {
        let attachment = ChatMessage.Attachment(
            id: attachmentId,
            tid: 0,
            messageId: messageId,
            userId: "user",
            url: attachmentUrl,
            filePath: nil,
            type: "video",
            name: "clip.mp4",
            metadata: nil,
            uploadedFileSize: 5_318_259,
            createdAt: Date(),
            status: status,
            transferProgress: 0
        )
        return MessageLayoutModel(
            channel: ChatChannel(id: channelId, type: "group", uri: "video-overlay"),
            message: ChatMessage(
                id: messageId,
                channelId: channelId,
                attachments: [attachment],
                user: ChatUser(id: "u1")
            ),
            appearance: MessageCell.appearance
        )
    }

    private func makeBoundVideoView(
        _ model: MessageLayoutModel
    ) throws -> (MessageCell.AttachmentStackView, MessageCell.AttachmentVideoView) {
        let stack = MessageCell.AttachmentStackView()
        stack.data = model
        let view = try XCTUnwrap(
            stack.subviews.compactMap { $0 as? MessageCell.AttachmentVideoView }.first,
            "the stack view created no video attachment view to inspect")
        return (stack, view)
    }

    /// Real bytes, in the folder a real download lands in — this is what makes the
    /// attachment playable, and so the play button eligible to be shown.
    @discardableResult
    private func makeFileOnDisk() throws -> String {
        let directory = URL(fileURLWithPath: Components.storage.storingKey.storageFolderPath)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory
            .appendingPathComponent("video-overlay-\(UUID().uuidString)-clip.mp4").path
        try Data(repeating: 0x1, count: 2048).write(to: URL(fileURLWithPath: path))
        temporaryFiles.append(path)
        session.setLocalPath(path, forUrl: attachmentUrl)
        return path
    }

    /// Pumps the main run loop — the overlay's fill-through delay and shrink-out are a
    /// `DispatchQueue.main.asyncAfter` and a `UIView` animation.
    private func pump(_ duration: TimeInterval, onEachStep: () -> Void = {}) {
        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            onEachStep()
        }
    }

    private func overlayDescription(_ view: MessageCell.AttachmentVideoView) -> String {
        "progressView.isHidden=\(view.progressView.isHidden) "
        + "isHiddenProgress=\(view.progressView.isHiddenProgress) "
        + "progress=\(view.progressView.progress) "
        + "playButton.isHidden=\(view.playButton.isHidden)"
    }

    // MARK: - 1. The ring is monotonic

    /// The shape of the bug as reported: a late, lower value arriving while the ring is
    /// nearly full. It must be dropped, not animated to.
    func testALateLowerTickDoesNotRewindTheRing() throws {
        let (_, view) = try makeBoundVideoView(makeModel())

        view.setProgress(CGFloat(0.94))
        XCTAssertEqual(view.progressView.progress, 0.94, accuracy: 0.0001)

        view.setProgress(CGFloat(0.62))

        XCTAssertEqual(view.progressView.progress, 0.94, accuracy: 0.0001,
                       "a tick older than the one already drawn must not move the ring: \(overlayDescription(view))")
    }

    /// `AttachmentStackView.bind` seeds a floor of 0.0001 for an active transfer it has no
    /// cached percent for. On an in-place rebind near the end of a download that floor used
    /// to reset the ring to empty — the "backward, then forward again" the user sees.
    func testRebindingMidDownloadDoesNotResetTheRingToItsFloor() throws {
        let model = makeModel()
        let (stack, view) = try makeBoundVideoView(model)

        view.setProgress(CGFloat(0.91))
        stack.data = model

        XCTAssertGreaterThanOrEqual(view.progressView.progress, 0.91,
                                    "a rebind must not rewind a ring that is nearly full: \(overlayDescription(view))")
    }

    /// The monotonic rule is scoped to the transfer on screen: once the overlay is gone,
    /// a new transfer must be able to draw its ring from the bottom again.
    func testANewTransferStartsFromTheBottomAgain() throws {
        let (_, view) = try makeBoundVideoView(makeModel())

        view.setProgress(CGFloat(0.8))
        view.clearTransferOverlay()
        view.setProgress(CGFloat(0.05))

        XCTAssertEqual(view.progressView.progress, 0.05, accuracy: 0.0001,
                       "the mark belongs to one transfer, not to the view: \(overlayDescription(view))")
        XCTAssertFalse(view.progressView.isHidden, "the new transfer's ring must be on screen")
    }

    /// A pause takes the ring's stroke off screen, so the value it froze at is no longer
    /// something a resumed transfer can regress from.
    func testResumingAfterAPauseCanDrawFromWhereTheTransferRestarts() throws {
        let (_, view) = try makeBoundVideoView(makeModel())

        view.setProgress(CGFloat(0.9))
        view.update(status: .pauseDownloading)
        XCTAssertEqual(view.progressView.progress, 0.9, accuracy: 0.0001,
                       "pausing must not animate the ring back down to empty: \(overlayDescription(view))")

        view.update(status: .downloading)
        view.setProgress(CGFloat(0.2))

        XCTAssertEqual(view.progressView.progress, 0.2, accuracy: 0.0001,
                       "a transfer that restarts from the beginning must be renderable: \(overlayDescription(view))")
    }

    // MARK: - 2. The ring and the play button are mutually exclusive

    /// The overlap as reported. `willHideProgressView` is the frame the shrink-out starts
    /// on — the ring is still on screen, drawn at 100% — and the play button used to be
    /// revealed right there, giving the two of them the middle of the thumbnail for the
    /// length of the animation.
    ///
    /// Driven through the hook rather than by sampling the animation: an unwindowed view's
    /// animations collapse to a single frame under test, so there is no window to sample.
    func testPlayButtonIsNotRevealedWhileTheRingIsStillOnScreen() throws {
        try makeFileOnDisk()
        let (_, view) = try makeBoundVideoView(makeModel())

        view.setProgress(CGFloat(0.5))
        XCTAssertFalse(view.progressView.isHidden, "precondition: a running download shows its ring")
        XCTAssertTrue(view.playButton.isHidden,
                      "the play button has no business on a downloading video: \(overlayDescription(view))")

        view.setProgress(CGFloat(1))
        view.willHideProgressView()

        XCTAssertFalse(view.progressView.isHidden,
                       "precondition: the shrink-out has not finished yet: \(overlayDescription(view))")
        XCTAssertTrue(view.playButton.isHidden,
                      "the ring is still up at 100% — the play button must wait for it to go: \(overlayDescription(view))")
    }

    /// The other end of it: once the ring really is off screen the play button takes its
    /// place, and nothing samples an overlap on the way there.
    func testPlayButtonAppearsOnceTheRingIsGone() throws {
        try makeFileOnDisk()
        let (_, view) = try makeBoundVideoView(makeModel())
        view.setProgress(CGFloat(0.5))

        var overlapped = false
        view.setProgress(CGFloat(1))
        pump(1.2) {
            if !view.progressView.isHidden, !view.playButton.isHidden { overlapped = true }
        }

        XCTAssertFalse(overlapped, "the ring and the play button were on screen together")
        XCTAssertTrue(view.progressView.isHidden, "the ring must be gone: \(overlayDescription(view))")
        XCTAssertFalse(view.playButton.isHidden,
                       "the play button must take its place once it is: \(overlayDescription(view))")
    }

    /// The other half of the same rule: while the ring is up, nothing re-resolving the play
    /// button may reveal it — not even with the bytes already on disk, which is the state a
    /// download is in for its last stretch.
    ///
    /// Asserted through the resolver rather than through a rebind: a rebind with no live
    /// task legitimately heals a stale `.downloading` to `.done` and clears the overlay
    /// outright (`MessageCellStaleTransferOverlayTests`), which is a different rule.
    func testThePlayButtonStaysHiddenWhileTheRingIsUpEvenWithBytesOnDisk() throws {
        let (_, view) = try makeBoundVideoView(makeModel())
        view.setProgress(CGFloat(0.4))

        try makeFileOnDisk()
        view.updatePlayButtonVisibility()

        XCTAssertFalse(view.progressView.isHidden, "precondition: the ring is up")
        XCTAssertTrue(view.playButton.isHidden,
                      "the ring is still up — nothing else may draw in that slot: \(overlayDescription(view))")
    }

    /// An already-downloaded video binds straight to its play button, with no overlay to
    /// wait for. This is the case the exclusivity rule must not break.
    func testAnAlreadyDownloadedVideoShowsItsPlayButtonImmediately() throws {
        try makeFileOnDisk()
        let (_, view) = try makeBoundVideoView(makeModel(status: .done))

        XCTAssertTrue(view.progressView.isHidden, "a finished transfer has no overlay: \(overlayDescription(view))")
        XCTAssertFalse(view.playButton.isHidden,
                       "a downloaded video is playable on sight: \(overlayDescription(view))")
    }
}
