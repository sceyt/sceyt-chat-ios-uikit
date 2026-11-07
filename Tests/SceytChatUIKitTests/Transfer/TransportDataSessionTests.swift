//
//  TransportDataSessionTests.swift
//  SceytChatUIKitTests
//
//  `TransportDataSession` on its own, driven through `SCTDataSessionTaskInfo` the way
//  `AttachmentTransfer` drives it: the one-slot upload queue, preparation and staging per
//  operation, every pause / resume / cancel ordering against the transport's answers, results
//  and progress of stale attempts, `cancel(attachments:)`, `interruptTransfers(error:)`, the
//  checksum step and the download state machine.
//

@testable import SceytChatUIKit
import SceytChat
import UIKit
import XCTest

// MARK: - Fakes

/// A provider each test scripts. Records every call.
private final class ScriptedTransport: FileTransferProvider {
    var onPrepare: (FileUploadRequest) async throws -> [String: String]? = { _ in nil }
    var onUpload: (FileUploadRequest, @escaping (Double) -> Void) async -> FileTransferResult<FileUploadResult> = { _, _ in
        .success(FileUploadResult(url: "REMOTE"))
    }
    var onDownload: (FileDownloadRequest, @escaping (Double) -> Void) async -> FileTransferResult<URL> = { request, _ in
        .success(request.destinationFile)
    }
    var onPause: (String) -> Bool = { _ in true }
    var onResume: (String) -> Bool = { _ in true }
    var onCancel: (String) -> Void = { _ in }

    private let lock = NSLock()
    private var _uploads = [FileUploadRequest]()
    private var _downloads = [FileDownloadRequest]()
    private var _paused = [String]()
    private var _resumed = [String]()
    private var _cancelled = [String]()

    var uploads: [FileUploadRequest] { lock.lock(); defer { lock.unlock() }; return _uploads }
    private var _prepared = [FileUploadRequest]()
    var prepared: [FileUploadRequest] { lock.lock(); defer { lock.unlock() }; return _prepared }

    func prepareUpload(_ request: FileUploadRequest) async throws -> [String: String]? {
        lock.lock(); _prepared.append(request); lock.unlock()
        return try await onPrepare(request)
    }
    var downloads: [FileDownloadRequest] { lock.lock(); defer { lock.unlock() }; return _downloads }
    var paused: [String] { lock.lock(); defer { lock.unlock() }; return _paused }
    var resumed: [String] { lock.lock(); defer { lock.unlock() }; return _resumed }
    var cancelled: [String] { lock.lock(); defer { lock.unlock() }; return _cancelled }

    func upload(_ request: FileUploadRequest, progress: @escaping (Double) -> Void) async -> FileTransferResult<FileUploadResult> {
        lock.lock(); _uploads.append(request); lock.unlock()
        return await onUpload(request, progress)
    }

    func download(_ request: FileDownloadRequest, progress: @escaping (Double) -> Void) async -> FileTransferResult<URL> {
        lock.lock(); _downloads.append(request); lock.unlock()
        return await onDownload(request, progress)
    }

    func pause(operationId: String) -> Bool {
        lock.lock(); _paused.append(operationId); lock.unlock()
        return onPause(operationId)
    }

    func resume(operationId: String) -> Bool {
        lock.lock(); _resumed.append(operationId); lock.unlock()
        return onResume(operationId)
    }

    func cancel(operationId: String) {
        lock.lock(); _cancelled.append(operationId); lock.unlock()
        onCancel(operationId)
    }

    private var _delivered = [String]()
    var delivered: [String] { lock.lock(); defer { lock.unlock() }; return _delivered }

    func uploadDelivered(operationId: String) {
        lock.lock(); _delivered.append(operationId); lock.unlock()
    }
}

/// The router under test, storing everything under one temporary directory.
private final class RouterSession: TransportDataSession {
    let root: URL
    var checksums = false
    var hasDestination = true
    var slots = 1
    /// What `downloadHeaders` gives every download.
    var headers = [String: String]()
    /// Every download's destination, when set (a new folder each time otherwise).
    var fixedDestination: URL?
    var appExtension = false
    /// A store that fails the way `FileStorage.store` does: it hands the source path back.
    var storeFails = false
    /// Replaces the default preparation when set.
    var preparation: ((ChatMessage.Attachment, String) async throws -> PreparedUploadFile)?

    private let lock = NSLock()
    private var _removed = [String]()
    private var _thumbnailPaths = [String]()
    private var _stored = [String]()
    private var _videoProcessInfos = [SCVideoProcessInfo]()
    /// The export state each preparation was given, in order.
    var videoProcessInfos: [SCVideoProcessInfo] { lock.lock(); defer { lock.unlock() }; return _videoProcessInfos }
    var removed: [String] { lock.lock(); defer { lock.unlock() }; return _removed }
    private var _queue = [String]()
    /// Every queue report, as "running/waiting".
    var queue: [String] { lock.lock(); defer { lock.unlock() }; return _queue }
    var thumbnailPaths: [String] { lock.lock(); defer { lock.unlock() }; return _thumbnailPaths }
    var stored: [String] { lock.lock(); defer { lock.unlock() }; return _stored }

    init(transport: FileTransferProvider, root: URL) {
        self.root = root
        super.init(provider: transport)
    }

    override func downloadHeaders(for attachment: ChatMessage.Attachment, message: ChatMessage) -> [String: String] {
        headers
    }

    override var checksumsBeforeUpload: Bool { checksums }
    override var maxConcurrentUploads: Int { slots }

    override func uploadQueueDidChange(running: Int, waiting: Int) {
        lock.lock(); _queue.append("\(running)/\(waiting)"); lock.unlock()
    }
    override var isAppExtension: Bool { appExtension }
    override var stagingDirectory: URL { root.appendingPathComponent("staging", isDirectory: true) }

    override func storeFile(atPath path: String, transferId: String, fileName: String?) -> String {
        lock.lock(); _stored.append(path); lock.unlock()
        if storeFails { return path }
        let folder = root.appendingPathComponent("store/\(transferId)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(fileName ?? (path as NSString).lastPathComponent)
        try? FileManager.default.copyItem(atPath: path, toPath: destination.path)
        return destination.path
    }

    override func removeFile(atPath path: String) {
        lock.lock(); _removed.append(path); lock.unlock()
        try? FileManager.default.removeItem(atPath: path)
    }

    override func updateThumbnailPath(transferId: String, filePath: String) {
        lock.lock(); _thumbnailPaths.append(filePath); lock.unlock()
    }

    override func downloadDestination(for attachment: ChatMessage.Attachment) -> URL? {
        guard hasDestination else { return nil }
        if let fixedDestination { return fixedDestination }
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
        lock.lock(); _videoProcessInfos.append(videoProcessInfo); lock.unlock()
        if let preparation {
            return try await preparation(attachment, operationId)
        }
        return try await super.prepareUploadFile(for: attachment, taskInfo: taskInfo, operationId: operationId, videoProcessInfo: videoProcessInfo)
    }
}

/// Holds a call until the test lets it go; optionally answers a cancellation by itself.
private final class Hold<T> {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Never>?
    private var value: T?
    private let cancelValue: T?
    private var _cancelled = false
    private var _waiting = false

    var wasCancelled: Bool { lock.lock(); defer { lock.unlock() }; return _cancelled }
    var isWaiting: Bool { lock.lock(); defer { lock.unlock() }; return _waiting }

    init(onCancel cancelValue: T? = nil) {
        self.cancelValue = cancelValue
    }

    func wait() async -> T {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                lock.lock()
                _waiting = true
                if let value {
                    lock.unlock()
                    continuation.resume(returning: value)
                    return
                }
                self.continuation = continuation
                lock.unlock()
            }
        } onCancel: {
            lock.lock(); _cancelled = true; lock.unlock()
            if let cancelValue { open(cancelValue) }
        }
    }

    func open(_ value: T) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        if continuation == nil, self.value == nil { self.value = value }
        lock.unlock()
        continuation?.resume(returning: value)
    }
}

/// Everything a task reported.
private final class Recorder {
    private let lock = NSLock()
    private var _events = [SCTDataSessionTaskInfo.Event]()

    init(_ taskInfo: SCTDataSessionTaskInfo) {
        taskInfo.onEvent = { [weak self] event in
            guard let self else { return }
            self.lock.lock(); self._events.append(event); self.lock.unlock()
        }
    }

    var events: [SCTDataSessionTaskInfo.Event] { lock.lock(); defer { lock.unlock() }; return _events }

    var progress: [Double] {
        events.compactMap { if case .updateProgress(let value) = $0 { return value } else { return nil } }
    }

    var failures: [Error?] {
        events.compactMap { if case .failure(let error) = $0 { return .some(error) } else { return nil } }
    }

    var successes: [String] {
        events.compactMap { if case .successURI(let uri) = $0 { return uri } else { return nil } }
    }

    var locations: [URL] {
        events.compactMap { if case .updateLocalFileURL(let url, _) = $0 { return url } else { return nil } }
    }

    var isOver: Bool { !failures.isEmpty || !successes.isEmpty }
}

/// The checksum step, answered by the test.
private final class ScriptedChecksumProvider: ChannelMessageChecksumProvider {
    static var answer: (ChatMessage.Attachment, @escaping (Result<String?, Error>) -> Void) -> Void = { _, completion in
        completion(.success(nil))
    }
    override func startChecksum(
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        completion: @escaping ((Result<String?, Error>) -> Void)
    ) {
        Self.answer(attachment, completion)
    }
}

/// The video export, answered by the test.
private final class ScriptedVideoProcessor: VideoProcessor {
    static var result: (String) -> Result<URL, Error> = { _ in .failure(CocoaError(.featureUnsupported)) }

    override class func export(from inputPath: String, processInfo: SCVideoProcessInfo) async -> Result<URL, Error> {
        result(inputPath)
    }
}

private struct Failure: Error, Equatable {
    let name: String
}

// MARK: - Tests

final class TransportDataSessionTests: XCTestCase {

    private var transport: ScriptedTransport!
    private var session: RouterSession!
    private var directory: URL!
    private var originalDatabase: Database!

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalDatabase = DataProvider.database
        DataProvider.database = MockDatabase()
        ScriptedChecksumProvider.answer = { _, completion in completion(.success(nil)) }
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("router-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        transport = ScriptedTransport()
        session = RouterSession(transport: transport, root: directory)
    }

    override func tearDownWithError() throws {
        DataProvider.database = originalDatabase
        try? FileManager.default.removeItem(at: directory)
        session = nil
        transport = nil
        try super.tearDownWithError()
    }

    // MARK: Fixtures

    private func file(size: Int = 100, name: String? = nil) throws -> URL {
        let url = directory.appendingPathComponent(name ?? "plain-\(UUID().uuidString).bin")
        try Data((0..<size).map { UInt8(truncatingIfNeeded: $0 &* 7) }).write(to: url)
        return url
    }

    private func image() throws -> URL {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
        let url = directory.appendingPathComponent("photo-\(UUID().uuidString).png")
        try XCTUnwrap(image.pngData()).write(to: url)
        return url
    }

    private func makeAttachment(
        tid: Int64 = 1,
        type: String = "file",
        name: String? = "report.pdf",
        filePath: String? = nil,
        url: String? = nil,
        metadata: String? = nil
    ) -> ChatMessage.Attachment {
        .init(id: 0, tid: tid, messageId: 1, userId: "user", url: url, filePath: filePath, type: type, name: name, metadata: metadata, uploadedFileSize: 0, createdAt: Date())
    }

    /// What every task's save of its provider's entries did, in order (`TransferRun` saves them
    /// in the app; here the test answers with `saveError`).
    private let savedEntries = Locked([[String: String]]())
    private var saveError: Error?

