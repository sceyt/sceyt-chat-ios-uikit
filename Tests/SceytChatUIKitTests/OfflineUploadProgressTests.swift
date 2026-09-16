//
//  OfflineUploadProgressTests.swift
//  SceytChatUIKitTests
//
//  Sending a file with no connection showed no loader at all — the bubble looked like a
//  delivered attachment while nothing had left the device. Three seams produced that, and each
//  one is pinned here:
//
//  1. **The heal.** `.pending` is in `healableDownloadStatuses`, and both the reconcile
//     (`downloadMessageAttachmentsIfNeeded`, which runs on every cell bind) and the view's
//     `renderedTransferStatus` read "the file is on disk" as "the transfer finished". True for a
//     download, false for an upload: its local file is the *source*. An outgoing attachment
//     waiting to upload was therefore rendered — and persisted — as `.done`.
//  2. **The failure.** The upload is a plain REST request, so offline it fails the instant it is
//     attempted. `.failedUploading` puts a retry arrow on a message the app resends by itself on
//     the next connect, so the wait reads as a dead end the user has to poke.
//  3. **The render.** `update(status: .pending)` did nothing at all, so even before the upload
//     was attempted there was no overlay for the window in between.
//
//  The guards at the bottom pin what must NOT change: an incoming `.pending` download whose
//  bytes are on disk still heals to `.done`, and an upload failure with a connection still fails.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

final class OfflineUploadProgressTests: XCTestCase {

    /// Lets a test decide what `AttachmentTransfer` believes about the connection — the real
    /// predicate reads `chatClient.connectionState`, which no unit test can drive.
    private final class TestableTransfer: AttachmentTransfer {
        nonisolated(unsafe) static var offline = false
        override class var isOffline: Bool { offline }
    }

    private var transfer: TestableTransfer!
    private var session: MockTransferDataSession!
    private var mockDB: MockDatabase!
    private var originalDataSession: SCTDataSession?
    private var originalDatabase: Database!
    private var temporaryFiles = [String]()

    private let channelId: ChannelId = 500
    private let messageId: MessageId = 5001
    private let attachmentId: AttachmentId = 851_649_417_420_390_555
    private let incomingUrl = "https://cdn.example/5A0C21/incoming.jpg"

