//
//  AttachmentTransferPipelineTests.swift
//  SceytChatUIKitTests
//
//  `AttachmentTransfer` end to end over `TransportDataSession` and a scripted
//  `FileTransferProvider`: the provider's prepared metadata entries saved before the upload
//  and kept through every metadata rebuild, the video poster on upload and on download, event
//  ordering, cancel / pause / resume, and the checksum table (`ChannelMessageChecksumProvider`).
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import UIKit
import XCTest

// MARK: - Fakes

/// Answers uploads with "PLAIN", or as the test says.
private final class ScriptedProvider: FileTransferProvider {
    var onUpload: ((FileUploadRequest) async -> FileTransferResult<FileUploadResult>)?
    /// The prepare step's answer; nil prepares nothing.
    var onPrepare: ((FileUploadRequest) async throws -> [String: String]?)?
    private var _prepares = [FileUploadRequest]()
    var prepares: [FileUploadRequest] { lock.lock(); defer { lock.unlock() }; return _prepares }

    func prepareUpload(_ request: FileUploadRequest) async throws -> [String: String]? {
        lock.lock(); _prepares.append(request); lock.unlock()
        return try await onPrepare?(request)
    }

    var onDownload: (FileDownloadRequest) async -> FileTransferResult<URL> = { _ in .failure(URLError(.badURL)) }
    private let lock = NSLock()
    private var _uploads = [FileUploadRequest]()
    private var _downloads = [FileDownloadRequest]()
    var uploads: [FileUploadRequest] { lock.lock(); defer { lock.unlock() }; return _uploads }
    var downloads: [FileDownloadRequest] { lock.lock(); defer { lock.unlock() }; return _downloads }
    let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    func upload(_ request: FileUploadRequest, progress: @escaping (Double) -> Void) async -> FileTransferResult<FileUploadResult> {
        lock.lock(); _uploads.append(request); lock.unlock()
        if let onUpload { return await onUpload(request) }
        return .success(FileUploadResult(url: "PLAIN"))
    }

    func download(_ request: FileDownloadRequest, progress: @escaping (Double) -> Void) async -> FileTransferResult<URL> {
        lock.lock(); _downloads.append(request); lock.unlock()
        return await onDownload(request)
    }

    private var _cancelled = [String]()
    var cancelled: [String] { lock.lock(); defer { lock.unlock() }; return _cancelled }

    func cancel(operationId: String) {
        lock.lock(); _cancelled.append(operationId); lock.unlock()
    }
}

/// The router, storing under one directory, with hooks for what the transport split cannot fake.
private final class HookedSession: TransportDataSession {
    let root: URL
    var checksums = false
    /// Replace the whole upload / download when set.
    var onUpload: ((ChatMessage.Attachment, SCTDataSessionTaskInfo) -> Void)?
    var onDownload: ((ChatMessage.Attachment, SCTDataSessionTaskInfo) -> Void)?
    /// Runs after the transport was handed a download, before `AttachmentTransfer` goes on.
    var afterDownloadStarted: ((SCTDataSessionTaskInfo) -> Void)?
    var onThumbnailUpload: (URL) -> Result<String, Error> = { _ in .failure(SCTDataSessionError.thumbnailUploadFailed) }
    var onThumbnailDownload: (String) -> Result<URL, Error> = { _ in .failure(SCTDataSessionError.thumbnailDownloadFailed) }
    private(set) var thumbnailUploads = [Data]()

    init(transport: FileTransferProvider, root: URL) {
        self.root = root
        super.init(provider: transport)
    }

    override var checksumsBeforeUpload: Bool { checksums }
    override var stagingDirectory: URL { root.appendingPathComponent("staging", isDirectory: true) }
    /// Whether a video's poster goes as a preview attachment (the new flow) or the old way.
    var previews = false
    override var sendsVideoPreviewAttachments: Bool { previews }

    override func storeFile(atPath path: String, transferId: String, fileName: String?) -> String { path }