    private func makeTask(
        _ attachment: ChatMessage.Attachment,
        _ type: SCTDataSessionTaskInfo.TransferType = .upload
    ) -> (SCTDataSessionTaskInfo, Recorder) {
        let message = ChatMessage(id: 1, channelId: 1, attachments: [attachment], user: ChatUser(id: "u"))
        let taskInfo = SCTDataSessionTaskInfo(transferType: type, message: message, attachment: attachment, checksumProvider: ScriptedChecksumProvider())
        let error = saveError
        taskInfo.onUploadPrepared = { [savedEntries] entries, done in
            savedEntries.mutate { $0.append(entries) }
            done(error)
        }
        return (taskInfo, Recorder(taskInfo))
    }

    /// Starts the upload of a new file attachment.
    @discardableResult
    private func upload(tid: Int64 = 1, type: String = "voice", metadata: String? = nil) throws -> (SCTDataSessionTaskInfo, Recorder, ChatMessage.Attachment) {
        let attachment = makeAttachment(tid: tid, type: type, filePath: try file().path, metadata: metadata)
        let (taskInfo, recorder) = makeTask(attachment)
        session.upload(attachment: attachment, taskInfo: taskInfo)
        return (taskInfo, recorder, attachment)
    }

    private func download(metadata: String? = nil) -> (SCTDataSessionTaskInfo, Recorder) {
        let attachment = makeAttachment(tid: 0, url: "https://files.example/\(UUID().uuidString)/report.pdf", metadata: metadata)
        let (taskInfo, recorder) = makeTask(attachment, .download)
        session.download(attachment: attachment, taskInfo: taskInfo)
        return (taskInfo, recorder)
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            RunLoop.main.run(until: Date().addingTimeInterval(0.005))
        }
        XCTAssertTrue(condition(), "timed out", file: file, line: line)
    }

    /// Lets queued work run, for asserting that something does *not* happen.
    private func settle(_ seconds: TimeInterval = 0.15) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func uploads(of operationId: String) -> Int {
        transport.uploads.filter { $0.operationId == operationId }.count
    }

    // MARK: - Identity and storage

    /// A sent message's uploads are final: the transport is told to forget each one it can
    /// find again (only an attachment with a `tid` has a stable operation).
    func testASentMessageTellsTheTransportItsUploadsAreDelivered() {
        let sent = makeAttachment(tid: 41)
        let unnamed = makeAttachment(tid: 0)
        let link = makeAttachment(tid: 43, type: "link")
        let message = ChatMessage(id: 1, channelId: 1, attachments: [sent, unnamed, link], user: ChatUser(id: "u"))

        session.messageSent(message)

        XCTAssertEqual(transport.delivered, ["upload-41"])
    }

    func testOperationIds() {
        XCTAssertEqual(session.uploadOperationId(for: makeAttachment(tid: 42)), "upload-42")
        let a = session.uploadOperationId(for: makeAttachment(tid: 0))
        let b = session.uploadOperationId(for: makeAttachment(tid: 0))
        XCTAssertTrue(a.hasPrefix("upload-"))
        XCTAssertNotEqual(a, b, "nothing can be found again without a tid")
        XCTAssertEqual(session.downloadOperationId(for: makeAttachment(tid: 7)), "download-tid7")
        let byId = ChatMessage.Attachment(id: 55, tid: 0, messageId: 1, userId: "u", url: "https://x/y?Signature=S", filePath: nil, type: "file", name: nil, metadata: nil, uploadedFileSize: 0, createdAt: Date())
        XCTAssertEqual(session.downloadOperationId(for: byId), "download-id55")
        let signed = "https://cdn.example/\(UUID().uuidString)/report.pdf?Signature=SECRET"
        let byURL = session.downloadOperationId(for: makeAttachment(tid: 0, url: signed))
        XCTAssertEqual(byURL, session.downloadOperationId(for: makeAttachment(tid: 0, url: signed)), "stable for one url")
        XCTAssertNotEqual(byURL, session.downloadOperationId(for: makeAttachment(tid: 0, url: signed + "2")))
        XCTAssertTrue(byURL.hasPrefix("download-url"))
        XCTAssertEqual(byURL.count, "download-url".count + 12, "short: a hash, never the url")
        XCTAssertFalse(byURL.contains("SECRET"))
    }

    func testDefaults() throws {
        let plain = TransportDataSession(provider: transport)
        XCTAssertEqual(plain.checksumsBeforeUpload, SceytChatUIKit.shared.config.preventDuplicateAttachmentUpload)
        XCTAssertTrue(plain.stagingDirectory.path.hasSuffix("upload-staging"))
        XCTAssertNil(plain.thumbnailFile(for: makeAttachment(), preferred: CGSize(width: 10, height: 10)))

        let existing = try file()
        XCTAssertEqual(plain.getFilePath(attachment: makeAttachment(filePath: existing.path)), existing.path)
        XCTAssertNil(plain.getFilePath(attachment: makeAttachment(filePath: directory.appendingPathComponent("gone").path)))
        XCTAssertNil(plain.getFilePath(attachment: makeAttachment()))

        XCTAssertNil(plain.downloadDestination(for: makeAttachment()))
        let destination = try XCTUnwrap(plain.downloadDestination(for: makeAttachment(name: "a.pdf", url: "https://files.example/TRANSFER/a.pdf")))
        XCTAssertTrue(destination.path.contains("TRANSFER"), destination.path)
        XCTAssertEqual(destination.lastPathComponent, "a.pdf")
    }

    func testDefaultStorageGoesThroughFileStorage() throws {
        let plain = TransportDataSession(provider: transport)
        let transferId = UUID().uuidString
        let stored = plain.storeFile(atPath: try file().path, transferId: transferId, fileName: "stored.bin")
        XCTAssertTrue(FileManager.default.fileExists(atPath: stored))
        plain.updateThumbnailPath(transferId: transferId, filePath: stored)
        plain.removeFile(atPath: stored)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stored))
    }

    func testStaleStagingIsPurgedOnInit() throws {
        let staging = directory.appendingPathComponent("staging", isDirectory: true)
        let stale = staging.appendingPathComponent("upload%2Dold", isDirectory: true)
        let fresh = staging.appendingPathComponent("upload%2Dnew", isDirectory: true)
        for folder in [stale, fresh] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-UploadStaging.staleAge - 60)],
            ofItemAtPath: stale.path
        )

        _ = RouterSession(transport: transport, root: directory)

        waitUntil { !FileManager.default.fileExists(atPath: stale.path) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
    }

    // MARK: - Upload requests and results

    func testPlainUploadSendsTheStoredFileAndReportsItsReference() throws {
        let source = try file(name: "notes.pdf")
        let attachment = makeAttachment(name: nil, filePath: source.path)
        let (taskInfo, recorder) = makeTask(attachment)
        transport.onUpload = { request, progress in
            progress(0.25)
            progress(0.75)
            return .success(FileUploadResult(url: "REF"))
        }

        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { recorder.isOver }

        let request = try XCTUnwrap(transport.uploads.first)
        XCTAssertEqual(request.metadata, [:])
        XCTAssertEqual(request.operationId, "upload-1")
        XCTAssertEqual(request.fileName, "notes.pdf", "the file's own name when the attachment has none")
        XCTAssertEqual(request.mimeType, "application/pdf")
        XCTAssertEqual(request.sourceFile.path, source.path, "a file is sent in place, as SCTSession did")
        XCTAssertTrue(session.stored.isEmpty, "never moved into storage")
        XCTAssertTrue(recorder.locations.isEmpty, "the attachment keeps its own file")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue((request.context as? AttachmentTransferContext)?.attachment === attachment)
        XCTAssertEqual(recorder.progress, [AttachmentTransfer.initialUploadProgress, 0.25, 0.75])
        XCTAssertEqual(recorder.successes, ["REF"])
        XCTAssertFalse(taskInfo.hasProviderEntries)
    }

    /// The progress the transport reports is of the file it sends: its size reaches the task
    /// before the first byte goes, for a staged (resized) file too.
    func testTheSentFilesSizeIsReportedBeforeTheTransportStarts() throws {
        let attachment = makeAttachment(type: "image", name: "photo.jpg", filePath: try image().path)
        let (taskInfo, recorder) = makeTask(attachment)
        var sizeSeenByTransport: Int64?
        var sentFileSize: Int64?
        transport.onUpload = { request, _ in
            sizeSeenByTransport = taskInfo.transferSize
            sentFileSize = (try? FileManager.default.attributesOfItem(atPath: request.sourceFile.path)[.size] as? NSNumber)?.int64Value
            return .success(FileUploadResult(url: "IMG"))
        }

        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { recorder.isOver }

        XCTAssertNotNil(sentFileSize)
        XCTAssertEqual(sizeSeenByTransport, sentFileSize)
    }

    /// Every attempt of a non-media file sends the attachment's own file: nothing is moved,
    /// and no folder is left behind per retry (finding #10).
    func testRetriesOfANonMediaFileSendItInPlaceAndLeaveNoFolders() throws {
        let plain = TransportDataSession(provider: transport)
        let source = try file(name: "contract.pdf")
        let storage = URL(fileURLWithPath: FileStorage.default.storagePath)
        let foldersBefore = Set((try? FileManager.default.contentsOfDirectory(atPath: storage.path)) ?? [])
        transport.onUpload = { _, _ in .failure(URLError(.timedOut)) }

        for attempt in 1...3 {
            let attachment = makeAttachment(tid: 700, filePath: source.path)
            let (taskInfo, recorder) = makeTask(attachment)
            plain.upload(attachment: attachment, taskInfo: taskInfo)
            waitUntil { recorder.isOver }
            XCTAssertEqual(transport.uploads.count, attempt)
            XCTAssertEqual(transport.uploads.last?.sourceFile.path, source.path, "attempt \(attempt) sends the file where it is")
            XCTAssertEqual(attachment.filePath, source.path)
            XCTAssertTrue(recorder.locations.isEmpty)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path), "the attachment's own file is never moved")
        let foldersAfter = Set((try? FileManager.default.contentsOfDirectory(atPath: storage.path)) ?? [])
        XCTAssertEqual(foldersAfter.subtracting(foldersBefore), [], "no storage folder per attempt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: plain.stagingDirectory.appendingPathComponent("upload%2D700").path))
    }


    func testFailureAndInterruptionAreBothReportedAsFailures() throws {
        let results: [FileTransferResult<FileUploadResult>] = [.failure(Failure(name: "failed")), .interrupted(Failure(name: "interrupted"))]
        for (index, result) in results.enumerated() {
            transport.onUpload = { _, _ in result }
            let (_, recorder, _) = try upload(tid: Int64(10 + index))
            waitUntil { recorder.isOver }
            XCTAssertEqual(recorder.failures.compactMap { $0 as? Failure }, [index == 0 ? Failure(name: "failed") : Failure(name: "interrupted")])
            XCTAssertTrue(recorder.successes.isEmpty)
        }
    }

    func testAnUploadWithoutAFileFailsAndFreesTheSlot() throws {
        let attachment = makeAttachment(filePath: nil)
        let (taskInfo, recorder) = makeTask(attachment)
        session.upload(attachment: attachment, taskInfo: taskInfo)
        let (_, next, _) = try upload(tid: 2)

        waitUntil { recorder.isOver && next.isOver }

        guard case .missingSourceFile = recorder.failures.first as? TransportDataSessionError else {
            return XCTFail("expected missingSourceFile, got \(recorder.failures)")
        }
        XCTAssertEqual(transport.uploads.map(\.operationId), ["upload-2"])
    }

    func testUploadsRunOneAtATime() throws {
        let first = Hold<FileTransferResult<FileUploadResult>>()
        transport.onUpload = { request, _ in
            request.operationId == "upload-1" ? await first.wait() : .success(FileUploadResult(url: "SECOND"))
        }
        let (_, a, _) = try upload(tid: 1)
        let (_, b, _) = try upload(tid: 2)

        waitUntil { first.isWaiting }
        settle()
        XCTAssertEqual(transport.uploads.map(\.operationId), ["upload-1"], "the second waits for the slot")

        first.open(.success(FileUploadResult(url: "FIRST")))
        waitUntil { a.isOver && b.isOver }
        XCTAssertEqual(transport.uploads.map(\.operationId), ["upload-1", "upload-2"])
        XCTAssertEqual(b.successes, ["SECOND"])
    }

    func testProgressAfterTheEndIsIgnored() throws {
        var report: ((Double) -> Void)?
        transport.onUpload = { _, progress in
            report = progress
            return .success(FileUploadResult(url: "R"))
        }
        let (_, recorder, _) = try upload()
        waitUntil { recorder.isOver }
        let before = recorder.progress

        report?(0.5)

        XCTAssertEqual(recorder.progress, before)
    }

    // MARK: - Preparation and staging

    func testAFileOfAnotherTypeIsSentAsIs() throws {
        let (_, recorder, attachment) = try upload(type: "voice")
        waitUntil { recorder.isOver }
        XCTAssertEqual(transport.uploads.first?.sourceFile.path, attachment.filePath)
        XCTAssertTrue(session.stored.isEmpty)
        XCTAssertTrue(recorder.locations.isEmpty)
    }

    func testAFolderIsZipped() throws {
        let folder = directory.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: folder.appendingPathComponent("a.txt"))
        let attachment = makeAttachment(name: "folder", filePath: folder.path)
        let (taskInfo, recorder) = makeTask(attachment)

        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { recorder.isOver }

        let sent = try XCTUnwrap(transport.uploads.first?.sourceFile)
        XCTAssertEqual(sent.pathExtension, "zip")
        XCTAssertEqual(recorder.locations, [sent])
        XCTAssertEqual(attachment.filePath, sent.path)
    }

    func testAnImageIsResizedStagedReusedByTheNextAttemptAndAdoptedWhenItLands() throws {
        let original = try image()
        let stagingFolder = directory.appendingPathComponent("staging/upload%2D1", isDirectory: true)
        transport.onUpload = { _, _ in .failure(Failure(name: "offline")) }

        // Attempt 1: resized and staged; the failure keeps the staged file.
        let first = makeAttachment(type: "image", name: "photo.jpg", filePath: original.path)
        let (firstTask, firstRecorder) = makeTask(first)
        session.upload(attachment: first, taskInfo: firstTask)
        waitUntil { firstRecorder.isOver }
        let staged = try XCTUnwrap(transport.uploads.first?.sourceFile)
        XCTAssertEqual(staged.deletingLastPathComponent().standardizedFileURL.path, stagingFolder.standardizedFileURL.path)
        XCTAssertEqual(staged.lastPathComponent, "photo.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: staged.path), "kept for the next attempt")
        XCTAssertEqual(first.filePath, original.path, "a failed attempt never replaces the original")
        let stagedBytes = try Data(contentsOf: staged)

        // Attempt 2 of the same operation: the same bytes, no new resize.
        transport.onUpload = { request, _ in
            XCTAssertEqual(try? Data(contentsOf: request.sourceFile), stagedBytes)
            return .success(FileUploadResult(url: "IMG"))
        }
        let second = makeAttachment(type: "image", name: "photo.jpg", filePath: original.path)
        let (secondTask, secondRecorder) = makeTask(second)
        session.upload(attachment: second, taskInfo: secondTask)
        waitUntil { secondRecorder.isOver }

        XCTAssertEqual(transport.uploads.last?.sourceFile, staged)
        XCTAssertEqual(secondRecorder.progress.first, nil, "nothing was prepared again")
        XCTAssertEqual(secondRecorder.successes, ["IMG"])
        let adopted = try XCTUnwrap(second.filePath)
        XCTAssertNotEqual(adopted, original.path)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: adopted)), stagedBytes, "the sent file becomes the attachment's")
        XCTAssertEqual(session.thumbnailPaths, [adopted])
        XCTAssertEqual(session.removed, [original.path], "the original image goes")
        XCTAssertFalse(FileManager.default.fileExists(atPath: stagingFolder.path), "staging is cleaned up")
    }

    func testAnEmptyStagedFileIsNotReused() throws {
        let stagingFolder = directory.appendingPathComponent("staging/upload%2D1", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
        try Data().write(to: stagingFolder.appendingPathComponent("empty.jpg"))
        let attachment = makeAttachment(type: "image", name: "photo.jpg", filePath: try image().path)
        let (taskInfo, recorder) = makeTask(attachment)

        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { recorder.isOver }

        XCTAssertEqual(transport.uploads.first?.sourceFile.lastPathComponent, "photo.jpg", "a new resize")
    }

    /// E1: the store failed, so the staged copy dies with the staging folder. The attachment
    /// keeps its original (not deleted), and nothing points at the staged path.
    func testAFailedStoreOfTheSentImageKeepsTheOriginal() throws {
        let original = try image()
        session.storeFails = true
        let attachment = makeAttachment(type: "image", name: "photo.jpg", filePath: original.path)
        let (taskInfo, recorder) = makeTask(attachment)

        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { recorder.isOver }

        XCTAssertEqual(session.stored.count, 1, "the store was tried")
        XCTAssertEqual(attachment.filePath, original.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path), "the original is not deleted")
        XCTAssertTrue(session.removed.isEmpty)
        XCTAssertTrue(recorder.locations.isEmpty, "no task is moved to the staged path")
        XCTAssertTrue(session.thumbnailPaths.isEmpty)
    }

    func testAnImageThatCannotBeDecodedIsSentAsIs() throws {
        let notAnImage = try file()
        let attachment = makeAttachment(type: "image", name: "broken.jpg", filePath: notAnImage.path)
        let (taskInfo, recorder) = makeTask(attachment)

        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { recorder.isOver }

        XCTAssertEqual(transport.uploads.first?.sourceFile.path, notAnImage.path)
        XCTAssertTrue(session.removed.isEmpty)
    }



    func testAVideoIsExportedAndStaged() throws {
        let exported = try file(name: "exported.mp4")
        session.environment.videoProcessor = { ScriptedVideoProcessor.self }
        ScriptedVideoProcessor.result = { _ in .success(exported) }

        let (_, recorder, attachment) = try upload(type: "video")
        waitUntil { recorder.isOver }

        let sent = try XCTUnwrap(transport.uploads.first?.sourceFile)
        XCTAssertEqual(sent.lastPathComponent, "exported.mp4")
        XCTAssertTrue(sent.path.contains("/staging/"))
        XCTAssertEqual(recorder.progress.first, AttachmentTransfer.initialUploadProgress, "a placeholder no larger than the task's first")
        XCTAssertNotEqual(attachment.filePath, exported.path)
        XCTAssertTrue(session.removed.isEmpty, "only an image's original is removed")
    }

    func testAVideoThatCannotBeExportedIsSentAsIs() throws {
        session.environment.videoProcessor = { ScriptedVideoProcessor.self }
        ScriptedVideoProcessor.result = { _ in .failure(CocoaError(.featureUnsupported)) }

        let (_, recorder, attachment) = try upload(type: "video")
        waitUntil { recorder.isOver }

        XCTAssertEqual(transport.uploads.first?.sourceFile.path, attachment.filePath)
    }

    // MARK: - Checksum

    func testAChecksumHitEndsTheUploadWithoutTheTransport() throws {
        session.checksums = true
        ScriptedChecksumProvider.answer = { attachment, completion in completion(.success(attachment.tid == 1 ? "STORED" : nil)) }

        let (_, recorder, _) = try upload()
        let (_, next, _) = try upload(tid: 2)
        waitUntil { recorder.isOver && next.isOver }

        XCTAssertEqual(recorder.successes, ["STORED"])
        XCTAssertEqual(transport.uploads.map(\.operationId), ["upload-2"], "the slot was freed")
        XCTAssertEqual(transport.prepared.map(\.operationId), ["upload-2"], "a checksum hit prepares nothing")
    }

    func testAChecksumMissUploads() throws {
        session.checksums = true
        let (_, recorder, _) = try upload()
        waitUntil { recorder.isOver }
        XCTAssertEqual(transport.uploads.count, 1)
        XCTAssertEqual(recorder.successes, ["REMOTE"])
    }

    func testAChecksumFailureIsReportedOnceAndNothingIsUploaded() throws {
        session.checksums = true
        ScriptedChecksumProvider.answer = { _, completion in completion(.failure(Failure(name: "db"))) }

        let (_, recorder, _) = try upload()
        waitUntil { recorder.isOver }
        settle()

        XCTAssertEqual(recorder.failures.count, 1)
        XCTAssertEqual(recorder.failures.first as? Failure, Failure(name: "db"))
        XCTAssertTrue(transport.uploads.isEmpty)
    }

    func testAPauseDuringTheChecksumStopsTheAttempt() throws {
        session.checksums = true
        let answer = Locked<((Result<String?, Error>) -> Void)?>(nil)
        ScriptedChecksumProvider.answer = { _, completion in answer.wrapped = completion }
        let (taskInfo, recorder, _) = try upload()
        waitUntil { answer.wrapped != nil }

        taskInfo.stop()
        answer.wrapped?(.success(nil))
        settle()

        XCTAssertTrue(transport.uploads.isEmpty)
        XCTAssertFalse(recorder.isOver)
    }

    func testAChecksumOfAnEarlierAttemptIsIgnored() throws {
        session.checksums = true
        let answers = Locked([(Result<String?, Error>) -> Void]())
        ScriptedChecksumProvider.answer = { _, completion in answers.mutate { $0.append(completion) } }
        let (taskInfo, recorder, _) = try upload()
        waitUntil { answers.wrapped.count == 1 }

        taskInfo.stop()
        taskInfo.resume()
        waitUntil { answers.wrapped.count == 2 }
        answers.wrapped[0](.success(nil))
        settle()
        XCTAssertTrue(transport.uploads.isEmpty, "the first attempt's miss does not upload")

        answers.wrapped[1](.success(nil))
        waitUntil { recorder.isOver }
        XCTAssertEqual(transport.uploads.count, 1)
        XCTAssertEqual(recorder.successes, ["REMOTE"])
    }

    /// A hit for a paused attempt arrives after its wait ended: it changes nothing (ending the
    /// task from there would leave the job, and tasks joined to it, unfinished). The current
    /// attempt's own checksum decides.
    func testAChecksumHitOfAnEarlierAttemptIsIgnoredAndTheCurrentOneDecides() throws {
        session.checksums = true
        let answers = Locked([(Result<String?, Error>) -> Void]())
        ScriptedChecksumProvider.answer = { attachment, completion in
            if attachment.tid == 1 { answers.mutate { $0.append(completion) } } else { completion(.success(nil)) }
        }
        let (taskInfo, recorder, _) = try upload()
        waitUntil { answers.wrapped.count == 1 }
        taskInfo.stop()
        taskInfo.resume()
        waitUntil { answers.wrapped.count == 2 }

        answers.wrapped[0](.success("STORED-LATE"))
        answers.wrapped[1](.success("STORED"))
        let (_, next, _) = try upload(tid: 2)
        waitUntil { recorder.isOver && next.isOver }

        XCTAssertEqual(recorder.successes, ["STORED"], "the current attempt's hit, not the late one")
        XCTAssertEqual(transport.uploads.map(\.operationId), ["upload-2"], "the slot was freed")
    }

    func testAFailureForATaskThatAlreadyEndedIsNotReportedAgain() throws {
        let hold = Hold<FileTransferResult<URL>>()
        transport.onDownload = { _, _ in await hold.wait() }
        let (taskInfo, recorder) = download()
        waitUntil { hold.isWaiting }

        taskInfo.failure(error: Failure(name: "elsewhere"))
        hold.open(.failure(Failure(name: "transport")))
        settle()

        XCTAssertEqual(recorder.failures.compactMap { $0 as? Failure }, [Failure(name: "elsewhere")])
    }

    func testAResultForATaskThatAlreadyEndedIsNotReportedAgain() throws {
        let hold = Hold<FileTransferResult<URL>>()
        transport.onDownload = { _, _ in await hold.wait() }
        let (taskInfo, recorder) = download()
        waitUntil { hold.isWaiting }

        // Ended elsewhere, e.g. failed on network loss.
        taskInfo.failure(error: Failure(name: "elsewhere"))
        hold.open(.success(try XCTUnwrap(transport.downloads.first).destinationFile))
        settle()

        XCTAssertEqual(recorder.failures.count, 1)
        XCTAssertTrue(recorder.successes.isEmpty, "the transfer's own result is not reported over it")
        XCTAssertTrue(recorder.locations.isEmpty, "nothing replaces the terminal event")
        guard case .failure? = taskInfo.event else { return XCTFail("the task still ended with its failure: \(String(describing: taskInfo.event))") }
    }

    /// The same for an upload that lands, staged file and all, after its task already ended.
    func testAnUploadThatLandsAfterItsTaskEndedIsNotReported() throws {
        let original = try image()
        let attachment = makeAttachment(type: "image", name: "photo.jpg", filePath: original.path)
        let (taskInfo, recorder) = makeTask(attachment)
        let hold = Hold<FileTransferResult<FileUploadResult>>()
        transport.onUpload = { _, _ in await hold.wait() }
        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { hold.isWaiting }

        taskInfo.failure(error: Failure(name: "elsewhere"))
        hold.open(.success(FileUploadResult(url: "LATE")))
        settle()

        XCTAssertEqual(recorder.failures.compactMap { $0 as? Failure }, [Failure(name: "elsewhere")])
        XCTAssertTrue(recorder.successes.isEmpty)
        XCTAssertEqual(recorder.locations.count, 0, "the staged file is not adopted over the ended task")
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path), "the original is kept")
    }

    // MARK: - Pause and resume

    func testAPauseWhileQueuedKeepsTheUploadOutOfTheQueueUntilResumed() throws {
        let first = Hold<FileTransferResult<FileUploadResult>>()
        transport.onUpload = { request, _ in
            request.operationId == "upload-1" ? await first.wait() : .success(FileUploadResult(url: "SECOND"))
        }
        let (_, a, _) = try upload(tid: 1)
        let (queued, b, _) = try upload(tid: 2)
        waitUntil { first.isWaiting }

        queued.stop()
        XCTAssertTrue(transport.paused.isEmpty, "nothing is running to pause")
        first.open(.success(FileUploadResult(url: "FIRST")))
        waitUntil { a.isOver }
        settle()
        XCTAssertEqual(uploads(of: "upload-2"), 0)

        queued.resume()
        waitUntil { b.isOver }
        XCTAssertEqual(b.successes, ["SECOND"])
        XCTAssertTrue(transport.resumed.isEmpty, "a new attempt, not a resume")
    }

    func testAPauseDuringPreparationStopsItAndResumeStartsANewAttempt() throws {
        let preparing = Hold<Void>()
        var preparations = 0
        let source = try file()
        session.preparation = { _, _ in
            preparations += 1
            if preparations == 1 { await preparing.wait() }
            return PreparedUploadFile(file: source, isStaged: false)
        }
        let (taskInfo, recorder, _) = try upload()
        let (_, next, _) = try upload(tid: 2)
        waitUntil { preparing.isWaiting }

        taskInfo.stop()
        waitUntil { next.isOver }
        XCTAssertEqual(transport.uploads.map(\.operationId), ["upload-2"], "the pause freed the slot")
        XCTAssertTrue(transport.paused.isEmpty, "the transport had nothing yet")

        preparing.open(())
        settle()
        XCTAssertEqual(uploads(of: "upload-1"), 0, "a prepared file of a paused attempt is not sent")

        taskInfo.resume()
        waitUntil { recorder.isOver }
        XCTAssertEqual(preparations, 3, "upload-2 and two attempts of upload-1")
        XCTAssertEqual(uploads(of: "upload-1"), 1)
    }

    func testUploadsRunUpToTheSlotCountAndTheRestWaitInOrder() throws {
        session.slots = 2
        let release = Hold<FileTransferResult<FileUploadResult>>()
        transport.onUpload = { request, _ in
            if request.operationId == "upload-1" { return await release.wait() }
            return await Hold<FileTransferResult<FileUploadResult>>().wait()
        }
        let (_, first, _) = try upload(tid: 1)
        _ = try upload(tid: 2)
        _ = try upload(tid: 3)
        waitUntil { self.transport.uploads.count == 2 }
        settle()
        XCTAssertEqual(transport.uploads.map(\.operationId), ["upload-1", "upload-2"], "two slots, the third waits")

        release.open(.success(FileUploadResult(url: "R1")))
        waitUntil { first.isOver }
        waitUntil { self.transport.uploads.count == 3 }
        XCTAssertEqual(transport.uploads.last?.operationId, "upload-3", "the freed slot goes to the next in line")
    }

    func testTheQueueIsReportedAsUploadsWaitTakeTheSlotAndLeave() throws {
        let first = Hold<FileTransferResult<FileUploadResult>>()
        transport.onUpload = { request, _ in
            request.operationId == "upload-1" ? await first.wait() : .success(FileUploadResult(url: request.operationId))
        }
        let (_, a, _) = try upload(tid: 1)
        _ = try upload(tid: 2)
        let (_, c, _) = try upload(tid: 3)
        waitUntil { first.isWaiting }
        settle()
        XCTAssertEqual(session.queue, ["1/0", "1/1", "1/2"], "one sending, two waiting")

        first.open(.success(FileUploadResult(url: "A")))
        waitUntil { a.isOver && c.isOver }
        settle()
        XCTAssertEqual(session.queue, ["1/0", "1/1", "1/2", "1/1", "1/0", "0/0"], "each freed slot goes to the next, then the queue empties")
    }

    func testCancellingOrPausingAQueuedUploadIsReported() throws {
        let first = Hold<FileTransferResult<FileUploadResult>>()
        transport.onUpload = { _, _ in await first.wait() }
        _ = try upload(tid: 1)
        let (paused, _, _) = try upload(tid: 2)
        let (cancelled, _, _) = try upload(tid: 3)
        waitUntil { first.isWaiting }

        paused.stop()
        settle()
        cancelled.cancel()
        settle()
        XCTAssertEqual(session.queue, ["1/0", "1/1", "1/2", "1/1", "1/0"])
    }

    func testAZeroSlotCountStillRunsOneUpload() throws {
        session.slots = 0
        let (_, recorder, _) = try upload()
        waitUntil { recorder.isOver }
        XCTAssertEqual(transport.uploads.count, 1)
    }

    func testAResumedUploadPreparesWithAnExportStateThePauseDidNotCancel() throws {
        let preparing = Hold<Void>()
        var preparations = 0
        let source = try file()
        session.preparation = { _, _ in
            preparations += 1
            if preparations == 1 { await preparing.wait() }
            return PreparedUploadFile(file: source, isStaged: false)
        }
        let (taskInfo, recorder, _) = try upload()
        waitUntil { preparing.isWaiting }

        taskInfo.stop()
        preparing.open(())
        settle()
        taskInfo.resume()
        waitUntil { recorder.isOver }

        let infos = session.videoProcessInfos
        XCTAssertEqual(infos.count, 2)
        XCTAssertTrue(infos.first?.isCancelled == true, "the pause cancelled the first attempt's export")
        XCTAssertFalse(infos.last?.isCancelled ?? true, "a cancelled export state stays cancelled: the next attempt needs its own, or the video is sent uncompressed")
        XCTAssertFalse(infos.first === infos.last)
    }

    func testProgressAfterTheEndIsDroppedAndDoesNotReplaceIt() throws {
        let (taskInfo, recorder, _) = try upload()
        waitUntil { recorder.isOver }
        let eventsAtEnd = recorder.events.count

        taskInfo.updateProgress(0.5)
        taskInfo.updateLocalFileLocation(newPath: "/late")

        XCTAssertEqual(recorder.events.count, eventsAtEnd, "nothing is delivered after the end")
        XCTAssertTrue(taskInfo.isTerminal, "a late progress tick does not replace the end")
    }

    func testAPreparationFailureOfACancelledUploadIsNotReported() throws {
        let preparing = Hold<Void>()
        session.preparation = { _, _ in
            await preparing.wait()
            throw Failure(name: "export")
        }
        let (taskInfo, recorder, _) = try upload()
        waitUntil { preparing.isWaiting }

        taskInfo.cancel()
        preparing.open(())
        settle()

        XCTAssertEqual(recorder.failures.count, 1, "the cancel, not the preparation's failure")
        XCTAssertEqual((recorder.failures.first as? URLError)?.code, .cancelled)
        XCTAssertEqual(transport.cancelled, ["upload-1"])
    }

    func testAPreparationFailureIsReported() throws {
        session.preparation = { _, _ in throw Failure(name: "export") }
        let (_, recorder, _) = try upload()
        waitUntil { recorder.isOver }
        XCTAssertEqual(recorder.failures.first as? Failure, Failure(name: "export"))
        XCTAssertTrue(transport.uploads.isEmpty)
    }

    func testAPauseInPlaceThatCannotResumeStartsANewAttempt() throws {
        let first = Hold<FileTransferResult<FileUploadResult>>()
        var attempts = 0
        transport.onUpload = { _, _ in
            attempts += 1
            return attempts == 1 ? await first.wait() : .success(FileUploadResult(url: "SECOND"))
        }
        transport.onResume = { _ in false }
        let (taskInfo, recorder, _) = try upload()
        waitUntil { first.isWaiting }

        taskInfo.stop()
        taskInfo.resume()
        waitUntil { recorder.isOver }

        XCTAssertEqual(transport.paused, ["upload-1"])
        XCTAssertEqual(transport.resumed, ["upload-1"])
        XCTAssertEqual(uploads(of: "upload-1"), 2)
        XCTAssertEqual(recorder.successes, ["SECOND"])
        XCTAssertTrue(first.wasCancelled, "the old invocation is stopped")

        // The first invocation ends late: it belongs to an earlier attempt.
        first.open(.success(FileUploadResult(url: "FIRST")))
        settle()
        XCTAssertEqual(recorder.successes, ["SECOND"])
    }

    func testACancelWhileTheTransportResumesIsNotUndone() throws {
        let first = Hold<FileTransferResult<FileUploadResult>>(onCancel: .interrupted(CancellationError()))
        transport.onUpload = { _, _ in await first.wait() }
        var taskInfo: SCTDataSessionTaskInfo!
        transport.onResume = { _ in
            taskInfo.cancel()
            return false
        }
        let started = try upload()
        taskInfo = started.0
        waitUntil { first.isWaiting }

        taskInfo.stop()
        taskInfo.resume()
        settle()

        XCTAssertEqual(uploads(of: "upload-1"), 1, "a cancelled upload never starts again")
        XCTAssertEqual(transport.cancelled, ["upload-1"])
        XCTAssertEqual(started.1.failures.count, 1, "the cancel's failure only")
        XCTAssertEqual((started.1.failures.first as? URLError)?.code, .cancelled)
    }

    func testAPauseThatRacesTheEndOfTheUploadChangesNothing() throws {
        let first = Hold<FileTransferResult<FileUploadResult>>(onCancel: .interrupted(CancellationError()))
        transport.onUpload = { _, _ in await first.wait() }
        var taskInfo: SCTDataSessionTaskInfo!
        transport.onPause = { _ in
            taskInfo.cancel()
            return true
        }
        let started = try upload()
        taskInfo = started.0
        waitUntil { first.isWaiting }

        taskInfo.stop()
        taskInfo.resume()
        settle()

        XCTAssertTrue(transport.resumed.isEmpty, "the cancelled upload is not paused, so not resumed")
        XCTAssertEqual(uploads(of: "upload-1"), 1)
    }

    func testAPausedInvocationThatFailsIsReplacedOnResume() throws {
        let first = Hold<FileTransferResult<FileUploadResult>>()
        var attempts = 0
        transport.onUpload = { _, _ in
            attempts += 1
            return attempts == 1 ? await first.wait() : .success(FileUploadResult(url: "SECOND"))
        }
        let (taskInfo, recorder, _) = try upload()
        waitUntil { first.isWaiting }

        taskInfo.stop()
        first.open(.interrupted(Failure(name: "lost")))
        settle()
        XCTAssertFalse(recorder.isOver, "an invocation that ends while paused is not a failure")

        taskInfo.resume()
        waitUntil { recorder.isOver }
        XCTAssertTrue(transport.resumed.isEmpty, "nothing alive to resume")
        XCTAssertEqual(uploads(of: "upload-1"), 2)
        XCTAssertEqual(recorder.successes, ["SECOND"])
    }

    func testAPausedInvocationThatLandsIsASuccess() throws {
        let first = Hold<FileTransferResult<FileUploadResult>>()
        transport.onUpload = { _, _ in await first.wait() }
        let (taskInfo, recorder, _) = try upload()
        waitUntil { first.isWaiting }

        taskInfo.stop()
        first.open(.success(FileUploadResult(url: "LANDED")))
        waitUntil { recorder.isOver }

        XCTAssertEqual(recorder.successes, ["LANDED"])
    }

    func testAnInvocationEndingWhileItsResumeWaitsInTheQueueIsReplaced() throws {
        let a1 = Hold<FileTransferResult<FileUploadResult>>()
        let b = Hold<FileTransferResult<FileUploadResult>>()
        var attemptsOfA = 0
        transport.onUpload = { request, _ in
            if request.operationId == "upload-2" { return await b.wait() }
            attemptsOfA += 1
            return attemptsOfA == 1 ? await a1.wait() : .success(FileUploadResult(url: "A2"))
        }
        let (taskA, recorderA, _) = try upload(tid: 1)
        let (_, recorderB, _) = try upload(tid: 2)
        waitUntil { a1.isWaiting }

        taskA.stop()
        waitUntil { b.isWaiting }
        taskA.resume()
        a1.open(.interrupted(Failure(name: "lost")))
        settle()
        XCTAssertFalse(recorderA.isOver)

        b.open(.success(FileUploadResult(url: "B")))
        waitUntil { recorderA.isOver && recorderB.isOver }
        XCTAssertTrue(transport.resumed.isEmpty, "the paused invocation was gone by its turn")
        XCTAssertEqual(uploads(of: "upload-1"), 2)
        XCTAssertEqual(recorderA.successes, ["A2"])
    }

    func testProgressAndResultsOfAStaleAttemptNeverReachTheTask() throws {
        let holds = [Hold<FileTransferResult<FileUploadResult>>(), Hold<FileTransferResult<FileUploadResult>>()]
        var reports = [(Double) -> Void]()
        transport.pausesInPlace(false)
        transport.onUpload = { _, progress in
            reports.append(progress)
            return await holds[reports.count - 1].wait()
        }
        let (taskInfo, recorder, _) = try upload()
        waitUntil { holds[0].isWaiting }
        reports[0](0.4)
        XCTAssertEqual(recorder.progress.last, 0.4)

        taskInfo.stop()
        XCTAssertTrue(holds[0].wasCancelled, "a pause the transport cannot hold stops the invocation")
        reports[0](0.5)
        XCTAssertEqual(recorder.progress.last, 0.4, "no progress while paused")

        taskInfo.resume()
        waitUntil { holds[1].isWaiting }
        reports[0](0.6)
        reports[1](0.2)
        holds[0].open(.success(FileUploadResult(url: "STALE")))
        settle()
        XCTAssertEqual(recorder.progress.last, 0.2)
        XCTAssertFalse(recorder.progress.contains(0.6))
        XCTAssertTrue(recorder.successes.isEmpty, "the stale attempt's result is dropped")

        holds[1].open(.success(FileUploadResult(url: "CURRENT")))
        waitUntil { recorder.isOver }
        XCTAssertEqual(recorder.successes, ["CURRENT"])
    }

    func testRepeatedPausesAndResumesAreHarmless() throws {
        let first = Hold<FileTransferResult<FileUploadResult>>()
        transport.onUpload = { _, _ in await first.wait() }
        let (taskInfo, recorder, _) = try upload()
        waitUntil { first.isWaiting }

        taskInfo.stop()
        taskInfo.stop()
        taskInfo.resume()
        waitUntil { self.transport.resumed.count == 1 }
        taskInfo.resume()
        settle()

        XCTAssertEqual(transport.paused, ["upload-1"])
        XCTAssertEqual(transport.resumed, ["upload-1"])
        first.open(.success(FileUploadResult(url: "R")))
        waitUntil { recorder.isOver }
        XCTAssertEqual(uploads(of: "upload-1"), 1)
    }

    // MARK: - Cancel

    func testCancellingARunningUploadStopsItAndDropsItsResult() throws {
        let first = Hold<FileTransferResult<FileUploadResult>>()
        transport.onUpload = { request, _ in
            request.operationId == "upload-1" ? await first.wait() : .success(FileUploadResult(url: "NEXT"))
        }
        let (taskInfo, recorder, _) = try upload(tid: 1)
        let (_, next, _) = try upload(tid: 2)
        waitUntil { first.isWaiting }

        taskInfo.cancel()
        taskInfo.cancel()
        waitUntil { next.isOver }
        XCTAssertTrue(first.wasCancelled)
        XCTAssertEqual(transport.cancelled, ["upload-1"], "repeats reach the transport once")

        first.open(.success(FileUploadResult(url: "LATE")))
        settle()
        XCTAssertEqual(recorder.failures.count, 1, "a cancelled upload ends, once")
        XCTAssertEqual((recorder.failures.first as? URLError)?.code, .cancelled, "like a cancelled download")
        XCTAssertTrue(recorder.successes.isEmpty, "its late result is dropped")

        taskInfo.stop()
        taskInfo.resume()
        settle()
        XCTAssertTrue(transport.paused.isEmpty)
        XCTAssertEqual(uploads(of: "upload-1"), 1)
    }

    func testCancellingAQueuedUploadRemovesItFromTheQueue() throws {
        let first = Hold<FileTransferResult<FileUploadResult>>()
        transport.onUpload = { _, _ in await first.wait() }
        let (_, a, _) = try upload(tid: 1)
        let (queued, b, _) = try upload(tid: 2)
        waitUntil { first.isWaiting }

        queued.cancel()
        first.open(.success(FileUploadResult(url: "A")))
        waitUntil { a.isOver }
        settle()

        XCTAssertEqual(transport.cancelled, ["upload-2"])
        XCTAssertEqual(uploads(of: "upload-2"), 0)
        XCTAssertEqual((b.failures.first as? URLError)?.code, .cancelled)
        XCTAssertEqual(b.failures.count, 1)
    }

    func testCancellingAPausedUploadDiscardsItsStaging() throws {
        let stagingFolder = directory.appendingPathComponent("staging/upload%2D1", isDirectory: true)
        let original = try image()
        let attachment = makeAttachment(type: "image", name: "photo.jpg", filePath: original.path)
        let (taskInfo, recorder) = makeTask(attachment)
        let hold = Hold<FileTransferResult<FileUploadResult>>(onCancel: .interrupted(CancellationError()))
        transport.onUpload = { _, _ in await hold.wait() }
        transport.onPause = { _ in false }
        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { hold.isWaiting }
        XCTAssertTrue(FileManager.default.fileExists(atPath: stagingFolder.path))

        taskInfo.stop()
        settle()
        XCTAssertTrue(FileManager.default.fileExists(atPath: stagingFolder.path), "a pause keeps the staged file")
        taskInfo.cancel()

        XCTAssertFalse(FileManager.default.fileExists(atPath: stagingFolder.path))
        XCTAssertEqual(transport.cancelled, ["upload-1"])
        XCTAssertEqual((recorder.failures.first as? URLError)?.code, .cancelled)
        XCTAssertEqual(recorder.failures.count, 1)
    }

    func testCancelAttachmentsReachesRunningAndSavedUploads() throws {
        let first = Hold<FileTransferResult<FileUploadResult>>(onCancel: .interrupted(CancellationError()))
        transport.onUpload = { _, _ in await first.wait() }
        let (_, running, attachment) = try upload(tid: 1)
        waitUntil { first.isWaiting }
        let savedStaging = directory.appendingPathComponent("staging/upload%2D9", isDirectory: true)
        try FileManager.default.createDirectory(at: savedStaging, withIntermediateDirectories: true)
        try Data([1]).write(to: savedStaging.appendingPathComponent("saved.jpg"))

        session.cancel(attachments: [attachment, makeAttachment(tid: 0), makeAttachment(tid: 9)])

        XCTAssertEqual(transport.cancelled, ["upload-1", "upload-9"], "nothing to name without a tid")
        XCTAssertTrue(first.wasCancelled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: savedStaging.path))
        settle()
        XCTAssertEqual((running.failures.first as? URLError)?.code, .cancelled)
        XCTAssertEqual(running.failures.count, 1)

        session.cancel(attachments: [attachment])
        XCTAssertEqual(transport.cancelled, ["upload-1", "upload-9", "upload-1"], "no job left: treated as saved")
    }

    // MARK: - Interrupt

    func testInterruptTransfersFailsEveryTaskWithoutAbandoningAny() throws {
        let upload1 = Hold<FileTransferResult<FileUploadResult>>()
        let downloadHold = Hold<FileTransferResult<URL>>(onCancel: .interrupted(CancellationError()))
        transport.onUpload = { _, _ in await upload1.wait() }
        transport.onDownload = { _, _ in await downloadHold.wait() }
        let (_, running, _) = try upload(tid: 1)
        let (_, queued, _) = try upload(tid: 2)
        let (_, downloading) = download()
        waitUntil { upload1.isWaiting && downloadHold.isWaiting }
        let lost = Failure(name: "network")

        session.interruptTransfers(error: lost)

        waitUntil { running.isOver && queued.isOver && downloading.isOver }
        for recorder in [running, queued, downloading] {
            XCTAssertEqual(recorder.failures.compactMap { $0 as? Failure }, [lost])
        }
        XCTAssertTrue(transport.cancelled.isEmpty, "an interruption is not an abandonment")
        XCTAssertTrue(upload1.wasCancelled)
        XCTAssertTrue(downloadHold.wasCancelled)

        // Late results are dropped, and the slot is free at once.
        upload1.open(.success(FileUploadResult(url: "LATE")))
        transport.onUpload = { _, _ in .success(FileUploadResult(url: "AFTER")) }
        let (_, after, _) = try upload(tid: 3)
        waitUntil { after.isOver }
        XCTAssertEqual(after.successes, ["AFTER"])
        XCTAssertEqual(running.failures.count, 1)
        XCTAssertTrue(running.successes.isEmpty)
        XCTAssertEqual(uploads(of: "upload-2"), 0)
    }

    // MARK: - Downloads

    func testADownloadWithoutAUsableURLOrDestinationFails() {
        for (url, hasDestination) in [(nil, true), ("", true), ("https://files.example/a/b.pdf", false)] as [(String?, Bool)] {
            session.hasDestination = hasDestination
            let attachment = makeAttachment(tid: 0, url: url)
            let (taskInfo, recorder) = makeTask(attachment, .download)
            session.download(attachment: attachment, taskInfo: taskInfo)
            waitUntil { recorder.isOver }
            guard case .invalidRequest = recorder.failures.first as? FileTransferError else {
                return XCTFail("\(String(describing: url)): expected invalidRequest, got \(recorder.failures)")
            }
        }
        XCTAssertTrue(transport.downloads.isEmpty)
    }

    func testPlainDownloadRequestProgressAndSuccess() throws {
        transport.onDownload = { request, progress in
            progress(0.5)
            progress(1)
            return .success(request.destinationFile)
        }

        let (taskInfo, recorder) = download(metadata: #"{"szw":3,"sceyt.enc":"TOKEN"}"#)
        waitUntil { recorder.isOver }

        let request = try XCTUnwrap(transport.downloads.first)
        XCTAssertTrue(request.headers.isEmpty)
        XCTAssertEqual(request.destinationFile.pathExtension == "part", false, "a plain download goes straight to its destination")
        XCTAssertTrue(request.operationId.hasPrefix("download-url"))
        XCTAssertEqual(request.url, taskInfo.attachment.url)
        XCTAssertTrue((request.context as? AttachmentTransferContext)?.attachment === taskInfo.attachment)
        XCTAssertEqual(recorder.progress, [0.5, 1])
        XCTAssertEqual(recorder.locations, [request.destinationFile])
        XCTAssertEqual(recorder.successes, [request.url])
        XCTAssertEqual(request.metadata, ["sceyt.enc": "TOKEN"], "the provider gets the attachment's string entries")
    }

        func testDownloadFailureAndInterruptionAreFailures() {
        let results: [FileTransferResult<URL>] = [.failure(Failure(name: "404")), .interrupted(Failure(name: "lost"))]
        for result in results {
            transport.onDownload = { _, _ in result }
            let (taskInfo, recorder) = download()
            waitUntil { recorder.isOver }
            XCTAssertEqual(recorder.failures.count, 1)
            XCTAssertNotNil(recorder.failures.first as? Failure)
            XCTAssertTrue(recorder.locations.isEmpty)
            _ = taskInfo
        }
    }

    func testADownloadPausedInPlaceResumesTheSameInvocation() throws {
        let hold = Hold<FileTransferResult<URL>>()
        transport.onDownload = { _, _ in await hold.wait() }
        let (taskInfo, recorder) = download()
        waitUntil { hold.isWaiting }

        taskInfo.stop()
        taskInfo.stop()
        taskInfo.resume()
        taskInfo.resume()
        let request = try XCTUnwrap(transport.downloads.first)
        hold.open(.success(request.destinationFile))
        waitUntil { recorder.isOver }

        XCTAssertEqual(transport.paused.count, 1)
        XCTAssertEqual(transport.resumed.count, 1)
        XCTAssertEqual(transport.downloads.count, 1)
        XCTAssertFalse(hold.wasCancelled)
        XCTAssertEqual(recorder.successes.count, 1)
    }

    func testADownloadPauseTheTransportCannotHoldRestartsOnResume() throws {
        let holds = [Hold<FileTransferResult<URL>>(onCancel: .interrupted(CancellationError())), Hold<FileTransferResult<URL>>()]
        var reports = [(Double) -> Void]()
        transport.pausesInPlace(false)
        transport.onDownload = { _, progress in
            reports.append(progress)
            return await holds[reports.count - 1].wait()
        }
        let (taskInfo, recorder) = download()
        waitUntil { holds[0].isWaiting }

        taskInfo.stop()
        waitUntil { holds[0].wasCancelled }
        settle()
        XCTAssertFalse(recorder.isOver, "stopped by a pause, not failed")
        reports[0](0.3)
        XCTAssertTrue(recorder.progress.isEmpty)

        taskInfo.resume()
        waitUntil { holds[1].isWaiting }
        XCTAssertTrue(transport.resumed.isEmpty)
        reports[0](0.4)
        reports[1](0.7)
        XCTAssertEqual(recorder.progress, [0.7], "only the current attempt reports")
        holds[1].open(.success(try XCTUnwrap(transport.downloads.last).destinationFile))
        waitUntil { recorder.isOver }
        XCTAssertEqual(transport.downloads.count, 2)
        XCTAssertEqual(recorder.successes.count, 1)
    }

    func testADownloadPausedInPlaceThatCannotResumeRestarts() throws {
        let first = Hold<FileTransferResult<URL>>(onCancel: .interrupted(CancellationError()))
        var attempts = 0
        transport.onDownload = { request, _ in
            attempts += 1
            return attempts == 1 ? await first.wait() : .success(request.destinationFile)
        }
        transport.onResume = { _ in false }
        let (taskInfo, recorder) = download()
        waitUntil { first.isWaiting }

        taskInfo.stop()
        taskInfo.resume()
        waitUntil { recorder.isOver }

        XCTAssertEqual(transport.resumed.count, 1)
        XCTAssertEqual(transport.downloads.count, 2)
        XCTAssertTrue(first.wasCancelled, "the old invocation is stopped")
        XCTAssertEqual(recorder.successes.count, 1)
    }

    func testADownloadThatEndsWhilePausedInPlaceIsReported() throws {
        let hold = Hold<FileTransferResult<URL>>()
        transport.onDownload = { _, _ in await hold.wait() }
        let (taskInfo, recorder) = download()
        waitUntil { hold.isWaiting }

        taskInfo.stop()
        hold.open(.failure(Failure(name: "timed out")))
        waitUntil { recorder.isOver }

        XCTAssertEqual(recorder.failures.first as? Failure, Failure(name: "timed out"))
        taskInfo.resume()
        settle()
        XCTAssertTrue(transport.resumed.isEmpty)
        XCTAssertEqual(transport.downloads.count, 1)
    }

    func testCancellingADownloadFailsItOnceAndDropsItsResult() throws {
        let hold = Hold<FileTransferResult<URL>>()
        transport.onDownload = { _, _ in await hold.wait() }
        let (taskInfo, recorder) = download()
        waitUntil { hold.isWaiting }

        taskInfo.cancel()
        taskInfo.cancel()
        waitUntil { hold.wasCancelled }
        hold.open(.success(try XCTUnwrap(transport.downloads.first).destinationFile))
        settle()

        XCTAssertEqual(transport.cancelled.count, 1)
        XCTAssertEqual(recorder.failures.count, 1)
        XCTAssertEqual((recorder.failures.first as? URLError)?.code, .cancelled)
        XCTAssertTrue(recorder.successes.isEmpty)

        taskInfo.stop()
        taskInfo.resume()
        settle()
        XCTAssertTrue(transport.paused.isEmpty)
        XCTAssertEqual(transport.downloads.count, 1)
    }

    func testAPauseRacingTheCancelOfADownloadChangesNothing() throws {
        let hold = Hold<FileTransferResult<URL>>(onCancel: .interrupted(CancellationError()))
        transport.onDownload = { _, _ in await hold.wait() }
        var taskInfo: SCTDataSessionTaskInfo!
        transport.onPause = { _ in
            taskInfo.cancel()
            return false
        }
        let started = download()
        taskInfo = started.0
        waitUntil { hold.isWaiting }

        taskInfo.stop()
        taskInfo.resume()
        settle()

        XCTAssertEqual(started.1.failures.count, 1, "the cancel's failure only")
        XCTAssertEqual(transport.downloads.count, 1)
    }

    /// A cancel that lands while the transport is being asked to resume must stay a cancel.
    func testACancelWhileTheTransportResumesADownloadIsNotUndone() throws {
        let first = Hold<FileTransferResult<URL>>(onCancel: .interrupted(CancellationError()))
        transport.onDownload = { request, _ in
            self.transport.downloads.count == 1 ? await first.wait() : .success(request.destinationFile)
        }
        var taskInfo: SCTDataSessionTaskInfo!
        transport.onResume = { _ in
            taskInfo.cancel()
            return false
        }
        let started = download()
        taskInfo = started.0
        waitUntil { first.isWaiting }

        taskInfo.stop()
        taskInfo.resume()
        settle()

        XCTAssertEqual(transport.downloads.count, 1, "a cancelled download never starts again")
        XCTAssertEqual(started.1.failures.count, 1)
        XCTAssertEqual((started.1.failures.first as? URLError)?.code, .cancelled)
        XCTAssertTrue(started.1.successes.isEmpty)
    }

    // MARK: - Trusted size, duplicates


    func testASecondStartOfARunningUploadJoinsIt() throws {
        let hold = Hold<FileTransferResult<FileUploadResult>>()
        transport.onUpload = { _, _ in await hold.wait() }
        let (first, a, attachment) = try upload(tid: 5)
        waitUntil { hold.isWaiting }

        let (second, b) = makeTask(attachment)
        session.upload(attachment: attachment, taskInfo: second)
        hold.open(.success(FileUploadResult(url: "ONE")))
        waitUntil { a.isOver && b.isOver }

        XCTAssertEqual(uploads(of: "upload-5"), 1, "one transfer, one staging folder, one transport record")
        XCTAssertEqual(a.successes, ["ONE"])
        XCTAssertEqual(b.successes, ["ONE"])
        XCTAssertEqual(first.operationId, second.operationId)
    }

    func testCancellingAJoinedUploadEndsBothTasks() throws {
        let hold = Hold<FileTransferResult<FileUploadResult>>(onCancel: .interrupted(CancellationError()))
        transport.onUpload = { _, _ in await hold.wait() }
        let (_, a, attachment) = try upload(tid: 6)
        waitUntil { hold.isWaiting }
        let (second, b) = makeTask(attachment)
        session.upload(attachment: attachment, taskInfo: second)

        second.cancel()
        waitUntil { a.isOver && b.isOver }

        XCTAssertEqual(transport.cancelled, ["upload-6"])
        XCTAssertEqual((a.failures.first as? URLError)?.code, .cancelled)
        XCTAssertEqual((b.failures.first as? URLError)?.code, .cancelled)
    }

    func testASecondStartOfARunningDownloadJoinsIt() throws {
        let hold = Hold<FileTransferResult<URL>>()
        transport.onDownload = { _, _ in await hold.wait() }
        let url = "https://files.example/\(UUID().uuidString)/report.pdf"
        let attachment = makeAttachment(tid: 0, url: url)
        let (first, a) = makeTask(attachment, .download)
        session.download(attachment: attachment, taskInfo: first)
        waitUntil { hold.isWaiting }
        let (second, b) = makeTask(makeAttachment(tid: 0, url: url), .download)
        session.download(attachment: second.attachment, taskInfo: second)

        hold.open(.success(try XCTUnwrap(transport.downloads.first).destinationFile))
        waitUntil { a.isOver && b.isOver }

        XCTAssertEqual(transport.downloads.count, 1)
        XCTAssertEqual(a.successes.count, 1)
        XCTAssertEqual(b.successes.count, 1)
        XCTAssertEqual(b.locations, a.locations, "both get the one file")
    }
}

