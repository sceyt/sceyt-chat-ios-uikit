//
//  AttachmentTransferTaskLeakTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import XCTest
import SceytChat
import UIKit

// MARK: - Mock data session

/// Records the task handed to it and nothing else — no operation queue, no URLSession —
/// so the only thing holding the task after `forget()` is `AttachmentTransfer` itself.
private final class MockLeakDataSession: NSObject, SCTDataSession {

    private let lock = NSLock()
    private var recorded: SCTDataSessionTaskInfo?

    var task: SCTDataSessionTaskInfo? {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    /// Drops the transport's own reference, leaving the task reachable only through
    /// whatever `AttachmentTransfer` still holds.
    func forget() {
        lock.lock(); defer { lock.unlock() }
        recorded = nil
    }

    func download(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {
        lock.lock(); defer { lock.unlock() }
        recorded = taskInfo
    }

    func upload(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {
        lock.lock(); defer { lock.unlock() }
        recorded = taskInfo
    }

    func getFilePath(attachment: ChatMessage.Attachment) -> String? { attachment.filePath }

    func thumbnailFile(for attachment: ChatMessage.Attachment, preferred size: CGSize) -> String? { nil }
}

// MARK: - Tests

/// A finished transfer must not outlive itself.
///
/// `AttachmentTransfer.handle` installs `taskInfo.onEvent`, and the task owns that
/// closure. Capturing `taskInfo` strongly inside it therefore closed a two-node retain
/// cycle — task to closure to task — that nothing anywhere ever broke, not even on a
/// clean success. Every attachment ever sent or fetched then stayed in memory for the
/// life of the process, together with its `ChatMessage`, its attachments and the
/// `ChannelMessageChecksumProvider` each task allocates. In Xcode's memory graph that
/// showed up as an ever-growing pile of `ChannelMessageChecksumProvider` instances
/// hanging off a "2-node cycle" root.
final class AttachmentTransferTaskLeakTests: XCTestCase {

    private var transfer: AttachmentTransfer!
    private var session: MockLeakDataSession!
    private var originalDataSession: SCTDataSession?
    private var originalDatabase: Database!

    private let messageId: MessageId = 4242

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalDatabase = DataProvider.database
        DataProvider.database = MockDatabase()
        originalDataSession = Components.dataSession
        session = MockLeakDataSession()
        Components.dataSession = session
        // A fresh instance, not `.default`: its caches are process-wide and would keep
        // state alive across tests.
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

    /// Deliberately not "video": a finishing *upload* of a video detours through
    /// `attachVideoThumbnailIfNeeded`, which is not what these tests are about.
    private func makeAttachment(
        tid: Int64 = 0,
        url: String? = nil,
        filePath: String? = nil
    ) -> ChatMessage.Attachment {
        .init(
            id: 0,
            tid: tid,
            messageId: messageId,
            userId: "user",
            url: url,
            filePath: filePath,
            type: "file",
            name: "report.pdf",
            metadata: nil,
            uploadedFileSize: 1024,
            createdAt: Date(),
            status: .pending
        )
    }

    private func makeMessage(_ attachments: [ChatMessage.Attachment]) -> ChatMessage {
        ChatMessage(id: messageId, channelId: 100, attachments: attachments, user: ChatUser(id: "u1"))
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }

    // MARK: - Tests

    func testFinishedDownloadTaskIsDeallocated() {
        weak var leaked: SCTDataSessionTaskInfo?

        autoreleasepool {
            let attachment = makeAttachment(url: "https://example.com/report.pdf")
            let message = makeMessage([attachment])

            transfer.downloadMessageAttachments(message: message, attachments: [attachment])
            XCTAssertTrue(waitUntil { self.session.task != nil },
                          "the transport was never asked to download")

            leaked = session.task
            // Drive the transfer the way a real transport would: some progress, then a
            // successful finish.
            session.task?.updateProgress(0.4)
            session.task?.success(origin: URL(string: "https://example.com/report.pdf")!)

            XCTAssertTrue(waitUntil { self.transfer.allTasks.isEmpty },
                          "the finished task was never retired from taskGroups")
            session.forget()
        }

        XCTAssertTrue(waitUntil { leaked == nil },
                      "a finished download task is still alive — onEvent is retaining it")
    }

    func testFinishedUploadTaskIsDeallocated() {
        weak var leaked: SCTDataSessionTaskInfo?

        autoreleasepool {
            let attachment = makeAttachment(tid: 77, filePath: "/tmp/report.pdf")
            let message = makeMessage([attachment])

            transfer.uploadMessageAttachments(message: message, attachments: [attachment])
            XCTAssertTrue(waitUntil { self.session.task != nil },
                          "the transport was never asked to upload")

            leaked = session.task
            session.task?.updateProgress(0.4)
            session.task?.success(origin: "https://example.com/report.pdf")

            XCTAssertTrue(waitUntil { self.transfer.allTasks.isEmpty },
                          "the finished task was never retired from taskGroups")
            session.forget()
        }

        XCTAssertTrue(waitUntil { leaked == nil },
                      "a finished upload task is still alive — onEvent is retaining it")
    }

    /// A transfer that never reaches `didEndTask` — the app is torn down mid-flight, the
    /// transport simply stops calling back — must still die once the registry lets go.
    /// The nil-out in `didEndTask` alone would not cover this; only the weak capture does.
    func testAbandonedTaskIsDeallocatedWhenTheRegistryDropsIt() {
        weak var leaked: SCTDataSessionTaskInfo?

        autoreleasepool {
            let attachment = makeAttachment(url: "https://example.com/abandoned.pdf")
            let message = makeMessage([attachment])

            transfer.downloadMessageAttachments(message: message, attachments: [attachment])
            XCTAssertTrue(waitUntil { self.session.task != nil },
                          "the transport was never asked to download")

            leaked = session.task
            session.task?.updateProgress(0.4)
            session.forget()
            // No success, no failure: drop the whole transfer instead, as a teardown would.
            transfer = nil
        }

        XCTAssertTrue(waitUntil { leaked == nil },
                      "an abandoned transfer task is still alive — onEvent is retaining it")
    }
}
