//
//  AttachmentTransferEncryptionGateTests.swift
//  SceytChatUIKitTests
//
//  Fail-closed rules 1-4, the two-size contract, the SDK's encryption metadata, the
//  `FileEncryption` facade and how `TransportDataSession` drives a `FileTransferTransport`.
//

@testable import SceytChatUIKit
import SceytChat
import XCTest

// MARK: - Fakes

/// A transport whose behaviour each test sets. Records every call.
private final class FakeTransport: FileTransferTransport {
    var onUpload: (FileUploadRequest) async -> FileTransferResult<FileUploadResult> = { _ in .success(FileUploadResult(url: "REMOTE")) }
    var onDownload: (FileDownloadRequest) async -> FileTransferResult<URL> = { _ in .failure(URLError(.badURL)) }
    var pausesInPlace = true

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
        return await onUpload(request)
    }

    func download(_ request: FileDownloadRequest, progress: @escaping (Double) -> Void) async -> FileTransferResult<URL> {
        lock.lock(); _downloads.append(request); lock.unlock()
        return await onDownload(request)
    }

    func pause(operationId: String) -> Bool {
        lock.lock(); _paused.append(operationId); lock.unlock()
        return pausesInPlace
    }

    func resume(operationId: String) -> Bool {
        lock.lock(); _resumed.append(operationId); lock.unlock()
        return pausesInPlace
    }

    func cancel(operationId: String) {
        lock.lock(); _cancelled.append(operationId); lock.unlock()
    }
}

/// The router under test, storing everything under one temporary directory.
private final class TestSession: TransportDataSession {
    var encrypts = true
    let root: URL

    init(transport: FileTransferTransport, root: URL) {
        self.root = root
        super.init(transport: transport)
    }

    override var supportsAttachmentEncryption: Bool { encrypts }
    override var checksumsBeforeUpload: Bool { false }
    override var stagingDirectory: URL { root.appendingPathComponent("staging", isDirectory: true) }

    override func storeFile(atPath path: String, transferId: String, fileName: String?) -> String {
        let folder = root.appendingPathComponent("store/\(transferId)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(fileName ?? (path as NSString).lastPathComponent)
        guard path != destination.path else { return path }
        try? FileManager.default.copyItem(atPath: path, toPath: destination.path)
        return destination.path
    }

    override func downloadDestination(for attachment: ChatMessage.Attachment) -> URL? {
        let folder = root.appendingPathComponent("downloads/\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(attachment.name ?? "file")
    }
}

/// Holds an upload until the test lets it go.
private final class Gate {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<FileTransferResult<FileUploadResult>, Never>?
    private var result: FileTransferResult<FileUploadResult>?

    func wait() async -> FileTransferResult<FileUploadResult> {
        await withCheckedContinuation { continuation in
            lock.lock()
            if let result {
                lock.unlock()
                continuation.resume(returning: result)
                return
            }
            self.continuation = continuation
            lock.unlock()
        }
    }

    func open(_ result: FileTransferResult<FileUploadResult>) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        if continuation == nil { self.result = result }
        lock.unlock()
        continuation?.resume(returning: result)
    }
}

// MARK: - Tests

final class AttachmentTransferEncryptionGateTests: XCTestCase {

    private var transfer: AttachmentTransfer!
    private var transport: FakeTransport!
    private var session: TestSession!
    private var directory: URL!
    private var originalDatabase: Database!