// MARK: - Coverage: the remaining branches of the router

extension TransportDataSessionTests {

    func testAStartOfAPausedUploadJoinsAndResumesIt() throws {
        transport.pausesInPlace(true)
        let hold = Hold<FileTransferResult<FileUploadResult>>()
        transport.onUpload = { _, _ in await hold.wait() }
        let (first, a, attachment) = try upload(tid: 7)
        waitUntil { hold.isWaiting }
        first.stop()
        waitUntil { self.transport.paused.count == 1 }

        let (second, b) = makeTask(attachment)
        session.upload(attachment: attachment, taskInfo: second)
        waitUntil { self.transport.resumed.count == 1 }
        hold.open(.success(FileUploadResult(url: "JOINED")))
        waitUntil { a.isOver && b.isOver }

        XCTAssertEqual(uploads(of: "upload-7"), 1)
        XCTAssertEqual(b.successes, ["JOINED"])
    }

    func testAStartOfAPausedDownloadJoinsAndResumesIt() throws {
        transport.pausesInPlace(true)
        let hold = Hold<FileTransferResult<URL>>()
        transport.onDownload = { _, _ in await hold.wait() }
        let url = "https://files.example/\(UUID().uuidString)/report.pdf"
        let (first, a) = makeTask(makeAttachment(tid: 0, url: url), .download)
        session.download(attachment: first.attachment, taskInfo: first)
        waitUntil { hold.isWaiting }
        first.stop()
        waitUntil { self.transport.paused.count == 1 }

        let (second, b) = makeTask(makeAttachment(tid: 0, url: url), .download)
        session.download(attachment: second.attachment, taskInfo: second)
        waitUntil { self.transport.resumed.count == 1 }
        hold.open(.success(try XCTUnwrap(transport.downloads.first).destinationFile))
        waitUntil { a.isOver && b.isOver }

        XCTAssertEqual(transport.downloads.count, 1)
    }