    override func downloadDestination(for attachment: ChatMessage.Attachment) -> URL? {
        let folder = root.appendingPathComponent("downloads/\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(attachment.name ?? "file")
    }

    override func prepareUploadFile(
        for attachment: ChatMessage.Attachment,
        taskInfo: SCTDataSessionTaskInfo,
        operationId: String,
        videoProcessInfo: SCVideoProcessInfo
    ) async throws -> PreparedUploadFile {
        PreparedUploadFile(file: URL(fileURLWithPath: try XCTUnwrap(attachment.filePath)), isStaged: false)
    }

    override func upload(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {
        if let onUpload { return onUpload(attachment, taskInfo) }
        super.upload(attachment: attachment, taskInfo: taskInfo)
    }

    override func download(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {
        if let onDownload { return onDownload(attachment, taskInfo) }
        super.download(attachment: attachment, taskInfo: taskInfo)
        afterDownloadStarted?(taskInfo)
    }

    /// When set, a poster upload answers after this long, off the caller's queue.
    var thumbnailDelay: TimeInterval = 0
    /// Replaces `getFilePath` when set.
    var filePathFor: ((ChatMessage.Attachment) -> String?)?

    override func getFilePath(attachment: ChatMessage.Attachment) -> String? {
        if let filePathFor { return filePathFor(attachment) }
        return super.getFilePath(attachment: attachment)
    }

    override func uploadAttachmentThumbnail(for attachment: ChatMessage.Attachment, fileUrl: URL, completion: @escaping (Result<String, Error>) -> Void) {
        if let data = try? Data(contentsOf: fileUrl) { thumbnailUploads.append(data) }
        let result = onThumbnailUpload(fileUrl)
        guard thumbnailDelay > 0 else { return completion(result) }
        DispatchQueue.global().asyncAfter(deadline: .now() + thumbnailDelay) { completion(result) }
    }

    override func downloadAttachmentThumbnail(for attachment: ChatMessage.Attachment, origin: String, completion: @escaping (Result<URL, Error>) -> Void) {
        completion(onThumbnailDownload(origin))
    }
}

/// `AttachmentTransfer` with the connection state and the poster frame under the test's control.
private final class PosterTransfer: AttachmentTransfer {
    /// Whether the device is offline, as the test sets it (read from the transfer queues).
    private let offlineState = Locked(true)
    var offline: Bool {
        get { offlineState.wrapped }
        set { offlineState.wrapped = newValue }
    }

    required init() {
        super.init()
        let offlineState = offlineState
        connectivity = { offlineState.wrapped }
    }
    /// Copied to a new temporary file for each poster asked for.
    var poster: URL?

    override func makeVideoThumbnailFile(for attachment: ChatMessage.Attachment) -> URL? {
        guard let poster else { return nil }
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("pvw_\(UUID().uuidString).jpg")
        try? FileManager.default.copyItem(at: poster, to: copy)
        return copy
    }

    /// The files the preview step made its poster from.
    private(set) var posterSources = [URL]()

    override func makeVideoThumbnailFile(from file: URL, for attachment: ChatMessage.Attachment) -> URL? {
        posterSources.append(file)
        return makeVideoThumbnailFile(for: attachment)
    }
}

private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
    return condition()
}

// MARK: - AttachmentTransfer

final class AttachmentTransferPipelineTests: XCTestCase {

    private var transfer: PosterTransfer!
    private var transport: ScriptedProvider!
    private var session: HookedSession!
    private var directory: URL!
    private var originalDataSession: SCTDataSession?
    private var originalDatabase: Database!

    private let messageId: MessageId = 902

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalDatabase = DataProvider.database
        DataProvider.database = MockDatabase()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pipeline-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        transport = ScriptedProvider(directory: directory)
        session = HookedSession(transport: transport, root: directory)
        transfer = PosterTransfer()
        transfer.offline = true
        let session = session!
        transfer.environment.dataSession = { session }
    }

    override func tearDownWithError() throws {
        DataProvider.database = originalDatabase
        try? FileManager.default.removeItem(at: directory)
        transfer = nil
        session = nil
        transport = nil
        try super.tearDownWithError()
    }

    // MARK: Fixtures

    private func file(size: Int = 100, ext: String = "bin") throws -> URL {
        let url = directory.appendingPathComponent("plain-\(UUID().uuidString).\(ext)")
        try Data((0..<size).map { UInt8(truncatingIfNeeded: $0 &* 17) }).write(to: url)
        return url
    }

    private func image() throws -> URL {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30), format: format).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
        let url = directory.appendingPathComponent("image-\(UUID().uuidString).png")
        try XCTUnwrap(image.pngData()).write(to: url)
        return url
    }

    private func makeAttachment(
        tid: Int64 = 1,
        type: String = "file",
        name: String = "report.pdf",
        url: String? = nil,
        filePath: String? = nil,
        metadata: String? = nil
    ) -> ChatMessage.Attachment {
        .init(id: 0, tid: tid, messageId: messageId, userId: "user", url: url, filePath: filePath, type: type, name: name, metadata: metadata, uploadedFileSize: 0, createdAt: Date())
    }

    private func makeMessage(_ attachments: [ChatMessage.Attachment]) -> ChatMessage {
        ChatMessage(id: messageId, channelId: 100, attachments: attachments, user: ChatUser(id: "u1"))
    }

    private func makeTask(_ attachment: ChatMessage.Attachment, _ type: SCTDataSessionTaskInfo.TransferType) -> SCTDataSessionTaskInfo {
        SCTDataSessionTaskInfo(transferType: type, message: makeMessage([attachment]), attachment: attachment)
    }

    private func upload(_ attachment: ChatMessage.Attachment, timeout: TimeInterval = 5) -> Error? {
        // Set on the transfer's queues, read here: behind a lock.
        let outcome = Locked<(finished: Bool, error: Error?)>((false, nil))
        transfer.uploadMessageAttachments(message: makeMessage([attachment]), attachments: [attachment]) { _, error in
            outcome.wrapped = (true, error)
        }
        XCTAssertTrue(waitUntil(timeout: timeout) { outcome.wrapped.finished }, "the upload never completed")
        return outcome.wrapped.error
    }

    private func download(_ attachment: ChatMessage.Attachment, timeout: TimeInterval = 5) -> (finished: Bool, error: Error?) {
        // Set on the transfer's queues, read here: behind a lock.
        let outcome = Locked<(finished: Bool, error: Error?)>((false, nil))
        transfer.downloadMessageAttachments(message: makeMessage([attachment]), attachments: [attachment]) { _, error in
            outcome.wrapped = (true, error)
        }
        let finished = waitUntil(timeout: timeout) { outcome.wrapped.finished }
        return (finished, outcome.wrapped.error)
    }

    /// A remote attachment: the stored object and what the message carries (with a provider's
    /// entry, which UIKit passes on and never reads).
    private func remote(of plaintext: URL, type: String = "file", name: String = "report.pdf", metadata: String = #"{"tmb":"x"}"#) throws -> (attachment: ChatMessage.Attachment, object: URL) {
        let object = directory.appendingPathComponent("remote-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: plaintext, to: object)
        let attachment = makeAttachment(
            tid: 0,
            type: type,
            name: name,
            url: "REMOTE-\(UUID().uuidString)",
            metadata: try ChatMessage.Attachment.metadata(metadata, merging: ["sceyt.enc": "TOKEN"])
        )
        return (attachment, object)
    }

    /// Serves `object` as stored: UIKit decrypts it.
    private func serve(_ object: URL) {
        transport.onDownload = { request in
            let staging = self.directory.appendingPathComponent("staging-\(UUID().uuidString)")
            do {
                try FileManager.default.copyItem(at: object, to: staging)
                try DefaultFileTransferProvider.publish(staging, to: request)
                return .success(request.destinationFile)
            } catch {
                return .failure(error)
            }
        }
    }

    // MARK: - Dedupe

    private func copy(_ file: URL) throws -> URL {
        let url = directory.appendingPathComponent("copy-\(UUID().uuidString).bin")
        try FileManager.default.copyItem(at: file, to: url)
        return url
    }

    /// An earlier upload of `content`: its message, its attachment and its checksum row.
    private func seedStoredUpload(of content: URL, url: String, metadata: String) throws {
        let database = try XCTUnwrap(DataProvider.database as? MockDatabase)
        let storedAttachment = makeAttachment(tid: 9000, url: url, filePath: content.path, metadata: metadata)
        let storedMessage = ChatMessage(id: 7000, channelId: 100, attachments: [storedAttachment], user: ChatUser(id: "u1"))
        try database.syncWrite { context in
            context.createOrUpdate(message: storedMessage.builder.build(), channelId: 100)
            context.createOrUpdate(checksum: .init(checksum: try XCTUnwrap(Components.storage.dedupeChecksum(filePath: content.path)), messageTid: storedMessage.tid, attachmentTid: 9000, data: url))
        }
        let found = database.read { AttachmentDTO.fetch(url: url, context: $0)?.convert() }
        XCTAssertEqual(try found.get()?.metadata, metadata, "the seeded attachment is found by its url")
    }

    // MARK: - Video poster on upload

    private func videoUpload() throws -> ChatMessage.Attachment {
        transfer.poster = try file(size: 2000, ext: "jpg")
        return makeAttachment(type: "video", name: "clip.mp4", filePath: try file(size: 4000, ext: "mp4").path)
    }


    func testAPlaintextVideoSendsAPlaintextPoster() throws {
        let attachment = try videoUpload()
        let poster = try Data(contentsOf: try XCTUnwrap(transfer.poster))
        session.onThumbnailUpload = { _ in .success("PLAIN-POSTER") }

        XCTAssertNil(upload(attachment))

        XCTAssertEqual(session.thumbnailUploads, [poster])
        XCTAssertEqual(try ChatMessage.Attachment.Metadata<String>.decode(try XCTUnwrap(attachment.metadata)).videoThumbnail, "PLAIN-POSTER")
    }

    func testAPosterThatFailsToUploadLeavesTheVideoWithoutOne() throws {
        let attachment = try videoUpload()
        session.onThumbnailUpload = { _ in .failure(SCTDataSessionError.thumbnailUploadFailed) }

        XCTAssertNil(upload(attachment))

        XCTAssertNil(try? ChatMessage.Attachment.Metadata<String>.decode(attachment.metadata ?? "").videoThumbnail)
        XCTAssertEqual(attachment.status, .done)
    }


    // MARK: - Video poster on download

    func testStoringAPlaintextPosterWritesItAsIs() async throws {
        let download = try file(size: 50, ext: "jpg")
        let bytes = try Data(contentsOf: download)
        let destination = directory.appendingPathComponent("thumb.jpg")

        try AttachmentTransfer.storeVideoThumbnail(download, of: makeAttachment(type: "video", metadata: #"{"pvw":"T"}"#), at: destination)

        XCTAssertEqual(try Data(contentsOf: destination), bytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: download.path), "the downloaded file is consumed")
    }

    // MARK: - Event ordering

    /// A transport that fails before `AttachmentTransfer` has installed its event hooks: the
    /// failure must still reach the completion.
    func testAFailureReportedBeforeTheHooksAreInstalledIsNotLost() throws {
        let remote = try remote(of: try file(size: 500))
        // A refusal: a connectivity error would park the download as `.pending` for a retry.
        transport.onDownload = { _ in .failure(URLError(.badServerResponse)) }
        session.afterDownloadStarted = { taskInfo in
            // Hold the transfer's queue until the session has reported, as a fast transport would.
            _ = waitUntilOffMain { taskInfo.event.map { if case .failure = $0 { return true } else { return false } } ?? false }
        }

        let (finished, error) = download(remote.attachment, timeout: 3)

        XCTAssertTrue(finished, "the download never completed")
        XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        XCTAssertEqual(remote.attachment.status, .failedDownloading)
        XCTAssertTrue(transfer.allTasks.isEmpty, "the task left the transfer")
    }

    /// The same for an upload a session fails synchronously, inside `upload(attachment:taskInfo:)`.
    func testAnUploadFailedAtOnceBySessionStillCompletes() throws {
        transfer.offline = false
        session.onUpload = { _, taskInfo in taskInfo.failure(error: URLError(.badServerResponse)) }
        let attachment = makeAttachment(tid: 60, filePath: try file().path)

        let error = upload(attachment, timeout: 3)

        XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        XCTAssertEqual(attachment.status, .failedUploading)
        XCTAssertTrue(transfer.allTasks.isEmpty)
    }

    // MARK: - Missing source, cancel

    /// An upload whose file is gone fails, so its status changes and its completion runs.
    func testAnUploadWithoutALocalFileFailsInsteadOfBeingSkipped() throws {
        transfer.offline = true
        let attachment = makeAttachment(tid: 61, filePath: nil)

        let error = upload(attachment)

        guard case .missingSourceFile = error as? TransportDataSessionError else {
            return XCTFail("expected missingSourceFile, got \(String(describing: error))")
        }
        XCTAssertEqual(attachment.status, .failedUploading, "a file that is gone fails even offline")
        XCTAssertTrue(transport.uploads.isEmpty)
        XCTAssertTrue(transfer.allTasks.isEmpty)
    }

    /// A cancelled upload ends: its task leaves the transfer, and a later upload of the same
    /// file is a new one instead of waiting on the cancelled task forever.
    func testACancelledUploadEndsAndTheFileCanBeUploadedAgain() throws {
        let attempts = Locked(0)
        transport.onUpload = { _ in
            var attempt = 0
            attempts.mutate { $0 += 1; attempt = $0 }
            if attempt == 1 {
                // Until the cancel stops it.
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                return .interrupted(CancellationError())
            }
            return .success(FileUploadResult(url: "SECOND"))
        }
        let attachment = makeAttachment(tid: 62, filePath: try file().path)
        let message = makeMessage([attachment])
        var first: (done: Bool, error: Error?) = (false, nil)
        transfer.uploadMessageAttachments(message: message, attachments: [attachment]) { _, error in first = (true, error) }
        XCTAssertTrue(waitUntil { self.transport.uploads.count == 1 })

        transfer.taskFor(message: message, attachment: attachment)?.cancel()

        XCTAssertTrue(waitUntil { first.done }, "a cancelled upload completes")
        XCTAssertEqual((first.error as? URLError)?.code, .cancelled)
        XCTAssertEqual(attachment.status, .pauseUploading, "a user cancel is never resent by a reconnect")
        XCTAssertTrue(waitUntil { self.transfer.allTasks.isEmpty }, "the task left the transfer")

        XCTAssertNil(upload(attachment))
        XCTAssertEqual(transport.uploads.count, 2, "uploaded again, not swallowed by the cancelled task")
        XCTAssertEqual(attachment.url, "SECOND")
        XCTAssertEqual(attachment.status, .done)
    }

    // MARK: - Cancel, pause, interruption (finding #6)

    /// The statuses `SyncService.resendPendingMessage` skips: a message with such an
    /// attachment is not resent on the next connect.
    private let notResent: Set<ChatMessage.Attachment.TransferStatus> = [.pauseUploading, .pauseDownloading]

    private func holdUploads() {
        transport.onUpload = { _ in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            return .interrupted(CancellationError())
        }
    }

    func testAUserCancelIsNotResentOnReconnect() throws {
        for offline in [false, true] {
            transfer.offline = offline
            holdUploads()
            let attachment = makeAttachment(tid: offline ? 64 : 63, filePath: try file().path)
            let message = makeMessage([attachment])
            var done = false
            transfer.uploadMessageAttachments(message: message, attachments: [attachment]) { _, _ in done = true }
            XCTAssertTrue(waitUntil { self.transfer.taskFor(message: message, attachment: attachment) != nil && !self.transport.uploads.isEmpty })

            transfer.taskFor(message: message, attachment: attachment)?.cancel()

            XCTAssertTrue(waitUntil { done })
            XCTAssertTrue(notResent.contains(attachment.status), "offline=\(offline): \(attachment.status) would be resent on reconnect")
            transport = ScriptedProvider(directory: directory)
            session = HookedSession(transport: transport, root: directory)
            let current = session!
            transfer.environment.dataSession = { current }
        }
    }

    /// "Stop" from outside the chat (the background-upload activity) cancels each running
    /// upload as the user's own cancel would: kept in the chat, never resent on reconnect.
    func testCancelAllUploadsCancelsEachAsTheUserWould() throws {
        transfer.offline = false
        holdUploads()
        let attachment = makeAttachment(tid: 71, filePath: try file().path)
        let message = makeMessage([attachment])
        let done = Locked(false)
        transfer.uploadMessageAttachments(message: message, attachments: [attachment]) { _, _ in done.wrapped = true }
        XCTAssertTrue(waitUntil { self.transfer.taskFor(message: message, attachment: attachment) != nil && !self.transport.uploads.isEmpty })

        let cancelled = Locked<Int?>(nil)
        transfer.cancelAllUploads(reason: "test") { cancelled.wrapped = $0 }

        XCTAssertTrue(waitUntil { done.wrapped })
        XCTAssertEqual(cancelled.wrapped, 1)
        XCTAssertTrue(notResent.contains(attachment.status), "\(attachment.status) would be resent on reconnect")
        XCTAssertNil(attachment.url)

        let none = Locked<Int?>(nil)
        transfer.cancelAllUploads(reason: "test again") { none.wrapped = $0 }
        XCTAssertTrue(waitUntil { none.wrapped != nil })
        XCTAssertEqual(none.wrapped, 0, "nothing left running")
    }

    /// A cancel the session reports without the task's own `cancel()` (an abandoned upload,
    /// `TransportDataSession.cancel(attachments:)`) is the user's too.
    func testAnAbandonedUploadIsNotResentOnReconnect() throws {
        transfer.offline = false
        holdUploads()
        let attachment = makeAttachment(tid: 65, filePath: try file().path)
        let message = makeMessage([attachment])
        var done = false
        transfer.uploadMessageAttachments(message: message, attachments: [attachment]) { _, _ in done = true }
        XCTAssertTrue(waitUntil { !self.transport.uploads.isEmpty })

        session.cancel(attachments: [attachment])

        XCTAssertTrue(waitUntil { done })
        XCTAssertEqual(attachment.status, .pauseUploading)
    }

    /// An interruption stays resendable, even when the error it carries is a cancellation.
    func testAnInterruptionStaysResendable() throws {
        for (offline, error, expected) in [
            (true, URLError(.cancelled), ChatMessage.Attachment.TransferStatus.pending),
            (true, URLError(.networkConnectionLost), .pending),
            (false, URLError(.networkConnectionLost), .failedUploading),
        ] {
            transfer.offline = offline
            holdUploads()
            let attachment = makeAttachment(tid: 66, filePath: try file().path)
            let message = makeMessage([attachment])
            var done = false
            transfer.uploadMessageAttachments(message: message, attachments: [attachment]) { _, _ in done = true }
            XCTAssertTrue(waitUntil { !self.transport.uploads.isEmpty })

            session.interruptTransfers(error: error)

            XCTAssertTrue(waitUntil { done })
            XCTAssertEqual(attachment.status, expected, "offline=\(offline) \(error.code)")
            XCTAssertFalse(notResent.contains(attachment.status), "an interruption is resent on reconnect")
            transport = ScriptedProvider(directory: directory)
            session = HookedSession(transport: transport, root: directory)
            let current = session!
            transfer.environment.dataSession = { current }
        }
    }

    /// A pause stops the upload without ending it, and a resume sends it.
    func testAPausedUploadStillResumes() throws {
        transfer.offline = false
        let attempts = Locked(0)
        transport.onUpload = { _ in
            var attempt = 0
            attempts.mutate { $0 += 1; attempt = $0 }
            if attempt == 1 {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                return .interrupted(CancellationError())
            }
            return .success(FileUploadResult(url: "RESUMED"))
        }
        let attachment = makeAttachment(tid: 67, filePath: try file().path)
        let message = makeMessage([attachment])
        let done = Locked<Error??>(nil)
        transfer.uploadMessageAttachments(message: message, attachments: [attachment]) { _, error in done.wrapped = .some(error) }
        XCTAssertTrue(waitUntil { self.transport.uploads.count == 1 })

        let paused = Locked<Bool?>(nil)
        transfer.stopTransfer(message: message, attachment: attachment) { paused.wrapped = $0 }
        XCTAssertTrue(waitUntil { paused.wrapped != nil })
        XCTAssertEqual(paused.wrapped, true)
        XCTAssertEqual(attachment.status, .pauseUploading)
        XCTAssertNotNil(transfer.taskFor(message: message, attachment: attachment), "a pause keeps the task")
        // The session sees the pause once it is persisted.
        XCTAssertTrue(waitUntil { self.transfer.taskFor(message: message, attachment: attachment)?.action == .stop })

        let resumed = Locked<Bool?>(nil)
        transfer.resumeTransfer(message: message, attachment: attachment) { resumed.wrapped = $0 }
        XCTAssertTrue(waitUntil { done.wrapped != nil })
        XCTAssertTrue(waitUntil { resumed.wrapped != nil })
        XCTAssertEqual(resumed.wrapped, true)
        XCTAssertNil(done.wrapped ?? nil)
        XCTAssertEqual(attachment.url, "RESUMED")
        XCTAssertEqual(attachment.status, .done)
    }

    func testUploadStatusAfterFailure() {
        XCTAssertEqual(AttachmentTransfer.uploadStatus(afterFailure: URLError(.cancelled), isOffline: false), .pauseUploading)
        XCTAssertEqual(AttachmentTransfer.uploadStatus(afterFailure: FileTransferError.cancelled, isOffline: false), .pauseUploading)
        XCTAssertEqual(AttachmentTransfer.uploadStatus(afterFailure: URLError(.timedOut), userCancelled: true, isOffline: false), .pauseUploading)
        XCTAssertEqual(AttachmentTransfer.uploadStatus(afterFailure: URLError(.cancelled), interrupted: true, isOffline: false), .pending)
        XCTAssertEqual(AttachmentTransfer.uploadStatus(afterFailure: AttachmentMetadataError.notAnObject, isOffline: false), .failedUploading)
        XCTAssertEqual(AttachmentTransfer.uploadStatus(afterFailure: TransportDataSessionError.missingSourceFile, isOffline: false), .failedUploading)
        XCTAssertEqual(AttachmentTransfer.uploadStatus(afterFailure: URLError(.timedOut), isOffline: false), .failedUploading)
        XCTAssertEqual(AttachmentTransfer.uploadStatus(afterFailure: URLError(.timedOut), isOffline: true), .pending)
    }

    // MARK: - Two starts for one message (finding #7)

    func testTwoStartsForOneMessageKeepEachOthersTasksAndCompletions() throws {
        transfer.offline = false
        let release = ReleaseSet()
        transport.onUpload = { request in
            while !release.contains(request.operationId) {
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
            return .success(FileUploadResult(url: "REF-\(request.operationId)"))
        }
        let a = makeAttachment(tid: 80, filePath: try file().path)
        let b = makeAttachment(tid: 81, filePath: try file().path)
        let message = makeMessage([a, b])
        let calls = CallLog()

        transfer.uploadMessageAttachments(message: message, attachments: [a]) { _, error in calls.record("first", error) }
        XCTAssertTrue(waitUntil { self.transport.uploads.count == 1 })
        transfer.uploadMessageAttachments(message: message, attachments: [b]) { _, error in calls.record("second", error) }
        XCTAssertTrue(waitUntil { self.transfer.allTasks.count == 2 }, "the second start merges, it does not drop the first's task")
        XCTAssertNotNil(transfer.taskFor(message: message, attachment: a))
        XCTAssertNotNil(transfer.taskFor(message: message, attachment: b))

        // Two more callers wait on the running upload of `a`: both keep their completion.
        transfer.uploadMessageAttachments(message: message, attachments: [a]) { _, error in calls.record("third", error) }
        transfer.uploadMessageAttachments(message: message, attachments: [a]) { _, error in calls.record("fourth", error) }
        XCTAssertTrue(waitUntil { calls.count("third") == 1 && calls.count("fourth") == 1 }, "told at once that it is already uploading")
        XCTAssertEqual(transfer.allTasks.count, 2, "no task for an upload already running")

        release.insert("upload-80")
        XCTAssertTrue(waitUntil { calls.count("first") == 1 && calls.count("third") == 2 && calls.count("fourth") == 2 },
                      "every caller waiting on a's upload hears its end: \(calls.names)")
        XCTAssertEqual(a.url, "REF-upload-80")
        XCTAssertEqual(transfer.allTasks.count, 1)
        XCTAssertNotNil(transfer.taskFor(message: message, attachment: b), "b's task is still there")

        release.insert("upload-81")
        XCTAssertTrue(waitUntil { calls.count("second") == 1 })
        XCTAssertEqual(b.url, "REF-upload-81")
        XCTAssertTrue(waitUntil { self.transfer.allTasks.isEmpty })
    }

    /// A task rejected before it starts never joins the message's group.
    func testARejectedUploadNeverJoinsTheRunningGroup() throws {
        transfer.offline = false
        holdUploads()
        let running = makeAttachment(tid: 82, filePath: try file().path)
        let missing = makeAttachment(tid: 83, filePath: nil)
        let message = makeMessage([running, missing])
        transfer.uploadMessageAttachments(message: message, attachments: [running])
        XCTAssertTrue(waitUntil { self.transfer.allTasks.count == 1 })

        var failed: Error?
        transfer.uploadMessageAttachments(message: message, attachments: [missing]) { _, error in failed = error }
        XCTAssertTrue(waitUntil { failed != nil })

        XCTAssertEqual(transfer.allTasks.count, 1)
        XCTAssertTrue(transfer.allTasks.first?.attachment === running)
    }

    // MARK: - Dedupe hit with a new poster (finding #2)

    // MARK: - Prepare hook

}

// MARK: - Coverage: the rest of AttachmentTransfer's transfer paths

/// `AttachmentTransfer` with no data session at all.
private final class SessionlessTransfer: AttachmentTransfer {
    override func dataSession(for message: ChatMessage? = nil, forAttachment: ChatMessage.Attachment? = nil) -> SCTDataSession? { nil }
}

/// A video processor that returns one fixed frame.
private final class OneFrameProcessor: VideoProcessor {
    static var frame: UIImage?
    override class func copyFrame(url: URL, at time: TimeInterval = 1) -> UIImage? { frame }
}

extension AttachmentTransferPipelineTests {

    private func pngImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
    }

    func testTheConnectionDecidesWhetherTheClientIsOffline() {
        XCTAssertEqual(AttachmentTransfer.isOffline, SceytChatUIKit.shared.chatClient.connectionState != .connected)
    }

    func testTransferIdentityFallsBackToThePathThenTheId() {
        XCTAssertEqual(AttachmentTransfer.transferIdentity(of: makeAttachment(tid: 0, filePath: "/a/B.PDF")), "pathb.pdf")
        let byId = ChatMessage.Attachment(id: 44, tid: 0, messageId: 1, userId: "u", url: nil, filePath: nil, type: "file", name: nil, metadata: nil, uploadedFileSize: 0, createdAt: Date())
        XCTAssertEqual(AttachmentTransfer.transferIdentity(of: byId), "id44")
        XCTAssertEqual(AttachmentTransfer.transferIdentity(of: makeAttachment(tid: 0)), "unknown")
    }

    func testAReceivedImageThatDoesNotDecodeIsRemovedOnce() throws {
        let message = makeMessage([])
        let broken = try file(size: 50, ext: "jpg")
        let attachment = makeAttachment(tid: 0, type: "image", url: "REMOTE-IMG-\(UUID().uuidString)", filePath: broken.path)

        XCTAssertFalse(transfer.keepsLocalFile(broken.path, of: attachment, message: message))
        XCTAssertFalse(FileManager.default.fileExists(atPath: broken.path))
        XCTAssertNil(attachment.filePath)
        // Downloaded again and still broken: kept, or it would download on every bind.
        try Data(count: 50).write(to: broken)
        XCTAssertTrue(transfer.keepsLocalFile(broken.path, of: attachment, message: message))

        let good = directory.appendingPathComponent("good-\(UUID().uuidString).png")
        try XCTUnwrap(pngImage().pngData()).write(to: good)
        XCTAssertTrue(transfer.keepsLocalFile(good.path, of: attachment, message: message))
        XCTAssertTrue(transfer.keepsLocalFile(good.path, of: attachment, message: message), "known readable")
    }

    func testRemovingEveryObserverWithoutAKey() {
        let attachment = makeAttachment(tid: 70)
        let message = makeMessage([attachment])
        transfer.progress(message: message, attachment: attachment, block: { _ in })
        transfer.progress(message: message, attachment: attachment, block: { _ in })
        transfer.removeProgressObserver(message: message, attachment: attachment)
        XCTAssertNil(transfer.currentProgressPercent(message: message, attachment: attachment))
    }

    func testNothingToUploadOrDownload() {
        let uploaded = Locked(false)
        transfer.uploadMessageAttachments(message: makeMessage([]), attachments: []) { _, error in
            XCTAssertNil(error)
            uploaded.wrapped = true
        }
        let downloaded = Locked(false)
        let bare = ChatMessage(id: messageId, channelId: 100, attachments: nil, user: ChatUser(id: "u1"))
        transfer.downloadMessageAttachments(message: bare) { _, error in
            XCTAssertNil(error)
            downloaded.wrapped = true
        }
        XCTAssertTrue(waitUntil { uploaded.wrapped && downloaded.wrapped })
    }

    func testWithoutADataSessionNothingTransfers() {
        let sessionless = SessionlessTransfer()
        let attachment = makeAttachment(tid: 71, url: "REMOTE", filePath: "/tmp/x")
        let errors = Locked([Error?]())
        sessionless.uploadMessageAttachments(message: makeMessage([attachment])) { _, error in errors.mutate { $0.append(error) } }
        sessionless.downloadMessageAttachments(message: makeMessage([attachment])) { _, error in errors.mutate { $0.append(error) } }
        XCTAssertTrue(waitUntil { errors.wrapped.count == 2 })
        for error in errors.wrapped {
            guard case .externalTransferrerNotImplemented = error as? AttachmentTransferError else { return XCTFail("\(String(describing: error))") }
        }
        XCTAssertEqual(sessionless.filePath(attachment: attachment), "/tmp/x")
        XCTAssertEqual(sessionless.filePath(attachment: makeAttachment(tid: 72, url: "https://cdn.example/none/a.bin")), Components.storage.filePath(for: "https://cdn.example/none/a.bin"))
        XCTAssertNil(sessionless.filePath(attachment: makeAttachment(tid: 73)))
    }

    func testAnUploadReportsTheMessageWhenItIsStored() throws {
        let attachment = makeAttachment(tid: 74, filePath: try file().path)
        let message = makeMessage([attachment])
        try XCTUnwrap(DataProvider.database as? MockDatabase).syncWrite { $0.createOrUpdate(message: message.builder.build(), channelId: 100) }
        var reported: ChatMessage?
        var done = false
        transfer.uploadMessageAttachments(message: message, attachments: [attachment]) { message, _ in
            reported = message
            done = true
        }
        XCTAssertTrue(waitUntil { done })
        XCTAssertNotNil(reported, "the message exists, so it is reported")
    }

    func testTheSessionsPathForTheFileIsUsed() throws {
        let own = try file()
        let resolved = try file()
        session.filePathFor = { _ in resolved.path }
        let attachment = makeAttachment(tid: 75, filePath: own.path)
        XCTAssertNil(upload(attachment))
        XCTAssertEqual(transport.uploads.first?.sourceFile.path, resolved.path)
    }

    func testAMissingSourceIsRecoveredFromTheSessionOrTheTemporaryFolder() throws {
        transfer.offline = false
        let recovered = try file()
        let gone = directory.appendingPathComponent("gone.bin").path
        session.filePathFor = { $0.filePath == gone ? recovered.path : $0.filePath }
        let fromSession = makeAttachment(tid: 76, filePath: gone)
        XCTAssertNil(upload(fromSession))
        XCTAssertEqual(transport.uploads.last?.sourceFile.path, recovered.path)

        session.filePathFor = { _ in nil }
        let name = "recover-\(UUID().uuidString).bin"
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try Data([1]).write(to: temporary)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let fromTemp = makeAttachment(tid: 77, name: name, filePath: directory.appendingPathComponent("elsewhere/\(name)").path)
        _ = upload(fromTemp)
        XCTAssertEqual(fromTemp.filePath.map { URL(fileURLWithPath: $0).standardizedFileURL.path }, temporary.standardizedFileURL.path)

        // Nothing to recover from: no name, or no such temporary file.
        let nameless = makeAttachment(tid: 78, name: "", filePath: directory.appendingPathComponent("x/").path)
        _ = upload(nameless)
        let unknown = makeAttachment(tid: 79, name: "never-\(UUID().uuidString)", filePath: directory.appendingPathComponent("y").path)
        _ = upload(unknown)
    }

    func testADownloadWithoutAURLFailsAndAWaitingCallerHearsTheEnd() throws {
        var failed: Error?
        let noURL = makeAttachment(tid: 0)
        transfer.downloadMessageAttachments(message: makeMessage([noURL])) { _, error in failed = error }
        XCTAssertTrue(waitUntil { failed != nil })
        guard case .missingURL = failed as? AttachmentTransferError else { return XCTFail("\(String(describing: failed))") }
        XCTAssertEqual(noURL.status, .failedDownloading, "a terminal status, not a spinner nothing will end")
        XCTAssertTrue(transfer.allTasks.isEmpty, "the task left the transfer")

        let remote = try remote(of: try file(size: 300))
        let release = ReleaseSet()
        transport.onDownload = { request in
            while !release.contains("go") { try? await Task.sleep(nanoseconds: 5_000_000) }
            return .failure(URLError(.timedOut))
        }
        let calls = CallLog()
        let message = makeMessage([remote.attachment])
        transfer.downloadMessageAttachments(message: message) { _, error in calls.record("first", error) }
        XCTAssertTrue(waitUntil { !self.transport.downloads.isEmpty })
        transfer.downloadMessageAttachments(message: message) { _, error in calls.record("second", error) }
        XCTAssertTrue(waitUntil { calls.count("second") == 1 })
        release.insert("go")
        XCTAssertTrue(waitUntil { calls.count("first") == 1 && calls.count("second") == 2 })
    }

    func testPauseAndResumeWithoutATaskOrAMatchingAttachment() throws {
        let uploading = makeAttachment(tid: 80, filePath: "/tmp/u")
        uploading.status = .uploading
        let done = makeAttachment(tid: 81)
        done.status = .done
        let answers = Locked([Bool]())
        transfer.stopTransfer(message: makeMessage([uploading]), attachment: uploading) { answer in answers.mutate { $0.append(answer) } }
        transfer.stopTransfer(message: makeMessage([done]), attachment: done) { answer in answers.mutate { $0.append(answer) } }
        transfer.resumeTransfer(message: makeMessage([done]), attachment: done) { answer in answers.mutate { $0.append(answer) } }
        XCTAssertTrue(waitUntil { answers.wrapped.count == 3 })
        XCTAssertEqual(answers.wrapped, [true, false, false])
        XCTAssertEqual(uploading.status, .pauseUploading)
        XCTAssertNil(transfer.transferStatus(message: makeMessage([done]), attachment: done))

        // A task whose message no longer lists the attachment.
        transport.onUpload = { _ in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            return .interrupted(CancellationError())
        }
        let running = makeAttachment(tid: 82, filePath: try file().path)
        let message = makeMessage([running])
        transfer.uploadMessageAttachments(message: message, attachments: [running])
        XCTAssertTrue(waitUntil { !self.transport.uploads.isEmpty })
        XCTAssertEqual(transfer.transferStatus(message: message, attachment: running), .uploading)
        let emptied = makeMessage([])
        answers.wrapped = []
        transfer.stopTransfer(message: emptied, attachment: running) { answer in answers.mutate { $0.append(answer) } }
        transfer.resumeTransfer(message: emptied, attachment: running) { answer in answers.mutate { $0.append(answer) } }
        XCTAssertTrue(waitUntil { answers.wrapped.count == 2 })
        XCTAssertEqual(answers.wrapped, [false, false], "nothing matched, so nothing was paused or resumed: callers restart the transfer")
        transfer.taskFor(message: message, attachment: running)?.cancel()
    }

    func testAFinishingVideoCannotBePausedAndNeedsNoResume() throws {
        let attachment = try videoUpload()
        let message = makeMessage([attachment])
        session.onThumbnailUpload = { _ in .success("POSTER") }
        session.thumbnailDelay = 0.6
        let finished = Locked(false)
        transfer.uploadMessageAttachments(message: message, attachments: [attachment]) { _, _ in finished.wrapped = true }
        XCTAssertTrue(waitUntil { self.transfer.taskFor(message: message, attachment: attachment)?.isTransferFinished == true })

        let answers = Locked([Bool]())
        transfer.stopTransfer(message: message, attachment: attachment) { answer in answers.mutate { $0.append(answer) } }
        transfer.resumeTransfer(message: message, attachment: attachment) { answer in answers.mutate { $0.append(answer) } }
        XCTAssertTrue(waitUntil { answers.wrapped.count == 2 })
        XCTAssertEqual(answers.wrapped, [false, true])
        XCTAssertTrue(waitUntil { finished.wrapped })
        XCTAssertEqual(attachment.status, .done)
    }

    func testAPosterFrameIsMadeFromTheVideo() throws {
        OneFrameProcessor.frame = pngImage()
        let base = AttachmentTransfer()
        base.environment.videoProcessor = { OneFrameProcessor.self }
        let video = makeAttachment(tid: 83, type: "video", filePath: try file(size: 10, ext: "mp4").path)

        let poster = try XCTUnwrap(base.makeVideoThumbnailFile(for: video))
        XCTAssertNotNil(UIImage(contentsOfFile: poster.path))
        try? FileManager.default.removeItem(at: poster)
        XCTAssertNil(base.makeVideoThumbnailFile(for: makeAttachment(tid: 84, type: "video", filePath: "/no/such.mp4")))
    }

    func testAPosterThatTakesTooLongIsLeftOut() throws {
        transfer.videoThumbnailTimeout = 0.2
        session.thumbnailDelay = 0.6
        for prepared in [nil, ["sceyt.enc": "TOKEN"]] as [[String: String]?] {
            transport.onPrepare = { _ in prepared }
            session.onThumbnailUpload = { _ in .success("LATE") }
            let attachment = try videoUpload()

            XCTAssertNil(upload(attachment))

            XCTAssertNil(try? ChatMessage.Attachment.Metadata<String>.decode(attachment.metadata ?? "").videoThumbnail, "sent without it")
            XCTAssertEqual(attachment.status, .done)
            // Let the late answer arrive: this test is about time (an answer after the
            // poster timeout), so it waits out the delay on purpose.
            _ = waitUntil(timeout: 0.6) { false }
            XCTAssertNil(try? ChatMessage.Attachment.Metadata<String>.decode(attachment.metadata ?? "").videoThumbnail, "a late poster is not attached")
            XCTAssertEqual(attachment.stringMetadataEntries["sceyt.enc"], prepared?["sceyt.enc"])
        }
    }

    func testAVideoWithoutAFrameOrWhosePlainPosterFailsGoesWithout() throws {
        let noFrame = try videoUpload()
        transfer.poster = nil
        XCTAssertNil(upload(noFrame))
        XCTAssertTrue(session.thumbnailUploads.isEmpty)

        let failing = try videoUpload()
        session.onThumbnailUpload = { _ in .failure(SCTDataSessionError.thumbnailUploadFailed) }
        XCTAssertNil(upload(failing))
        XCTAssertEqual(failing.status, .done)
    }

    func testWhetherAPosterNeedsADownload() {
        let origin = "https://cdn.example/poster-\(UUID().uuidString).jpg"
        let video = makeAttachment(tid: 0, type: "video", url: "REMOTE-V", metadata: #"{"tmb":"x","pvw":"\#(origin)"}"#)
        XCTAssertTrue(transfer.needsVideoThumbnailDownload(attachment: video))
        XCTAssertFalse(transfer.needsVideoThumbnailDownload(attachment: makeAttachment(type: "image")))
    }

    func testAPosterDownloadThatFailsIsDropped() {
        let origin = "poster-fail-\(UUID().uuidString)"
        let video = makeAttachment(tid: 0, type: "video", url: "REMOTE-V2", metadata: #"{"tmb":"x","pvw":"\#(origin)"}"#)
        // Asked from the poster's own task: counted behind a lock.
        let asked = Locked(0)
        session.onThumbnailDownload = { _ in
            asked.mutate { $0 += 1 }
            return .failure(SCTDataSessionError.thumbnailDownloadFailed)
        }
        transfer.downloadVideoThumbnailsIfNeeded(message: makeMessage([video]))
        XCTAssertTrue(waitUntil { asked.wrapped == 1 })
        XCTAssertTrue(transfer.needsVideoThumbnailDownload(attachment: video), "retried on the next bind")
    }

    func testASuccessByURLAndAMovedFileArePersisted() throws {
        let moved = try file()
        session.onUpload = { _, taskInfo in
            DispatchQueue.global().async {
                taskInfo.updateLocalFileLocation(newPath: moved.path)
                taskInfo.success(origin: URL(string: "https://cdn.example/by-url")!)
            }
        }
        let attachment = makeAttachment(tid: 85, filePath: try file().path)
        XCTAssertNil(upload(attachment))
        XCTAssertEqual(attachment.url, "https://cdn.example/by-url")
        XCTAssertEqual(attachment.filePath, moved.path)
    }

    func testAnEndThatCannotBePersistedStillCompletes() throws {
        let faulty = FaultyDatabase(try XCTUnwrap(DataProvider.database as? MockDatabase))
        faulty.failingWrites = Set(1...100)
        DataProvider.database = faulty
        let attachment = makeAttachment(tid: 86, filePath: try file().path)
        XCTAssertNil(upload(attachment))
        XCTAssertEqual(attachment.status, .done)
    }

    func testThePausedSummary() {
        let attachment = makeAttachment(tid: 87)
        attachment.status = .pauseUploading
        AttachmentTransfer.logSummary(makeTask(attachment, .upload), attachment: attachment, error: URLError(.timedOut))
    }

    func testSmallFallbacks() throws {
        // No observer to remove.
        let lonely = makeAttachment(tid: 88)
        transfer.removeProgressObserver(message: makeMessage([lonely]), attachment: lonely, objectIdKey: "nobody")
        // The message's own attachments when none are given.
        XCTAssertTrue(transfer.downloadMessageAttachmentsIfNeeded(message: makeMessage([makeAttachment(tid: 89, type: "link")])).isEmpty)
        // A nameless attachment is recovered by its file's name.
        let name = "nameless-\(UUID().uuidString).bin"
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try Data([1]).write(to: temporary)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let nameless = ChatMessage.Attachment(id: 0, tid: 90, messageId: messageId, userId: "u", url: nil, filePath: directory.appendingPathComponent("moved/\(name)").path, type: "file", name: nil, metadata: nil, uploadedFileSize: 0, createdAt: Date())
        _ = upload(nameless)
        XCTAssertEqual(nameless.filePath.map { URL(fileURLWithPath: $0).standardizedFileURL.path }, temporary.standardizedFileURL.path)
    }

    func testAVoiceWhoseFileIsAnImageKeepsItsVoiceMetadata() throws {
        let image = directory.appendingPathComponent("voice-\(UUID().uuidString).png")
        try XCTUnwrap(pngImage().pngData()).write(to: image)
        let voice = makeAttachment(tid: 0, type: "voice", name: "v.png", url: "REMOTE-VOICE", metadata: #"{"tmb":[1,2,3],"dur":2}"#)
        session.onDownload = { _, taskInfo in
            DispatchQueue.global().async {
                taskInfo.updateLocalFileLocation(newPath: image.path)
                taskInfo.success(origin: "REMOTE-VOICE")
            }
        }
        let (finished, error) = download(voice)
        XCTAssertTrue(finished)
        XCTAssertNil(error)
        XCTAssertEqual(try ChatMessage.Attachment.Metadata<[Int]>.decode(try XCTUnwrap(voice.metadata)).width, 20)
    }
}

private final class ReleaseSet {
    private let lock = NSLock()
    private var ids = Set<String>()
    func insert(_ id: String) { lock.lock(); ids.insert(id); lock.unlock() }
    func contains(_ id: String) -> Bool { lock.lock(); defer { lock.unlock() }; return ids.contains(id) }
}

private final class CallLog {
    private let lock = NSLock()
    private var calls = [(String, Error?)]()
    func record(_ name: String, _ error: Error?) { lock.lock(); calls.append((name, error)); lock.unlock() }
    func count(_ name: String) -> Int { lock.lock(); defer { lock.unlock() }; return calls.filter { $0.0 == name }.count }
    var names: [String] { lock.lock(); defer { lock.unlock() }; return calls.map(\.0) }
}

// MARK: - Log trail

/// Every log line written while it is installed, with its level.
private final class TrailCapture {
    private let lock = NSLock()
    private var _lines = [(level: SceytChatUIKit.Logger.LogLevel, text: String)]()
    private let previousLevel = Components.logger.logLevel
    private let previousCallback = Components.logger.onLog

    init() {
        Components.logger.setLogLevel(.verbose) { [weak self] message, level, _, _, _, _ in
            guard let self else { return }
            self.lock.lock(); self._lines.append((level, message)); self.lock.unlock()
        }
    }

    /// The lines so far, and a fresh start.
    func take() -> [(level: SceytChatUIKit.Logger.LogLevel, text: String)] {
        lock.lock(); defer { lock.unlock() }
        let lines = _lines
        _lines = []
        return lines
    }

    func stop() {
        Components.logger.setLogLevel(previousLevel, callBack: previousCallback)
    }
}

extension AttachmentTransferPipelineTests {

}

/// Waits on a background-safe spin (the caller is not the main thread).
private func waitUntilOffMain(timeout: TimeInterval = 2, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        Thread.sleep(forTimeInterval: 0.005)
    }
    return condition()
}

// MARK: - ChannelMessageChecksumProvider

final class ChecksumReuseTests: XCTestCase {

    private var database: MockDatabase!
    private var originalDatabase: Database!
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalDatabase = DataProvider.database
        database = MockDatabase()
        DataProvider.database = database
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("checksum-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        DataProvider.database = originalDatabase
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    private func file(_ bytes: Data) throws -> URL {
        let url = directory.appendingPathComponent("\(UUID().uuidString).bin")
        try bytes.write(to: url)
        return url
    }

    private func attachment(tid: Int64, url: String? = nil, filePath: String?, metadata: String? = nil, size: UInt? = nil, type: String = "file") -> ChatMessage.Attachment {
        let size = size ?? filePath.map { Storage.sizeOfItem(at: $0) } ?? 0
        return .init(id: 0, tid: tid, messageId: 0, userId: "u", url: url, filePath: filePath, type: type, name: "a.bin", metadata: metadata, uploadedFileSize: size, createdAt: Date())
    }

    /// An earlier upload of `bytes`, under `key` (its own dedupe checksum by default).
    private func seed(_ bytes: Data, url: String, metadata: String, storedSize: UInt? = nil, key: Int64? = nil) throws {
        let stored = attachment(tid: 8000, url: url, filePath: try file(bytes).path, metadata: metadata, size: storedSize)
        let message = ChatMessage(id: 6000, channelId: 1, attachments: [stored], user: ChatUser(id: "u"))
        let key = try key ?? XCTUnwrap(Components.storage.dedupeChecksum(filePath: stored.filePath!))
        try database.syncWrite { context in
            context.createOrUpdate(message: message.builder.build(), channelId: 1)
            context.createOrUpdate(checksum: .init(checksum: key, messageTid: message.tid, attachmentTid: 8000, data: url))
        }
    }

    private func checksumRows(_ key: Int64) -> Int {
        (try? database.read { ChecksumDTO.fetch(checksum: key, context: $0) != nil ? 1 : 0 }.get()) ?? 0
    }

    private func checksum(_ attachment: ChatMessage.Attachment) -> Result<String?, Error>? {
        let message = ChatMessage(id: 0, channelId: 1, attachments: [attachment], user: ChatUser(id: "u"))
        var result: Result<String?, Error>?
        let provider = ChannelMessageChecksumProvider()
        provider.startChecksum(message: message, attachment: attachment) { result = $0 }
        XCTAssertTrue(waitUntil { result != nil })
        return result
    }

    /// A hit reuses the stored attachment's url with its whole metadata: a provider's entries
    /// (the key that object was encrypted with) go with it.
    func testAHitReusesTheStoredObjectWithItsProvidersEntries() throws {
        let bytes = Data("plain again".utf8)
        try seed(bytes, url: "OBJECT-2", metadata: #"{"tmb":"t","sceyt.enc":"STORED-TOKEN"}"#)

        let new = attachment(tid: 3, filePath: try file(bytes).path)
        guard case .success(let link) = checksum(new) else { return XCTFail("the checksum failed") }
        XCTAssertEqual(link, "OBJECT-2")
        XCTAssertEqual(new.stringMetadataEntries["sceyt.enc"], "STORED-TOKEN")
    }

    // MARK: Collisions

    /// Two files whose sampled bytes are the same but whose sizes differ: the old CRC32-only
    /// key matched them, and the second send delivered the first file.
    func testFilesOfDifferentSizesNeverShareAnObject() throws {
        let saved = Storage.calculateChecksumMaxBytes
        Storage.calculateChecksumMaxBytes = 30
        defer { Storage.calculateChecksumMaxBytes = saved }
        let first = Data(repeating: 0, count: 100)
        let second = Data(repeating: 0, count: 101)
        XCTAssertEqual(Components.storage.checksum(filePath: try file(first).path), Components.storage.checksum(filePath: try file(second).path), "the sampled CRC32 alone collides")
        try seed(first, url: "FIRST-FILE", metadata: #"{"tmb":"t"}"#)

        let new = attachment(tid: 20, filePath: try file(second).path)
        guard case .success(let link) = checksum(new) else { return XCTFail("the checksum failed") }

        XCTAssertNil(link, "a miss: the size is part of the match")
        XCTAssertNotEqual(new.status, .done)
    }

    /// A row whose key matches but whose stored object is of another size is not reused.
    func testAStoredObjectOfAnotherSizeIsNotReused() throws {
        let bytes = Data("sized bytes".utf8)
        let local = try file(bytes)
        try seed(Data("other".utf8), url: "OTHER-SIZE", metadata: #"{"tmb":"t"}"#, storedSize: 5, key: try XCTUnwrap(Components.storage.dedupeChecksum(filePath: local.path)))

        guard case .success(let link) = checksum(attachment(tid: 21, filePath: local.path)) else { return XCTFail("the checksum failed") }

        XCTAssertNil(link)
    }

    /// Every empty or unreadable file had checksum 0: they all shared one row.
    func testAnEmptyOrUnreadableFileIsNeverDedupedOrRecorded() throws {
        try seed(Data("x".utf8), url: "ZERO-ROW", metadata: #"{"tmb":"t"}"#, key: 0)
        let empty = try file(Data())
        let missing = directory.appendingPathComponent("gone.bin").path
        XCTAssertNil(Components.storage.dedupeChecksum(filePath: empty.path))
        XCTAssertNil(Components.storage.dedupeChecksum(filePath: missing))

        for path in [empty.path, missing] {
            guard case .success(let link) = checksum(attachment(tid: 22, filePath: path, size: 0)) else { return XCTFail("the checksum failed") }
            XCTAssertNil(link, "\(path) never matches the 0 row")
        }
        XCTAssertEqual(checksumRows(0), 1, "only the seeded row: nothing new is recorded under 0")
    }

    /// Rows written before the size was part of the key hold a bare CRC32: never matched.
    func testARowWithTheOldKeyIsNotMatched() throws {
        let bytes = Data("legacy bytes".utf8)
        let local = try file(bytes)
        try seed(bytes, url: "LEGACY", metadata: #"{"tmb":"t"}"#, key: Int64(Components.storage.checksum(filePath: local.path)))

        guard case .success(let link) = checksum(attachment(tid: 23, filePath: local.path)) else { return XCTFail("the checksum failed") }

        XCTAssertNil(link)
        XCTAssertEqual(checksumRows(try XCTUnwrap(Components.storage.dedupeChecksum(filePath: local.path))), 1, "recorded under the new key for the next send")
    }

    func testNothingToChecksum() {
        for attachment in [attachment(tid: 4, filePath: nil), ChatMessage.Attachment(id: 0, tid: 5, messageId: 0, userId: "u", url: "https://x", filePath: "/tmp/x", type: "link", name: nil, metadata: nil, uploadedFileSize: 0, createdAt: Date())] {
            guard case .success(nil) = checksum(attachment) else { return XCTFail("\(attachment)") }
        }
    }
}

// MARK: - Coverage: the checksum table's failure paths, and Storage's checksum helpers

/// `MockDatabase`, failing the reads and writes the test names (counted from 1).
final class FaultyDatabase: Database {
    let inner: MockDatabase
    var failingReads = Set<Int>()
    var failingWrites = Set<Int>()
    private let lock = NSLock()
    private var reads = 0
    private var writes = 0
    struct Failure: Error {}

    init(_ inner: MockDatabase) { self.inner = inner }

    private func nextRead() -> Bool { lock.lock(); defer { lock.unlock() }; reads += 1; return failingReads.contains(reads) }
    private func nextWrite() -> Bool { lock.lock(); defer { lock.unlock() }; writes += 1; return failingWrites.contains(writes) }

    func write(resultQueue: DispatchQueue, _ perform: @escaping (NSManagedObjectContext) throws -> Void, completion: ((Error?) -> Void)?) {
        guard !nextWrite() else { resultQueue.async { completion?(Failure()) }; return }
        inner.write(resultQueue: resultQueue, perform, completion: completion)
    }
    func performWriteTask(resultQueue: DispatchQueue, _ perform: @escaping (NSManagedObjectContext) throws -> Void, completion: ((Error?) -> Void)?) {
        write(resultQueue: resultQueue, perform, completion: completion)
    }
    func syncWrite(_ perform: @escaping (NSManagedObjectContext) throws -> Void) throws { try inner.syncWrite(perform) }
    func read<Fetch>(resultQueue: DispatchQueue, _ perform: @escaping (NSManagedObjectContext) throws -> Fetch, completion: ((Result<Fetch, Error>) -> Void)?) {
        guard !nextRead() else { resultQueue.async { completion?(.failure(Failure())) }; return }
        inner.read(resultQueue: resultQueue, perform, completion: completion)
    }
    func read<Fetch>(_ perform: @escaping (NSManagedObjectContext) throws -> Fetch) -> Result<Fetch, Error> { inner.read(perform) }
    func performBgTask<Fetch>(resultQueue: DispatchQueue, _ perform: @escaping (NSManagedObjectContext) throws -> Fetch, completion: ((Result<Fetch, Error>) -> Void)?) {
        read(resultQueue: resultQueue, perform, completion: completion)
    }
    var viewContext: NSManagedObjectContext { inner.viewContext }
    var backgroundPerformContext: NSManagedObjectContext { inner.backgroundPerformContext }
    var backgroundReadOnlyContext: NSManagedObjectContext { inner.backgroundReadOnlyContext }
    var backgroundReadOnlyObservableContext: NSManagedObjectContext { inner.backgroundReadOnlyObservableContext }
    func recreate(completion: @escaping ((Error?) -> Void)) { inner.recreate(completion: completion) }
    func deleteAll(completion: (() -> Void)?) { inner.deleteAll(completion: completion) }
}

/// Answers the lookup with a fixed row, without resolving the asset path (and, when asked,
/// with the file gone from the attachment).
private final class RowProvider: ChannelMessageChecksumProvider {
    var row: ChatMessage.Attachment.Checksum?
    var clearsFile = false
    convenience init(row: ChatMessage.Attachment.Checksum, clearsFile: Bool) {
        self.init()
        self.row = row
        self.clearsFile = clearsFile
    }
    override func checksum(attachment: ChatMessage.Attachment, completion: @escaping (ChatMessage.Attachment.Checksum?) -> Void) {
        if clearsFile { attachment.filePath = nil }
        completion(row)
    }
}

/// A video processor that finds no asset for any identifier.
private final class NoAssetProcessor: VideoProcessor {
    override class func assetUrl(localIdentifier: String, completion: @escaping (URL?) -> Void) { completion(nil) }
}

extension ChecksumReuseTests {

    private func faulty(reads: Set<Int> = [], writes: Set<Int> = []) -> FaultyDatabase {
        let faulty = FaultyDatabase(database)
        faulty.failingReads = reads
        faulty.failingWrites = writes
        DataProvider.database = faulty
        return faulty
    }

    func testNothingToChecksumOrRecord() throws {
        let provider = ChannelMessageChecksumProvider()
        let message = ChatMessage(id: 0, channelId: 1, attachments: [], user: ChatUser(id: "u"))
        var looked: ChatMessage.Attachment.Checksum?? = nil
        provider.checksum(attachment: attachment(tid: 30, filePath: nil)) { looked = .some($0) }
        XCTAssertTrue(waitUntil { looked != nil })
        XCTAssertNil(looked ?? nil)
        var recorded: Error?? = nil
        provider.createChecksum(message: message, attachment: attachment(tid: 31, filePath: nil)) { recorded = .some($0) }
        XCTAssertTrue(waitUntil { recorded != nil })

        // A video whose asset cannot be found.
        // The checksum is model code outside the transfer layer: it reads the app's component.
        let original = Components.videoProcessor
        defer { Components.videoProcessor = original }
        Components.videoProcessor = NoAssetProcessor.self
        let video = attachment(tid: 32, filePath: try file(Data([1, 2])).path, type: "video")
        looked = nil
        provider.checksum(attachment: video) { looked = .some($0) }
        XCTAssertTrue(waitUntil { looked != nil })
        XCTAssertNil(looked ?? nil)
    }

    func testALookupThatFailsIsAMiss() throws {
        _ = faulty(reads: [1])
        let new = attachment(tid: 33, filePath: try file(Data("lookup".utf8)).path)
        guard case .success(nil) = checksum(new) else { return XCTFail() }
    }

    func testARecordThatFailsFailsTheChecksum() throws {
        _ = faulty(writes: [1])
        let new = attachment(tid: 34, filePath: try file(Data("record".utf8)).path)
        guard case .failure = checksum(new) else { return XCTFail("the upload fails with it") }
    }

    func testARowWhoseObjectNoAttachmentHasIsAMiss() throws {
        let bytes = Data("orphan row".utf8)
        let local = try file(bytes)
        let key = try XCTUnwrap(Components.storage.dedupeChecksum(filePath: local.path))
        try database.syncWrite { $0.createOrUpdate(checksum: .init(checksum: key, messageTid: 1, attachmentTid: 1, data: "NOBODY-HAS-IT")) }

        guard case .success(nil) = checksum(attachment(tid: 35, filePath: local.path)) else { return XCTFail() }
    }

    func testAFailedLookupOfTheStoredAttachmentFailsTheChecksum() throws {
        let bytes = Data("second read".utf8)
        try seed(bytes, url: "STORED-READ", metadata: #"{"tmb":"t"}"#)
        _ = faulty(reads: [2])
        guard case .failure = checksum(attachment(tid: 36, filePath: try file(bytes).path)) else { return XCTFail() }
    }

    func testAHitThatCannotBePersistedFailsTheChecksum() throws {
        let bytes = Data("hit write".utf8)
        try seed(bytes, url: "STORED-WRITE", metadata: #"{"tmb":"t"}"#)
        _ = faulty(writes: [1])
        guard case .failure = checksum(attachment(tid: 37, filePath: try file(bytes).path)) else { return XCTFail() }
    }

    func testAHitInAMessageOfSeveralAttachmentsReplacesTheMatchingOne() throws {
        let bytes = Data("several".utf8)
        try seed(bytes, url: "STORED-SEVERAL", metadata: #"{"tmb":"t"}"#)
        let hit = attachment(tid: 38, filePath: try file(bytes).path)
        let other = attachment(tid: 39, filePath: try file(Data("other".utf8)).path)
        let message = ChatMessage(id: 0, channelId: 1, attachments: [hit, other], user: ChatUser(id: "u"))
        var result: Result<String?, Error>?
        // Held: the provider answers only while it is alive.
        let provider = ChannelMessageChecksumProvider()
        provider.startChecksum(message: message, attachment: hit) { result = $0 }
        XCTAssertTrue(waitUntil { result != nil })
        withExtendedLifetime(provider) {}
        guard case .success("STORED-SEVERAL") = result else { return XCTFail("\(String(describing: result))") }
    }

    func testAHitWithoutAnAssetPathOrAMessageListMeasuresWhatItHas() throws {
        let bytes = Data("no asset".utf8)
        try seed(bytes, url: "STORED-NOASSET", metadata: #"{"tmb":"t"}"#)
        let key = try XCTUnwrap(Components.storage.dedupeChecksum(filePath: try file(bytes).path))
        for clearsFile in [false, true] {
            let new = attachment(tid: clearsFile ? 41 : 40, filePath: try file(bytes).path)
            let provider = RowProvider(row: .init(checksum: key, messageTid: 1, attachmentTid: 8000, data: "STORED-NOASSET"), clearsFile: clearsFile)
            let message = ChatMessage(id: 0, channelId: 1, attachments: nil, user: ChatUser(id: "u"))
            var result: Result<String?, Error>?
            provider.startChecksum(message: message, attachment: new) { result = $0 }
            XCTAssertTrue(waitUntil { result != nil })
            withExtendedLifetime(provider) {}
            // Without a file its size is 0, so the stored object's size does not match: a miss.
            guard case .success(let link) = result else { return XCTFail("\(String(describing: result))") }
            XCTAssertEqual(link, clearsFile ? nil : "STORED-NOASSET")
        }
    }

    // MARK: Storage

    func testStorageChecksumOfAnEmptyFileIsZero() throws {
        XCTAssertEqual(Storage.checksum(filePath: try file(Data()).path), 0)
        let url = try file(Data([1, 2, 3]))
        XCTAssertEqual(Storage.attributesOfItem(at: url)[.size] as? UInt, 3)
    }

    func testStoringATemporaryFileThatCannotBeWrittenFails() {
        XCTAssertNil(Storage.storeInTemporaryDirectory(data: Data([1]), filename: "no-such-folder-\(UUID().uuidString)/x", ext: "jpg"))
        let stored = Storage.storeInTemporaryDirectory(data: Data([1]), filename: "stored-\(UUID().uuidString)", ext: "jpg")
        XCTAssertEqual(stored?.pathExtension, "jpg")
        stored.map { try? FileManager.default.removeItem(at: $0) }
    }

    func testZippingAFolderThatIsGoneFailsInsteadOfHanging() async throws {
        do {
            _ = try await Storage.makeUploadingUrl(directoryUrl: directory.appendingPathComponent("gone", isDirectory: true))
            XCTFail("nothing to zip")
        } catch {}
    }

    func testAZipThatCannotBeCopiedOutFails() async throws {
        let folder = directory.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data([1]).write(to: folder.appendingPathComponent("a.bin"))
        let original = Storage.copyZippedItem
        defer { Storage.copyZippedItem = original }
        Storage.copyZippedItem = { _, _ in throw CocoaError(.fileWriteNoPermission) }
        do {
            _ = try await Storage.makeUploadingUrl(directoryUrl: folder)
            XCTFail("the copy failed")
        } catch {
            XCTAssertEqual((error as? CocoaError)?.code, .fileWriteNoPermission)
        }
    }
}

// MARK: - The provider's prepared entries (spec: FileTransferProvider.prepareUpload)

extension AttachmentTransferPipelineTests {

    /// What `prepareUpload` returns lands in the attachment's metadata, which the message
    /// carries; an image's metadata is rebuilt with its dimensions on the way and keeps it.
    func testThePreparedEntriesAreInTheSentMetadataAfterAnImageRebuild() throws {
        transport.onPrepare = { _ in ["sceyt.enc": "TOKEN"] }
        let attachment = makeAttachment(tid: 70, type: "image", name: "photo.png", filePath: try image().path, metadata: #"{"tmb":"x"}"#)

        XCTAssertNil(upload(attachment))

        XCTAssertEqual(attachment.status, .done)
        XCTAssertEqual(attachment.stringMetadataEntries["sceyt.enc"], "TOKEN")
        XCTAssertEqual(transport.uploads.first?.metadata["sceyt.enc"], "TOKEN", "the upload sees what was saved")
    }

    /// A video's poster rebuilds its metadata from the typed model: the provider's entry stays.
    func testAVideoPosterKeepsThePreparedEntries() throws {
        transport.onPrepare = { _ in ["sceyt.enc": "TOKEN"] }
        session.onThumbnailUpload = { _ in .success("POSTER") }
        let attachment = try videoUpload()

        XCTAssertNil(upload(attachment))

        XCTAssertEqual(try ChatMessage.Attachment.Metadata<String>.decode(try XCTUnwrap(attachment.metadata)).videoThumbnail, "POSTER")
        XCTAssertEqual(attachment.stringMetadataEntries["sceyt.enc"], "TOKEN")
    }

    /// A prepare that throws fails the upload before any byte; nothing is saved.
    func testAFailedPrepareFailsTheUploadBeforeAnyByte() throws {
        transfer.offline = false
        struct NoSlot: Error {}
        transport.onPrepare = { _ in throw NoSlot() }
        let attachment = makeAttachment(tid: 71, filePath: try file().path)

        XCTAssertTrue(upload(attachment) is NoSlot)

        XCTAssertTrue(transport.uploads.isEmpty)
        XCTAssertEqual(attachment.status, .failedUploading)
        XCTAssertNil(attachment.stringMetadataEntries["sceyt.enc"])
    }
}

// MARK: - A video's poster as a preview attachment (video-preview spec)

extension AttachmentTransferPipelineTests {

    /// Stores a message of `attachment` (as the sender stores it before the upload), uploads
    /// the stored attachment (its tid is the SDK's), and returns it with the message the sender
    /// would send: the stored one.
    private func sendStored(_ attachment: ChatMessage.Attachment) throws -> (video: ChatMessage.Attachment, message: ChatMessage?, error: Error?) {
        let database = try XCTUnwrap(DataProvider.database as? MockDatabase)
        try database.syncWrite { context in
            context.createOrUpdate(message: self.makeMessage([attachment]).builder.build(), channelId: 100)
        }
        let message = try XCTUnwrap(try database.read { MessageDTO.fetch(id: self.messageId, context: $0)?.convert() }.get())
        let stored = try XCTUnwrap(message.attachments?.first)
        stored.filePath = attachment.filePath
        let outcome = Locked<(finished: Bool, message: ChatMessage?, error: Error?)>((false, nil, nil))
        transfer.uploadMessageAttachments(message: message, attachments: [stored]) { sent, error in
            outcome.wrapped = (true, sent, error)
        }
        XCTAssertTrue(waitUntil { outcome.wrapped.finished }, "the upload never completed")
        return (stored, outcome.wrapped.message, outcome.wrapped.error)
    }

    /// The poster goes first, through the provider (prepared: its own "sceyt.enc"), as its own
    /// preview attachment; the video names it in `pvw`, and the message sent carries both.
    func testAVideoSendsItsPosterFirstAsAPreviewAttachment() throws {
        session.previews = true
        transport.onPrepare = { request in ["sceyt.enc": "TOKEN-\(request.operationId)"] }
        transport.onUpload = { request in
            .success(FileUploadResult(url: request.operationId.hasSuffix("-thumbnail") ? "PREVIEW-OBJECT" : "VIDEO-OBJECT"))
        }
        let source = try videoUpload()
        source.updateMetadata(#"{"szw":3810,"szh":1962,"tmb":"hash","dur":10}"#)

        let (video, sent, error) = try sendStored(source)

        XCTAssertNil(error)
        let operationId = "upload-\(video.tid)"
        XCTAssertEqual(transport.uploads.map(\.operationId), ["\(operationId)-thumbnail", operationId], "the poster before the video")
        XCTAssertEqual(transport.uploads.map(\.parentOperationId), [operationId, nil], "the poster is part of the video's upload")
        XCTAssertEqual(transfer.posterSources.map(\.path), [video.filePath], "made from the file the video upload sends")
        XCTAssertTrue(session.thumbnailUploads.isEmpty, "never the old way too")
        let videoMeta = try ChatMessage.Attachment.Metadata<String>.decode(try XCTUnwrap(video.metadata))
        XCTAssertEqual(videoMeta.videoThumbnail, "PREVIEW-OBJECT")
        XCTAssertEqual(video.stringMetadataEntries["sceyt.enc"], "TOKEN-\(operationId)")

        let message = try XCTUnwrap(sent)
        XCTAssertEqual(message.attachments?.map(\.type), ["video"], "the preview is no item of the message")
        let preview = try XCTUnwrap(message.previewAttachment(of: try XCTUnwrap(message.attachments?.first)))
        XCTAssertEqual(preview.type, "preview")
        XCTAssertEqual(preview.url, "PREVIEW-OBJECT")
        XCTAssertEqual(preview.name, "clip-preview.jpg")
        let previewMeta = try XCTUnwrap(ChatMessage.Attachment.metadataObject(preview.metadata))
        XCTAssertEqual(Set(previewMeta.keys), ["szw", "szh", "tmb", "sceyt.enc"], "no dur, no pvw")
        XCTAssertEqual(previewMeta["szw"] as? Int, 3810)
        XCTAssertEqual(previewMeta["tmb"] as? String, "hash")
        XCTAssertEqual(previewMeta["sceyt.enc"] as? String, "TOKEN-\(operationId)-thumbnail", "its own key, not the video's")
        XCTAssertEqual(message.builder.build().attachments?.count, 2, "both go out")
        XCTAssertNotNil(transfer.cachedVideoThumbnailPath(attachment: video), "the sender shows its own poster at once")
        if let cached = transfer.cachedVideoThumbnailPath(attachment: video) { try? FileManager.default.removeItem(atPath: cached) }
    }

    /// Without a frame the video goes alone: no `pvw`, no preview, and no poster the old way
    /// either (a retry could make none).
    func testAVideoWithoutAFrameGoesAlone() throws {
        session.previews = true
        transport.onUpload = { _ in .success(FileUploadResult(url: "VIDEO-OBJECT")) }
        let source = try videoUpload()
        transfer.poster = nil

        let (video, sent, error) = try sendStored(source)

        XCTAssertNil(error)
        XCTAssertEqual(video.status, .done)
        XCTAssertEqual(transport.uploads.map(\.operationId), ["upload-\(video.tid)"], "only the video")
        XCTAssertNil(try? ChatMessage.Attachment.Metadata<String>.decode(video.metadata ?? "").videoThumbnail)
        XCTAssertNil(sent?.previewAttachments)
        XCTAssertTrue(session.thumbnailUploads.isEmpty)
    }

    /// A preview whose upload fails fails the video's attempt: the video's bytes never go
    /// without it. The retry sends the preview first again, then the video.
    func testAFailedPreviewFailsTheVideoAndTheRetrySendsBoth() throws {
        session.previews = true
        transport.onUpload = { request in
            request.operationId.hasSuffix("-thumbnail") ? .failure(URLError(.badServerResponse)) : .success(FileUploadResult(url: "VIDEO-OBJECT"))
        }
        let (video, failed, error) = try sendStored(try videoUpload())

        XCTAssertNotNil(error, "the attempt fails with the preview")
        XCTAssertNil(failed?.previewAttachments)
        let operationId = "upload-\(video.tid)"
        XCTAssertEqual(transport.uploads.map(\.operationId), ["\(operationId)-thumbnail"], "the video's bytes never went")
        XCTAssertTrue(transport.cancelled.contains("\(operationId)-thumbnail"), "what the preview's upload left goes")
        XCTAssertNil(try? ChatMessage.Attachment.Metadata<String>.decode(video.metadata ?? "").videoThumbnail)
        XCTAssertTrue(session.thumbnailUploads.isEmpty, "never the old way")

        transport.onUpload = { request in
            .success(FileUploadResult(url: request.operationId.hasSuffix("-thumbnail") ? "PREVIEW-OBJECT" : "VIDEO-OBJECT"))
        }
        let database = try XCTUnwrap(DataProvider.database as? MockDatabase)
        let message = try XCTUnwrap(try database.read { MessageDTO.fetch(id: self.messageId, context: $0)?.convert() }.get())
        let outcome = Locked<(finished: Bool, message: ChatMessage?, error: Error?)>((false, nil, nil))
        transfer.uploadMessageAttachments(message: message, attachments: [video]) { sent, error in
            outcome.wrapped = (true, sent, error)
        }
        XCTAssertTrue(waitUntil { outcome.wrapped.finished }, "the retry never completed")

        XCTAssertNil(outcome.wrapped.error)
        XCTAssertEqual(
            transport.uploads.map(\.operationId),
            ["\(operationId)-thumbnail", "\(operationId)-thumbnail", operationId],
            "the retry: the preview first, then the video"
        )
        XCTAssertEqual(try ChatMessage.Attachment.Metadata<String>.decode(try XCTUnwrap(video.metadata)).videoThumbnail, "PREVIEW-OBJECT")
        let sent = try XCTUnwrap(outcome.wrapped.message)
        XCTAssertEqual(sent.previewAttachment(of: try XCTUnwrap(sent.attachments?.first))?.url, "PREVIEW-OBJECT")
        if let cached = transfer.cachedVideoThumbnailPath(attachment: video) { try? FileManager.default.removeItem(atPath: cached) }
    }

    /// An interrupted preview upload ends the video's attempt as an interrupted video upload
    /// would.
    func testAnInterruptedPreviewInterruptsTheVideo() throws {
        session.previews = true
        transport.onUpload = { request in
            request.operationId.hasSuffix("-thumbnail") ? .interrupted(URLError(.networkConnectionLost)) : .success(FileUploadResult(url: "VIDEO-OBJECT"))
        }
        let (video, sent, error) = try sendStored(try videoUpload())

        XCTAssertNotNil(error)
        XCTAssertNil(sent?.previewAttachments)
        XCTAssertEqual(transport.uploads.map(\.operationId), ["upload-\(video.tid)-thumbnail"], "the video's bytes never went")
        XCTAssertNotEqual(video.status, .done)
    }

    /// A slow preview holds the video, past the old poster's time limit: the two go in order,
    /// never the video alone.
    func testTheVideoWaitsForASlowPreview() throws {
        session.previews = true
        transfer.videoThumbnailTimeout = 0.2
        transport.onUpload = { request in
            if request.operationId.hasSuffix("-thumbnail") {
                try? await Task.sleep(nanoseconds: 600_000_000)
                return .success(FileUploadResult(url: "PREVIEW-OBJECT"))
            }
            return .success(FileUploadResult(url: "VIDEO-OBJECT"))
        }
        let (video, sent, error) = try sendStored(try videoUpload())

        XCTAssertNil(error)
        let operationId = "upload-\(video.tid)"
        XCTAssertEqual(transport.uploads.map(\.operationId), ["\(operationId)-thumbnail", operationId])
        XCTAssertFalse(transport.cancelled.contains("\(operationId)-thumbnail"))
        let message = try XCTUnwrap(sent)
        XCTAssertEqual(message.previewAttachment(of: try XCTUnwrap(message.attachments?.first))?.url, "PREVIEW-OBJECT")
        if let cached = transfer.cachedVideoThumbnailPath(attachment: video) { try? FileManager.default.removeItem(atPath: cached) }
    }

    /// The previewer's forward sends the video with its preview.
    func testForwardingAVideoKeepsItsPreview() {
        let video = makeAttachment(tid: 0, type: "video", name: "clip.mp4", url: "V", metadata: #"{"tmb":"h","pvw":"P"}"#)
        let preview = makeAttachment(tid: 0, type: "preview", url: "P", metadata: #"{"tmb":"h"}"#)
        let message = makeMessage([video, preview])
        let forwarded = [video.builder.build()] + (message.previewAttachment(of: video).map { [$0.builder.build()] } ?? [])
        XCTAssertEqual(forwarded.map(\.type), ["video", "preview"])
    }

    /// A received video's poster is its message's preview attachment: fetched (and decrypted)
    /// by the provider, with the preview's own entries, into the poster cache.
    func testAReceivedPreviewIsFetchedThroughTheProvider() throws {
        session.previews = true
        let origin = "PREVIEW-\(UUID().uuidString)"
        let poster = try file(size: 64, ext: "jpg")
        transport.onDownload = { request in
            do {
                try FileManager.default.copyItem(at: poster, to: request.destinationFile)
                return .success(request.destinationFile)
            } catch {
                return .failure(error)
            }
        }
        let video = makeAttachment(tid: 0, type: "video", name: "clip.mp4", url: "VIDEO-OBJECT", metadata: "{\"tmb\":\"h\",\"pvw\":\"\(origin)\"}")
        let preview = makeAttachment(tid: 0, type: "preview", name: "clip-preview.jpg", url: origin, metadata: #"{"tmb":"h","sceyt.enc":"TOKEN"}"#)
        let message = makeMessage([video, preview])
        XCTAssertEqual(message.attachments?.count, 1)

        transfer.downloadVideoThumbnailsIfNeeded(message: message)

        XCTAssertTrue(waitUntil { self.transfer.cachedVideoThumbnailPath(attachment: video) != nil })
        let request = try XCTUnwrap(transport.downloads.first)
        XCTAssertEqual(request.url, origin)
        XCTAssertEqual(request.metadata["sceyt.enc"], "TOKEN", "the preview's own entries")
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: try XCTUnwrap(transfer.cachedVideoThumbnailPath(attachment: video)))), try Data(contentsOf: poster))
        if let cached = transfer.cachedVideoThumbnailPath(attachment: video) { try? FileManager.default.removeItem(atPath: cached) }
    }
}

final class ChatMessagePreviewAttachmentTests: XCTestCase {

    private func attachment(_ type: String, url: String, metadata: String? = nil) -> ChatMessage.Attachment {
        .init(id: 0, tid: 0, messageId: 1, userId: "u", url: url, filePath: nil, type: type, name: nil, metadata: metadata, uploadedFileSize: 0, createdAt: Date())
    }

    /// A "preview" attachment is never one of the message's items: `attachments.first`,
    /// counts and formatters see the video alone. The builder sends both.
    func testAPreviewIsKeptApartFromTheItems() {
        let video = attachment("video", url: "V", metadata: #"{"tmb":"h","pvw":"P"}"#)
        let preview = attachment("preview", url: "P")
        let message = ChatMessage(id: 1, channelId: 1, attachments: [preview, video], user: ChatUser(id: "u"))

        XCTAssertEqual(message.attachments?.map(\.url), ["V"])
        XCTAssertEqual(message.previewAttachments?.map(\.url), ["P"])
        XCTAssertEqual(message.allAttachments.count, 2)
        XCTAssertTrue(message.previewAttachment(of: video) === preview)
        XCTAssertEqual(message.builder.build().attachments?.count, 2)
    }

    func testAMessageWithoutPreviewsHasNone() {
        let video = attachment("video", url: "V", metadata: #"{"tmb":"h"}"#)
        let message = ChatMessage(id: 1, channelId: 1, attachments: [video], user: ChatUser(id: "u"))
        XCTAssertNil(message.previewAttachments)
        XCTAssertNil(message.previewAttachment(of: video), "an old message: the poster by its origin, as before")
    }
}
