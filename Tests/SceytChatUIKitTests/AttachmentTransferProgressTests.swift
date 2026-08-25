//
//  AttachmentTransferProgressTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import XCTest
import SceytChat
import UIKit

// MARK: - Mock data session

/// Captures the `SCTDataSessionTaskInfo` handed to `download` so a test can drive
/// progress by hand, exactly the way a real transport's progress callback would.
final class MockTransferDataSession: NSObject, SCTDataSession {

    private let lock = NSLock()
    private var tasks = [String: SCTDataSessionTaskInfo]()
    /// Paths `getFilePath` should report as already on disk.
    private var localPaths = [String: String]()

    /// Reports `path` from `getFilePath` for the attachment with this url, i.e.
    /// "these bytes are already on disk".
    func setLocalPath(_ path: String?, forUrl url: String) {
        lock.lock(); defer { lock.unlock() }
        localPaths[url] = path
    }

    /// Keyed by url, which is what identifies an attachment across the copies the
    /// emitter and the subscriber hold.
    func task(forUrl url: String) -> SCTDataSessionTaskInfo? {
        lock.lock(); defer { lock.unlock() }
        return tasks[url]
    }

    var startedDownloadCount: Int {
        lock.lock(); defer { lock.unlock() }
        return tasks.count
    }

    func download(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {
        lock.lock(); defer { lock.unlock() }
        tasks[attachment.url ?? ""] = taskInfo
    }

    func upload(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {
        lock.lock(); defer { lock.unlock() }
        tasks[attachment.url ?? attachment.filePath ?? ""] = taskInfo
    }

    func getFilePath(attachment: ChatMessage.Attachment) -> String? {
        lock.lock(); defer { lock.unlock() }
        return attachment.url.flatMap { localPaths[$0] }
    }

    func thumbnailFile(for attachment: ChatMessage.Attachment, preferred size: CGSize) -> String? { nil }
}

// MARK: - Tests

/// Covers the two defects that made a download's progress ring stop moving.
///
/// 1. **Identity.** The emitter (`taskInfo.attachment`, captured when the transfer
///    started) and the subscriber (`layout.attachment`, rebound from the database)
///    are different instances of the same attachment, and the database copy can
///    carry a server-assigned `id` the task's copy has never seen. Keying the
///    registry on `id` split one transfer across two keys and every tick was
///    published to a bucket nobody was listening on.
/// 2. **Observer scope.** `removeProgressObserver` dropped every subscriber for an
///    attachment, so a channel-info cell being deallocated silently unsubscribed the
///    message cell that was still on screen showing the same download.
final class AttachmentTransferProgressTests: XCTestCase {

    private var transfer: AttachmentTransfer!
    private var session: MockTransferDataSession!
    private var originalDataSession: SCTDataSession?
    private var originalDatabase: Database!

    private let messageId: MessageId = 900
    private let attachmentUrl = "87E3B0FD-4547-4DFD-975B-AC17D1022CE1"

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalDatabase = DataProvider.database
        DataProvider.database = MockDatabase()
        originalDataSession = Components.dataSession
        session = MockTransferDataSession()
        Components.dataSession = session
        // A fresh instance, not `.default`: the caches are process-wide and would
        // otherwise leak between tests.
        transfer = AttachmentTransfer()
    }

    override func tearDownWithError() throws {
        Components.dataSession = originalDataSession
        DataProvider.database = originalDatabase
        transfer = nil
        session = nil
        try super.tearDownWithError()
    }

    // MARK: Fixtures

    /// `id: 0` models the copy a task captures before the server has assigned one;
    /// a non-zero `id` models the copy the database hands back later. Both describe
    /// the same attachment and carry the same url.
    private func makeAttachment(
        id: AttachmentId = 0,
        tid: Int64 = 0,
        url: String? = nil,
        filePath: String? = nil,
        type: String = "video",
        status: ChatMessage.Attachment.TransferStatus = .pending
    ) -> ChatMessage.Attachment {
        .init(
            id: id,
            tid: tid,
            messageId: messageId,
            userId: "user",
            url: url ?? attachmentUrl,
            filePath: filePath,
            type: type,
            name: "video.mp4",
            metadata: nil,
            uploadedFileSize: 5_318_259,
            createdAt: Date(),
            status: status
        )
    }

    private func makeMessage(_ attachments: [ChatMessage.Attachment]) -> ChatMessage {
        ChatMessage(id: messageId, channelId: 100, attachments: attachments, user: ChatUser(id: "u1"))
    }

    private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }

    /// Starts a real download through `AttachmentTransfer` and returns the task the
    /// mock transport captured, so the test can emit progress on it.
    private func startDownload(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment]
    ) throws -> SCTDataSessionTaskInfo {
        transfer.downloadMessageAttachments(message: message, attachments: attachments)
        let url = attachments[0].url ?? ""
        XCTAssertTrue(waitUntil { self.session.task(forUrl: url) != nil },
                      "the transport was never asked to download")
        return try XCTUnwrap(session.task(forUrl: url))
    }

    // MARK: - Transfer identity

    /// The regression: the same attachment, before and after the server assigns an
    /// id, must resolve to one identity. Keying on `id` made these two differ and
    /// silently split the transfer in half.
    func testIdentityIsStableWhenTheServerAssignsAnAttachmentId() {
        let captured = makeAttachment(id: 0)
        let fromDatabase = makeAttachment(id: 851_649_417_420_390_401)

        XCTAssertEqual(
            AttachmentTransfer.transferIdentity(of: captured),
            AttachmentTransfer.transferIdentity(of: fromDatabase),
            "an attachment gaining an id mid-transfer must keep one identity")
    }

    /// The identity must still separate siblings — this is what the `id`-first
    /// version was introduced to fix, and the replacement must not regress it.
    /// Before either change both hashed to `tid` 0 and shared one bucket.
    func testIdentitySeparatesSiblingAttachmentsOfOneMessage() {
        let first = makeAttachment(url: "AAAA-1111")
        let second = makeAttachment(url: "BBBB-2222")

        XCTAssertNotEqual(
            AttachmentTransfer.transferIdentity(of: first),
            AttachmentTransfer.transferIdentity(of: second),
            "two attachments of one message must not share a progress bucket")
    }

    /// An upload starts with a local file and no url, and gains a url when it
    /// finishes. Leading with `tid` — which outgoing attachments always carry — is
    /// what keeps that from changing the identity halfway through.
    func testIdentityIsStableAcrossAnUploadGainingItsUrl() {
        let beforeUpload = makeAttachment(tid: 555, url: "", filePath: "/tmp/video.mp4")
        let afterUpload = makeAttachment(id: 42, tid: 555, url: "REMOTE-URL", filePath: "/tmp/video.mp4")

        XCTAssertEqual(
            AttachmentTransfer.transferIdentity(of: beforeUpload),
            AttachmentTransfer.transferIdentity(of: afterUpload),
            "an upload must keep one identity from local file to uploaded url")
    }

    // MARK: - Delivery

    /// End to end, against the exact shape from the WAAFI log: the task holds an
    /// id-less copy, the cell subscribes with the database's id-carrying copy, and
    /// every tick must still arrive.
    func testProgressReachesAnObserverRegisteredWithTheDatabaseCopy() throws {
        let captured = makeAttachment(id: 0)
        let message = makeMessage([captured])
        let task = try startDownload(message: message, attachments: [captured])

        let fromDatabase = makeAttachment(id: 851_649_417_420_390_401, status: .downloading)
        var received = [Double]()
        transfer.progress(message: message, attachment: fromDatabase, objectIdKey: "cell") { progress in
            received.append(progress.progress)
        }

        task.updateProgress(0.25)
        task.updateProgress(0.5)

        XCTAssertEqual(received, [0.25, 0.5],
                       "ticks published by the task must reach the cell's subscription")
        XCTAssertEqual(transfer.currentProgressPercent(message: message, attachment: fromDatabase), 0.5,
                       "a rebind must be able to restore the percent using the database copy")
        XCTAssertEqual(transfer.currentProgressPercent(message: message, attachment: captured), 0.5,
                       "...and using the task's copy — they are the same transfer")
    }

    /// `taskFor` decides whether callers believe a transfer is still alive. It used
    /// to match with `==`, which is `id`-first, so a live task holding an id-less
    /// copy was reported as no task at all.
    func testTaskForFindsTheTaskWhenTheAttachmentGainsAnId() throws {
        let captured = makeAttachment(id: 0)
        let message = makeMessage([captured])
        _ = try startDownload(message: message, attachments: [captured])

        let fromDatabase = makeAttachment(id: 851_649_417_420_390_401, status: .downloading)
        XCTAssertNotNil(transfer.taskFor(message: message, attachment: fromDatabase),
                        "a live task must be found via the database copy of its attachment")
    }

    /// A tick for one attachment must not be published to a sibling's observers —
    /// the percent would be rendered against the wrong file size.
    func testProgressIsNotDeliveredToASiblingAttachment() throws {
        let first = makeAttachment(url: "AAAA-1111")
        let second = makeAttachment(url: "BBBB-2222")
        let message = makeMessage([first, second])
        let firstTask = try startDownload(message: message, attachments: [first, second])

        var secondReceived = [Double]()
        transfer.progress(message: message, attachment: second, objectIdKey: "cell2") { progress in
            secondReceived.append(progress.progress)
        }

        firstTask.updateProgress(0.4)

        XCTAssertTrue(secondReceived.isEmpty,
                      "a sibling attachment must not receive this attachment's progress")
    }

    // MARK: - Observer scope

    /// The channel-info round trip: two views observe the same download, one is
    /// deallocated and unsubscribes. The other must keep receiving ticks.
    func testRemovingOneObserverLeavesTheOthersSubscribed() throws {
        let attachment = makeAttachment(id: 0)
        let message = makeMessage([attachment])
        let task = try startDownload(message: message, attachments: [attachment])

        var messageCell = [Double]()
        var infoCell = [Double]()
        transfer.progress(message: message, attachment: attachment, objectIdKey: "messagecell") { messageCell.append($0.progress) }
        transfer.progress(message: message, attachment: attachment, objectIdKey: "infocell") { infoCell.append($0.progress) }

        task.updateProgress(0.1)
        XCTAssertEqual(messageCell, [0.1])
        XCTAssertEqual(infoCell, [0.1])

        // The channel-info cell goes away.
        transfer.removeProgressObserver(message: message, attachment: attachment, objectIdKey: "infocell")
        task.updateProgress(0.2)

        XCTAssertEqual(messageCell, [0.1, 0.2],
                       "the surviving observer must keep receiving progress")
        XCTAssertEqual(infoCell, [0.1],
                       "the removed observer must receive nothing further")
    }

    /// Unsubscribing must not discard the cached percent while the transfer is still
    /// running — that cache is what a later rebind reads to restore the ring, and
    /// erasing it is what left the ring at its synthetic floor.
    func testRemovingAnObserverKeepsTheCachedPercentWhileTheTransferIsLive() throws {
        let attachment = makeAttachment(id: 0)
        let message = makeMessage([attachment])
        let task = try startDownload(message: message, attachments: [attachment])

        transfer.progress(message: message, attachment: attachment, objectIdKey: "infocell") { _ in }
        task.updateProgress(0.42)
        XCTAssertEqual(transfer.currentProgressPercent(message: message, attachment: attachment), 0.42)

        transfer.removeProgressObserver(message: message, attachment: attachment, objectIdKey: "infocell")

        XCTAssertEqual(transfer.currentProgressPercent(message: message, attachment: attachment), 0.42,
                       "the cached percent belongs to the transfer, not to any one observer")
    }

    /// Re-registering under the same key replaces rather than accumulates, so a cell
    /// rebinding on every scroll does not multiply its own closures.
    func testRebindingReplacesTheSameSubscriberInsteadOfAccumulating() throws {
        let attachment = makeAttachment(id: 0)
        let message = makeMessage([attachment])
        let task = try startDownload(message: message, attachments: [attachment])

        var callCount = 0
        for _ in 0..<5 {
            transfer.progress(message: message, attachment: attachment, objectIdKey: "messagecell") { _ in
                callCount += 1
            }
        }
        task.updateProgress(0.3)

        XCTAssertEqual(callCount, 1, "a rebinding cell must hold exactly one subscription")
    }

    // MARK: - Task group

    /// One attachment finishing must not evict its still-running siblings from the
    /// task group: that group is the guard consulted before starting a download, so
    /// clearing it wholesale let the next rebind start a second transfer for bytes
    /// already in flight.
    func testFinishingOneAttachmentLeavesASiblingTaskInTheGroup() throws {
        let first = makeAttachment(url: "AAAA-1111")
        let second = makeAttachment(url: "BBBB-2222")
        let message = makeMessage([first, second])
        let firstTask = try startDownload(message: message, attachments: [first, second])
        XCTAssertNotNil(transfer.taskFor(message: message, attachment: second))

        firstTask.failure(error: NSError(domain: "test", code: 1))

        XCTAssertTrue(waitUntil { self.transfer.taskFor(message: message, attachment: first) == nil },
                      "the finished task must be removed from the group")
        XCTAssertNotNil(transfer.taskFor(message: message, attachment: second),
                        "a sibling still transferring must stay in the group")
    }

    /// With the group intact, a second download request for an in-flight attachment
    /// must be recognised and skipped rather than starting a duplicate transfer.
    func testASecondRequestDoesNotStartADuplicateDownload() throws {
        let attachment = makeAttachment(id: 0)
        let message = makeMessage([attachment])
        _ = try startDownload(message: message, attachments: [attachment])
        XCTAssertEqual(session.startedDownloadCount, 1)

        // What `cellForItemAt` does on every rebind.
        transfer.downloadMessageAttachments(message: message, attachments: [attachment])
        _ = waitUntil(timeout: 0.3) { false }

        XCTAssertEqual(session.startedDownloadCount, 1,
                       "an attachment already in flight must not be downloaded twice")
    }

    // MARK: - downloadMessageAttachmentsIfNeeded: status reconciliation
    //
    // This runs from `cellForItemAt` on every cell bind, and it mutates attachment
    // status, so a mistake here is felt on every scroll.

    /// A `.pending` attachment whose bytes are already on disk is completed in place
    /// rather than downloaded again, and its observers are told.
    func testAlreadyDownloadedAttachmentIsCompletedWithoutDownloading() throws {
        let attachment = makeAttachment(status: .pending)
        let message = makeMessage([attachment])
        session.setLocalPath("/tmp/already-there.mp4", forUrl: attachmentUrl)

        var completions = [AttachmentTransfer.AttachmentCompletion]()
        transfer.progress(message: message, attachment: attachment, objectIdKey: "cell", block: { _ in }) {
            completions.append($0)
        }

        let started = transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])

        XCTAssertTrue(started.isEmpty, "a file already on disk must not be downloaded again")
        XCTAssertEqual(attachment.status, .done)
        XCTAssertEqual(attachment.transferProgress, 1)
        XCTAssertEqual(completions.count, 1, "observers must be told the attachment is already complete")
        XCTAssertNil(completions.first?.error)
        XCTAssertEqual(session.startedDownloadCount, 0)
    }

    /// The inverse: an attachment marked `.done` whose file has gone (cache eviction,
    /// reinstall) must be reset so it downloads again instead of showing forever as
    /// complete with nothing to open.
    func testDoneAttachmentWithNoFileIsResetAndDownloadedAgain() throws {
        let attachment = makeAttachment(status: .done)
        let message = makeMessage([attachment])
        // getFilePath returns nil — nothing on disk.

        let started = transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])

        // Reset happens synchronously; the task that flips it to .downloading is
        // dispatched onto the transfer queue afterwards.
        XCTAssertEqual(started.count, 1, "a .done attachment with no local file must be re-queued")
        XCTAssertEqual(attachment.transferProgress, 0, "its stale 100% must be cleared")
        XCTAssertTrue(waitUntil { self.session.startedDownloadCount == 1 },
                      "and it must actually reach the transport")
        XCTAssertEqual(attachment.status, .downloading)
    }

    /// A user-paused download must stay paused. Without the status filter it would
    /// restart itself every time the cell rebinds, i.e. on every scroll past it.
    func testPausedDownloadIsNotRestartedOnRebind() throws {
        let attachment = makeAttachment(status: .pauseDownloading)
        let message = makeMessage([attachment])

        let started = transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])
        _ = waitUntil(timeout: 0.3) { false }

        XCTAssertTrue(started.isEmpty, "a paused download must not restart on rebind")
        XCTAssertEqual(attachment.status, .pauseDownloading)
        XCTAssertEqual(session.startedDownloadCount, 0)
    }

    /// Same contract for a failed download — it waits for an explicit retry.
    func testFailedDownloadIsNotRestartedOnRebind() throws {
        let attachment = makeAttachment(status: .failedDownloading)
        let message = makeMessage([attachment])

        let started = transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])
        _ = waitUntil(timeout: 0.3) { false }

        XCTAssertTrue(started.isEmpty, "a failed download must not restart on rebind")
        XCTAssertEqual(session.startedDownloadCount, 0)
    }

    /// Link previews are metadata, not files; they must never enter the transfer path.
    func testLinkAttachmentIsNeverDownloaded() throws {
        let link = makeAttachment(type: "link", status: .pending)
        let message = makeMessage([link])

        let started = transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [link])
        _ = waitUntil(timeout: 0.3) { false }

        XCTAssertTrue(started.isEmpty, "link attachments are not transferred")
        XCTAssertEqual(session.startedDownloadCount, 0)
    }

    // MARK: - Completion

    /// The path every finished download takes: observers are told, the cached percent
    /// is dropped (the transfer is over, so nothing would ever move it again), and the
    /// task leaves the group so a later request can start a fresh one.
    func testSuccessfulCompletionNotifiesObserversAndClearsState() throws {
        let attachment = makeAttachment(id: 0)
        let message = makeMessage([attachment])
        let task = try startDownload(message: message, attachments: [attachment])

        var completions = [AttachmentTransfer.AttachmentCompletion]()
        transfer.progress(message: message, attachment: attachment, objectIdKey: "cell", block: { _ in }) {
            completions.append($0)
        }
        task.updateProgress(0.9)
        XCTAssertEqual(transfer.currentProgressPercent(message: message, attachment: attachment), 0.9)

        task.success(origin: attachmentUrl)

        XCTAssertTrue(waitUntil { !completions.isEmpty }, "observers must be told the download finished")
        XCTAssertNil(completions.first?.error)
        XCTAssertTrue(waitUntil { self.transfer.taskFor(message: message, attachment: attachment) == nil },
                      "a finished task must leave the group")
        XCTAssertNil(transfer.currentProgressPercent(message: message, attachment: attachment),
                     "the cached percent must be dropped once the transfer is over")
    }

    /// A failure must reach observers carrying the error, so the cell can show a retry
    /// affordance rather than a ring that silently stops.
    func testFailedCompletionDeliversTheErrorToObservers() throws {
        let attachment = makeAttachment(id: 0)
        let message = makeMessage([attachment])
        let task = try startDownload(message: message, attachments: [attachment])

        var completions = [AttachmentTransfer.AttachmentCompletion]()
        transfer.progress(message: message, attachment: attachment, objectIdKey: "cell", block: { _ in }) {
            completions.append($0)
        }

        task.failure(error: NSError(domain: "test", code: 7))

        XCTAssertTrue(waitUntil { !completions.isEmpty })
        XCTAssertNotNil(completions.first?.error, "a failed download must report its error")
    }

    // MARK: - Pause / resume

    /// `stopTransfer` used to find its attachment with `$0.id == attachment.id`. Every
    /// attachment of an incoming message has `id == 0`, so that matched whichever came
    /// first: pausing the second video paused the first and left the second running.
    func testPausingOneAttachmentDoesNotPauseItsSibling() throws {
        let first = makeAttachment(url: "AAAA-1111", status: .downloading)
        let second = makeAttachment(url: "BBBB-2222", status: .downloading)
        let message = makeMessage([first, second])
        _ = try startDownload(message: message, attachments: [first, second])

        transfer.stopTransfer(message: message, attachment: second)

        XCTAssertTrue(waitUntil { second.status == .pauseDownloading },
                      "the requested attachment must be paused")
        XCTAssertEqual(first.status, .downloading, "its sibling must be left alone")
    }

    /// And the same for resuming.
    func testResumingOneAttachmentDoesNotResumeItsSibling() throws {
        let first = makeAttachment(url: "AAAA-1111", status: .downloading)
        let second = makeAttachment(url: "BBBB-2222", status: .downloading)
        let message = makeMessage([first, second])
        _ = try startDownload(message: message, attachments: [first, second])

        transfer.stopTransfer(message: message, attachment: second)
        XCTAssertTrue(waitUntil { second.status == .pauseDownloading })
        first.status = .pauseDownloading

        transfer.resumeTransfer(message: message, attachment: second)

        XCTAssertTrue(waitUntil { second.status == .downloading },
                      "the requested attachment must resume")
        XCTAssertEqual(first.status, .pauseDownloading, "its sibling must stay paused")
    }

    /// Pausing must still work when the caller passes the database's id-carrying copy
    /// while the task holds an id-less one — the mismatch that started all of this.
    func testPausingWorksWhenTheAttachmentGainedAnId() throws {
        let captured = makeAttachment(id: 0, status: .downloading)
        let message = makeMessage([captured])
        _ = try startDownload(message: message, attachments: [captured])

        let fromDatabase = makeAttachment(id: 851_649_417_420_390_401, status: .downloading)
        transfer.stopTransfer(message: message, attachment: fromDatabase)

        XCTAssertTrue(waitUntil { captured.status == .pauseDownloading },
                      "the message's attachment must be paused even when the copies disagree on id")
    }
}