    func testAnUploadWithoutATidStillUploads() throws {
        let (_, recorder, _) = try upload(tid: 0)
        waitUntil { recorder.isOver }
        XCTAssertEqual(recorder.successes, ["REMOTE"])
        XCTAssertTrue(transport.uploads.first?.operationId.hasPrefix("upload-") == true)
    }


    func testAnUploadPausedAsItTakesTheSlotGivesTheSlotUp() throws {
        var armed = true
        session.willBeginUpload = { taskInfo in
            guard armed else { return }
            armed = false
            taskInfo.stop()
        }
        let (taskInfo, recorder, _) = try upload(tid: 8)
        settle()
        XCTAssertTrue(transport.uploads.isEmpty, "paused before it started")
        XCTAssertFalse(recorder.isOver)

        taskInfo.resume()
        waitUntil { recorder.isOver }
        XCTAssertEqual(recorder.successes, ["REMOTE"])
    }

    func testADownloadCancelledAsItRestartsIsNotStarted() throws {
        transport.pausesInPlace(false)
        let hold = Hold<FileTransferResult<URL>>(onCancel: .interrupted(CancellationError()))
        transport.onDownload = { _, _ in await hold.wait() }
        var starts = 0
        session.willStartDownload = { taskInfo in
            starts += 1
            if starts == 2 { taskInfo.cancel() }
        }
        let (taskInfo, recorder) = download()
        waitUntil { hold.isWaiting }
        taskInfo.stop()
        taskInfo.resume()
        waitUntil { recorder.isOver }

        XCTAssertEqual(transport.downloads.count, 1, "the restart never went out")
        XCTAssertEqual((recorder.failures.first as? URLError)?.code, .cancelled)
    }