    private let messageId: MessageId = 901
    private var encryption: FileEncryption { Components.fileEncryption }

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalDatabase = DataProvider.database
        DataProvider.database = MockDatabase()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("enc-gate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        transport = FakeTransport()
        session = TestSession(transport: transport, root: directory)
        transfer = AttachmentTransfer()
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

    private func file(size: Int) throws -> URL {
        let url = directory.appendingPathComponent("plain-\(UUID().uuidString).bin")
        try Data((0..<size).map { UInt8(truncatingIfNeeded: $0 &* 13) }).write(to: url)
        return url
    }

    private func makeAttachment(tid: Int64 = 1, url: String? = nil, filePath: String? = nil, metadata: String? = nil) -> ChatMessage.Attachment {
        .init(
            id: 0,
            tid: tid,
            messageId: messageId,
            userId: "user",
            url: url,
            filePath: filePath,
            type: "file",
            name: "report.pdf",
            metadata: metadata,
            uploadedFileSize: 0,
            createdAt: Date()
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

    /// Uploads one attachment and returns the error the transfer completed with.
    private func upload(_ attachment: ChatMessage.Attachment) -> Error? {
        var finished = false
        var result: Error?
        transfer.uploadMessageAttachments(message: makeMessage([attachment]), attachments: [attachment]) { _, error in
            result = error
            finished = true
        }
        XCTAssertTrue(waitUntil { finished }, "the upload never completed")
        return result
    }

    private func download(_ attachment: ChatMessage.Attachment) -> Error? {
        var finished = false
        var result: Error?
        transfer.downloadMessageAttachments(message: makeMessage([attachment]), attachments: [attachment]) { _, error in
            result = error
            finished = true
        }
        XCTAssertTrue(waitUntil { finished }, "the download never completed")
        return result
    }

    /// What a transport does with an encrypted request: a session of the facade, all of it read.
    private func encryptedUpload(_ request: FileUploadRequest, into ciphertext: URL) async -> FileTransferResult<FileUploadResult> {
        do {
            let session = try await encryption.prepareEncryption(file: request.sourceFile)
            defer { session.close() }
            try session.materialize(to: ciphertext)
            return .success(FileUploadResult(url: "REMOTE-UUID", encryptionInfo: session.encryptionInfo))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Rule 1: unsupported session

    func testRequiredEncryptionOnAPlaintextSessionFailsWithoutUploading() throws {
        session.encrypts = false
        let attachment = makeAttachment(filePath: try file(size: 100).path)

        let error = upload(attachment)

        guard case .encryptionUnsupportedBySession = error as? AttachmentEncryptionError else {
            return XCTFail("expected encryptionUnsupportedBySession, got \(String(describing: error))")
        }
        XCTAssertTrue(transport.uploads.isEmpty, "a plaintext session must never be handed the file")
        XCTAssertEqual(attachment.status, .failedUploading)
        XCTAssertNil(attachment.url)
    }

    // MARK: - Upload through the transport

    func testEncryptedUploadCarriesEncAndThePlaintextSize() throws {
        let plaintext = try file(size: 5000)
        let attachment = makeAttachment(filePath: plaintext.path)
        let ciphertext = directory.appendingPathComponent("cipher")
        transport.onUpload = { request in
            XCTAssertEqual(request.type, .encrypted)
            XCTAssertEqual(request.operationId, "upload-1")
            XCTAssertEqual(request.fileName, "report.pdf")
            XCTAssertEqual(request.mimeType, "application/pdf")
            XCTAssertTrue((request.context as? AttachmentTransferContext)?.attachment === attachment)
            return await self.encryptedUpload(request, into: ciphertext)
        }

        let error = upload(attachment)

        XCTAssertNil(error)
        XCTAssertEqual(attachment.status, .done)
        XCTAssertEqual(attachment.url, "REMOTE-UUID")
        let enc = try XCTUnwrap(attachment.encryption, "enc must ride in the metadata")
        XCTAssertEqual(enc.algorithm, StreamingAeadFileEncryptionProvider.format)
        XCTAssertEqual(enc.attachmentId.count, 22, "16 random bytes, base64url")
        XCTAssertTrue(enc.renditions.isEmpty)
        let object = try XCTUnwrap(
            (try JSONSerialization.jsonObject(with: Data(attachment.metadata!.utf8)) as? [String: Any])?["enc"] as? [String: Any]
        )
        XCTAssertEqual(Set(object.keys), ["v", "alg", "attachmentId", "key"])
        XCTAssertEqual(object["v"] as? Int, 1)
        XCTAssertFalse(attachment.metadata!.contains(FileEncryptionMetadata.field), "only enc, not the SDK's own field")
        XCTAssertEqual(attachment.uploadedFileSize, 5000, "the message shows the original size, not the object's")
        XCTAssertNotEqual(try Data(contentsOf: ciphertext).prefix(5000), try Data(contentsOf: plaintext).prefix(5000))

        // The receiver can decrypt with what the message carries.
        let output = directory.appendingPathComponent("decrypted")
        let decrypted = expectation(description: "decrypted")
        Task {
            try await self.encryption.decrypt(file: ciphertext, to: output, encryptionInfo: enc.fileInfo, plaintextSize: nil)
            decrypted.fulfill()
        }
        wait(for: [decrypted], timeout: 5)
        XCTAssertEqual(try Data(contentsOf: output), try Data(contentsOf: plaintext))
    }

    // MARK: - Rule 2: success without the encryption

    func testEncryptedSuccessWithoutEncryptionInfoIsRejected() throws {
        let attachment = makeAttachment(filePath: try file(size: 100).path)
        transport.onUpload = { _ in .success(FileUploadResult(url: "PLAINTEXT-UUID")) }

        let error = upload(attachment)

        guard case .encryptionBypassed = error as? AttachmentEncryptionError else {
            return XCTFail("expected encryptionBypassed, got \(String(describing: error))")
        }
        XCTAssertNil(attachment.url, "a bypassed upload must not look delivered")
        XCTAssertEqual(attachment.status, .failedUploading)
        XCTAssertNil(attachment.encryption)
    }

    // MARK: - RC1: legacy path untouched

    func testPlaintextPolicySendsAPlainRequest() throws {
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
        let attachment = makeAttachment(filePath: try file(size: 100).path)

        XCTAssertNil(upload(attachment))

        XCTAssertEqual(transport.uploads.first?.type, .plain)
        XCTAssertEqual(attachment.url, "REMOTE")
        XCTAssertNil(attachment.encryption)
        XCTAssertFalse(attachment.isEncrypted)
    }

    // MARK: - Downloads

    private func encryptedRemote(size: Int) async throws -> (attachment: ChatMessage.Attachment, ciphertext: URL, plaintext: Data) {
        let plaintext = try file(size: size)
        let ciphertext = directory.appendingPathComponent("remote-\(UUID().uuidString)")
        let info = try await encryption.encrypt(file: plaintext, to: ciphertext)
        let metadata = try ChatMessage.Attachment.metadata(#"{"tmb":""}"#, settingEncryption: AttachmentEncryption(info: info))
        let attachment = makeAttachment(tid: 0, url: "REMOTE-\(UUID().uuidString)", metadata: metadata)
        return (attachment, ciphertext, try Data(contentsOf: plaintext))
    }

    private func remote(size: Int) throws -> (attachment: ChatMessage.Attachment, ciphertext: URL, plaintext: Data) {
        var made: Result<(ChatMessage.Attachment, URL, Data), Error>?
        Task {
            do {
                made = .success(try await self.encryptedRemote(size: size))
            } catch {
                made = .failure(error)
            }
        }
        XCTAssertTrue(waitUntil { made != nil })
        return try XCTUnwrap(made).get()
    }

    /// The transport's part: hands the stored object to the default publishing step.
    private func serve(_ ciphertext: URL) {
        transport.onDownload = { request in
            let staging = self.directory.appendingPathComponent("staging-\(UUID().uuidString)")
            do {
                try FileManager.default.copyItem(at: ciphertext, to: staging)
                try await DefaultFileTransferTransport.publish(staging, to: request, encryption: self.encryption)
                return .success(request.destinationFile)
            } catch {
                return .failure(error)
            }
        }
    }

    func testEncryptedDownloadIsDecryptedBeforeItCountsAsDone() throws {
        let remote = try remote(size: 3 * (1 << 20) + 11)
        serve(remote.ciphertext)

        XCTAssertNil(download(remote.attachment))

        let request = try XCTUnwrap(transport.downloads.first)
        XCTAssertEqual(request.encryptionInfo, remote.attachment.encryption?.fileInfo)
        XCTAssertEqual(request.url, remote.attachment.url)
        XCTAssertEqual(remote.attachment.status, .done)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: try XCTUnwrap(remote.attachment.filePath))), remote.plaintext)
        XCTAssertEqual(remote.attachment.uploadedFileSize, UInt(remote.plaintext.count))
        XCTAssertNotNil(remote.attachment.encryption, "updateLocalFileURL must not drop enc")
    }

    func testTamperedDownloadFailsAndLeavesNoPlaintext() throws {
        let remote = try remote(size: 500)
        var bytes = try Data(contentsOf: remote.ciphertext)
        bytes[100] ^= 0x01
        try bytes.write(to: remote.ciphertext)
        serve(remote.ciphertext)

        let error = download(remote.attachment)

        guard case .decryptionFailed(let reason) = error as? AttachmentEncryptionError,
              (reason as NSError).domain == FileEncryptionErrorDomain,
              (reason as NSError).code == FileEncryptionError.authentication.rawValue
        else { return XCTFail("\(String(describing: error))") }
        XCTAssertEqual(remote.attachment.status, .failedDownloading)
        let destination = try XCTUnwrap(transport.downloads.first?.destinationFile)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testMalformedEncryptionInfoIsRejectedBeforeFetching() throws {
        let remote = try remote(size: 500)
        remote.attachment.metadata = #"{"tmb":"","enc":{"v":2,"alg":"x","attachmentId":"a","key":"k"}}"#
        XCTAssertTrue(remote.attachment.isEncrypted, "an unreadable enc is never plaintext")
        XCTAssertNil(remote.attachment.encryption)

        let error = download(remote.attachment)

        guard case .invalidEncryptionInfo = error as? AttachmentEncryptionError else {
            return XCTFail("expected invalidEncryptionInfo, got \(String(describing: error))")
        }
        XCTAssertTrue(transport.downloads.isEmpty, "nothing is fetched for a malformed enc")
        XCTAssertEqual(remote.attachment.status, .failedDownloading)
    }

    func testEncryptedDownloadOnAPlaintextSessionIsNotFetched() throws {
        session.encrypts = false
        let remote = try remote(size: 500)

        let error = download(remote.attachment)

        guard case .encryptionUnsupportedBySession = error as? AttachmentEncryptionError else {
            return XCTFail("expected encryptionUnsupportedBySession, got \(String(describing: error))")
        }
        XCTAssertTrue(transport.downloads.isEmpty)
    }

    // MARK: - Control

    func testAPauseInPlaceResumesTheSameInvocation() throws {
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
        let gate = Gate()
        transport.onUpload = { _ in await gate.wait() }
        let attachment = makeAttachment(filePath: try file(size: 100).path)
        var finished = false
        transfer.uploadMessageAttachments(message: makeMessage([attachment]), attachments: [attachment]) { _, _ in finished = true }
        XCTAssertTrue(waitUntil { self.transport.uploads.count == 1 })
        let task = try XCTUnwrap(transfer.allTasks.first)

        task.stop()
        XCTAssertEqual(transport.paused, ["upload-1"])
        task.resume()
        XCTAssertTrue(waitUntil { self.transport.resumed == ["upload-1"] })
        gate.open(.success(FileUploadResult(url: "REMOTE")))

        XCTAssertTrue(waitUntil { finished })
        XCTAssertEqual(transport.uploads.count, 1, "the paused invocation continued; no second upload")
        XCTAssertEqual(attachment.url, "REMOTE")
    }

    func testAPauseTheTransportCannotHoldStartsANewAttemptOnResume() throws {
        transfer.environment.keyProvider = { InlineAttachmentKeyProvider() }
        transport.pausesInPlace = false
        let gate = Gate()
        transport.onUpload = { _ in
            await withTaskCancellationHandler {
                await gate.wait()
            } onCancel: {
                gate.open(.interrupted(CancellationError()))
            }
        }
        let attachment = makeAttachment(filePath: try file(size: 100).path)
        var finished = false
        transfer.uploadMessageAttachments(message: makeMessage([attachment]), attachments: [attachment]) { _, _ in finished = true }
        XCTAssertTrue(waitUntil { self.transport.uploads.count == 1 })
        let task = try XCTUnwrap(transfer.allTasks.first)

        task.stop()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertFalse(finished, "an interruption by a pause is not a failure")
        transport.onUpload = { _ in .success(FileUploadResult(url: "SECOND")) }
        task.resume()

        XCTAssertTrue(waitUntil { finished })
        XCTAssertEqual(transport.uploads.map(\.operationId), ["upload-1", "upload-1"], "the same operation, so saved work is found")
        XCTAssertEqual(attachment.url, "SECOND")
    }

    func testCancellingASavedUploadReachesTheTransport() {
        session.cancel(attachments: [makeAttachment(tid: 77)])
        XCTAssertEqual(transport.cancelled, ["upload-77"])
    }

    // MARK: - Metadata

    func testEncryptionSurvivesAMediaMetadataRebuild() throws {
        let encryption = AttachmentEncryption(
            algorithm: StreamingAeadFileEncryptionProvider.format,
            attachmentId: "t7qA7hJJlA8x9sgMjck7Qg",
            key: "Rx3aNGnrgKqgOFEAC_3pg44jSri5YmYPP0U374KYztU",
            renditions: [.init(role: "thumbnail", attachmentId: "_6uFmwHgdmPV1Se7LJBaZw", key: "gki1f9gzn6QMjD64as0shiT_cChCh-CekjAreTl4a2w")]
        )
        let original = try ChatMessage.Attachment.metadata(#"{"szw":1,"szh":2,"tmb":"x"}"#, settingEncryption: encryption)
        let rebuilt = ChatMessage.Attachment.Metadata<String>(width: 30, height: 40, thumbnail: "x").build()
        let merged = ChatMessage.Attachment.metadata(rebuilt, preservingEncryptionFrom: original)

        XCTAssertEqual(ChatMessage.Attachment.encryption(inMetadata: merged), encryption)
        XCTAssertEqual(try ChatMessage.Attachment.Metadata<String>.decode(merged!).width, 30)
        XCTAssertEqual(ChatMessage.Attachment.metadata(rebuilt, preservingEncryptionFrom: #"{"tmb":"x"}"#), rebuilt)
    }

    /// The example `enc` from the spec decodes as is.
    func testDecodesTheSpecExample() throws {
        let metadata = #"""
        {"szw":3810,"szh":1962,"tmb":"x/cBBIL7uYh6eHh6d3pGbp/19g==","dur":33,"video_thumb":"b9d80ec3-e1e9-442f-db3a-df545cad86bb",
         "enc":{"v":1,"alg":"tink-aes256-gcm-hkdf-64k+commit-v1","attachmentId":"t7qA7hJJlA8x9sgMjck7Qg",
                "key":"Rx3aNGnrgKqgOFEAC_3pg44jSri5YmYPP0U374KYztU",
                "renditions":[{"role":"thumbnail","attachmentId":"_6uFmwHgdmPV1Se7LJBaZw","key":"gki1f9gzn6QMjD64as0shiT_cChCh-CekjAreTl4a2w"}]}}
        """#
        let encryption = try XCTUnwrap(ChatMessage.Attachment.encryption(inMetadata: metadata))
        XCTAssertEqual(encryption.attachmentId, "t7qA7hJJlA8x9sgMjck7Qg")
        XCTAssertEqual(encryption.thumbnail?.attachmentId, "_6uFmwHgdmPV1Se7LJBaZw")
        XCTAssertEqual(encryption.thumbnail?.key, "gki1f9gzn6QMjD64as0shiT_cChCh-CekjAreTl4a2w")
    }

    /// `enc` has no size: the original size is derived from the stored object's, which must
    /// agree with what the SDK actually produces.
    func testDerivedPlaintextSizeMatchesTheSDK() async throws {
        let segment = 64 * 1024
        for size in [0, 1, segment - 56 - 1, segment - 56, segment - 56 + 1, segment - 16, 3 * segment + 7, 1 << 20] {
            let ciphertext = directory.appendingPathComponent("size-\(size)")
            let info = try await encryption.encrypt(file: try file(size: size), to: ciphertext)
            let stored = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: ciphertext.path)[.size] as? UInt64)
            XCTAssertEqual(AttachmentEncryption.ciphertextSize(plaintextSize: UInt64(size)), stored, "size \(size)")
            XCTAssertEqual(AttachmentEncryption.plaintextSize(ciphertextSize: stored), UInt64(size), "size \(size)")
            XCTAssertEqual(try AttachmentEncryption(info: info).fileEncryptionInfo(ciphertextSize: stored).data.plainSize, UInt64(size))
        }
        XCTAssertNil(AttachmentEncryption.plaintextSize(ciphertextSize: 10))
    }

    /// The poster is decrypted with its rendition's key, never the file's, and never stored
    /// when it doesn't verify.
    func testEncryptedVideoThumbnailIsDecryptedWithItsRendition() async throws {
        let poster = try file(size: 2000)
        let posterCipher = directory.appendingPathComponent("poster.enc")
        let posterInfo = try await encryption.encrypt(file: poster, to: posterCipher)
        let videoInfo = try await encryption.encrypt(file: try file(size: 100), to: directory.appendingPathComponent("video.enc"))
        let enc = AttachmentEncryption(info: videoInfo, renditions: [.init(role: AttachmentEncryption.Rendition.thumbnailRole, info: posterInfo)])
        let attachment = makeAttachment(metadata: try ChatMessage.Attachment.metadata(#"{"video_thumb":"T"}"#, settingEncryption: enc))

        let destination = directory.appendingPathComponent("thumb.jpg")
        let download = directory.appendingPathComponent("download-1")
        try FileManager.default.copyItem(at: posterCipher, to: download)
        try await AttachmentTransfer.storeVideoThumbnail(download, of: attachment, at: destination, encryption: encryption)
        XCTAssertEqual(try Data(contentsOf: destination), try Data(contentsOf: poster))

        // Signed for the video, not the poster: the poster's key must be used.
        let swapped = AttachmentEncryption(info: videoInfo, renditions: [.init(role: AttachmentEncryption.Rendition.thumbnailRole, info: videoInfo)])
        let tampered = makeAttachment(metadata: try ChatMessage.Attachment.metadata(#"{"video_thumb":"T"}"#, settingEncryption: swapped))
        let other = directory.appendingPathComponent("thumb2.jpg")
        let download2 = directory.appendingPathComponent("download-2")
        try FileManager.default.copyItem(at: posterCipher, to: download2)
        do {
            try await AttachmentTransfer.storeVideoThumbnail(download2, of: tampered, at: other, encryption: encryption)
            XCTFail("a poster under the wrong key must not be stored")
        } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: other.path))

        // Encrypted, but no poster key: nothing is shown.
        let noRendition = makeAttachment(metadata: try ChatMessage.Attachment.metadata(#"{"video_thumb":"T"}"#, settingEncryption: AttachmentEncryption(info: videoInfo)))
        let download3 = directory.appendingPathComponent("download-3")
        try FileManager.default.copyItem(at: posterCipher, to: download3)
        do {
            try await AttachmentTransfer.storeVideoThumbnail(download3, of: noRendition, at: other, encryption: encryption)
            XCTFail("an encrypted poster without its key must not be stored")
        } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: other.path))
    }

    // MARK: - FileEncryption (doc §5)

    /// A transport uploads by range: ranges are exact slices of the whole object, cut anywhere
    /// across the 64 KiB records, and a range read again gives the same bytes.
    func testRangesAreExactRepeatableSlicesOfTheObject() async throws {
        let session = try await encryption.prepareEncryption(file: try file(size: 300_000))
        defer { session.close() }
        let whole = directory.appendingPathComponent("whole")
        try session.materialize(to: whole)
        let expected = try Data(contentsOf: whole)
        XCTAssertEqual(Int64(expected.count), session.ciphertextSize)
        XCTAssertEqual(session.plaintextSize, 300_000)

        let cuts: [Int64] = [0, 1, 65_535, 65_536, 65_537, 200_000, session.ciphertextSize]
        var joined = Data()
        for (start, end) in zip(cuts, cuts.dropFirst()) {
            let part = directory.appendingPathComponent("part-\(start)")
            try session.write(start..<end, to: part)
            joined += try Data(contentsOf: part)
        }
        XCTAssertEqual(joined, expected)
        XCTAssertEqual(try session.read(offset: 65_000, length: 5_000), expected.subdata(in: 65_000..<70_000))
        XCTAssertEqual(try session.read(offset: 65_000, length: 5_000), try session.read(offset: 65_000, length: 5_000))
    }

    func testRestoredSessionMakesTheSameBytesUnderTheSameKey() async throws {
        let source = try file(size: 200_000)
        let first = try await encryption.prepareEncryption(file: source)
        let firstBytes = try first.read(offset: 0, length: Int(first.ciphertextSize))
        let checkpoint = first.checkpoint()
        let firstInfo = first.encryptionInfo
        let firstSourceId = first.sourceId
        first.close()
        // A transport serializes the checkpoint as a whole.
        let saved = try JSONDecoder().decode(EncryptedFileCheckpoint.self, from: JSONEncoder().encode(checkpoint))

        let restored = try await encryption.restoreEncryption(file: source, checkpoint: saved)
        defer { restored.close() }
        XCTAssertEqual(restored.encryptionInfo, firstInfo, "the same key and attachment id")
        XCTAssertEqual(restored.sourceId, firstSourceId)
        XCTAssertEqual(saved.plaintextSize, 200_000)
        XCTAssertEqual(try restored.read(offset: 0, length: Int(restored.ciphertextSize)), firstBytes, "parts already stored stay valid")
    }

    func testRestoreRejectsAChangedSourceAndAnUnreadableCheckpoint() async throws {
        let source = try file(size: 1000)
        let first = try await encryption.prepareEncryption(file: source)
        let checkpoint = first.checkpoint()
        first.close()
        try Data(repeating: 7, count: 1000).write(to: source)

        do {
            _ = try await encryption.restoreEncryption(file: source, checkpoint: checkpoint)
            XCTFail("a changed source must not continue the old session")
        } catch {}
        let unreadable = EncryptedFileCheckpoint(encryptionInfo: checkpoint.encryptionInfo, plaintextSize: 1000, data: "not a checkpoint")
        do {
            _ = try await encryption.restoreEncryption(file: source, checkpoint: unreadable)
            XCTFail("an unreadable checkpoint must be refused")
        } catch {
            guard case .invalidCheckpoint = error as? AttachmentEncryptionError else { return XCTFail("\(error)") }
        }
        // The transport starts over under a new key.
        let fresh = try await encryption.prepareEncryption(file: source)
        XCTAssertNotEqual(fresh.encryptionInfo.key, checkpoint.encryptionInfo.key)
        fresh.close()
    }
}
