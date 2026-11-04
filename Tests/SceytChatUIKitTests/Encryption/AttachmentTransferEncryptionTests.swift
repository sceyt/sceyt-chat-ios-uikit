//
//  AttachmentTransferEncryptionTests.swift
//  SceytChatUIKitTests
//
//  The encryption parts of `AttachmentTransfer` beyond the fail-closed gate tests: the setup
//  and gate helpers one by one, rejected successes (a download the session never decrypted,
//  an `enc` that cannot be written), offline failures, a dedupe hit that reuses an encrypted
//  object, the encrypted video poster on upload and on download, the media-metadata rebuild of
//  an encrypted image, and the checksum table only reusing encrypted objects for an encrypted
//  send (`ChannelMessageChecksumProvider`).
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import UIKit
import XCTest

// MARK: - Fakes

/// Answers uploads by encrypting the request with the real SDK, or as the test says.
private final class EncryptingTransport: FileTransferTransport {
    var onUpload: ((FileUploadRequest) async -> FileTransferResult<FileUploadResult>)?
    var onDownload: (FileDownloadRequest) async -> FileTransferResult<URL> = { _ in .failure(URLError(.badURL)) }
    private let lock = NSLock()
    private var _uploads = [FileUploadRequest]()
    private var _downloads = [FileDownloadRequest]()
    var uploads: [FileUploadRequest] { lock.lock(); defer { lock.unlock() }; return _uploads }
    var downloads: [FileDownloadRequest] { lock.lock(); defer { lock.unlock() }; return _downloads }
    /// The objects the default upload stored, by remote reference.
    private(set) var objects = [String: URL]()
    let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    func upload(_ request: FileUploadRequest, progress: @escaping (Double) -> Void) async -> FileTransferResult<FileUploadResult> {
        lock.lock(); _uploads.append(request); lock.unlock()
        if let onUpload { return await onUpload(request) }
        guard request.type == .encrypted else { return .success(FileUploadResult(remoteReference: "PLAIN")) }
        do {
            let object = directory.appendingPathComponent("object-\(UUID().uuidString)")
            let info = try await ChatSDKFileEncryption().encrypt(file: request.sourceFile, to: object)
            lock.lock(); objects["ENC"] = object; lock.unlock()
            return .success(FileUploadResult(remoteReference: "ENC", encryptionInfo: info))
        } catch {
            return .failure(error)
        }
    }

    func download(_ request: FileDownloadRequest, progress: @escaping (Double) -> Void) async -> FileTransferResult<URL> {
        lock.lock(); _downloads.append(request); lock.unlock()
        return await onDownload(request)
    }

    func cancel(operationId: String) {}
}

/// The router, storing under one directory, with hooks for what the transport split cannot fake.
private final class HookedSession: TransportDataSession {
    let root: URL
    var encrypts = true
    var checksums = false
    /// Replace the whole upload / download when set.
    var onUpload: ((ChatMessage.Attachment, SCTDataSessionTaskInfo) -> Void)?
    var onDownload: ((ChatMessage.Attachment, SCTDataSessionTaskInfo) -> Void)?
    /// Runs after the transport was handed a download, before `AttachmentTransfer` goes on.
    var afterDownloadStarted: ((SCTDataSessionTaskInfo) -> Void)?
    var onThumbnailUpload: (URL) -> Result<String, Error> = { _ in .failure(SCTDataSessionError.thumbnailUploadFailed) }
    var onThumbnailDownload: (String) -> Result<URL, Error> = { _ in .failure(SCTDataSessionError.thumbnailDownloadFailed) }
    private(set) var thumbnailUploads = [Data]()

    init(transport: FileTransferTransport, root: URL) {
        self.root = root
        super.init(transport: transport)
    }

    override var supportsAttachmentEncryption: Bool { encrypts }
    override var checksumsBeforeUpload: Bool { checksums }
    override var stagingDirectory: URL { root.appendingPathComponent("staging", isDirectory: true) }

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
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("video_thumb_\(UUID().uuidString).jpg")
        try? FileManager.default.copyItem(at: poster, to: copy)
        return copy
    }
}