    func testAnEmptyPreparedFileIsSent() throws {
        let empty = directory.appendingPathComponent("empty.bin")
        try Data().write(to: empty)
        session.preparation = { _, _ in PreparedUploadFile(file: empty, isStaged: false) }
        let (_, recorder, _) = try upload(tid: 9)
        waitUntil { recorder.isOver }
        XCTAssertEqual(transport.uploads.last?.sourceFile, empty)
    }

    func testAPreparedFileThatIsGoneFailsWithoutSending() throws {
        let gone = directory.appendingPathComponent("gone.bin")
        session.preparation = { _, _ in PreparedUploadFile(file: gone, isStaged: false) }
        let (_, recorder, _) = try upload(tid: 9)
        waitUntil { recorder.isOver }
        XCTAssertTrue(transport.uploads.isEmpty)
        guard case .missingSourceFile = recorder.failures.first as? TransportDataSessionError else {
            return XCTFail("expected missingSourceFile, got \(recorder.failures)")
        }
    }



    func testAMissingSourceFailsWithoutSending() throws {
        let missing = directory.appendingPathComponent("deleted.m4a").path
        let attachment = makeAttachment(tid: 12, type: "voice", filePath: missing)
        let (taskInfo, recorder) = makeTask(attachment)
        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { recorder.isOver }
        XCTAssertTrue(transport.uploads.isEmpty)
        XCTAssertTrue(recorder.failures.first as? TransportDataSessionError != nil)
    }

