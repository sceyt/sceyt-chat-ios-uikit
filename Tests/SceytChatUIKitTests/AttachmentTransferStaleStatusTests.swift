//
//  AttachmentTransferStaleStatusTests.swift
//  SceytChatUIKitTests
//
//  A transfer status lives in the database; the transfer itself lives in a process. Kill the
//  process and the two disagree, and nothing on the next launch is obliged to notice — which is
//  how a video ends up fully downloaded and playable while the chat still shows its progress
//  ring. These tests pin the three seams that let that happen:
//
//  1. **Reconciliation.** `downloadMessageAttachmentsIfNeeded` runs on every cell bind and is the
//     only place a stale status can be corrected. It used to reconcile just two combinations
//     (`.pending` + file → `.done`, `.done` + no file → `.pending`), leaving a stale
//     `.downloading` whose bytes are on disk in a dead end: the heal skipped it, and the
//     needs-download filter dropped it because the file exists, so no task and therefore no
//     completion would ever write `.done`.
//  2. **Announcement.** `AttachmentTransferStatusRelay` is the backstop for a status change that
//     does not reach a view through its progress subscription. Pause, resume and failure were
//     announced on it; `.done` — the one that hides the ring — was not.
//  3. **Atomicity.** A finished download persisted its local file and its terminal status in two
//     separate async writes. A kill between them left `filePath` set under a `.downloading`
//     status: bytes on disk beneath a transfer the next launch keeps waiting on.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

final class AttachmentTransferStaleStatusTests: XCTestCase {

    private var transfer: AttachmentTransfer!
    private var session: MockTransferDataSession!
    private var mockDB: MockDatabase!
    private var originalDataSession: SCTDataSession?
    private var originalDatabase: Database!
    private var temporaryFiles = [String]()

    private let channelId: ChannelId = 100
    private let messageId: MessageId = 901
    private let attachmentId: AttachmentId = 851_649_417_420_390_401
    private let attachmentUrl = "https://cdn.example/9F1C0B/video.mp4"

