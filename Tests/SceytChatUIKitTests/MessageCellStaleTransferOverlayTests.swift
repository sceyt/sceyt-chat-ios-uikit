//
//  MessageCellStaleTransferOverlayTests.swift
//  SceytChatUIKitTests
//
//  Gap 4: the chat's attachment overlay is decided from the *stored status*, while the media
//  gallery decides it from *transfer reality*.
//
//  `ChannelInfoViewController+MediaCollectionView.syncTransferOverlay` resolves in this order —
//  live percent → bytes on disk → auto-download policy → stored status — and states the rule
//  outright: "The bytes are on disk: nothing to overlay, whatever the status claims."
//  `MessageCell.AttachmentStackView.bind` has no equivalent. It switches on
//  `layout.transferStatus` and consults the filesystem only as a tiebreaker *inside* the
//  active-transfer branch, so a status that outlived its transfer is rendered as if the
//  transfer were still real. `AttachmentView.update(status:)` compounds it: for
//  `.pauseDownloading`/`.failedDownloading` it calls `setProgress(0.0001)` unconditionally from
//  `data`'s `didSet`, with no filePath check anywhere on that path.
//
//  Two consequences, and the second is the one that matters:
//
//  (a) A download button or a surviving ring is painted over a file that is already on disk.
//  (b) Tapping that overlay *writes*: `pauseAction` resolves `.downloading` and requests a
//      pause, and `stopTransfer`'s no-live-task branch then persists `.pauseDownloading` over a
//      complete file — re-creating by hand the exact stale row that
//      `downloadMessageAttachmentsIfNeeded` reconciles away.
//
//  These tests are written against the *unfixed* view layer and are expected to fail until
//  `bind` and `pauseAction` adopt the gallery's rule. The guard tests at the bottom pass today
//  and must keep passing: they pin the states the fix must NOT touch, which is where a naive
//  "file on disk → done" precheck would over-reach.
//
//  Note these drive the shared `fileProvider` singleton (that is what `bind` consults), so they
//  use their own message id and never start a transfer on it — `taskFor` and
//  `currentProgressPercent` are therefore nil throughout, which is exactly the "no transfer
//  behind this status" condition under test.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

final class MessageCellStaleTransferOverlayTests: XCTestCase {

    private var session: MockTransferDataSession!
    private var mockDB: MockDatabase!
    private var originalDataSession: SCTDataSession?
    private var originalDatabase: Database!
    private var temporaryFiles = [String]()