    func testAnAppExtensionResizesWithLessMemory() throws {
        session.appExtension = true
        let attachment = makeAttachment(tid: 13, type: "image", name: "photo.jpg", filePath: try image().path)
        let (taskInfo, recorder) = makeTask(attachment)
        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { recorder.isOver }

        let sent = try XCTUnwrap(transport.uploads.first?.sourceFile)
        XCTAssertTrue(sent.path.contains("staging"), "resized and staged")
    }

    func testAStagingFailureFailsTheUpload() throws {
        // A file where the staging folder goes: nothing can be staged.
        try Data("x".utf8).write(to: directory.appendingPathComponent("staging"))
        let attachment = makeAttachment(tid: 14, type: "image", name: "photo.jpg", filePath: try image().path)
        let (taskInfo, recorder) = makeTask(attachment)
        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { recorder.isOver }

        XCTAssertEqual(recorder.failures.count, 1)
        XCTAssertTrue(transport.uploads.isEmpty)
    }

    func testReportingOnlyEndsATaskWithAnEnding() throws {
        let (taskInfo, recorder) = makeTask(makeAttachment(tid: 15))
        session.report(taskInfo, .updateProgress(0.5))
        session.report(taskInfo, .updateLocalFileURL(directory, nil))
        XCTAssertTrue(recorder.events.isEmpty)
        let url = try XCTUnwrap(URL(string: "https://files.example/a"))
        session.report(taskInfo, .successURL(url))
        XCTAssertTrue(taskInfo.isTerminal)
        session.report(taskInfo, .failure(nil))
        XCTAssertEqual(recorder.events.count, 1, "an ended task is left alone")
    }

