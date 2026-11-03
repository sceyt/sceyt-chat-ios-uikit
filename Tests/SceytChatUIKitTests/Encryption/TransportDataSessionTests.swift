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

/// A transport each test scripts. Records every call.
private final class ScriptedTransport: FileTransferTransport {
    var onUpload: (FileUploadRequest, @escaping (Double) -> Void) async -> FileTransferResult<FileUploadResult> = { _, _ in
        .success(FileUploadResult(remoteReference: "REMOTE"))
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
}

/// The router under test, storing everything under one temporary directory.
private final class RouterSession: TransportDataSession {
    let root: URL
    var checksums = false
    var hasDestination = true
    /// Replaces the default preparation when set.
    var preparation: ((ChatMessage.Attachment, String) async throws -> PreparedUploadFile)?

    private let lock = NSLock()
    private var _removed = [String]()
    private var _thumbnailPaths = [String]()
    private var _stored = [String]()
    var removed: [String] { lock.lock(); defer { lock.unlock() }; return _removed }
    var thumbnailPaths: [String] { lock.lock(); defer { lock.unlock() }; return _thumbnailPaths }
    var stored: [String] { lock.lock(); defer { lock.unlock() }; return _stored }

    init(transport: FileTransferTransport, root: URL) {
        self.root = root
        super.init(transport: transport)
    }

    override var checksumsBeforeUpload: Bool { checksums }
    override var stagingDirectory: URL { root.appendingPathComponent("staging", isDirectory: true) }