    private var ctx: NSManagedObjectContext { mockDB.container.viewContext }

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalDatabase = DataProvider.database
        mockDB = MockDatabase()
        DataProvider.database = mockDB
        originalDataSession = Components.dataSession
        session = MockTransferDataSession()
        Components.dataSession = session
        // A fresh instance, not `.default`: the caches are process-wide and would otherwise
        // leak between tests.
        transfer = AttachmentTransfer()
    }

    override func tearDownWithError() throws {
        for path in temporaryFiles {
            try? FileManager.default.removeItem(atPath: path)
        }
        temporaryFiles.removeAll()
        Components.dataSession = originalDataSession
        DataProvider.database = originalDatabase
        transfer = nil
        session = nil
        mockDB = nil
        try super.tearDownWithError()
    }

    // MARK: - Fixtures

    private func makeAttachment(
        id: AttachmentId? = nil,
        url: String? = nil,
        filePath: String? = nil,
        type: String = "video",
        status: ChatMessage.Attachment.TransferStatus,
        transferProgress: Double = 0
    ) -> ChatMessage.Attachment {
        ChatMessage.Attachment(
            id: id ?? attachmentId,
            tid: 0,
            messageId: messageId,
            userId: "user",
            url: url ?? attachmentUrl,
            filePath: filePath,
            type: type,
            name: "video.mp4",
            metadata: nil,
            uploadedFileSize: 5_318_259,
            createdAt: Date(),
            status: status,
            transferProgress: transferProgress
        )
    }

    private func makeMessage(_ attachments: [ChatMessage.Attachment]) -> ChatMessage {
        ChatMessage(id: messageId, channelId: channelId, attachments: attachments, user: ChatUser(id: "u1"))
    }

    /// The row a relaunch reads back: whatever status was last committed, with no live task
    /// behind it. This is the state a kill mid-download leaves.
    @discardableResult
    private func seedRow(
        status: ChatMessage.Attachment.TransferStatus,
        filePath: String? = nil,
        transferProgress: Double = 0,
        type: String = "video"
    ) throws -> AttachmentDTO {
        let (_, _) = ChannelDTO.fetchOrCreate(id: channelId, context: ctx)
        let message = MessageDTO.fetchOrCreate(id: messageId, channelId: Int64(channelId), context: ctx)
        message.channelId = Int64(channelId)
        message.incoming = true
        message.createdAt = Date().bridgeDate
        message.user = UserDTO.fetchOrCreate(id: "u1", context: ctx)

        let attachment = AttachmentDTO.fetchOrCreate(url: attachmentUrl, message: message, context: ctx)
        attachment.id = Int64(attachmentId)
        attachment.channelId = Int64(channelId)
        attachment.type = type
        attachment.name = "video.mp4"
        attachment.createdAt = Date().bridgeDate
        attachment.uploadedFileSize = 5_318_259
        attachment.status = status.rawValue
        attachment.transferProgress = transferProgress
        attachment.filePath = filePath
        try ctx.save()
        return attachment
    }

    /// Reads the committed row back. Writes land on background contexts, so the value is polled
    /// until the merge into `viewContext` has happened.
    private func persistedStatus() -> ChatMessage.Attachment.TransferStatus? {
        ctx.refreshAllObjects()
        guard let dto = AttachmentDTO.fetch(id: attachmentId, context: ctx) else { return nil }
        return ChatMessage.Attachment.TransferStatus(rawValue: dto.status)
    }

    private func persistedRow() -> AttachmentDTO? {
        ctx.refreshAllObjects()
        return AttachmentDTO.fetch(id: attachmentId, context: ctx)
    }

    /// A real file, so the checks that ask the filesystem rather than the database see bytes.
    ///
    /// Written inside the storage folder, where a real download lands: `AttachmentDTO` stores
    /// `filePath` relative to that folder and re-absolutises it on read, so a path from anywhere
    /// else does not survive the round trip.
    private func makeFileOnDisk(named name: String = "video.mp4") throws -> String {
        let directory = URL(fileURLWithPath: Components.storage.storingKey.storageFolderPath)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory
            .appendingPathComponent("stale-status-\(UUID().uuidString)-\(name)").path
        try Data(repeating: 0x1, count: 2048).write(to: URL(fileURLWithPath: path))
        temporaryFiles.append(path)
        return path
    }

    private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }

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

    /// Records every status the relay announces. Held weakly by the relay, so a test must keep
    /// its own strong reference for as long as it expects deliveries.
    private final class RelayObserver: AttachmentTransferStatusObserver {
        private(set) var received = [(ChatMessage.Attachment, ChatMessage.Attachment.TransferStatus)]()
        func attachmentTransferStatusDidChange(
            _ attachment: ChatMessage.Attachment,
            status: ChatMessage.Attachment.TransferStatus
        ) {
            received.append((attachment, status))
        }
    }

    // MARK: - Gap 1: reconciling a status that outlived its transfer

    /// The reported bug, exactly. The app was killed mid-download, so the row says `.downloading`
    /// with no process behind it; the bytes are on disk. The heal skipped `.downloading` and the
    /// needs-download filter dropped it for having a file, so nothing ever wrote `.done` and the
    /// chat kept its ring up forever.
    func testStaleDownloadingWithBytesOnDiskIsHealedToDone() throws {
        let filePath = try makeFileOnDisk()
        session.setLocalPath(filePath, forUrl: attachmentUrl)
        let attachment = makeAttachment(status: .downloading, transferProgress: 0.4)
        let message = makeMessage([attachment])

        let started = transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])

        XCTAssertTrue(started.isEmpty, "the bytes are already on disk — nothing to download")
        XCTAssertEqual(attachment.status, .done,
                       "a .downloading status with no task and the file on disk is stale, and the file is the authority")
        XCTAssertEqual(attachment.transferProgress, 1)
        XCTAssertEqual(session.startedDownloadCount, 0)
    }

    /// Healing in memory alone is not enough: the layout model is rebuilt from the database on the
    /// next channel open, so an unpersisted heal is re-lost every launch.
    func testStaleDownloadingHealIsPersisted() throws {
        try seedRow(status: .downloading, transferProgress: 0.4)
        let filePath = try makeFileOnDisk()
        session.setLocalPath(filePath, forUrl: attachmentUrl)
        let attachment = makeAttachment(status: .downloading, transferProgress: 0.4)
        let message = makeMessage([attachment])

        transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])

        XCTAssertTrue(waitUntil { self.persistedStatus() == .done },
                      "the heal must be committed, or the next launch reads .downloading again")
        XCTAssertEqual(persistedRow()?.transferProgress, 1)
    }

    /// The resolved path is adopted onto the attachment: the row's `filePath` is empty after a
    /// kill mid-download, and a `.done` attachment with no path is what the inverse heal treats
    /// as "the file is gone" — the two would fight each other on every bind.
    func testHealAdoptsTheResolvedFilePath() throws {
        try seedRow(status: .downloading)
        let filePath = try makeFileOnDisk()
        session.setLocalPath(filePath, forUrl: attachmentUrl)
        let attachment = makeAttachment(status: .downloading)
        XCTAssertNil(attachment.filePath)
        let message = makeMessage([attachment])

        transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])

        XCTAssertEqual(attachment.filePath, filePath,
                       "the heal must record where the bytes actually are")
        _ = waitUntil { self.persistedRow()?.filePath != nil }
        XCTAssertEqual(persistedRow()?.fullFilePath, filePath,
                       "and commit it")
    }

    /// A pause is a user decision about a transfer, and the transfer is over — the bytes arrived.
    /// Leaving it `.pauseDownloading` shows a download button over a file that is already there.
    func testStalePausedDownloadWithBytesOnDiskIsHealedToDone() throws {
        let filePath = try makeFileOnDisk()
        session.setLocalPath(filePath, forUrl: attachmentUrl)
        let attachment = makeAttachment(status: .pauseDownloading)
        let message = makeMessage([attachment])

        let started = transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])

        XCTAssertTrue(started.isEmpty)
        XCTAssertEqual(attachment.status, .done,
                       "a paused download whose bytes are on disk has nothing left to resume")
    }

    /// Same for a failure: the retry already happened somewhere else and won.
    func testStaleFailedDownloadWithBytesOnDiskIsHealedToDone() throws {
        let filePath = try makeFileOnDisk()
        session.setLocalPath(filePath, forUrl: attachmentUrl)
        let attachment = makeAttachment(status: .failedDownloading)
        let message = makeMessage([attachment])

        let started = transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])

        XCTAssertTrue(started.isEmpty)
        XCTAssertEqual(attachment.status, .done,
                       "a failed download whose bytes are on disk succeeded after all")
    }

    /// Observers subscribed to the transfer are told, so a cell that bound before the heal ran
    /// resolves its completion rather than waiting on a transfer that will never start.
    func testHealNotifiesTheTransfersObservers() throws {
        let filePath = try makeFileOnDisk()
        session.setLocalPath(filePath, forUrl: attachmentUrl)
        let attachment = makeAttachment(status: .downloading)
        let message = makeMessage([attachment])

        var completions = [AttachmentTransfer.AttachmentCompletion]()
        transfer.progress(message: message, attachment: attachment, objectIdKey: "cell", block: { _ in }) {
            completions.append($0)
        }

        transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])

        XCTAssertEqual(completions.count, 1, "the heal must resolve the observers it silences")
        XCTAssertNil(completions.first?.error)
    }

    /// An upload also has a local file. Declaring it `.done` because a file exists would claim
    /// bytes reached the server that never left the device, so the heal must be download-only.
    func testHealDoesNotCompleteAFailedUpload() throws {
        let filePath = try makeFileOnDisk()
        session.setLocalPath(filePath, forUrl: attachmentUrl)
        let attachment = makeAttachment(filePath: filePath, status: .failedUploading)
        let message = makeMessage([attachment])

        transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])
        _ = waitUntil(timeout: 0.3) { false }

        XCTAssertEqual(attachment.status, .failedUploading,
                       "a failed upload's local file is the source, not proof of delivery")
        XCTAssertEqual(session.startedDownloadCount, 0)
    }

    /// And a paused upload keeps its retry affordance.
    func testHealDoesNotCompleteAPausedUpload() throws {
        let filePath = try makeFileOnDisk()
        session.setLocalPath(filePath, forUrl: attachmentUrl)
        let attachment = makeAttachment(filePath: filePath, status: .pauseUploading)
        let message = makeMessage([attachment])

        transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])
        _ = waitUntil(timeout: 0.3) { false }

        XCTAssertEqual(attachment.status, .pauseUploading)
    }

    /// A live transfer is not stale, whatever the filesystem says. Without this guard the heal
    /// would complete an upload out from under the task still streaming it.
    func testHealLeavesALiveTransferAlone() throws {
        let filePath = try makeFileOnDisk()
        let attachment = makeAttachment(status: .pending)
        let message = makeMessage([attachment])
        let task = try startDownload(message: message, attachments: [attachment])
        XCTAssertNotNil(task)
        // The transport reports the bytes as present only now, while its task is still live.
        session.setLocalPath(filePath, forUrl: attachmentUrl)

        transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])
        _ = waitUntil(timeout: 0.3) { false }

        XCTAssertEqual(attachment.status, .downloading,
                       "a transfer with a live task decides its own terminal status")
    }

    /// The regressions the heal must not cause: with no file on disk, a paused or failed download
    /// still waits for an explicit retry instead of restarting on every scroll.
    func testPausedDownloadWithNoFileStaysPausedAndDoesNotRestart() throws {
        let attachment = makeAttachment(status: .pauseDownloading)
        let message = makeMessage([attachment])

        let started = transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])
        _ = waitUntil(timeout: 0.3) { false }

        XCTAssertTrue(started.isEmpty)
        XCTAssertEqual(attachment.status, .pauseDownloading)
        XCTAssertEqual(session.startedDownloadCount, 0)
    }

    func testFailedDownloadWithNoFileStaysFailedAndDoesNotRestart() throws {
        let attachment = makeAttachment(status: .failedDownloading)
        let message = makeMessage([attachment])

        let started = transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])
        _ = waitUntil(timeout: 0.3) { false }

        XCTAssertTrue(started.isEmpty)
        XCTAssertEqual(attachment.status, .failedDownloading)
        XCTAssertEqual(session.startedDownloadCount, 0)
    }

    /// A stale `.downloading` with *no* file is a different case with a different answer: there is
    /// something to fetch, so it must actually be re-queued rather than healed.
    func testStaleDownloadingWithNoFileIsDownloadedAgain() throws {
        let attachment = makeAttachment(status: .downloading, transferProgress: 0.4)
        let message = makeMessage([attachment])

        let started = transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])

        XCTAssertEqual(started.count, 1, "there are no bytes on disk — this one must be fetched")
        XCTAssertTrue(waitUntil { self.session.startedDownloadCount == 1 })
    }

    /// The inverse heal, unchanged: `.done` is not proof the bytes are still there.
    func testDoneWithNoFileIsStillResetAndDownloadedAgain() throws {
        try seedRow(status: .done, transferProgress: 1)
        let attachment = makeAttachment(status: .done, transferProgress: 1)
        let message = makeMessage([attachment])

        let started = transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])

        XCTAssertEqual(started.count, 1)
        XCTAssertEqual(attachment.transferProgress, 0, "its stale 100% must be cleared")
        XCTAssertTrue(waitUntil { self.session.startedDownloadCount == 1 })
    }

    /// Link previews are metadata, not files, and must never be touched by either heal.
    func testLinkAttachmentIsUntouchedByTheHeal() throws {
        let filePath = try makeFileOnDisk()
        session.setLocalPath(filePath, forUrl: attachmentUrl)
        let link = makeAttachment(type: "link", status: .pending)
        let message = makeMessage([link])

        let started = transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [link])
        _ = waitUntil(timeout: 0.3) { false }

        XCTAssertTrue(started.isEmpty)
        XCTAssertEqual(link.status, .pending)
        XCTAssertEqual(session.startedDownloadCount, 0)
    }

    // MARK: - Gap 2: announcing `.done` on the status relay

    /// The relay exists to reach a view whose progress subscription did not carry the change —
    /// a cell reconfigured mid-download, a duplicate layout instance, an observer already
    /// removed. Pause, resume and failure were announced on it. `.done`, the status that hides
    /// the ring, was not, so those views had no second chance to learn the download finished.
    func testSuccessfulDownloadAnnouncesDoneOnTheRelay() throws {
        let attachment = makeAttachment(status: .pending)
        let message = makeMessage([attachment])
        let task = try startDownload(message: message, attachments: [attachment])

        let observer = RelayObserver()
        AttachmentTransferStatusRelay.default.add(observer)

        task.success(origin: attachmentUrl)

        XCTAssertTrue(waitUntil { observer.received.contains { $0.1 == .done } },
                      "a finished download must be announced, or a view that missed the completion keeps its ring")
    }

    /// The relay carries the attachment and consumers filter on transfer identity, so the
    /// announcement has to be matchable against the copy a cell is bound to.
    func testAnnouncedDoneIsMatchableByTransferIdentity() throws {
        let captured = makeAttachment(id: 0, status: .pending)
        let message = makeMessage([captured])
        let task = try startDownload(message: message, attachments: [captured])

        let observer = RelayObserver()
        AttachmentTransferStatusRelay.default.add(observer)

        task.success(origin: attachmentUrl)

        XCTAssertTrue(waitUntil { observer.received.contains { $0.1 == .done } })
        let announced = try XCTUnwrap(observer.received.first { $0.1 == .done }?.0)
        let boundInACell = makeAttachment(status: .downloading)
        XCTAssertEqual(
            AttachmentTransfer.transferIdentity(of: announced),
            AttachmentTransfer.transferIdentity(of: boundInACell),
            "a consumer bound to the database copy must recognise the announced attachment")
    }

    /// The heal is a status change raised outside any progress stream too — the same reason the
    /// relay exists — so it must announce as well, or a cell already on screen keeps its ring
    /// until something unrelated reconfigures it.
    func testHealAnnouncesDoneOnTheRelay() throws {
        let filePath = try makeFileOnDisk()
        session.setLocalPath(filePath, forUrl: attachmentUrl)
        let attachment = makeAttachment(status: .downloading)
        let message = makeMessage([attachment])

        let observer = RelayObserver()
        AttachmentTransferStatusRelay.default.add(observer)

        transfer.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])

        XCTAssertTrue(waitUntil { observer.received.contains { $0.1 == .done } },
                      "the heal must announce, or the visible cell keeps rendering the stale status")
    }

    // MARK: - Gap 3: the local file and the terminal status land together

    /// `SCTSession` stores the downloaded file, reports its location, and only then reports
    /// success — two separate async database writes. A kill in between committed `filePath`
    /// under a `.downloading` status: bytes on disk beneath a transfer the next launch keeps
    /// waiting on. This drives only the first half and asserts the committed row is already
    /// self-consistent.
    func testDownloadedFileAndTerminalStatusArePersistedTogether() throws {
        try seedRow(status: .downloading)
        let attachment = makeAttachment(status: .downloading)
        let message = makeMessage([attachment])
        let task = try startDownload(message: message, attachments: [attachment])
        let filePath = try makeFileOnDisk()

        // The transport has the bytes on disk. `success` is deliberately not called — that is
        // the write the kill would have prevented.
        task.updateLocalFileLocation(newPath: filePath)

        _ = waitUntil { self.persistedRow()?.filePath != nil }
        XCTAssertEqual(persistedRow()?.fullFilePath, filePath,
                       "the local file must be committed")
        XCTAssertEqual(persistedStatus(), .done,
                       "the committed row must never say \"bytes on disk, still downloading\"")
        XCTAssertEqual(persistedRow()?.transferProgress, 1)
    }

    /// And the in-memory attachment agrees, so a cell binding in that window does not seed a ring
    /// for a transfer whose bytes have landed.
    func testDownloadedFileMarksTheAttachmentDoneInMemory() throws {
        let attachment = makeAttachment(status: .downloading)
        let message = makeMessage([attachment])
        let task = try startDownload(message: message, attachments: [attachment])
        let filePath = try makeFileOnDisk()

        task.updateLocalFileLocation(newPath: filePath)

        XCTAssertTrue(waitUntil { attachment.status == .done })
        XCTAssertEqual(attachment.filePath, filePath)
    }

    /// An upload's local file is its *source*: `SCTUploadOperation` moves the resized image or
    /// exported video into storage and reports the new location before a byte is sent. Treating
    /// that as completion would mark every upload done the moment it started.
    func testRelocatingAnUploadsSourceFileDoesNotCompleteIt() throws {
        let sourcePath = try makeFileOnDisk(named: "outgoing.mp4")
        let attachment = makeAttachment(url: "", filePath: sourcePath, status: .pending)
        let message = makeMessage([attachment])

        transfer.uploadMessageAttachments(message: message, attachments: [attachment])
        // An outgoing attachment has no remote url yet, and the mock keys such an upload
        // under the empty string.
        XCTAssertTrue(waitUntil { self.session.task(forUrl: "") != nil },
                      "the transport was never asked to upload")
        let task = try XCTUnwrap(session.task(forUrl: ""))

        let storedPath = try makeFileOnDisk(named: "stored.mp4")
        task.updateLocalFileLocation(newPath: storedPath)
        _ = waitUntil(timeout: 0.3) { false }

        XCTAssertEqual(attachment.status, .uploading,
                       "an upload is finished by its server ack, not by its file moving")
    }

    /// Whatever the atomic write records, the real completion still runs and still announces —
    /// the two must not fight, and `.done` must arrive on the relay exactly as before.
    func testSuccessAfterTheAtomicWriteStillCompletesTheTransfer() throws {
        try seedRow(status: .downloading)
        let attachment = makeAttachment(status: .downloading)
        let message = makeMessage([attachment])
        let task = try startDownload(message: message, attachments: [attachment])
        let filePath = try makeFileOnDisk()

        var completions = [AttachmentTransfer.AttachmentCompletion]()
        transfer.progress(message: message, attachment: attachment, objectIdKey: "cell", block: { _ in }) {
            completions.append($0)
        }

        task.updateLocalFileLocation(newPath: filePath)
        task.success(origin: attachmentUrl)

        XCTAssertTrue(waitUntil { !completions.isEmpty }, "observers must still be told")
        XCTAssertNil(completions.first?.error)
        XCTAssertTrue(waitUntil { self.transfer.taskFor(message: message, attachment: attachment) == nil },
                      "a finished task must still leave the group")
        XCTAssertNil(transfer.currentProgressPercent(message: message, attachment: attachment),
                     "the cached percent must still be dropped")
        // The task leaves the group as soon as its final write is *enqueued*, so poll rather
        // than reading the row on the same tick.
        XCTAssertTrue(waitUntil { self.persistedStatus() == .done },
                      "the committed row must end up .done")
    }
}