    func testEventDescriptionsCarryNoURL() throws {
        let url = try XCTUnwrap(URL(string: "https://files.example/a?Signature=SECRET"))
        XCTAssertEqual(TransportDataSession.describe(.updateLocalFileURL(url, nil)), "updateLocalFileURL")
        XCTAssertFalse(TransportDataSession.describe(.successURI(url.absoluteString)).contains("SECRET"))
        XCTAssertFalse(TransportDataSession.describe(.successURL(url)).contains("SECRET"))
    }

    func testStagingFolderNamesAreThePercentEncodedOperationId() {
        for id in ["upload-1", "upload-\(UUID().uuidString)", "download-url/a?b=c d", "upload-é✓🙂", ""] {
            XCTAssertEqual(UploadStaging.folderName(id), id.addingPercentEncoding(withAllowedCharacters: .alphanumerics), id)
        }
    }

    func testAnImageWithoutANameIsStagedUnderAGeneratedOne() throws {
        let attachment = makeAttachment(tid: 16, type: "image", name: nil, filePath: try image().path)
        let (taskInfo, recorder) = makeTask(attachment)
        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { recorder.isOver }
        XCTAssertEqual(recorder.successes, ["REMOTE"])
    }

    func testAStagingFolderHoldingOnlyAFolderIsNotReused() throws {
        let folder = directory.appendingPathComponent("staging/upload%2D17/sub", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let attachment = makeAttachment(tid: 17, type: "image", name: "p.jpg", filePath: try image().path)
        let (taskInfo, recorder) = makeTask(attachment)
        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { recorder.isOver }
        XCTAssertEqual(transport.uploads.first?.sourceFile.lastPathComponent, "p.jpg", "resized afresh")
    }

    func testFileEventsBeforeTheHooksAreLogged() {
        let attachment = makeAttachment(tid: 18)
        let message = ChatMessage(id: 1, channelId: 1, attachments: [attachment], user: ChatUser(id: "u"))
        let taskInfo = SCTDataSessionTaskInfo(transferType: .upload, message: message, attachment: attachment, checksumProvider: ScriptedChecksumProvider())
        taskInfo.updateLocalFileLocation(newPath: "/tmp/a")
        taskInfo.updateLocalFileLocation(newLocation: URL(fileURLWithPath: "/tmp/b"))
        XCTAssertEqual(attachment.filePath, "/tmp/b")
    }

    func testMimeTypes() {
        let staged = PreparedUploadFile(file: URL(fileURLWithPath: "/x/photo.jpg"), isStaged: true)
        let inPlace = PreparedUploadFile(file: URL(fileURLWithPath: "/x/plain-1.bin"), isStaged: false)
        XCTAssertEqual(UploadCoordinator.mimeType(of: staged, fileName: "photo.heic"), "image/jpeg", "a staged file is typed by its own bytes")
        XCTAssertEqual(UploadCoordinator.mimeType(of: inPlace, fileName: "report.pdf"), "application/pdf")
        XCTAssertEqual(UploadCoordinator.mimeType(of: inPlace, fileName: "report"), UploadCoordinator.mimeType(of: inPlace, fileName: "plain-1.bin"))
    }
}

private extension ScriptedTransport {
    func pausesInPlace(_ inPlace: Bool) {
        onPause = { _ in inPlace }
        onResume = { _ in inPlace }
    }
}

// MARK: - Logs

/// Every log line written while it is installed.
private final class LogCapture {
    private let lock = NSLock()
    private var _lines = [String]()
    private let previousLevel = Components.logger.logLevel
    private let previousCallback = Components.logger.onLog

    var lines: [String] { lock.lock(); defer { lock.unlock() }; return _lines }

    init() {
        Components.logger.setLogLevel(.verbose) { [weak self] message, _, _, _, _, _ in
            guard let self else { return }
            self.lock.lock(); self._lines.append(message); self.lock.unlock()
        }
    }

    func stop() {
        Components.logger.setLogLevel(previousLevel, callBack: previousCallback)
    }
}

extension TransportDataSessionTests {

    /// A provider's entries (a key) on an upload and a download, and failures carrying signed
    /// URLs, logged at the most verbose level: neither the entry values nor a URL's query reach
    /// a log line, while the terminal outcomes do.
    func testTransferLogsCarryNoKeyAndNoSignedQuery() throws {
        let capture = LogCapture()
        defer { capture.stop() }
        let key = "KEY-\(UUID().uuidString)"
        let signed = "https://cdn.example.com/\(UUID().uuidString)/report.pdf?Signature=SIG-SECRET&Key-Pair-Id=PAIR"

        transport.onPrepare = { _ in ["sceyt.enc": key] }
        transport.onUpload = { _, _ in .success(FileUploadResult(url: signed)) }
        let (_, uploaded, _) = try upload(tid: 11)
        waitUntil { uploaded.isOver }

        transport.onUpload = { _, _ in
            .failure(URLError(.notConnectedToInternet, userInfo: [NSURLErrorFailingURLStringErrorKey: signed]))
        }
        let (_, failed, _) = try upload(tid: 12)
        waitUntil { failed.isOver }

        transport.onDownload = { request, progress in
            progress(0.3)
            progress(0.8)
            return .success(request.destinationFile)
        }
        let attachment = makeAttachment(tid: 0, url: signed, metadata: "{\"sceyt.enc\":\"\(key)\"}")
        let (taskInfo, downloaded) = makeTask(attachment, .download)
        session.download(attachment: attachment, taskInfo: taskInfo)
        waitUntil { downloaded.isOver }

        let lines = capture.lines
        XCTAssertTrue(lines.contains { $0.contains("[Transfer] xfer=upload-11 ") && $0.contains("finished (success)") })
        XCTAssertTrue(lines.contains { $0.contains("[Transfer] xfer=upload-12 ") && $0.contains("finished (failure)") })
        XCTAssertTrue(lines.contains { $0.contains("[Transfer] xfer=download-url") && $0.contains("finished (") })
        // A session's startup purge (of any session made by these tests) is about no transfer.
        let transferLines = lines.filter { ($0.contains("[Transfer]") || $0.contains("[Encryption]")) && !$0.contains(" purge") }
        XCTAssertTrue(transferLines.allSatisfy { $0.contains("xfer=") }, "every line names its transfer: \(transferLines.filter { !$0.contains("xfer=") })")
        XCTAssertTrue(lines.filter { $0.hasPrefix("[ERROR]") }.isEmpty, "the session reports failures at debug; the end of the transfer reports them once: \(lines.filter { $0.hasPrefix("[ERROR]") })")
        for secret in [key, "SIG-SECRET", "Key-Pair-Id"] {
            let leaking = lines.filter { $0.contains(secret) }
            XCTAssertTrue(leaking.isEmpty, "\(secret) reached the logs: \(leaking)")
        }
    }
}

// MARK: - Download contract (doc §4, §10)

extension TransportDataSessionTests {