    private var ctx: NSManagedObjectContext { mockDB.container.viewContext }

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalDatabase = DataProvider.database
        mockDB = MockDatabase()
        DataProvider.database = mockDB
        originalDataSession = Components.dataSession
        session = MockTransferDataSession()
        Components.dataSession = session
        TestableTransfer.offline = false
        // A fresh instance, not `.default`: the caches are process-wide.
        transfer = TestableTransfer()
    }

    override func tearDownWithError() throws {
        for path in temporaryFiles {
            try? FileManager.default.removeItem(atPath: path)
        }
        temporaryFiles.removeAll()
        TestableTransfer.offline = false
        Components.dataSession = originalDataSession
        DataProvider.database = originalDatabase
        transfer = nil
        session = nil
        mockDB = nil
        try super.tearDownWithError()
    }

    // MARK: - Fixtures

    /// An attachment the user just picked: bytes on disk, no remote url yet. This is what every
    /// outgoing file looks like until its upload is acked.
    private func makeOutgoingAttachment(
        filePath: String,
        status: ChatMessage.Attachment.TransferStatus = .pending,
        type: String = "image"
    ) -> ChatMessage.Attachment {
        ChatMessage.Attachment(
            id: attachmentId,
            tid: 71,
            messageId: messageId,
            userId: "u1",
            // Empty rather than nil: that is what the mock transport keys an upload under,
            // and `isPendingUpload` must treat both the same.
            url: "",
            filePath: filePath,
            type: type,
            name: "outgoing.jpg",
            metadata: nil,
            uploadedFileSize: 2048,
            createdAt: Date(),
            status: status,
            transferProgress: 0
        )
    }

    private func makeIncomingAttachment(
        status: ChatMessage.Attachment.TransferStatus = .pending,
        filePath: String? = nil
    ) -> ChatMessage.Attachment {
        ChatMessage.Attachment(
            id: attachmentId,
            tid: 0,
            messageId: messageId,
            userId: "u2",
            url: incomingUrl,
            filePath: filePath,
            type: "image",
            name: "incoming.jpg",
            metadata: nil,
            uploadedFileSize: 2048,
            createdAt: Date(),
            status: status,
            transferProgress: 0
        )
    }

    private func makeMessage(_ attachments: [ChatMessage.Attachment]) -> ChatMessage {
        ChatMessage(id: messageId, channelId: channelId, attachments: attachments, user: ChatUser(id: "u1"))
    }

    private func makeModel(_ attachment: ChatMessage.Attachment) -> MessageLayoutModel {
        MessageLayoutModel(
            channel: ChatChannel(id: channelId, type: "group", uri: "offline-upload"),
            message: makeMessage([attachment]),
            appearance: MessageCell.appearance
        )
    }

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

    private func makeFileOnDisk(named name: String = "outgoing.jpg") throws -> String {
        let directory = URL(fileURLWithPath: Components.storage.storingKey.storageFolderPath)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory
            .appendingPathComponent("offline-upload-\(UUID().uuidString)-\(name)").path
        try Data(repeating: 0x1, count: 2048).write(to: URL(fileURLWithPath: path))
        temporaryFiles.append(path)
        return path
    }

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

    // MARK: - What the bubble shows while the file waits

    /// The reported bug. Offline, the attachment sits in `.pending` for the whole wait, and
    /// `update(status:)` drew nothing for it — an unsent photo was indistinguishable from a
    /// delivered one.
    func testQueuedUploadShowsItsLoader() throws {
        let filePath = try makeFileOnDisk()
        session.setLocalPath(filePath, forUrl: "")
        let model = makeModel(makeOutgoingAttachment(filePath: filePath))

        let (_, view) = try makeBoundStack(model)

        XCTAssertTrue(showsTransferOverlay(view),
                      "a file waiting to upload must show it is still going out: \(overlayDescription(view))")
        XCTAssertFalse(view.progressView.isHiddenProgress,
                       "the ring belongs to a transfer that has not failed: \(overlayDescription(view))")
        XCTAssertGreaterThan(view.progressView.progress, 0,
                             "the ring must be seeded, or it draws as an empty circle: \(overlayDescription(view))")
    }

    /// The heal that hid it. `.pending` + a local file reads as a finished download, and for an
    /// upload that same file is the source of bytes that have not been sent.
    func testQueuedUploadIsNotResolvedToDone() throws {
        let filePath = try makeFileOnDisk()
        session.setLocalPath(filePath, forUrl: "")
        let model = makeModel(makeOutgoingAttachment(filePath: filePath))

        let (_, view) = try makeBoundStack(model)

        XCTAssertEqual(view.renderedTransferStatus(for: .pending), .pending,
                       "an upload's local file is its source, not proof of delivery")
    }

    /// The loader carries a cancel button, so tapping it has to mean something. There is no task
    /// behind a queued upload — the pause is what stops the next connect from sending it.
    func testTappingTheQueuedUploadsCancelRequestsAPause() throws {
        let filePath = try makeFileOnDisk()
        session.setLocalPath(filePath, forUrl: "")
        let model = makeModel(makeOutgoingAttachment(filePath: filePath))
        let (stack, view) = try makeBoundStack(model)

        var actions = [MessageCell.AttachmentStackView.Action]()
        stack.onAction = { actions.append($0) }
        stack.pauseAction(view.pauseButton)

        let requestedPause = actions.contains { action in
            if case .pauseTransfer = action { return true }
            return false
        }
        XCTAssertTrue(requestedPause, "the cancel glyph on a queued upload must stop it")
    }

    // MARK: - What the transfer records while the file waits

    /// The reconcile runs on every cell bind. Marking the outgoing attachment `.done` there
    /// persists the lie: the next channel open reads a delivered-looking row for a file the
    /// server has never seen.
    func testQueuedUploadIsNotReconciledToDone() throws {
        let filePath = try makeFileOnDisk()
        session.setLocalPath(filePath, forUrl: "")
        let attachment = makeOutgoingAttachment(filePath: filePath)
        let message = makeMessage([attachment])

        let started = transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])
        _ = waitUntil(timeout: 0.3) { false }

        XCTAssertEqual(attachment.status, .pending,
                       "the bytes are on disk because they have not been sent yet")
        XCTAssertEqual(attachment.transferProgress, 0)
        XCTAssertTrue(started.isEmpty, "there is nothing to download — the file is the one being sent")
        XCTAssertEqual(session.startedDownloadCount, 0)
    }

    /// Offline, the REST upload fails the moment it is attempted. `.failedUploading` reads as a
    /// dead end and swaps the loader for a retry arrow — on a message
    /// `SyncService.resendPendingMessage` will send by itself on the next connect.
    func testOfflineUploadFailureKeepsTheAttachmentQueued() throws {
        TestableTransfer.offline = true
        let filePath = try makeFileOnDisk()
        let attachment = makeOutgoingAttachment(filePath: filePath)
        let message = makeMessage([attachment])

        transfer.uploadMessageAttachments(message: message, attachments: [attachment])
        XCTAssertTrue(waitUntil { self.session.task(forUrl: "") != nil },
                      "the transport was never asked to upload")
        let task = try XCTUnwrap(session.task(forUrl: ""))

        task.failure(error: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))

        XCTAssertTrue(waitUntil { attachment.status == .pending },
                      "with no connection the upload is waiting, not refused — it was \(attachment.status)")
    }

    /// A queued upload can still be paused by hand, and the pause has to be persisted: it is the
    /// only thing that keeps `SyncService` from resending the message on the next connect.
    func testPausingAQueuedUploadWithNoTaskPersistsPauseUploading() throws {
        let filePath = try makeFileOnDisk()
        let attachment = makeOutgoingAttachment(filePath: filePath)
        let message = makeMessage([attachment])

        var reported: Bool?
        transfer.stopTransfer(message: message, attachment: attachment) { reported = $0 }

        XCTAssertTrue(waitUntil { attachment.status == .pauseUploading },
                      "pausing a queued upload must stick — it was \(attachment.status)")
        XCTAssertEqual(reported, true)
    }

    // MARK: - Guards: what must not change

    /// The download heal this rule exists for. An incoming attachment whose bytes are on disk is
    /// finished, whatever its stored status says.
    func testIncomingPendingDownloadWithBytesOnDiskStillHealsToDone() throws {
        let filePath = try makeFileOnDisk(named: "incoming.jpg")
        session.setLocalPath(filePath, forUrl: incomingUrl)
        let attachment = makeIncomingAttachment()
        let message = makeMessage([attachment])

        let started = transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])

        XCTAssertEqual(attachment.status, .done,
                       "a downloaded file is a downloaded file — this heal must survive")
        XCTAssertTrue(started.isEmpty)
    }

    /// The view half of the same guard.
    func testIncomingPendingDownloadWithBytesOnDiskShowsNoOverlay() throws {
        let filePath = try makeFileOnDisk(named: "incoming.jpg")
        session.setLocalPath(filePath, forUrl: incomingUrl)
        let model = makeModel(makeIncomingAttachment(filePath: filePath))

        let (_, view) = try makeBoundStack(model)

        XCTAssertEqual(view.renderedTransferStatus(for: .pending), .done,
                       "an incoming attachment's local file is the result of its download")
        XCTAssertFalse(showsTransferOverlay(view),
                       "there is nothing left to transfer: \(overlayDescription(view))")
    }

    /// With a connection, a failed upload is a real failure and must keep its retry affordance —
    /// nothing else would ever retry it.
    func testOnlineUploadFailureStillFails() throws {
        TestableTransfer.offline = false
        let filePath = try makeFileOnDisk()
        let attachment = makeOutgoingAttachment(filePath: filePath)
        let message = makeMessage([attachment])

        transfer.uploadMessageAttachments(message: message, attachments: [attachment])
        XCTAssertTrue(waitUntil { self.session.task(forUrl: "") != nil })
        let task = try XCTUnwrap(session.task(forUrl: ""))

        task.failure(error: NSError(domain: "server", code: 413))

        XCTAssertTrue(waitUntil { attachment.status == .failedUploading },
                      "a refusal from a reachable server is a failure — it was \(attachment.status)")
    }

    /// A paused upload keeps its own state: the user's decision outranks "it is waiting".
    func testPausedUploadIsNotTreatedAsQueued() throws {
        let filePath = try makeFileOnDisk()
        session.setLocalPath(filePath, forUrl: "")
        let model = makeModel(makeOutgoingAttachment(filePath: filePath, status: .pauseUploading))

        let (_, view) = try makeBoundStack(model)

        XCTAssertTrue(view.progressView.isHiddenProgress,
                      "a paused upload shows its resume glyph, not a moving ring: \(overlayDescription(view))")
    }
}
