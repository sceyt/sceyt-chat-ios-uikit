//
//  VideoAttachmentProgressLabelTests.swift
//  SceytChatUIKitTests
//
//  The "<downloaded> / <total>" label under a downloading video's ring is on screen for as
//  long as the ring draws a transfer in flight.
//
//  It used to be hidden by every `update(status:)` — which runs on each rebind and on each
//  status relay — and shown again only when `setProgress` drew a value *different* from the
//  one already on screen. A rebind re-seeds the same value (or the 0.0001 floor, dropped as
//  stale), and the relay re-seeds a cached percent that is a tick behind (also stale), so the
//  ring kept running with no byte count until the next tick that happened to be higher.
//

@testable import SceytChatUIKit
import SceytChat
import XCTest

final class VideoAttachmentProgressLabelTests: XCTestCase {

    private var session: MockTransferDataSession!
    private var originalDataSession: SCTDataSession?

    private let channelId: ChannelId = 402
    private let messageId: MessageId = 4021
    private let attachmentId: AttachmentId = 851_649_417_420_390_779
    private let attachmentUrl = "https://cdn.example/9B7C32/clip.mp4"

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalDataSession = Components.dataSession
        session = MockTransferDataSession()
        Components.dataSession = session
    }

    override func tearDownWithError() throws {
        Components.dataSession = originalDataSession
        session = nil
        try super.tearDownWithError()
    }

    // MARK: - Fixtures

    private func makeModel() -> MessageLayoutModel {
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
            uploadedFileSize: 8_739_000,
            createdAt: Date(),
            status: .downloading,
            transferProgress: 0
        )
        return MessageLayoutModel(
            channel: ChatChannel(id: channelId, type: "group", uri: "video-label"),
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

    private func tick(_ view: MessageCell.AttachmentVideoView, _ progress: Double) {
        view.setProgress(.init(
            message: view.data.ownerMessage!,
            attachment: view.data.attachment,
            progress: progress
        ))
    }

    private func describe(_ view: MessageCell.AttachmentVideoView) -> String {
        "label.isHidden=\(view.progressLabel.isHidden) text=\(view.progressLabel.text ?? "nil") "
        + "ring.isHidden=\(view.progressView.isHidden) "
        + "isHiddenProgress=\(view.progressView.isHiddenProgress) "
        + "progress=\(view.progressView.progress)"
    }

    // MARK: - Tests

    func testATickShowsTheByteCount() throws {
        let (_, view) = try makeBoundVideoView(makeModel())

        tick(view, 0.3)

        XCTAssertFalse(view.progressLabel.isHidden, describe(view))
        XCTAssertFalse((view.progressLabel.text ?? "").isEmpty, describe(view))
    }

    /// A reconfigure while the download runs — the cell's message changed for any other
    /// reason — must not take the byte count off a ring that keeps running.
    func testRebindingMidDownloadKeepsTheByteCount() throws {
        let model = makeModel()
        let (stack, view) = try makeBoundVideoView(model)
        tick(view, 0.5)

        stack.data = model

        XCTAssertFalse(view.progressView.isHidden, "precondition: the ring is still up: \(describe(view))")
        XCTAssertFalse(view.progressLabel.isHidden,
                       "the ring is still drawing the download — its byte count must stay: \(describe(view))")
    }

    /// The status relay re-renders the status and re-seeds the cached percent, which is
    /// always a tick behind what the ring draws, and so is dropped as stale.
    func testAStatusRelayMidDownloadKeepsTheByteCount() throws {
        let (_, view) = try makeBoundVideoView(makeModel())
        tick(view, 0.5)

        view.attachmentTransferStatusDidChange(view.data.attachment, status: .downloading)

        XCTAssertFalse(view.progressLabel.isHidden,
                       "a status relay must not take the byte count off a running ring: \(describe(view))")
    }

    /// A late, lower tick is dropped for the ring; it must not drop the label with it.
    func testAStaleTickKeepsTheByteCount() throws {
        let (_, view) = try makeBoundVideoView(makeModel())
        tick(view, 0.6)
        view.update(status: .downloading)

        tick(view, 0.4)

        XCTAssertEqual(view.progressView.progress, 0.6, accuracy: 0.0001)
        XCTAssertFalse(view.progressLabel.isHidden, describe(view))
    }

    func testPausingHidesTheByteCountAndResumingBringsItBack() throws {
        let (_, view) = try makeBoundVideoView(makeModel())
        tick(view, 0.5)

        view.update(status: .pauseDownloading)
        XCTAssertTrue(view.progressLabel.isHidden, "a paused transfer shows its resume icon only: \(describe(view))")

        view.update(status: .downloading)
        tick(view, 0.55)
        XCTAssertFalse(view.progressLabel.isHidden, describe(view))
    }

    func testTheByteCountGoesWithTheRing() throws {
        let (_, view) = try makeBoundVideoView(makeModel())
        tick(view, 0.5)

        view.clearTransferOverlay()

        XCTAssertTrue(view.progressLabel.isHidden, describe(view))
    }
}