    func testDownloadHeadersOfTheSessionReachTheTransport() throws {
        session.headers = ["X-Chat-Token": "t", "X-Message-Id": "7"]
        transport.onDownload = { request, _ in .success(request.destinationFile) }
        let (_, recorder) = download()
        waitUntil { recorder.isOver }
        XCTAssertEqual(transport.downloads.first?.headers, ["X-Chat-Token": "t", "X-Message-Id": "7"])
    }


}

// MARK: - Audit fixes: checksum after a cancel, checksum timeout, destination via fileStore

extension TransportDataSessionTests {

    /// A checksum hit that answers after the user cancelled keeps the cancel: no success, and
    /// the attachment gets no url it was never sent with.
    func testAChecksumHitAfterACancelStaysACancel() throws {
        session.checksums = true
        let answer = Locked<((Result<String?, Error>) -> Void)?>(nil)
        ScriptedChecksumProvider.answer = { _, completion in answer.wrapped = completion }
        let (taskInfo, recorder, attachment) = try upload()
        waitUntil { answer.wrapped != nil }

        taskInfo.cancel()
        waitUntil { recorder.isOver }
        answer.wrapped?(.success("STORED-LATE"))
        settle()

        XCTAssertTrue(recorder.successes.isEmpty, "a cancel is never turned into a success")
        XCTAssertNotEqual(attachment.url, "STORED-LATE")
        XCTAssertTrue(transport.uploads.isEmpty)
    }

    func testAChecksumFailureAfterACancelIsNotReportedAgain() throws {
        session.checksums = true
        let answer = Locked<((Result<String?, Error>) -> Void)?>(nil)
        ScriptedChecksumProvider.answer = { _, completion in answer.wrapped = completion }
        let (taskInfo, recorder, _) = try upload()
        waitUntil { answer.wrapped != nil }

        taskInfo.cancel()
        waitUntil { recorder.isOver }
        answer.wrapped?(.failure(Failure(name: "late")))
        settle()

        XCTAssertEqual(recorder.failures.count, 1)
        XCTAssertNil(recorder.failures.first as? Failure, "still the cancel, not the late failure")
    }

    /// A checksum provider that never answers does not hold the upload slot: after the
    /// timeout the file is uploaded, and a late answer changes nothing.
    func testAChecksumThatNeverAnswersTimesOutAndUploads() throws {
        session.checksums = true
        session.checksumTimeout = 0.2
        let answer = Locked<((Result<String?, Error>) -> Void)?>(nil)
        ScriptedChecksumProvider.answer = { _, completion in answer.wrapped = completion }
        let (_, recorder, _) = try upload()
        waitUntil { recorder.isOver }

        XCTAssertEqual(transport.uploads.count, 1, "uploaded once the wait timed out")
        XCTAssertEqual(recorder.successes, ["REMOTE"])
        answer.wrapped?(.success("STORED-LATE"))
        settle()
        XCTAssertEqual(recorder.successes, ["REMOTE"], "the late answer is ignored")
    }

    /// Cancelled while the checksum is out: the attempt stops at once, without the answer.
    func testACancelDuringAChecksumThatNeverAnswersFreesTheSlot() throws {
        session.checksums = true
        let answer = Locked<((Result<String?, Error>) -> Void)?>(nil)
        ScriptedChecksumProvider.answer = { attachment, completion in
            if attachment.tid == 1 { answer.wrapped = completion } else { completion(.success(nil)) }
        }
        let (first, firstRecorder, _) = try upload(tid: 1)
        waitUntil { answer.wrapped != nil }
        let (_, second, _) = try upload(tid: 2)

        first.cancel()
        waitUntil { firstRecorder.isOver && second.isOver }
        XCTAssertEqual(transport.uploads.map(\.operationId), ["upload-2"], "the next upload got the slot")
    }

    func testTheDownloadDestinationComesFromTheFileStore() throws {
        let plain = TransportDataSession(provider: transport)
        let store = DestinationStore(root: directory)
        plain.fileStore = store
        let destination = try XCTUnwrap(plain.downloadDestination(for: makeAttachment(name: "a.pdf", url: "https://files.example/TRANSFER/a.pdf")))
        XCTAssertEqual(destination, directory.appendingPathComponent("store/TRANSFER/a.pdf"))
    }
}

/// A file store that keeps downloads under its own root.
private struct DestinationStore: AttachmentFileStore {
    let root: URL
    func store(fileAt path: String, transferId: String, fileName: String?) -> String { path }
    func remove(fileAt path: String) {}
    func updateThumbnailPath(transferId: String, filePath: String) {}
    func downloadDestination(transferId: String, fileName: String?) -> URL {
        root.appendingPathComponent("store/\(transferId)/\(fileName ?? "file")")
    }
}

final class AttachmentFileStoreResultTests: XCTestCase {
    func testAStoresAnswerIsReadAsAThrow() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let stored = folder.appendingPathComponent("stored").path
        try Data("x".utf8).write(to: URL(fileURLWithPath: stored))

        XCTAssertEqual(try AttachmentFileStoreResult.check(stored, source: "/source"), stored)
        XCTAssertThrowsError(try AttachmentFileStoreResult.check("/source", source: "/source")) {
            XCTAssertEqual($0 as? AttachmentFileStoreError, .sourceReturned)
        }
        XCTAssertThrowsError(try AttachmentFileStoreResult.check(folder.appendingPathComponent("none").path, source: "/source")) {
            XCTAssertEqual($0 as? AttachmentFileStoreError, .nothingStored)
        }
    }
}

extension TransportDataSessionTests {
    /// A checksum failure that answers after the wait timed out does not fail the upload that
    /// went ahead without it.
    func testAChecksumFailureAfterTheTimeoutDoesNotFailTheUpload() throws {
        session.checksums = true
        session.checksumTimeout = 0.1
        let answer = Locked<((Result<String?, Error>) -> Void)?>(nil)
        ScriptedChecksumProvider.answer = { _, completion in answer.wrapped = completion }
        let hold = Hold<FileTransferResult<FileUploadResult>>(onCancel: .interrupted(CancellationError()))
        transport.onUpload = { _, _ in await hold.wait() }
        let (_, recorder, _) = try upload()
        waitUntil { hold.isWaiting }

        answer.wrapped?(.failure(Failure(name: "late")))
        settle()
        XCTAssertFalse(recorder.isOver, "the upload is still running")

        hold.open(.success(FileUploadResult(url: "REMOTE")))
        waitUntil { recorder.isOver }
        XCTAssertEqual(recorder.successes, ["REMOTE"])
    }
}

// MARK: - Provider prepare step (spec: FileTransferProvider.prepareUpload)

extension TransportDataSessionTests {

    /// The entries `prepareUpload` returns are saved before the upload starts, and the upload
    /// gets them merged into its metadata.
    func testPreparedEntriesAreSavedBeforeTheUploadAndReachIt() throws {
        let order = Locked([String]())
        transport.onPrepare = { _ in
            order.mutate { $0.append("prepare") }
            return ["sceyt.enc": "TOKEN", "sceyt.other": "x"]
        }
        transport.onUpload = { request, _ in
            order.mutate { $0.append("upload \(request.metadata["sceyt.enc"] ?? "-")") }
            return .success(FileUploadResult(url: "REF"))
        }
        let (taskInfo, recorder, _) = try upload(metadata: #"{"szw":3,"dur":5}"#)
        let saves = savedEntries
        waitUntil { recorder.isOver }

        XCTAssertEqual(recorder.successes, ["REF"])
        XCTAssertEqual(saves.wrapped, [["sceyt.enc": "TOKEN", "sceyt.other": "x"]])
        XCTAssertEqual(order.wrapped, ["prepare", "upload TOKEN"])
        XCTAssertEqual(transport.uploads.first?.metadata, ["sceyt.enc": "TOKEN", "sceyt.other": "x"])
        XCTAssertTrue(taskInfo.hasProviderEntries)
    }

    /// `prepareUpload` sees the attachment's saved entries (an earlier attempt's): only the
    /// string ones, the media numbers are not the provider's.
    func testPrepareSeesTheSavedEntries() throws {
        transport.onPrepare = { _ in nil }
        let (_, recorder, _) = try upload(metadata: #"{"szw":3,"tmb":"hash","sceyt.enc":"SAVED"}"#)
        waitUntil { recorder.isOver }

        XCTAssertEqual(transport.prepared.first?.metadata, ["tmb": "hash", "sceyt.enc": "SAVED"])
        XCTAssertTrue(savedEntries.wrapped.isEmpty, "nil saves nothing")
        XCTAssertEqual(transport.uploads.first?.metadata, ["tmb": "hash", "sceyt.enc": "SAVED"])
    }

    /// A throwing `prepareUpload` fails the attempt: nothing is uploaded.
    func testAPrepareThatThrowsFailsWithoutUploading() throws {
        transport.onPrepare = { _ in throw Failure(name: "no slot") }
        let (_, recorder, _) = try upload()
        waitUntil { recorder.isOver }

        XCTAssertEqual(recorder.failures.first as? Failure, Failure(name: "no slot"))
        XCTAssertTrue(transport.uploads.isEmpty)
    }

    /// Entries that could not be saved fail the attempt: the message would go out without them.
    func testEntriesThatCannotBeSavedFailWithoutUploading() throws {
        saveError = Failure(name: "db")
        transport.onPrepare = { _ in ["sceyt.enc": "TOKEN"] }
        let (_, recorder, _) = try upload()
        waitUntil { recorder.isOver }

        XCTAssertEqual(recorder.failures.first as? Failure, Failure(name: "db"))
        XCTAssertTrue(transport.uploads.isEmpty)
    }

    /// A retry keeps the entries an earlier attempt saved (prepare returns nil): it still goes
    /// with provider entries, and its metrics say so.
    func testAnUploadWithSavedEntriesStillHasProviderEntries() throws {
        transport.onPrepare = { _ in nil }
        let (taskInfo, recorder, _) = try upload(metadata: #"{"tmb":"h","sceyt.enc":"SAVED"}"#)
        waitUntil { recorder.isOver }
        XCTAssertTrue(taskInfo.hasProviderEntries)

        let (plain, plainRecorder, _) = try upload(tid: 2, metadata: #"{"tmb":"h","szw":3}"#)
        waitUntil { plainRecorder.isOver }
        XCTAssertFalse(plain.hasProviderEntries, "UIKit's own keys are no provider's")
    }

    /// Cancelling a video abandons its preview's upload as well as its own.
    func testCancellingAVideoAbandonsItsPreview() {
        let video = makeAttachment(tid: 9, type: "video", filePath: "/tmp/v.mp4")
        session.cancel(attachments: [video])
        XCTAssertEqual(transport.cancelled, ["upload-9", "upload-9-thumbnail"])
    }

    /// Every attempt prepares again (a retry finds the entries the first one saved).
    func testEveryAttemptPrepares() throws {
        transport.onUpload = { _, _ in .failure(Failure(name: "500")) }
        let (_, first, _) = try upload(tid: 5)
        waitUntil { first.isOver }
        transport.onUpload = { _, _ in .success(FileUploadResult(url: "REF")) }
        let (_, second, _) = try upload(tid: 5)
        waitUntil { second.isOver }

        XCTAssertEqual(transport.prepared.map(\.operationId), ["upload-5", "upload-5"])
    }
}