/// A `FileEncryption` that cannot prepare anything.
private final class UnpreparedEncryption: FileEncryption {
    func prepareEncryption(file: URL) async throws -> FileEncryptionSession { throw AttachmentEncryptionError.snapshotFailed(CocoaError(.fileNoSuchFile)) }
    func restoreEncryption(file: URL, checkpoint: EncryptedFileCheckpoint) async throws -> FileEncryptionSession { throw AttachmentEncryptionError.invalidCheckpoint }
    func discard(_ checkpoint: EncryptedFileCheckpoint) {}
    func decrypt(file: URL, to destination: URL, encryptionInfo: EncryptedFileInfo, plaintextSize: Int64?) async throws {
        throw AttachmentEncryptionError.decryptionFailed(CocoaError(.fileReadCorruptFile))
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

final class AttachmentTransferEncryptionTests: XCTestCase {

    private var transfer: PosterTransfer!
    private var transport: EncryptingTransport!
    private var session: HookedSession!
    private var directory: URL!
    private var originalDataSession: SCTDataSession?
    private var originalDatabase: Database!

    private let messageId: MessageId = 902
    private let encryption = ChatSDKFileEncryption()

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalDatabase = DataProvider.database
        DataProvider.database = MockDatabase()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("enc-transfer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        transport = EncryptingTransport(directory: directory)
        session = HookedSession(transport: transport, root: directory)
        transfer = PosterTransfer()
        transfer.offline = true
        let session = session!
        transfer.environment.dataSession = { session }
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider { _, _ in .required } }
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

    /// An encrypted remote attachment: the stored object and what the message carries.
    private func remote(of plaintext: URL, type: String = "file", name: String = "report.pdf", metadata: String = #"{"tmb":"x"}"#) throws -> (attachment: ChatMessage.Attachment, object: URL) {
        let object = directory.appendingPathComponent("remote-\(UUID().uuidString)")
        let info = try encrypt(plaintext, to: object)
        let attachment = makeAttachment(
            tid: 0,
            type: type,
            name: name,
            url: "REMOTE-\(UUID().uuidString)",
            metadata: try ChatMessage.Attachment.metadata(metadata, settingEncryption: AttachmentEncryption(info: info))
        )
        return (attachment, object)
    }

    private func encrypt(_ file: URL, to object: URL) throws -> EncryptedFileInfo {
        let result = Locked<Result<EncryptedFileInfo, Error>?>(nil)
        Task {
            do { result.wrapped = .success(try await self.encryption.encrypt(file: file, to: object)) } catch { result.wrapped = .failure(error) }
        }
        XCTAssertTrue(waitUntil { result.wrapped != nil })
        return try XCTUnwrap(result.wrapped).get()
    }

    private func decrypt(_ object: URL, info: EncryptedFileInfo) throws -> Data {
        let output = directory.appendingPathComponent("decrypted-\(UUID().uuidString)")
        let result = Locked<Result<Void, Error>?>(nil)
        Task {
            do {
                try await self.encryption.decrypt(file: object, to: output, encryptionInfo: info, plaintextSize: nil)
                result.wrapped = .success(())
            } catch { result.wrapped = .failure(error) }
        }
        XCTAssertTrue(waitUntil { result.wrapped != nil })
        try XCTUnwrap(result.wrapped).get()
        return try Data(contentsOf: output)
    }

    /// Serves `object` through the default publishing step.
    private func serve(_ object: URL) {
        transport.onDownload = { request in
            let staging = self.directory.appendingPathComponent("staging-\(UUID().uuidString)")
            do {
                try FileManager.default.copyItem(at: object, to: staging)
                try await DefaultFileTransferTransport.publish(staging, to: request, encryption: self.encryption)
                return .success(request.destinationFile)
            } catch {
                return .failure(error)
            }
        }
    }

    // MARK: - Setup and gate helpers

    func testUploadEncryptionCoversOnlyRequiredAttachmentsWithAFile() throws {
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider { attachment, _ in attachment.tid == 3 ? .none : .required } }
        let withFile = makeAttachment(tid: 1, filePath: try file().path)
        let withoutFile = makeAttachment(tid: 2)
        let notRequired = makeAttachment(tid: 3, filePath: try file().path)
        let link = makeAttachment(tid: 4, type: "link", filePath: try file().path)

        let setups = transfer.uploadEncryption(message: makeMessage([withFile, withoutFile, notRequired, link]), attachments: [withFile, withoutFile, notRequired, link])

        XCTAssertEqual(Set(setups.keys), [ObjectIdentifier(withFile)])
        XCTAssertNil(setups[ObjectIdentifier(withFile)]?.download)
        XCTAssertNil(setups[ObjectIdentifier(withFile)]?.error)
    }

    func testDownloadEncryptionReadsEncAndRejectsWhatItCannotRead() throws {
        let enc = AttachmentEncryption(algorithm: StreamingAeadFileEncryptionProvider.format, attachmentId: "a", key: "7b64ReeCOhm0NOUU1jMyLzNHwQVjgtI9p8MEvF5k6C4")
        let plain = makeAttachment(metadata: #"{"tmb":"x"}"#)
        let readable = makeAttachment(metadata: try ChatMessage.Attachment.metadata(nil, settingEncryption: enc))
        let otherAlgorithm = makeAttachment(metadata: try ChatMessage.Attachment.metadata(nil, settingEncryption: AttachmentEncryption(algorithm: "aes-cbc", attachmentId: "a", key: "7b64ReeCOhm0NOUU1jMyLzNHwQVjgtI9p8MEvF5k6C4")))
        let malformed = makeAttachment(metadata: #"{"enc":{"v":1}}"#)
        let truncated = makeAttachment(metadata: #"{"enc":{"alg":"#)

        let setups = transfer.downloadEncryption(attachments: [plain, readable, otherAlgorithm, malformed, truncated])

        XCTAssertNil(setups[ObjectIdentifier(plain)], "a plaintext attachment stays on the legacy path")
        XCTAssertEqual(setups[ObjectIdentifier(readable)]?.download, enc)
        XCTAssertNil(setups[ObjectIdentifier(readable)]?.error)
        for attachment in [otherAlgorithm, malformed, truncated] {
            guard case .invalidEncryptionInfo = setups[ObjectIdentifier(attachment)]?.error as? AttachmentEncryptionError else {
                return XCTFail("expected invalidEncryptionInfo for \(attachment.metadata ?? "")")
            }
            XCTAssertNil(setups[ObjectIdentifier(attachment)]?.download)
        }
    }

    func testApplyMarksTheTaskAndFailsClosed() {
        let enc = AttachmentEncryption(algorithm: "alg", attachmentId: "a", key: "7b64ReeCOhm0NOUU1jMyLzNHwQVjgtI9p8MEvF5k6C4")
        let attachment = makeAttachment()

        let ready = makeTask(attachment, .download)
        XCTAssertNil(AttachmentTransfer.apply(.init(download: enc), to: ready, dataSession: session))
        XCTAssertEqual(ready.encryption, .required)
        XCTAssertEqual(ready.downloadEncryption, enc)

        let malformed = makeTask(attachment, .download)
        guard case .invalidEncryptionInfo = AttachmentTransfer.apply(.init(error: AttachmentEncryptionError.invalidEncryptionInfo), to: malformed, dataSession: session) as? AttachmentEncryptionError else {
            return XCTFail("the setup's error")
        }

        session.encrypts = false
        let unsupported = makeTask(attachment, .upload)
        guard case .encryptionUnsupportedBySession = AttachmentTransfer.apply(.init(), to: unsupported, dataSession: session) as? AttachmentEncryptionError else {
            return XCTFail("a session that cannot encrypt comes first")
        }
        XCTAssertEqual(unsupported.encryption, .required, "marked either way, so nothing treats it as plaintext")
    }

    func testEncryptionGate() throws {
        let encrypted = makeAttachment(metadata: try ChatMessage.Attachment.metadata(nil, settingEncryption: AttachmentEncryption(algorithm: "a", attachmentId: "b", key: "zXgmf8ZVlpdTnfhSSh34q87xbERlhieF1MTFzn78ILw")))
        let plain = makeAttachment()
        func gate(_ type: SCTDataSessionTaskInfo.TransferType, _ attachment: ChatMessage.Attachment, _ setup: (SCTDataSessionTaskInfo) -> Void) -> AttachmentEncryptionError? {
            let taskInfo = makeTask(attachment, type)
            setup(taskInfo)
            return AttachmentTransfer.encryptionGateError(taskInfo: taskInfo, attachment: attachment) as? AttachmentEncryptionError
        }

        XCTAssertNil(gate(.upload, plain) { _ in }, "not encrypted: no gate")
        XCTAssertNil(gate(.download, plain) { _ in })
        guard case .encryptionBypassed = gate(.upload, plain, { $0.encryption = .required }) else { return XCTFail("upload without its encryption") }
        XCTAssertNil(gate(.upload, plain) {
            $0.encryption = .required
            $0.uploadedEncryption = EncryptedFileInfo(algorithm: "a", attachmentId: "b", key: "zXgmf8ZVlpdTnfhSSh34q87xbERlhieF1MTFzn78ILw")
        })
        XCTAssertNil(gate(.upload, encrypted) { $0.encryption = .required }, "a dedupe hit reused an encrypted object with its enc")
        guard case .encryptionBypassed = gate(.download, encrypted, { $0.encryption = .required }) else { return XCTFail("download never decrypted") }
        XCTAssertNil(gate(.download, encrypted) {
            $0.encryption = .required
            $0.didDecryptDownload = true
        })
    }

    // MARK: - Rejected successes

    func testADownloadTheSessionDidNotDecryptIsRejectedAndItsFileRemoved() throws {
        let remote = try remote(of: try file(size: 500))
        let stored = directory.appendingPathComponent("stored-ciphertext")
        session.onDownload = { _, taskInfo in
            // A session that claims encryption support but stores the object as is.
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                try? FileManager.default.copyItem(at: remote.object, to: stored)
                taskInfo.updateLocalFileLocation(newPath: stored.path)
                taskInfo.success(origin: remote.attachment.url!)
            }
        }

        let (finished, error) = download(remote.attachment)

        XCTAssertTrue(finished)
        guard case .encryptionBypassed = error as? AttachmentEncryptionError else {
            return XCTFail("expected encryptionBypassed, got \(String(describing: error))")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: stored.path), "ciphertext is never kept as the file")
        XCTAssertNil(remote.attachment.filePath)
        XCTAssertEqual(remote.attachment.transferProgress, 0)
        XCTAssertEqual(remote.attachment.uploadedFileSize, 0, "the ciphertext's size is not the file's")
        XCTAssertEqual(remote.attachment.status, .failedDownloading)
    }

    func testAnUploadTheSessionDidNotEncryptIsRejected() throws {
        let attachment = makeAttachment(filePath: try file().path)
        session.onUpload = { _, taskInfo in
            // A session that claims encryption support but reports a plain upload.
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                taskInfo.success(origin: "PLAINTEXT-OBJECT")
            }
        }

        let error = upload(attachment)

        guard case .encryptionBypassed = error as? AttachmentEncryptionError else {
            return XCTFail("expected encryptionBypassed, got \(String(describing: error))")
        }
        XCTAssertNil(attachment.url, "kept out of the checksum table, so nothing dedupes onto it")
        XCTAssertNil(attachment.encryption)
        XCTAssertEqual(attachment.status, .failedUploading)
    }

    func testAnEncThatCannotBeWrittenRejectsTheUpload() throws {
        let attachment = makeAttachment(filePath: try file().path, metadata: "not a json object")

        let error = upload(attachment)

        guard case .metadataFailed(let reason) = error as? AttachmentEncryptionError,
              case .metadataNotAnObject = reason as? AttachmentEncryptionError
        else { return XCTFail("expected metadataFailed(metadataNotAnObject), got \(String(describing: error))") }
        XCTAssertNil(attachment.url, "an object nobody can decrypt is not sent")
        XCTAssertEqual(attachment.status, .failedUploading)
        XCTAssertEqual(attachment.metadata, "not a json object")
    }

    // MARK: - Offline

    func testOfflineFailuresWaitUnlessEncryptionRefusedThem() throws {
        transfer.offline = true
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
        transport.onUpload = { _ in .failure(URLError(.notConnectedToInternet)) }
        let waiting = makeAttachment(tid: 1, filePath: try file().path)
        XCTAssertNotNil(upload(waiting))
        XCTAssertEqual(waiting.status, .pending, "offline is not a refusal")

        transfer.environment.keyProvider = { InlineAttachmentKeyProvider { _, _ in .required } }
        transport.onUpload = { _ in .success(FileUploadResult(remoteReference: "PLAIN")) }
        let refused = makeAttachment(tid: 2, filePath: try file().path)
        XCTAssertNotNil(upload(refused))
        XCTAssertEqual(refused.status, .failedUploading, "an encryption refusal fails even offline")

        transfer.offline = false
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
        transport.onUpload = { _ in .failure(URLError(.timedOut)) }
        let online = makeAttachment(tid: 3, filePath: try file().path)
        XCTAssertNotNil(upload(online))
        XCTAssertEqual(online.status, .failedUploading)
    }

    // MARK: - Dedupe

    func testAChecksumHitOnAnEncryptedObjectReusesItsEnc() throws {
        session.checksums = true
        let content = try file(size: 300)
        let storedEnc = AttachmentEncryption(algorithm: StreamingAeadFileEncryptionProvider.format, attachmentId: "stored", key: "CweZ37AtigP65_yafHCBtUWtN5_Q41Y-y3U6hbP85Rw")
        try seedStoredUpload(of: content, url: "STORED-ENC", metadata: try ChatMessage.Attachment.metadata(#"{"tmb":"s"}"#, settingEncryption: storedEnc))
        let attachment = makeAttachment(tid: 50, filePath: try copy(content).path)

        XCTAssertNil(upload(attachment))

        XCTAssertTrue(transport.uploads.isEmpty, "nothing is uploaded again")
        XCTAssertEqual(attachment.url, "STORED-ENC")
        XCTAssertEqual(attachment.encryption, storedEnc, "the receiver gets the key the object was encrypted with")
        XCTAssertEqual(attachment.status, .done)
    }

    func testAChecksumHitOnAPlaintextObjectIsNotReusedForAnEncryptedSend() throws {
        session.checksums = true
        let content = try file(size: 300)
        try seedStoredUpload(of: content, url: "STORED-PLAIN", metadata: #"{"tmb":"s"}"#)
        let attachment = makeAttachment(tid: 51, filePath: try copy(content).path)

        XCTAssertNil(upload(attachment))

        XCTAssertEqual(transport.uploads.map(\.type), [.encrypted])
        XCTAssertEqual(attachment.url, "ENC")
        XCTAssertNotNil(attachment.encryption)
    }

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

    func testAnEncryptedVideoSendsItsPosterEncryptedUnderItsOwnKey() throws {
        let attachment = try videoUpload()
        let poster = try Data(contentsOf: try XCTUnwrap(transfer.poster))
        var sentPoster: URL?
        session.onThumbnailUpload = { url in
            sentPoster = url
            return .success("POSTER-ORIGIN")
        }

        XCTAssertNil(upload(attachment))

        let enc = try XCTUnwrap(attachment.encryption)
        let rendition = try XCTUnwrap(enc.thumbnail, "the poster's key rides in enc.renditions")
        XCTAssertNotEqual(rendition.key, enc.key)
        XCTAssertNotEqual(rendition.attachmentId, enc.attachmentId)
        XCTAssertEqual(try ChatMessage.Attachment.Metadata<String>.decode(try XCTUnwrap(attachment.metadata)).videoThumbnail, "POSTER-ORIGIN")
        XCTAssertEqual(sentPoster?.pathExtension, "enc")
        XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(sentPoster).path), "the ciphertext is removed once sent")

        let sent = try XCTUnwrap(session.thumbnailUploads.first)
        XCTAssertNotEqual(sent.prefix(poster.count), poster, "never the plaintext poster")
        let object = directory.appendingPathComponent("poster-object")
        try sent.write(to: object)
        XCTAssertEqual(try decrypt(object, info: enc.info(of: rendition)), poster)
    }

    func testAPlaintextVideoSendsAPlaintextPoster() throws {
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
        let attachment = try videoUpload()
        let poster = try Data(contentsOf: try XCTUnwrap(transfer.poster))
        session.onThumbnailUpload = { _ in .success("PLAIN-POSTER") }

        XCTAssertNil(upload(attachment))

        XCTAssertEqual(session.thumbnailUploads, [poster])
        XCTAssertNil(attachment.encryption)
        XCTAssertEqual(try ChatMessage.Attachment.Metadata<String>.decode(try XCTUnwrap(attachment.metadata)).videoThumbnail, "PLAIN-POSTER")
    }

    func testAPosterThatFailsToUploadLeavesTheVideoWithoutOne() throws {
        let attachment = try videoUpload()
        session.onThumbnailUpload = { _ in .failure(SCTDataSessionError.thumbnailUploadFailed) }

        XCTAssertNil(upload(attachment))

        let enc = try XCTUnwrap(attachment.encryption)
        XCTAssertNil(enc.thumbnail, "video_thumb and its rendition go together or not at all")
        XCTAssertNil(try? ChatMessage.Attachment.Metadata<String>.decode(attachment.metadata ?? "").videoThumbnail)
        XCTAssertEqual(attachment.status, .done)
    }

    func testAPosterThatCannotBeEncryptedIsNotSent() throws {
        let attachment = try videoUpload()
        transfer.environment.fileEncryption = { UnpreparedEncryption() }

        XCTAssertNil(upload(attachment))

        XCTAssertTrue(session.thumbnailUploads.isEmpty, "a plaintext poster would show the video")
        XCTAssertNil(try XCTUnwrap(attachment.encryption).thumbnail)
        XCTAssertEqual(attachment.status, .done)
    }

    // MARK: - Video poster on download

    func testStoringAPlaintextPosterWritesItAsIs() async throws {
        let download = try file(size: 50, ext: "jpg")
        let bytes = try Data(contentsOf: download)
        let destination = directory.appendingPathComponent("thumb.jpg")

        try await AttachmentTransfer.storeVideoThumbnail(download, of: makeAttachment(type: "video", metadata: #"{"video_thumb":"T"}"#), at: destination, encryption: encryption)

        XCTAssertEqual(try Data(contentsOf: destination), bytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: download.path), "the downloaded file is consumed")
    }

    func testStoringAnEncryptedPosterReplacesAnOlderOne() async throws {
        let poster = try file(size: 900, ext: "jpg")
        let object = directory.appendingPathComponent("poster.enc")
        let posterInfo = try await encryption.encrypt(file: poster, to: object)
        let videoInfo = EncryptedFileInfo(algorithm: posterInfo.algorithm, attachmentId: "video", key: posterInfo.key)
        let enc = AttachmentEncryption(info: videoInfo, renditions: [.init(role: AttachmentEncryption.Rendition.thumbnailRole, info: posterInfo)])
        let attachment = makeAttachment(type: "video", metadata: try ChatMessage.Attachment.metadata(#"{"video_thumb":"T"}"#, settingEncryption: enc))
        let destination = directory.appendingPathComponent("thumb.jpg")
        try Data("stale".utf8).write(to: destination)

        try await AttachmentTransfer.storeVideoThumbnail(object, of: attachment, at: destination, encryption: encryption)

        XCTAssertEqual(try Data(contentsOf: destination), try Data(contentsOf: poster))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasPrefix(".") }, [], "no temporary file is left")
    }

    func testAnUnreadableEncMeansNoPoster() async throws {
        let download = try file(size: 50, ext: "jpg")
        let destination = directory.appendingPathComponent("thumb.jpg")
        do {
            try await AttachmentTransfer.storeVideoThumbnail(download, of: makeAttachment(type: "video", metadata: #"{"video_thumb":"T","enc":{"v":7}}"#), at: destination, encryption: encryption)
            XCTFail("an unreadable enc is never shown as plaintext")
        } catch {
            guard case .invalidEncryptionInfo = error as? AttachmentEncryptionError else { return XCTFail("\(error)") }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: download.path))
    }

    func testAReceivedEncryptedPosterIsDecryptedIntoTheCache() throws {
        let poster = try image()
        let object = directory.appendingPathComponent("poster.enc")
        let posterInfo = try encrypt(poster, to: object)
        let videoInfo = try encrypt(try file(size: 100), to: directory.appendingPathComponent("video.enc"))
        let enc = AttachmentEncryption(info: videoInfo, renditions: [.init(role: AttachmentEncryption.Rendition.thumbnailRole, info: posterInfo)])

        for tampered in [false, true] {
            let origin = "poster-\(UUID().uuidString)"
            let cache = FileStorage.default.videoThumbnailCachePath(origin: origin)
            defer { try? FileManager.default.removeItem(atPath: cache) }
            let attachment = makeAttachment(tid: 0, type: "video", url: "REMOTE-VIDEO", metadata: try ChatMessage.Attachment.metadata(#"{"tmb":"x","video_thumb":"\#(origin)"}"#, settingEncryption: enc))
            session.onThumbnailDownload = { _ in
                let local = self.directory.appendingPathComponent("received-\(UUID().uuidString)")
                var bytes = (try? Data(contentsOf: object)) ?? Data()
                if tampered { bytes[bytes.count / 2] ^= 0x01 }
                try? bytes.write(to: local)
                return .success(local)
            }

            transfer.downloadVideoThumbnailsIfNeeded(message: makeMessage([attachment]))

            if tampered {
                RunLoop.main.run(until: Date().addingTimeInterval(0.3))
                XCTAssertFalse(FileManager.default.fileExists(atPath: cache), "a poster that does not verify is never cached")
            } else {
                XCTAssertTrue(waitUntil { FileManager.default.fileExists(atPath: cache) })
                XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: cache)), try Data(contentsOf: poster))
            }
        }
    }

    // MARK: - Metadata rebuild

    func testAnEncryptedImageKeepsItsEncWhenItsMetadataIsRebuilt() throws {
        let remote = try remote(of: try image(), type: "image", name: "photo.png", metadata: #"{"tmb":"x","szw":1,"szh":1}"#)
        serve(remote.object)

        let (finished, error) = download(remote.attachment)

        XCTAssertTrue(finished)
        XCTAssertNil(error)
        let metadata = try ChatMessage.Attachment.Metadata<String>.decode(try XCTUnwrap(remote.attachment.metadata))
        XCTAssertEqual(metadata.width, 40, "rebuilt from the decrypted image")
        XCTAssertNotNil(remote.attachment.encryption, "the rebuild must not drop enc")
        XCTAssertEqual(remote.attachment.status, .done)
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
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
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
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
        let attempts = Locked(0)
        transport.onUpload = { _ in
            var attempt = 0
            attempts.mutate { $0 += 1; attempt = $0 }
            if attempt == 1 {
                // Until the cancel stops it.
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                return .interrupted(CancellationError())
            }
            return .success(FileUploadResult(remoteReference: "SECOND"))
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
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
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
            transport = EncryptingTransport(directory: directory)
            session = HookedSession(transport: transport, root: directory)
            let current = session!
            transfer.environment.dataSession = { current }
        }
    }

    /// A cancel the session reports without the task's own `cancel()` (an abandoned upload,
    /// `TransportDataSession.cancel(attachments:)`) is the user's too.
    func testAnAbandonedUploadIsNotResentOnReconnect() throws {
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
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
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
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
            transport = EncryptingTransport(directory: directory)
            session = HookedSession(transport: transport, root: directory)
            let current = session!
            transfer.environment.dataSession = { current }
        }
    }

    /// A pause stops the upload without ending it, and a resume sends it.
    func testAPausedUploadStillResumes() throws {
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
        transfer.offline = false
        let attempts = Locked(0)
        transport.onUpload = { _ in
            var attempt = 0
            attempts.mutate { $0 += 1; attempt = $0 }
            if attempt == 1 {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                return .interrupted(CancellationError())
            }
            return .success(FileUploadResult(remoteReference: "RESUMED"))
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
        XCTAssertEqual(AttachmentTransfer.uploadStatus(afterFailure: AttachmentEncryptionError.encryptionBypassed, isOffline: false), .failedUploading)
        XCTAssertEqual(AttachmentTransfer.uploadStatus(afterFailure: TransportDataSessionError.missingSourceFile, isOffline: false), .failedUploading)
        XCTAssertEqual(AttachmentTransfer.uploadStatus(afterFailure: URLError(.timedOut), isOffline: false), .failedUploading)
        XCTAssertEqual(AttachmentTransfer.uploadStatus(afterFailure: URLError(.timedOut), isOffline: true), .pending)
    }

    // MARK: - Two starts for one message (finding #7)

    func testTwoStartsForOneMessageKeepEachOthersTasksAndCompletions() throws {
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
        transfer.offline = false
        let release = ReleaseSet()
        transport.onUpload = { request in
            while !release.contains(request.operationId) {
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
            return .success(FileUploadResult(remoteReference: "REF-\(request.operationId)"))
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
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
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

    private func seedEncryptedVideo(_ content: URL, url: String) throws -> AttachmentEncryption {
        let storedEnc = AttachmentEncryption(algorithm: StreamingAeadFileEncryptionProvider.format, attachmentId: "stored", key: "CweZ37AtigP65_yafHCBtUWtN5_Q41Y-y3U6hbP85Rw")
        try seedStoredUpload(of: content, url: url, metadata: try ChatMessage.Attachment.metadata(#"{"tmb":"s"}"#, settingEncryption: storedEnc))
        return storedEnc
    }

    func testADedupeHitWithANewPosterKeepsEncAndAddsTheRendition() throws {
        session.checksums = true
        let content = try file(size: 4000, ext: "mp4")
        let storedEnc = try seedEncryptedVideo(content, url: "STORED-VIDEO")
        transfer.poster = try file(size: 2000, ext: "jpg")
        let poster = try Data(contentsOf: try XCTUnwrap(transfer.poster))
        session.onThumbnailUpload = { _ in .success("POSTER-HIT") }
        let attachment = makeAttachment(tid: 90, type: "video", name: "clip.mp4", filePath: try copy(content).path)
        // A video's checksum reads its asset file (a Photos lookup otherwise).
        attachment.assetFilePath = attachment.filePath

        XCTAssertNil(upload(attachment))

        XCTAssertTrue(transport.uploads.isEmpty, "a dedupe hit: the video is not uploaded again")
        XCTAssertEqual(attachment.url, "STORED-VIDEO")
        let enc = try XCTUnwrap(attachment.encryption, "the reused object's key survives the poster's metadata rebuild")
        XCTAssertEqual(enc.attachmentId, storedEnc.attachmentId)
        XCTAssertEqual(enc.key, storedEnc.key)
        let rendition = try XCTUnwrap(enc.thumbnail, "the new poster's key is written for a dedupe hit too")
        XCTAssertEqual(try ChatMessage.Attachment.Metadata<String>.decode(try XCTUnwrap(attachment.metadata)).videoThumbnail, "POSTER-HIT")
        let sent = try XCTUnwrap(session.thumbnailUploads.first)
        let object = directory.appendingPathComponent("hit-poster")
        try sent.write(to: object)
        XCTAssertEqual(try decrypt(object, info: enc.info(of: rendition)), poster)
        XCTAssertEqual(attachment.status, .done)
    }

    /// With no encryption required, a dedupe hit can still reuse an encrypted object: its ref
    /// must never go out without its `enc`, and its poster is encrypted with it.
    func testThePlainPolicyNeverSendsACiphertextRefWithoutEnc() throws {
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
        session.checksums = true
        let content = try file(size: 4000, ext: "mp4")
        let storedEnc = try seedEncryptedVideo(content, url: "STORED-VIDEO-PLAIN")
        transfer.poster = try file(size: 2000, ext: "jpg")
        let poster = try Data(contentsOf: try XCTUnwrap(transfer.poster))
        for posterResult in [Result<String, Error>.success("POSTER-PLAIN"), .failure(SCTDataSessionError.thumbnailUploadFailed)] {
            session.onThumbnailUpload = { _ in posterResult }
            let attachment = makeAttachment(tid: 91, type: "video", name: "clip.mp4", filePath: try copy(content).path)
            attachment.assetFilePath = attachment.filePath

            XCTAssertNil(upload(attachment))

            XCTAssertEqual(attachment.url, "STORED-VIDEO-PLAIN")
            let enc = try XCTUnwrap(attachment.encryption, "a ciphertext ref without its key could never be opened")
            XCTAssertEqual(enc.key, storedEnc.key)
            if case .success = posterResult {
                let rendition = try XCTUnwrap(enc.thumbnail)
                let sent = try XCTUnwrap(session.thumbnailUploads.last)
                XCTAssertNotEqual(sent.prefix(poster.count), poster, "never a plaintext poster for an encrypted video")
                let object = directory.appendingPathComponent("plain-hit-poster-\(UUID().uuidString)")
                try sent.write(to: object)
                XCTAssertEqual(try decrypt(object, info: enc.info(of: rendition)), poster)
            } else {
                XCTAssertNil(enc.thumbnail)
                XCTAssertNil(try? ChatMessage.Attachment.Metadata<String>.decode(attachment.metadata ?? "").videoThumbnail)
            }
        }
    }

    /// A plaintext poster's metadata rebuild keeps an `enc` already there.
    func testAPlainPosterRebuildKeepsEnc() throws {
        let enc = AttachmentEncryption(algorithm: "a", attachmentId: "b", key: "zXgmf8ZVlpdTnfhSSh34q87xbERlhieF1MTFzn78ILw")
        let attachment = makeAttachment(type: "video", metadata: try ChatMessage.Attachment.metadata(#"{"tmb":"x"}"#, settingEncryption: enc))
        var meta = try ChatMessage.Attachment.Metadata<String>.decode(try XCTUnwrap(attachment.metadata))
        meta.videoThumbnail = "V"
        AttachmentTransfer.updateMetadata(of: attachment, rebuiltFrom: meta)
        XCTAssertEqual(attachment.encryption, enc)
        XCTAssertEqual(attachment.imageDecodedMetadata?.videoThumbnail, "V")
    }

    func testTheEncAnUploadWrites() throws {
        let rendition = AttachmentEncryption.Rendition(role: AttachmentEncryption.Rendition.thumbnailRole, attachmentId: "p", key: "YGzDgK1imJtelRMNIoRMDMFn3l2SITyRHaqTrSwGYx4")
        let reused = AttachmentEncryption(algorithm: "alg", attachmentId: "r", key: "fc3Ym1caWRIAWJRXZAj3kM088pUm0Etu7i2i70hQsDk", renditions: [
            .init(role: AttachmentEncryption.Rendition.thumbnailRole, attachmentId: "old", key: "BtHbbG6Z6Hk0kPbpcRr8eWlr7nR7O8nhoS2NmIPAtyk"),
            .init(role: "other", attachmentId: "o", key: "y4TL5ZGVvz2hb4Yt5NEoKwHxSRWy3H3plIQFlMNzm5E"),
        ])
        let hit = makeAttachment(metadata: try ChatMessage.Attachment.metadata(nil, settingEncryption: reused))
        let plain = makeAttachment()

        let none = makeTask(plain, .upload)
        XCTAssertNil(AttachmentTransfer.uploadEncryption(of: none, attachment: plain))
        none.thumbnailRendition = rendition
        XCTAssertNil(AttachmentTransfer.uploadEncryption(of: none, attachment: plain), "nothing to attach a rendition to")

        let hitTask = makeTask(hit, .upload)
        XCTAssertNil(AttachmentTransfer.uploadEncryption(of: hitTask, attachment: hit), "a hit's enc is already in place")
        hitTask.thumbnailRendition = rendition
        let written = try XCTUnwrap(AttachmentTransfer.uploadEncryption(of: hitTask, attachment: hit))
        XCTAssertEqual(written.key, "fc3Ym1caWRIAWJRXZAj3kM088pUm0Etu7i2i70hQsDk")
        XCTAssertEqual(written.renditions.map(\.attachmentId), ["o", "p"], "the new poster replaces the old one")

        let uploaded = makeTask(plain, .upload)
        uploaded.uploadedEncryption = EncryptedFileInfo(algorithm: "alg", attachmentId: "u", key: "O4kW0_9syhx4EGfXXDXG1E_RjeEH-MpcqGZXXweqn5k")
        uploaded.thumbnailRendition = rendition
        XCTAssertEqual(AttachmentTransfer.uploadEncryption(of: uploaded, attachment: plain)?.renditions, [rendition])
    }
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

extension AttachmentTransferEncryptionTests {

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
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
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
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
        let own = try file()
        let resolved = try file()
        session.filePathFor = { _ in resolved.path }
        let attachment = makeAttachment(tid: 75, filePath: own.path)
        XCTAssertNil(upload(attachment))
        XCTAssertEqual(transport.uploads.first?.sourceFile.path, resolved.path)
    }

    func testAMissingSourceIsRecoveredFromTheSessionOrTheTemporaryFolder() throws {
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
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
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
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
        for required in [false, true] {
            transfer.environment.keyProvider = { required ? InlineAttachmentKeyProvider { _, _ in .required } : InlineAttachmentKeyProvider() }
            session.onThumbnailUpload = { _ in .success("LATE") }
            let attachment = try videoUpload()

            XCTAssertNil(upload(attachment))

            XCTAssertNil(try? ChatMessage.Attachment.Metadata<String>.decode(attachment.metadata ?? "").videoThumbnail, "sent without it")
            XCTAssertEqual(attachment.status, .done)
            // Let the late answer arrive: this test is about time (an answer after the
            // poster timeout), so it waits out the delay on purpose.
            _ = waitUntil(timeout: 0.6) { false }
            XCTAssertNil(attachment.encryption?.thumbnail, "a late poster is not attached")
        }
    }

    func testAVideoWithoutAFrameOrWhosePlainPosterFailsGoesWithout() throws {
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
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
        let video = makeAttachment(tid: 0, type: "video", url: "REMOTE-V", metadata: #"{"tmb":"x","video_thumb":"\#(origin)"}"#)
        XCTAssertTrue(transfer.needsVideoThumbnailDownload(attachment: video))
        XCTAssertFalse(transfer.needsVideoThumbnailDownload(attachment: makeAttachment(type: "image")))
    }

    func testAPosterDownloadThatFailsIsDropped() {
        let origin = "poster-fail-\(UUID().uuidString)"
        let video = makeAttachment(tid: 0, type: "video", url: "REMOTE-V2", metadata: #"{"tmb":"x","video_thumb":"\#(origin)"}"#)
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
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
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
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
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
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
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
        session.encrypts = false
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

extension AttachmentTransferEncryptionTests {

    /// One encrypted upload (through the checksum step) and one tampered encrypted download:
    /// every transfer line of each names that transfer with one `xfer=`, each ends with one
    /// summary line, the tampered download logs exactly one ERROR, and no key, `enc` key or
    /// signed query is logged.
    func testEachTransferLogsUnderOneIdWithOneSummaryAndOneErrorPerFailure() throws {
        let capture = TrailCapture()
        defer { capture.stop() }
        func isTransferLine(_ text: String) -> Bool {
            ["[Transfer]", "[Encryption]", "[Attachment]", "[CHECKSUM]"].contains { text.contains($0) }
        }
        func settle() { RunLoop.main.run(until: Date().addingTimeInterval(0.3)) }

        // Upload
        session.checksums = true
        let attachment = makeAttachment(tid: 77, filePath: try file(size: 3000).path)
        XCTAssertNil(upload(attachment))
        settle()
        let uploadLines = capture.take()
        let key = try XCTUnwrap(attachment.encryption?.key)

        // Tampered download
        let remote = try remote(of: try file(size: 5000))
        var bytes = try Data(contentsOf: remote.object)
        bytes[bytes.count / 2] ^= 0x01
        try bytes.write(to: remote.object)
        serve(remote.object)
        _ = capture.take() // the fixture's own encryption above is not the transfer's
        let (finished, error) = download(remote.attachment)
        XCTAssertTrue(finished)
        guard case .decryptionFailed = error as? AttachmentEncryptionError else { return XCTFail("\(String(describing: error))") }
        settle()
        let downloadLines = capture.take()

        let downloadId = TransportDataSession.shortDownloadOperationId(for: remote.attachment)
        for (name, lines, id) in [("upload", uploadLines, "upload-77"), ("download", downloadLines, downloadId)] {
            let transfer = lines.map(\.text).filter(isTransferLine)
            XCTAssertFalse(transfer.isEmpty, name)
            let untagged = transfer.filter { !$0.contains("xfer=\(id) ") }
            XCTAssertTrue(untagged.isEmpty, "\(name): every line carries xfer=\(id): \(untagged)")
            let summaries = transfer.filter { $0.contains("transfer finished") }
            XCTAssertEqual(summaries.count, 1, "\(name): one summary line: \(summaries)")
            XCTAssertTrue(summaries.first?.contains("msg=\(messageId)/") == true, name)
            XCTAssertTrue(summaries.first?.contains("channel=100") == true, name)
            XCTAssertTrue(summaries.first?.contains("type=encrypted") == true, name)
            for secret in [key, remote.attachment.encryption?.key ?? "?"] {
                XCTAssertFalse(lines.contains { $0.text.contains(secret) }, "\(name): a key reached the logs")
            }
        }
        let uploadSummary = try XCTUnwrap(uploadLines.first { $0.text.contains("transfer finished") })
        XCTAssertEqual(uploadSummary.level, .info)
        XCTAssertTrue(uploadSummary.text.contains("dir=upload") && uploadSummary.text.contains("result=success") && uploadSummary.text.contains("attempts=1") && uploadSummary.text.contains("size=3000"), uploadSummary.text)
        XCTAssertTrue(uploadLines.filter { $0.level == .error }.isEmpty, "\(uploadLines.filter { $0.level == .error }.map(\.text))")
        let loud = uploadLines.filter { $0.level <= .info }
        XCTAssertLessThanOrEqual(loud.count, 10, "a successful upload stays short at info+: \(loud.map(\.text))")

        let errors = downloadLines.filter { $0.level <= .error }
        XCTAssertEqual(errors.count, 1, "one ERROR for one failure: \(errors.map(\.text))")
        let failure = try XCTUnwrap(errors.first?.text)
        XCTAssertTrue(failure.contains("transfer finished") && failure.contains("dir=download") && failure.contains("result=failure"), failure)
        XCTAssertTrue(failure.contains("decryptionFailed(authentication failed"), "the cause chain: \(failure)")

        // For the report: the trail as it is logged.
        print("TRAIL-BEGIN")
        (uploadLines + downloadLines).filter { isTransferLine($0.text) }.forEach { print("TRAIL \($0.text)") }
        print("TRAIL-END")
    }
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

final class ChecksumEncryptionTests: XCTestCase {

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

    private func checksum(_ attachment: ChatMessage.Attachment, encryption: EncryptionRequirement?) -> Result<String?, Error>? {
        let message = ChatMessage(id: 0, channelId: 1, attachments: [attachment], user: ChatUser(id: "u"))
        var result: Result<String?, Error>?
        let provider = ChannelMessageChecksumProvider()
        if let encryption {
            provider.startChecksum(message: message, attachment: attachment, encryption: encryption) { result = $0 }
        } else {
            provider.startChecksum(message: message, attachment: attachment) { result = $0 }
        }
        XCTAssertTrue(waitUntil { result != nil })
        return result
    }

    func testAnEncryptedSendReusesOnlyAnEncryptedObject() throws {
        let bytes = Data("same bytes".utf8)
        let enc = try ChatMessage.Attachment.metadata(#"{"tmb":"t"}"#, settingEncryption: AttachmentEncryption(algorithm: "alg", attachmentId: "id", key: "7b64ReeCOhm0NOUU1jMyLzNHwQVjgtI9p8MEvF5k6C4"))
        try seed(bytes, url: "ENCRYPTED-OBJECT", metadata: enc)

        let new = attachment(tid: 1, filePath: try file(bytes).path)
        guard case .success(let link) = checksum(new, encryption: .required) else { return XCTFail("the checksum failed") }

        XCTAssertEqual(link, "ENCRYPTED-OBJECT")
        XCTAssertEqual(new.metadata, enc, "the reused object's enc comes with it")
        XCTAssertEqual(new.status, .done)
    }

    func testAnEncryptedSendNeverReusesAPlaintextObject() throws {
        let bytes = Data("plain bytes".utf8)
        try seed(bytes, url: "PLAIN-OBJECT", metadata: #"{"tmb":"t"}"#)

        let new = attachment(tid: 2, filePath: try file(bytes).path)
        guard case .success(let link) = checksum(new, encryption: .required) else { return XCTFail("the checksum failed") }

        XCTAssertNil(link, "a miss: the file is encrypted and uploaded")
        XCTAssertNil(new.metadata)
        XCTAssertNotEqual(new.status, .done)
    }

    func testAPlaintextSendReusesEitherKind() throws {
        let bytes = Data("plain again".utf8)
        try seed(bytes, url: "PLAIN-OBJECT-2", metadata: #"{"tmb":"t"}"#)

        for encryption in [nil, EncryptionRequirement.none] {
            let new = attachment(tid: 3, filePath: try file(bytes).path)
            guard case .success(let link) = checksum(new, encryption: encryption) else { return XCTFail("the checksum failed") }
            XCTAssertEqual(link, "PLAIN-OBJECT-2", "the legacy entry point is the plaintext policy")
        }
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
        guard case .success(let link) = checksum(new, encryption: nil) else { return XCTFail("the checksum failed") }

        XCTAssertNil(link, "a miss: the size is part of the match")
        XCTAssertNotEqual(new.status, .done)
    }

    /// A row whose key matches but whose stored object is of another size is not reused.
    func testAStoredObjectOfAnotherSizeIsNotReused() throws {
        let bytes = Data("sized bytes".utf8)
        let local = try file(bytes)
        try seed(Data("other".utf8), url: "OTHER-SIZE", metadata: #"{"tmb":"t"}"#, storedSize: 5, key: try XCTUnwrap(Components.storage.dedupeChecksum(filePath: local.path)))

        guard case .success(let link) = checksum(attachment(tid: 21, filePath: local.path), encryption: nil) else { return XCTFail("the checksum failed") }

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
            guard case .success(let link) = checksum(attachment(tid: 22, filePath: path, size: 0), encryption: nil) else { return XCTFail("the checksum failed") }
            XCTAssertNil(link, "\(path) never matches the 0 row")
        }
        XCTAssertEqual(checksumRows(0), 1, "only the seeded row: nothing new is recorded under 0")
    }

    /// Rows written before the size was part of the key hold a bare CRC32: never matched.
    func testARowWithTheOldKeyIsNotMatched() throws {
        let bytes = Data("legacy bytes".utf8)
        let local = try file(bytes)
        try seed(bytes, url: "LEGACY", metadata: #"{"tmb":"t"}"#, key: Int64(Components.storage.checksum(filePath: local.path)))

        guard case .success(let link) = checksum(attachment(tid: 23, filePath: local.path), encryption: nil) else { return XCTFail("the checksum failed") }

        XCTAssertNil(link)
        XCTAssertEqual(checksumRows(try XCTUnwrap(Components.storage.dedupeChecksum(filePath: local.path))), 1, "recorded under the new key for the next send")
    }

    func testNothingToChecksum() {
        for attachment in [attachment(tid: 4, filePath: nil), ChatMessage.Attachment(id: 0, tid: 5, messageId: 0, userId: "u", url: "https://x", filePath: "/tmp/x", type: "link", name: nil, metadata: nil, uploadedFileSize: 0, createdAt: Date())] {
            guard case .success(nil) = checksum(attachment, encryption: .required) else { return XCTFail("\(attachment)") }
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

extension ChecksumEncryptionTests {

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
        guard case .success(nil) = checksum(new, encryption: nil) else { return XCTFail() }
    }

    func testARecordThatFailsFailsTheChecksum() throws {
        _ = faulty(writes: [1])
        let new = attachment(tid: 34, filePath: try file(Data("record".utf8)).path)
        guard case .failure = checksum(new, encryption: nil) else { return XCTFail("the upload fails with it") }
    }

    func testARowWhoseObjectNoAttachmentHasIsAMiss() throws {
        let bytes = Data("orphan row".utf8)
        let local = try file(bytes)
        let key = try XCTUnwrap(Components.storage.dedupeChecksum(filePath: local.path))
        try database.syncWrite { $0.createOrUpdate(checksum: .init(checksum: key, messageTid: 1, attachmentTid: 1, data: "NOBODY-HAS-IT")) }

        guard case .success(nil) = checksum(attachment(tid: 35, filePath: local.path), encryption: nil) else { return XCTFail() }
    }

    func testAFailedLookupOfTheStoredAttachmentFailsTheChecksum() throws {
        let bytes = Data("second read".utf8)
        try seed(bytes, url: "STORED-READ", metadata: #"{"tmb":"t"}"#)
        _ = faulty(reads: [2])
        guard case .failure = checksum(attachment(tid: 36, filePath: try file(bytes).path), encryption: nil) else { return XCTFail() }
    }

    func testAHitThatCannotBePersistedFailsTheChecksum() throws {
        let bytes = Data("hit write".utf8)
        try seed(bytes, url: "STORED-WRITE", metadata: #"{"tmb":"t"}"#)
        _ = faulty(writes: [1])
        guard case .failure = checksum(attachment(tid: 37, filePath: try file(bytes).path), encryption: nil) else { return XCTFail() }
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
        provider.startChecksum(message: message, attachment: hit, encryption: .none) { result = $0 }
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
            provider.startChecksum(message: message, attachment: new, encryption: .none) { result = $0 }
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