    override func storeFile(atPath path: String, transferId: String, fileName: String?) -> String {
        lock.lock(); _stored.append(path); lock.unlock()
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
    static var requirements = [EncryptionRequirement]()

    override func startChecksum(
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        encryption: EncryptionRequirement,
        completion: @escaping ((Result<String?, Error>) -> Void)
    ) {
        Self.requirements.append(encryption)
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
    private var originalChecksumProvider: ChannelMessageChecksumProvider.Type!
    private var originalVideoProcessor: VideoProcessor.Type!
    private var originalDatabase: Database!

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalDatabase = DataProvider.database
        DataProvider.database = MockDatabase()
        originalChecksumProvider = Components.channelMessageChecksumProvider
        originalVideoProcessor = Components.videoProcessor
        Components.channelMessageChecksumProvider = ScriptedChecksumProvider.self
        ScriptedChecksumProvider.answer = { _, completion in completion(.success(nil)) }
        ScriptedChecksumProvider.requirements = []
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("router-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        transport = ScriptedTransport()
        session = RouterSession(transport: transport, root: directory)
    }

    override func tearDownWithError() throws {
        Components.channelMessageChecksumProvider = originalChecksumProvider
        Components.videoProcessor = originalVideoProcessor
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
        url: String? = nil
    ) -> ChatMessage.Attachment {
        .init(id: 0, tid: tid, messageId: 1, userId: "user", url: url, filePath: filePath, type: type, name: name, metadata: nil, uploadedFileSize: 0, createdAt: Date())
    }

    private func makeTask(
        _ attachment: ChatMessage.Attachment,
        _ type: SCTDataSessionTaskInfo.TransferType = .upload,
        encryption: EncryptionRequirement = .none,
        downloadEncryption: AttachmentEncryption? = nil
    ) -> (SCTDataSessionTaskInfo, Recorder) {
        let message = ChatMessage(id: 1, channelId: 1, attachments: [attachment], user: ChatUser(id: "u"))
        let taskInfo = SCTDataSessionTaskInfo(transferType: type, message: message, attachment: attachment)
        taskInfo.encryption = encryption
        taskInfo.downloadEncryption = downloadEncryption
        return (taskInfo, Recorder(taskInfo))
    }

    /// Starts the upload of a new file attachment.
    @discardableResult
    private func upload(tid: Int64 = 1, type: String = "voice", encryption: EncryptionRequirement = .none) throws -> (SCTDataSessionTaskInfo, Recorder, ChatMessage.Attachment) {
        let attachment = makeAttachment(tid: tid, type: type, filePath: try file().path)
        let (taskInfo, recorder) = makeTask(attachment, encryption: encryption)
        session.upload(attachment: attachment, taskInfo: taskInfo)
        return (taskInfo, recorder, attachment)
    }

    private func download(encryption: EncryptionRequirement = .none, downloadEncryption: AttachmentEncryption? = nil) -> (SCTDataSessionTaskInfo, Recorder) {
        let attachment = makeAttachment(tid: 0, url: "https://files.example/\(UUID().uuidString)/report.pdf")
        let (taskInfo, recorder) = makeTask(attachment, .download, encryption: encryption, downloadEncryption: downloadEncryption)
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
        let plain = TransportDataSession(transport: transport)
        XCTAssertTrue(plain.supportsAttachmentEncryption)
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
        let plain = TransportDataSession(transport: transport)
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
            [.modificationDate: Date().addingTimeInterval(-TransportDataSession.staleStagingAge - 60)],
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
            return .success(FileUploadResult(remoteReference: "REF"))
        }

        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { recorder.isOver }

        let request = try XCTUnwrap(transport.uploads.first)
        XCTAssertEqual(request.type, .plain)
        XCTAssertEqual(request.operationId, "upload-1")
        XCTAssertEqual(request.fileName, "notes.pdf", "the file's own name when the attachment has none")
        XCTAssertEqual(request.mimeType, "application/pdf")
        XCTAssertEqual(request.sourceFile.path, source.path, "a file is sent in place, as SCTSession did")
        XCTAssertTrue(session.stored.isEmpty, "never moved into storage")
        XCTAssertTrue(recorder.locations.isEmpty, "the attachment keeps its own file")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue((request.context as? AttachmentTransferContext)?.attachment === attachment)
        XCTAssertEqual(recorder.progress, [0.01, 0.25, 0.75])
        XCTAssertEqual(recorder.successes, ["REF"])
        XCTAssertNil(taskInfo.uploadedEncryption)
        XCTAssertNil(taskInfo.uploadedPlaintextSize)
    }

    /// Every attempt of a non-media file sends the attachment's own file: nothing is moved,
    /// and no folder is left behind per retry (finding #10).
    func testRetriesOfANonMediaFileSendItInPlaceAndLeaveNoFolders() throws {
        let plain = TransportDataSession(transport: transport)
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

    func testEncryptedUploadRecordsTheEncryptionAndThePlaintextSize() throws {
        let info = EncryptedFileInfo(algorithm: "alg", attachmentId: "id", key: "key")
        transport.onUpload = { request, _ in
            XCTAssertEqual(request.type, .encrypted)
            return .success(FileUploadResult(remoteReference: "ENC", encryptionInfo: info))
        }

        let (taskInfo, recorder, _) = try upload(encryption: .required)
        waitUntil { recorder.isOver }

        XCTAssertEqual(recorder.successes, ["ENC"])
        XCTAssertEqual(taskInfo.uploadedEncryption, info)
        XCTAssertEqual(taskInfo.uploadedPlaintextSize, 100)
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
            request.operationId == "upload-1" ? await first.wait() : .success(FileUploadResult(remoteReference: "SECOND"))
        }
        let (_, a, _) = try upload(tid: 1)
        let (_, b, _) = try upload(tid: 2)

        waitUntil { first.isWaiting }
        settle()
        XCTAssertEqual(transport.uploads.map(\.operationId), ["upload-1"], "the second waits for the slot")

        first.open(.success(FileUploadResult(remoteReference: "FIRST")))
        waitUntil { a.isOver && b.isOver }
        XCTAssertEqual(transport.uploads.map(\.operationId), ["upload-1", "upload-2"])
        XCTAssertEqual(b.successes, ["SECOND"])
    }

    func testProgressAfterTheEndIsIgnored() throws {
        var report: ((Double) -> Void)?
        transport.onUpload = { _, progress in
            report = progress
            return .success(FileUploadResult(remoteReference: "R"))
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
            return .success(FileUploadResult(remoteReference: "IMG"))
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

    func testAnImageThatCannotBeDecodedIsSentAsIs() throws {
        let notAnImage = try file()
        let attachment = makeAttachment(type: "image", name: "broken.jpg", filePath: notAnImage.path)
        let (taskInfo, recorder) = makeTask(attachment)

        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { recorder.isOver }

        XCTAssertEqual(transport.uploads.first?.sourceFile.path, notAnImage.path)
        XCTAssertTrue(session.removed.isEmpty)
    }

    func testEncryptedSizeFallsBackToTheAttachmentWhenTheStagedFileIsGone() throws {
        let original = try image()
        let info = EncryptedFileInfo(algorithm: "alg", attachmentId: "id", key: "key")
        transport.onUpload = { request, _ in
            try? FileManager.default.removeItem(at: request.sourceFile)
            return .success(FileUploadResult(remoteReference: "ENC", encryptionInfo: info))
        }
        let attachment = makeAttachment(type: "image", name: "photo.jpg", filePath: original.path)
        let (taskInfo, recorder) = makeTask(attachment, encryption: .required)

        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { recorder.isOver }

        XCTAssertEqual(recorder.successes, ["ENC"])
        XCTAssertTrue(session.stored.isEmpty, "nothing to adopt")
        XCTAssertEqual(attachment.filePath, original.path)
        XCTAssertEqual(taskInfo.uploadedPlaintextSize, TransportDataSession.fileSize(original))
    }

    func testAVideoIsExportedAndStaged() throws {
        let exported = try file(name: "exported.mp4")
        Components.videoProcessor = ScriptedVideoProcessor.self
        ScriptedVideoProcessor.result = { _ in .success(exported) }

        let (_, recorder, attachment) = try upload(type: "video")
        waitUntil { recorder.isOver }

        let sent = try XCTUnwrap(transport.uploads.first?.sourceFile)
        XCTAssertEqual(sent.lastPathComponent, "exported.mp4")
        XCTAssertTrue(sent.path.contains("/staging/"))
        XCTAssertEqual(recorder.progress.first, 0.01)
        XCTAssertNotEqual(attachment.filePath, exported.path)
        XCTAssertTrue(session.removed.isEmpty, "only an image's original is removed")
    }

    func testAVideoThatCannotBeExportedIsSentAsIs() throws {
        Components.videoProcessor = ScriptedVideoProcessor.self
        ScriptedVideoProcessor.result = { _ in .failure(CocoaError(.featureUnsupported)) }

        let (_, recorder, attachment) = try upload(type: "video")
        waitUntil { recorder.isOver }

        XCTAssertEqual(transport.uploads.first?.sourceFile.path, attachment.filePath)
    }

    // MARK: - Checksum

    func testAChecksumHitEndsTheUploadWithoutTheTransport() throws {
        session.checksums = true
        ScriptedChecksumProvider.answer = { attachment, completion in completion(.success(attachment.tid == 1 ? "STORED" : nil)) }

        let (_, recorder, _) = try upload(encryption: .required)
        let (_, next, _) = try upload(tid: 2)
        waitUntil { recorder.isOver && next.isOver }

        XCTAssertEqual(recorder.successes, ["STORED"])
        XCTAssertEqual(transport.uploads.map(\.operationId), ["upload-2"], "the slot was freed")
        XCTAssertEqual(ScriptedChecksumProvider.requirements, [.required, .none], "the checksum only reuses objects of the same kind")
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
        var answer: ((Result<String?, Error>) -> Void)?
        ScriptedChecksumProvider.answer = { _, completion in answer = completion }
        let (taskInfo, recorder, _) = try upload()
        waitUntil { answer != nil }

        taskInfo.stop()
        answer?(.success(nil))
        settle()

        XCTAssertTrue(transport.uploads.isEmpty)
        XCTAssertFalse(recorder.isOver)
    }

    func testAChecksumOfAnEarlierAttemptIsIgnored() throws {
        session.checksums = true
        var answers = [(Result<String?, Error>) -> Void]()
        ScriptedChecksumProvider.answer = { _, completion in answers.append(completion) }
        let (taskInfo, recorder, _) = try upload()
        waitUntil { answers.count == 1 }

        taskInfo.stop()
        taskInfo.resume()
        waitUntil { answers.count == 2 }
        answers[0](.success(nil))
        settle()
        XCTAssertTrue(transport.uploads.isEmpty, "the first attempt's miss does not upload")

        answers[1](.success(nil))
        waitUntil { recorder.isOver }
        XCTAssertEqual(transport.uploads.count, 1)
        XCTAssertEqual(recorder.successes, ["REMOTE"])
    }

    func testAChecksumHitOfAnEarlierAttemptEndsTheTask() throws {
        session.checksums = true
        var answers = [(Result<String?, Error>) -> Void]()
        ScriptedChecksumProvider.answer = { attachment, completion in
            if attachment.tid == 1 { answers.append(completion) } else { completion(.success(nil)) }
        }
        let (taskInfo, recorder, _) = try upload()
        waitUntil { answers.count == 1 }
        taskInfo.stop()
        taskInfo.resume()
        waitUntil { answers.count == 2 }

        // The earlier attempt's checksum finds the object: the task ends with it, and the
        // current attempt then has nothing left to send.
        answers[0](.success("STORED"))
        answers[1](.success(nil))
        let (_, next, _) = try upload(tid: 2)
        waitUntil { next.isOver }

        XCTAssertEqual(recorder.successes, ["STORED"])
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
        hold.open(.success(FileUploadResult(remoteReference: "LATE")))
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
            request.operationId == "upload-1" ? await first.wait() : .success(FileUploadResult(remoteReference: "SECOND"))
        }
        let (_, a, _) = try upload(tid: 1)
        let (queued, b, _) = try upload(tid: 2)
        waitUntil { first.isWaiting }

        queued.stop()
        XCTAssertTrue(transport.paused.isEmpty, "nothing is running to pause")
        first.open(.success(FileUploadResult(remoteReference: "FIRST")))
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
            return attempts == 1 ? await first.wait() : .success(FileUploadResult(remoteReference: "SECOND"))
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
        first.open(.success(FileUploadResult(remoteReference: "FIRST")))
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
            return attempts == 1 ? await first.wait() : .success(FileUploadResult(remoteReference: "SECOND"))
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
        first.open(.success(FileUploadResult(remoteReference: "LANDED")))
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
            return attemptsOfA == 1 ? await a1.wait() : .success(FileUploadResult(remoteReference: "A2"))
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

        b.open(.success(FileUploadResult(remoteReference: "B")))
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
        holds[0].open(.success(FileUploadResult(remoteReference: "STALE")))
        settle()
        XCTAssertEqual(recorder.progress.last, 0.2)
        XCTAssertFalse(recorder.progress.contains(0.6))
        XCTAssertTrue(recorder.successes.isEmpty, "the stale attempt's result is dropped")

        holds[1].open(.success(FileUploadResult(remoteReference: "CURRENT")))
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
        first.open(.success(FileUploadResult(remoteReference: "R")))
        waitUntil { recorder.isOver }
        XCTAssertEqual(uploads(of: "upload-1"), 1)
    }

    // MARK: - Cancel

    func testCancellingARunningUploadStopsItAndDropsItsResult() throws {
        let first = Hold<FileTransferResult<FileUploadResult>>()
        transport.onUpload = { request, _ in
            request.operationId == "upload-1" ? await first.wait() : .success(FileUploadResult(remoteReference: "NEXT"))
        }
        let (taskInfo, recorder, _) = try upload(tid: 1)
        let (_, next, _) = try upload(tid: 2)
        waitUntil { first.isWaiting }

        taskInfo.cancel()
        taskInfo.cancel()
        waitUntil { next.isOver }
        XCTAssertTrue(first.wasCancelled)
        XCTAssertEqual(transport.cancelled, ["upload-1"], "repeats reach the transport once")

        first.open(.success(FileUploadResult(remoteReference: "LATE")))
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
        first.open(.success(FileUploadResult(remoteReference: "A")))
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
        upload1.open(.success(FileUploadResult(remoteReference: "LATE")))
        transport.onUpload = { _, _ in .success(FileUploadResult(remoteReference: "AFTER")) }
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
        let enc = AttachmentEncryption(algorithm: "alg", attachmentId: "id", key: "k")
        transport.onDownload = { request, progress in
            progress(0.5)
            progress(1)
            return .success(request.destinationFile)
        }

        // `downloadEncryption` alone does not make it encrypted.
        let (taskInfo, recorder) = download(downloadEncryption: enc)
        waitUntil { recorder.isOver }

        let request = try XCTUnwrap(transport.downloads.first)
        XCTAssertNil(request.encryptionInfo)
        XCTAssertNil(request.plaintextSize)
        XCTAssertTrue(request.operationId.hasPrefix("download-url"))
        XCTAssertEqual(request.url, taskInfo.attachment.url)
        XCTAssertTrue((request.context as? AttachmentTransferContext)?.attachment === taskInfo.attachment)
        XCTAssertEqual(recorder.progress, [0.5, 1])
        XCTAssertEqual(recorder.locations, [request.destinationFile])
        XCTAssertEqual(recorder.successes, [request.url])
        XCTAssertFalse(taskInfo.didDecryptDownload)
    }

    func testEncryptedDownloadIsMarkedDecryptedAndHoldsItsBarShortOfFull() throws {
        let enc = AttachmentEncryption(algorithm: "alg", attachmentId: "id", key: "k")
        transport.onDownload = { request, progress in
            progress(0.5)
            progress(1)
            return .success(request.destinationFile)
        }

        let (taskInfo, recorder) = download(encryption: .required, downloadEncryption: enc)
        waitUntil { recorder.isOver }

        XCTAssertEqual(transport.downloads.first?.encryptionInfo, enc.fileInfo)
        XCTAssertEqual(recorder.progress, [0.5, 0.99])
        XCTAssertTrue(taskInfo.didDecryptDownload)
        XCTAssertEqual(recorder.successes.count, 1)
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
            XCTAssertFalse(taskInfo.didDecryptDownload)
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

    func testAnEncryptedDownloadPassesTheSentSizeToVerify() throws {
        let enc = AttachmentEncryption(algorithm: "alg", attachmentId: "id", key: "k")
        for (size, encrypted, expected) in [(UInt(1234), true, Int64?(1234)), (0, true, nil), (1234, false, nil)] {
            let attachment = ChatMessage.Attachment(id: 0, tid: 0, messageId: 1, userId: "u", url: "https://files.example/\(UUID().uuidString)/a.bin", filePath: nil, type: "file", name: "a.bin", metadata: nil, uploadedFileSize: size, createdAt: Date())
            let (taskInfo, recorder) = makeTask(attachment, .download, encryption: encrypted ? .required : .none, downloadEncryption: enc)
            session.download(attachment: attachment, taskInfo: taskInfo)
            waitUntil { recorder.isOver }
            XCTAssertEqual(transport.downloads.last?.plaintextSize, expected, "size \(size) encrypted \(encrypted)")
        }
    }

    func testASecondStartOfARunningUploadJoinsIt() throws {
        let hold = Hold<FileTransferResult<FileUploadResult>>()
        transport.onUpload = { _, _ in await hold.wait() }
        let (first, a, attachment) = try upload(tid: 5)
        waitUntil { hold.isWaiting }

        let (second, b) = makeTask(attachment)
        session.upload(attachment: attachment, taskInfo: second)
        hold.open(.success(FileUploadResult(remoteReference: "ONE")))
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
        hold.open(.success(FileUploadResult(remoteReference: "JOINED")))
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

    func testAnEncryptedDownloadWithoutEncGoesOutWithoutIt() {
        let (_, recorder) = download(encryption: .required, downloadEncryption: nil)
        waitUntil { recorder.isOver }
        XCTAssertNil(transport.downloads.first?.encryptionInfo, "the gate in AttachmentTransfer rejects what comes back")
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

    func testPreparedFilesThatAreGoneOrEmptyAreStillSent() throws {
        let empty = directory.appendingPathComponent("empty.bin")
        try Data().write(to: empty)
        for file in [directory.appendingPathComponent("gone.bin"), empty] {
            session.preparation = { _, _ in PreparedUploadFile(file: file, isStaged: false) }
            let (_, recorder, _) = try upload(tid: 9)
            waitUntil { recorder.isOver }
            XCTAssertEqual(transport.uploads.last?.sourceFile, file)
        }
    }

    func testAPlainUploadThatComesBackWithEncryptionKeepsIt() throws {
        let info = EncryptedFileInfo(algorithm: "a", attachmentId: "b", key: "c")
        transport.onUpload = { _, _ in .success(FileUploadResult(remoteReference: "R", encryptionInfo: info)) }
        let (taskInfo, recorder, _) = try upload(tid: 10)
        waitUntil { recorder.isOver }
        XCTAssertEqual(taskInfo.uploadedEncryption, info)
    }

    func testAnEncryptedUploadWhoseFilesAreGoneHasNoPlaintextSize() throws {
        let prepared = try file()
        session.preparation = { _, _ in PreparedUploadFile(file: prepared, isStaged: false) }
        transport.onUpload = { request, _ in
            try? FileManager.default.removeItem(at: request.sourceFile)
            return .success(FileUploadResult(remoteReference: "E", encryptionInfo: EncryptedFileInfo(algorithm: "a", attachmentId: "b", key: "c")))
        }
        let attachment = makeAttachment(tid: 11, filePath: directory.appendingPathComponent("gone").path)
        let (taskInfo, recorder) = makeTask(attachment, encryption: .required)
        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { recorder.isOver }

        XCTAssertEqual(recorder.successes, ["E"])
        XCTAssertNil(taskInfo.uploadedPlaintextSize)
    }

    func testAMissingSourceIsSentAsWhatThePreparationMakes() throws {
        let missing = directory.appendingPathComponent("deleted.m4a").path
        let attachment = makeAttachment(tid: 12, type: "voice", filePath: missing)
        let (taskInfo, recorder) = makeTask(attachment)
        session.upload(attachment: attachment, taskInfo: taskInfo)
        waitUntil { recorder.isOver }
        XCTAssertEqual(transport.uploads.first?.sourceFile.path, missing)
    }

    func testAnAppExtensionResizesWithLessMemory() throws {
        let original = TransportDataSession.isAppExtension
        defer { TransportDataSession.isAppExtension = original }
        TransportDataSession.isAppExtension = { true }
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

    func testMimeTypes() {
        let staged = PreparedUploadFile(file: URL(fileURLWithPath: "/x/photo.jpg"), isStaged: true)
        let inPlace = PreparedUploadFile(file: URL(fileURLWithPath: "/x/plain-1.bin"), isStaged: false)
        XCTAssertEqual(TransportDataSession.mimeType(of: staged, fileName: "photo.heic"), "image/jpeg", "a staged file is typed by its own bytes")
        XCTAssertEqual(TransportDataSession.mimeType(of: inPlace, fileName: "report.pdf"), "application/pdf")
        XCTAssertEqual(TransportDataSession.mimeType(of: inPlace, fileName: "report"), TransportDataSession.mimeType(of: inPlace, fileName: "plain-1.bin"))
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

    /// An encrypted upload, an encrypted download and failures carrying signed URLs, logged at
    /// the most verbose level: neither the key nor a URL's query reaches a log line, while the
    /// terminal outcomes do.
    func testTransferLogsCarryNoKeyAndNoSignedQuery() throws {
        let capture = LogCapture()
        defer { capture.stop() }
        let key = "KEY-\(UUID().uuidString)"
        let signed = "https://cdn.example.com/\(UUID().uuidString)/report.pdf?Signature=SIG-SECRET&Key-Pair-Id=PAIR"

        transport.onUpload = { _, _ in
            .success(FileUploadResult(remoteReference: signed, encryptionInfo: EncryptedFileInfo(algorithm: "alg", attachmentId: "id", key: key)))
        }
        let (_, uploaded, _) = try upload(tid: 11, encryption: .required)
        waitUntil { uploaded.isOver }

        transport.onUpload = { _, _ in
            .failure(URLError(.notConnectedToInternet, userInfo: [NSURLErrorFailingURLStringErrorKey: signed]))
        }
        let (_, failed, _) = try upload(tid: 12, encryption: .required)
        waitUntil { failed.isOver }

        // Success without its encryption: rejected.
        transport.onUpload = { _, _ in .success(FileUploadResult(remoteReference: signed)) }
        let (_, bypassed, _) = try upload(tid: 13, encryption: .required)
        waitUntil { bypassed.isOver }

        transport.onDownload = { request, progress in
            progress(0.3)
            progress(0.8)
            return .success(request.destinationFile)
        }
        let attachment = makeAttachment(tid: 0, url: signed)
        let (taskInfo, downloaded) = makeTask(attachment, .download, encryption: .required, downloadEncryption: AttachmentEncryption(algorithm: "alg", attachmentId: "id", key: key))
        session.download(attachment: attachment, taskInfo: taskInfo)
        waitUntil { downloaded.isOver }

        let lines = capture.lines
        XCTAssertTrue(lines.contains { $0.contains("[Transfer] xfer=upload-11 ") && $0.contains("finished (success)") })
        XCTAssertTrue(lines.contains { $0.contains("[Transfer] xfer=upload-12 ") && $0.contains("finished (failure)") })
        XCTAssertTrue(lines.contains { $0.contains("[Encryption] xfer=upload-13 ") && $0.contains("encryptionBypassed") })
        XCTAssertTrue(lines.contains { $0.contains("[Transfer] xfer=download-url") && $0.contains("finished (success)") })
        let transferLines = lines.filter { $0.contains("[Transfer]") || $0.contains("[Encryption]") }
        XCTAssertTrue(transferLines.allSatisfy { $0.contains("xfer=") }, "every line names its transfer: \(transferLines.filter { !$0.contains("xfer=") })")
        XCTAssertTrue(lines.filter { $0.hasPrefix("[ERROR]") }.isEmpty, "the session reports failures at debug; the end of the transfer reports them once: \(lines.filter { $0.hasPrefix("[ERROR]") })")
        for secret in [key, "SIG-SECRET", "Key-Pair-Id"] {
            let leaking = lines.filter { $0.contains(secret) }
            XCTAssertTrue(leaking.isEmpty, "\(secret) reached the logs: \(leaking)")
        }
    }
}