    private let channelId: ChannelId = 400
    private let messageId: MessageId = 4001
    private let attachmentId: AttachmentId = 851_649_417_420_390_777
    private let attachmentUrl = "https://cdn.example/4F2A19/clip.mp4"

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalDatabase = DataProvider.database
        mockDB = MockDatabase()
        DataProvider.database = mockDB
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
        DataProvider.database = originalDatabase
        session = nil
        mockDB = nil
        try super.tearDownWithError()
    }

    // MARK: - Fixtures

    private func makeAttachment(
        status: ChatMessage.Attachment.TransferStatus,
        filePath: String? = nil,
        type: String = "video"
    ) -> ChatMessage.Attachment {
        ChatMessage.Attachment(
            id: attachmentId,
            tid: 0,
            messageId: messageId,
            userId: "user",
            url: attachmentUrl,
            filePath: filePath,
            type: type,
            name: "clip.mp4",
            metadata: nil,
            uploadedFileSize: 5_318_259,
            createdAt: Date(),
            status: status,
            transferProgress: 0
        )
    }

    private func makeModel(_ attachment: ChatMessage.Attachment) -> MessageLayoutModel {
        MessageLayoutModel(
            channel: ChatChannel(id: channelId, type: "group", uri: "stale-overlay"),
            message: ChatMessage(
                id: messageId,
                channelId: channelId,
                attachments: [attachment],
                user: ChatUser(id: "u1")
            ),
            appearance: MessageCell.appearance
        )
    }

    /// A stack view bound to `model`, plus the attachment view it created. Going through
    /// `data` is what exercises `bind` — the method under test is private.
    private func makeBoundStack(
        _ model: MessageLayoutModel
    ) throws -> (MessageCell.AttachmentStackView, MessageCell.AttachmentView) {
        let stack = MessageCell.AttachmentStackView()
        stack.data = model
        let view = try XCTUnwrap(
            stack.subviews.compactMap { $0 as? MessageCell.AttachmentView }.first,
            "the stack view created no attachment view to inspect")
        return (stack, view)
    }

    /// Real bytes, in the storage folder a real download lands in.
    private func makeFileOnDisk() throws -> String {
        let directory = URL(fileURLWithPath: Components.storage.storingKey.storageFolderPath)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory
            .appendingPathComponent("stale-overlay-\(UUID().uuidString)-clip.mp4").path
        try Data(repeating: 0x1, count: 2048).write(to: URL(fileURLWithPath: path))
        temporaryFiles.append(path)
        return path
    }

    /// True when anything of the transfer overlay is on screen. `progressView` carries the ring
    /// and `pauseButton` the cancel/download/retry glyph; a paused or failed state hides the ring
    /// stroke via `isHiddenProgress` but keeps both views visible, so neither alone is a
    /// sufficient check.
    private func showsTransferOverlay(_ view: MessageCell.AttachmentView) -> Bool {
        !view.progressView.isHidden || !view.pauseButton.isHidden
    }

    private func overlayDescription(_ view: MessageCell.AttachmentView) -> String {
        "progressView.isHidden=\(view.progressView.isHidden) "
        + "isHiddenProgress=\(view.progressView.isHiddenProgress) "
        + "progress=\(view.progressView.progress) "
        + "pauseButton.isHidden=\(view.pauseButton.isHidden)"
    }

    private func waitUntil(timeout: TimeInterval = 1, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }

    // MARK: - (a) The overlay is painted over bytes that are already on disk

    /// A paused download whose bytes have since arrived. `update(status:)` runs
    /// `setProgress(0.0001)` from `data`'s `didSet` with no filePath check, so the cell offers a
    /// download button for a video the user can already play.
    func testStalePausedDownloadOverBytesOnDiskShowsNoOverlay() throws {
        session.setLocalPath(try makeFileOnDisk(), forUrl: attachmentUrl)
        let model = makeModel(makeAttachment(status: .pauseDownloading))

        let (_, view) = try makeBoundStack(model)

        XCTAssertFalse(showsTransferOverlay(view),
                       "the bytes are on disk — there is nothing to download: \(overlayDescription(view))")
    }

    /// Same for a failure that a later attempt already won: `.failedDownloading` renders
    /// identically to `.pauseDownloading`.
    func testStaleFailedDownloadOverBytesOnDiskShowsNoOverlay() throws {
        session.setLocalPath(try makeFileOnDisk(), forUrl: attachmentUrl)
        let model = makeModel(makeAttachment(status: .failedDownloading))

        let (_, view) = try makeBoundStack(model)

        XCTAssertFalse(showsTransferOverlay(view),
                       "a failed download whose bytes are on disk succeeded after all: \(overlayDescription(view))")
    }

    /// The in-place reconfigure, which is the path a visible cell actually takes. The first bind
    /// seeds a ring correctly — no file yet. Then the bytes land and the same stale
    /// `.downloading` layout is rebound: `bind`'s `.downloading` branch finds no live percent, a
    /// filePath, and no task, so *no* branch fires and the ring from the previous binding is
    /// simply left on screen with nothing left to move or hide it.
    func testRebindingOverBytesOnDiskHidesASurvivingRing() throws {
        let model = makeModel(makeAttachment(status: .downloading))

        let (stack, view) = try makeBoundStack(model)
        XCTAssertTrue(showsTransferOverlay(view),
                      "precondition: with no local file a .downloading attachment must show its ring")

        // The transfer finished somewhere this view never heard about — a completion that
        // landed on a duplicate layout instance, a cell reconfigured mid-download.
        session.setLocalPath(try makeFileOnDisk(), forUrl: attachmentUrl)
        stack.data = model

        XCTAssertFalse(showsTransferOverlay(view),
                       "a rebind over bytes on disk must clear the ring: \(overlayDescription(view))")
    }

    // MARK: - (b) Tapping the stale overlay writes

    /// The damaging half. `pauseAction` resolves its action from the stored status, so a tap on
    /// the surviving ring requests a pause of a transfer that no longer exists — and
    /// `stopTransfer`'s no-live-task branch persists `.pauseDownloading` over a complete file,
    /// putting back the very row the reconcile just corrected.
    func testTappingASurvivingRingOverBytesOnDiskDoesNotRequestAPause() throws {
        let model = makeModel(makeAttachment(status: .downloading))
        let (stack, view) = try makeBoundStack(model)
        XCTAssertTrue(showsTransferOverlay(view), "precondition: the ring must be up to be tappable")

        session.setLocalPath(try makeFileOnDisk(), forUrl: attachmentUrl)
        stack.data = model

        var actions = [MessageCell.AttachmentStackView.Action]()
        stack.onAction = { actions.append($0) }
        stack.pauseAction(view.pauseButton)
        _ = waitUntil(timeout: 0.2) { false }

        let requestedPause = actions.contains { action in
            if case .pauseTransfer = action { return true }
            return false
        }
        XCTAssertFalse(requestedPause,
                       "with the bytes on disk there is no transfer to pause, and pausing persists a status that contradicts the file")
    }

    // MARK: - Guards: states the fix must not touch

    /// A real download in progress. The ring is the whole point of it — a file-on-disk precheck
    /// must not be reachable here, because there is no file.
    func testActiveDownloadWithNoFileStillShowsItsRing() throws {
        let model = makeModel(makeAttachment(status: .downloading))

        let (_, view) = try makeBoundStack(model)

        XCTAssertTrue(showsTransferOverlay(view),
                      "a download with nothing on disk must show its ring: \(overlayDescription(view))")
    }

    /// A genuinely paused download still needs its tap-to-download affordance.
    func testPausedDownloadWithNoFileStillShowsItsDownloadButton() throws {
        let model = makeModel(makeAttachment(status: .pauseDownloading))

        let (_, view) = try makeBoundStack(model)

        XCTAssertFalse(view.pauseButton.isHidden,
                       "a paused download with no local file must still offer to download: \(overlayDescription(view))")
    }

    /// The over-reach trap. An upload's local file is its *source*, not proof of delivery, so
    /// "the file exists" says nothing about whether the bytes were sent. A precheck that hid the
    /// overlay on file-existence alone would silently drop the retry affordance for every upload
    /// that failed — the user would see a sent-looking attachment that never left the device.
    func testFailedUploadOverItsLocalFileStillShowsItsRetryButton() throws {
        let filePath = try makeFileOnDisk()
        session.setLocalPath(filePath, forUrl: attachmentUrl)
        let model = makeModel(makeAttachment(status: .failedUploading, filePath: filePath))

        let (_, view) = try makeBoundStack(model)

        XCTAssertFalse(view.pauseButton.isHidden,
                       "a failed upload must keep its retry button even though its file is on disk: \(overlayDescription(view))")
    }
}
