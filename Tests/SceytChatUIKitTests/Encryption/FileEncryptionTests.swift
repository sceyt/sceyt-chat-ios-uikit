//
//  FileEncryptionTests.swift
//  SceytChatUIKitTests
//
//  `ChatSDKFileEncryption`, the default `FileEncryption`: snapshots, checkpoints and their
//  restore, decryption of tampered, truncated, mis-keyed or mis-sized objects (nothing is ever
//  left at the destination), range reads at the object's edges and the `write` / `encrypt`
//  helpers every transport relies on.
//

@testable import SceytChatUIKit
import SceytChat
import XCTest

// MARK: - Fakes

/// The SDK's provider, made to fail on request.
private final class FailingProvider: NSObject, FileEncryptionProvider {
    let real = StreamingAeadFileEncryptionProvider()
    var prepareError: Error?
    var openError: Error?
    private(set) var openedSources = [CiphertextRangeSource]()

    func prepareUpload(fileURL: URL, uniqueId: String) throws -> PreparedUpload {
        if let prepareError { throw prepareError }
        return try real.prepareUpload(fileURL: fileURL, uniqueId: uniqueId)
    }

    func restoreUpload(fileURL: URL, checkpoint: FileEncryptionCheckpoint) throws -> PreparedUpload {
        try real.restoreUpload(fileURL: fileURL, checkpoint: checkpoint)
    }

    func openDownload(source: CiphertextRangeSource, encryptionInfo: FileEncryptionInfo) throws -> PlaintextReader {
        openedSources.append(source)
        if let openError { throw openError }
        return try real.openDownload(source: source, encryptionInfo: encryptionInfo)
    }
}

/// A session whose reads fail from `failingOffset` on.
private final class BrokenSession: FileEncryptionSession {
    let sourceId = "broken"
    let plaintextSize: Int64 = 10
    let ciphertextSize: Int64
    let encryptionInfo = EncryptedFileInfo(algorithm: "a", attachmentId: "b", key: "zXgmf8ZVlpdTnfhSSh34q87xbERlhieF1MTFzn78ILw")
    let failingOffset: Int64
    private(set) var reads = [Range<Int64>]()
    private(set) var closed = false

    init(ciphertextSize: Int64, failingOffset: Int64) {
        self.ciphertextSize = ciphertextSize
        self.failingOffset = failingOffset
    }

    func read(offset: Int64, length: Int) throws -> Data {
        reads.append(offset..<offset + Int64(length))
        if offset + Int64(length) > failingOffset { throw CocoaError(.fileReadUnknown) }
        return Data(repeating: 0xAB, count: length)
    }

    func checkpoint() -> EncryptedFileCheckpoint {
        EncryptedFileCheckpoint(encryptionInfo: encryptionInfo, plaintextSize: plaintextSize, data: "broken")
    }

    func close() { closed = true }
}

/// A `FileEncryption` handing out a `BrokenSession`, or failing to.
private final class BrokenEncryption: FileEncryption {
    var session: BrokenSession?
    private(set) var discarded = [EncryptedFileCheckpoint]()

    func prepareEncryption(file: URL) async throws -> FileEncryptionSession {
        guard let session else { throw AttachmentEncryptionError.snapshotFailed(CocoaError(.fileNoSuchFile)) }
        return session
    }

    func restoreEncryption(file: URL, checkpoint: EncryptedFileCheckpoint) async throws -> FileEncryptionSession {
        throw AttachmentEncryptionError.invalidCheckpoint
    }

    func discard(_ checkpoint: EncryptedFileCheckpoint) { discarded.append(checkpoint) }

    func decrypt(file: URL, to destination: URL, encryptionInfo: EncryptedFileInfo, plaintextSize: Int64?) async throws {}
}

// MARK: - Tests

final class FileEncryptionTests: XCTestCase {

    private var encryption: ChatSDKFileEncryption!
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        encryption = ChatSDKFileEncryption()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("file-encryption-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        encryption = nil
        try super.tearDownWithError()
    }

    // MARK: Fixtures

    private func file(size: Int, seed: UInt8 = 13) throws -> URL {
        let url = directory.appendingPathComponent("plain-\(UUID().uuidString).bin")
        try Data((0..<size).map { UInt8(truncatingIfNeeded: $0 &* Int(seed)) }).write(to: url)
        return url
    }

    /// Encrypts a new file of `size` bytes; returns the object, its info and the plaintext.
    private func encrypted(size: Int) async throws -> (object: URL, info: EncryptedFileInfo, plaintext: Data) {
        let plaintext = try file(size: size)
        let object = directory.appendingPathComponent("object-\(UUID().uuidString)")
        let info = try await encryption.encrypt(file: plaintext, to: object)
        return (object, info, try Data(contentsOf: plaintext))
    }

    private func transferId(of session: FileEncryptionSession) throws -> String {
        try XCTUnwrap(session as? ChatSDKEncryptionSession).transferId
    }

    /// Decrypts and returns the error, asserting nothing is left at `destination`.
    private func decryptionError(
        _ object: URL,
        info: EncryptedFileInfo,
        plaintextSize: Int64? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> Error? {
        let destination = directory.appendingPathComponent("out-\(UUID().uuidString)")
        do {
            try await encryption.decrypt(file: object, to: destination, encryptionInfo: info, plaintextSize: plaintextSize)
            XCTFail("decryption must fail", file: file, line: line)
            return nil
        } catch {
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path), "a failed decryption leaves nothing", file: file, line: line)
            return error
        }
    }

    /// The SDK's reason inside `decryptionFailed`.
    private func reason(_ error: Error?, file: StaticString = #filePath, line: UInt = #line) -> NSError? {
        guard case .decryptionFailed(let reason) = error as? AttachmentEncryptionError else {
            XCTFail("expected decryptionFailed, got \(String(describing: error))", file: file, line: line)
            return nil
        }
        return reason as NSError
    }

    // MARK: - Prepare

    func testPrepareEncryptsAReadOnlySnapshotThatDiscardRemoves() async throws {
        let source = try file(size: 70_000)
        let session = try await encryption.prepareEncryption(file: source)
        let transferId = try transferId(of: session)
        let snapshot = AttachmentEncryptionFiles.snapshot(transferId: transferId)

        XCTAssertEqual(session.plaintextSize, 70_000)
        XCTAssertEqual(UInt64(session.ciphertextSize), AttachmentEncryption.ciphertextSize(plaintextSize: 70_000))
        XCTAssertEqual(session.encryptionInfo.algorithm, StreamingAeadFileEncryptionProvider.format)
        XCTAssertEqual(session.encryptionInfo.attachmentId.count, 22)
        XCTAssertFalse(session.sourceId.isEmpty)
        XCTAssertEqual(try Data(contentsOf: snapshot), try Data(contentsOf: source))
        let permissions = try FileManager.default.attributesOfItem(atPath: snapshot.path)[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o400, "the snapshot is never written again")
        XCTAssertTrue(snapshot.path.hasPrefix(AttachmentEncryptionFiles.transfersDirectory.path))

        let checkpoint = session.checkpoint()
        XCTAssertEqual(checkpoint.encryptionInfo, session.encryptionInfo)
        XCTAssertEqual(checkpoint.plaintextSize, 70_000)
        XCTAssertFalse(checkpoint.data.contains(checkpoint.encryptionInfo.key), "the opaque data has no key")
        session.close()
        XCTAssertTrue(FileManager.default.fileExists(atPath: snapshot.path), "closing keeps what a restore needs")

        encryption.discard(checkpoint)
        XCTAssertFalse(FileManager.default.fileExists(atPath: AttachmentEncryptionFiles.directory(transferId: transferId).path))
    }

    func testEverySessionHasItsOwnKeyAndId() async throws {
        let source = try file(size: 100)
        let first = try await encryption.prepareEncryption(file: source)
        let second = try await encryption.prepareEncryption(file: source)
        defer {
            for session in [first, second] {
                session.close()
                encryption.discard(session.checkpoint())
            }
        }
        XCTAssertNotEqual(first.encryptionInfo.key, second.encryptionInfo.key)
        XCTAssertNotEqual(first.encryptionInfo.attachmentId, second.encryptionInfo.attachmentId)
        XCTAssertNotEqual(first.sourceId, second.sourceId)
        XCTAssertNotEqual(try first.read(offset: 0, length: 180), try second.read(offset: 0, length: 180))
    }

    func testPrepareOfAMissingFileFailsWithSnapshotFailed() async {
        do {
            _ = try await encryption.prepareEncryption(file: directory.appendingPathComponent("missing"))
            XCTFail("nothing to encrypt")
        } catch {
            guard case .snapshotFailed = error as? AttachmentEncryptionError else {
                return XCTFail("expected snapshotFailed, got \(error)")
            }
        }
    }

    func testPrepareRethrowsTheProvidersErrorAndRemovesItsSnapshot() async throws {
        let provider = FailingProvider()
        provider.prepareError = NSError(domain: FileEncryptionErrorDomain, code: FileEncryptionError.invalidArgument.rawValue)
        encryption = ChatSDKFileEncryption(provider: { provider })
        let before = Set((try? FileManager.default.contentsOfDirectory(atPath: AttachmentEncryptionFiles.transfersDirectory.path)) ?? [])

        do {
            _ = try await encryption.prepareEncryption(file: try file(size: 100))
            XCTFail("the provider failed")
        } catch {
            XCTAssertEqual((error as NSError).code, FileEncryptionError.invalidArgument.rawValue)
        }
        let after = Set((try? FileManager.default.contentsOfDirectory(atPath: AttachmentEncryptionFiles.transfersDirectory.path)) ?? [])
        XCTAssertTrue(after.isSubset(of: before), "the snapshot of the failed session is removed")
    }

    // MARK: - Restore

    func testRestoreFallsBackToTheFileWhenTheSnapshotIsGone() async throws {
        let source = try file(size: 5000)
        let first = try await encryption.prepareEncryption(file: source)
        let bytes = try first.read(offset: 0, length: Int(first.ciphertextSize))
        let checkpoint = first.checkpoint()
        first.close()
        // The snapshot is a clone of the unchanged file: the SDK checks size and mtime.
        try FileManager.default.removeItem(at: AttachmentEncryptionFiles.snapshot(transferId: try transferId(of: first)))

        let restored = try await encryption.restoreEncryption(file: source, checkpoint: checkpoint)
        defer { restored.close(); encryption.discard(checkpoint) }

        XCTAssertEqual(restored.encryptionInfo, checkpoint.encryptionInfo)
        XCTAssertEqual(try restored.read(offset: 0, length: Int(restored.ciphertextSize)), bytes)
    }

    func testRestoreRejectsACheckpointOfAnotherVersionOrWithoutData() async throws {
        let info = EncryptedFileInfo(algorithm: StreamingAeadFileEncryptionProvider.format, attachmentId: "a", key: "7b64ReeCOhm0NOUU1jMyLzNHwQVjgtI9p8MEvF5k6C4")
        let saved = String(decoding: try JSONEncoder().encode(ChatSDKFileEncryption.SavedSession(transferId: "t", sdkData: "d")), as: UTF8.self)
        let otherVersion = saved.replacingOccurrences(of: #""v":1"#, with: #""v":2"#)
        XCTAssertNotEqual(otherVersion, saved)
        for data in [otherVersion, "", "{}", #"{"v":1}"#] {
            do {
                _ = try await encryption.restoreEncryption(file: try file(size: 10), checkpoint: EncryptedFileCheckpoint(encryptionInfo: info, plaintextSize: 10, data: data))
                XCTFail("\(data) must be refused")
            } catch {
                guard case .invalidCheckpoint = error as? AttachmentEncryptionError else {
                    return XCTFail("\(data): expected invalidCheckpoint, got \(error)")
                }
            }
        }
    }

    func testRestoreOfACheckpointWhoseSDKDataIsCorruptFails() async throws {
        let session = try await encryption.prepareEncryption(file: try file(size: 1000))
        let checkpoint = session.checkpoint()
        session.close()
        defer { encryption.discard(checkpoint) }
        let saved = try ChatSDKFileEncryption.SavedSession(checkpoint)
        let corrupt = EncryptedFileCheckpoint(
            encryptionInfo: checkpoint.encryptionInfo,
            plaintextSize: checkpoint.plaintextSize,
            data: ChatSDKFileEncryption.SavedSession(transferId: saved.transferId, sdkData: "garbage").encoded
        )

        do {
            _ = try await encryption.restoreEncryption(file: try file(size: 1000), checkpoint: corrupt)
            XCTFail("the SDK's state is unreadable")
        } catch {
            XCTAssertEqual((error as NSError).domain, FileEncryptionErrorDomain)
        }
    }

    func testDiscardOfAnUnreadableCheckpointDoesNothing() async throws {
        let session = try await encryption.prepareEncryption(file: try file(size: 10))
        let transferId = try transferId(of: session)
        let checkpoint = session.checkpoint()
        session.close()
        defer { encryption.discard(checkpoint) }

        encryption.discard(EncryptedFileCheckpoint(encryptionInfo: checkpoint.encryptionInfo, plaintextSize: 10, data: "garbage"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: AttachmentEncryptionFiles.snapshot(transferId: transferId).path))
    }

    func testSavedSessionRoundTrips() throws {
        let saved = ChatSDKFileEncryption.SavedSession(transferId: "T-1", sdkData: "{\"a\":1}")
        let info = EncryptedFileInfo(algorithm: "a", attachmentId: "b", key: "zXgmf8ZVlpdTnfhSSh34q87xbERlhieF1MTFzn78ILw")
        let decoded = try ChatSDKFileEncryption.SavedSession(EncryptedFileCheckpoint(encryptionInfo: info, plaintextSize: 1, data: saved.encoded))
        XCTAssertEqual(decoded.v, ChatSDKFileEncryption.SavedSession.version)
        XCTAssertEqual(decoded.transferId, "T-1")
        XCTAssertEqual(decoded.sdkData, "{\"a\":1}")
    }

    // MARK: - Sessions

    func testRangeReadsAtTheEdgesOfTheObject() async throws {
        let session = try await encryption.prepareEncryption(file: try file(size: 2 * 65_536))
        defer { session.close(); encryption.discard(session.checkpoint()) }
        let size = session.ciphertextSize
        let whole = try session.read(offset: 0, length: Int(size))
        XCTAssertEqual(Int64(whole.count), size)

        XCTAssertEqual(try session.read(offset: 0, length: 1), whole.prefix(1))
        XCTAssertEqual(try session.read(offset: size - 1, length: 1), whole.suffix(1))
        XCTAssertEqual(try session.read(offset: 65_535, length: 2), whole.subdata(in: 65_535..<65_537), "across a segment boundary")
        XCTAssertThrowsError(try session.read(offset: size, length: 1), "past the end")
        XCTAssertThrowsError(try session.read(offset: size - 1, length: 2), "overlapping the end")
    }

    func testAClosedSessionCannotBeRead() async throws {
        let session = try await encryption.prepareEncryption(file: try file(size: 100))
        let checkpoint = session.checkpoint()
        defer { encryption.discard(checkpoint) }
        session.close()
        session.close()

        XCTAssertThrowsError(try session.read(offset: 0, length: 10)) { error in
            XCTAssertEqual((error as NSError).code, FileEncryptionError.closed.rawValue)
        }
    }

    func testWriteOfARangeIntoAMissingFolderThrows() async throws {
        let session = try await encryption.prepareEncryption(file: try file(size: 100))
        defer { session.close(); encryption.discard(session.checkpoint()) }
        let url = directory.appendingPathComponent("missing/part")

        XCTAssertThrowsError(try session.write(0..<10, to: url)) { error in
            XCTAssertEqual((error as? CocoaError)?.code, .fileWriteUnknown)
        }
    }

    func testWriteReplacesAnOldFileAndAcceptsAnEmptyRange() throws {
        let session = BrokenSession(ciphertextSize: 3 << 20, failingOffset: .max)
        let url = directory.appendingPathComponent("part")
        try Data(repeating: 1, count: 50).write(to: url)

        try session.write(5..<5, to: url)
        XCTAssertEqual(try Data(contentsOf: url), Data(), "the old file is replaced")
        XCTAssertTrue(session.reads.isEmpty)

        try session.materialize(to: url)
        XCTAssertEqual(try Data(contentsOf: url).count, 3 << 20)
        XCTAssertEqual(session.reads, [0..<(1 << 20), (1 << 20)..<(2 << 20), (2 << 20)..<(3 << 20)], "read in 1 MiB chunks")
    }

    func testWriteRemovesThePartialFileWhenAReadFails() {
        let session = BrokenSession(ciphertextSize: 3 << 20, failingOffset: 2 << 20)
        let url = directory.appendingPathComponent("part")

        XCTAssertThrowsError(try session.materialize(to: url))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "no prefix of the object is left behind")
    }

    // MARK: - encrypt

    func testEncryptClosesAndDiscardsTheSessionWhenWritingFails() async {
        let broken = BrokenEncryption()
        let session = BrokenSession(ciphertextSize: 100, failingOffset: 0)
        broken.session = session

        do {
            _ = try await broken.encrypt(file: directory, to: directory.appendingPathComponent("out"))
            XCTFail("the session cannot be read")
        } catch {}
        XCTAssertTrue(session.closed)
        XCTAssertEqual(broken.discarded, [session.checkpoint()])
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("out").path))
    }

    func testEncryptPropagatesAFailedPrepare() async {
        let broken = BrokenEncryption()
        do {
            _ = try await broken.encrypt(file: directory, to: directory.appendingPathComponent("out"))
            XCTFail("nothing was prepared")
        } catch {
            guard case .snapshotFailed = error as? AttachmentEncryptionError else { return XCTFail("\(error)") }
        }
        XCTAssertTrue(broken.discarded.isEmpty)
    }

    func testEncryptLeavesNoSnapshotBehind() async throws {
        let before = Set((try? FileManager.default.contentsOfDirectory(atPath: AttachmentEncryptionFiles.transfersDirectory.path)) ?? [])
        _ = try await encrypted(size: 1000)
        let after = Set((try? FileManager.default.contentsOfDirectory(atPath: AttachmentEncryptionFiles.transfersDirectory.path)) ?? [])
        XCTAssertTrue(after.isSubset(of: before))
    }

    func testOffMainRunsOnAnotherThreadAndRethrows() async {
        let onMain = try? await FileEncryptionChunk.offMain { Thread.isMainThread }
        XCTAssertEqual(onMain, false)
        do {
            _ = try await FileEncryptionChunk.offMain { () throws -> Int in throw CocoaError(.fileReadUnknown) }
            XCTFail("the error must reach the caller")
        } catch {
            XCTAssertEqual((error as? CocoaError)?.code, .fileReadUnknown)
        }
    }

    // MARK: - Decrypt

    func testDecryptsWithADerivedOrAnExplicitSize() async throws {
        for size in [0, 1, 65_480, 65_481, 200_000] {
            let object = try await encrypted(size: size)
            for plaintextSize in [nil, Int64(size)] {
                let destination = directory.appendingPathComponent("out-\(UUID().uuidString)")
                try await encryption.decrypt(file: object.object, to: destination, encryptionInfo: object.info, plaintextSize: plaintextSize)
                XCTAssertEqual(try Data(contentsOf: destination), object.plaintext, "size \(size), given \(String(describing: plaintextSize))")
            }
        }
    }

    func testDecryptOfAnObjectNoFileEncryptsToFailsBeforeOpeningIt() async throws {
        let provider = FailingProvider()
        encryption = ChatSDKFileEncryption(provider: { provider })
        let object = directory.appendingPathComponent("short")
        try Data(repeating: 0, count: 10).write(to: object)

        let error = await decryptionError(object, info: EncryptedFileInfo(algorithm: StreamingAeadFileEncryptionProvider.format, attachmentId: "a", key: "7b64ReeCOhm0NOUU1jMyLzNHwQVjgtI9p8MEvF5k6C4"))

        guard case .decryptionFailed(let reason) = error as? AttachmentEncryptionError,
              case .invalidCiphertextSize(10) = reason as? AttachmentEncryptionError
        else { return XCTFail("expected invalidCiphertextSize(10), got \(String(describing: error))") }
        XCTAssertTrue(provider.openedSources.isEmpty, "nothing reaches the SDK")
    }

    func testDecryptWithAWrongTrustedSizeFails() async throws {
        let object = try await encrypted(size: 1000)
        for wrong: Int64 in [999, 1001, 0] {
            let reason = reason(await decryptionError(object.object, info: object.info, plaintextSize: wrong))
            XCTAssertEqual(reason?.domain, FileEncryptionErrorDomain, "size \(wrong)")
        }
    }

    /// A sender that could not tell the plaintext size sent the stored object's size: never a
    /// real plaintext size for that object, so the derived size is used instead of failing.
    func testATrustedSizeThatIsTheStoredObjectsIsReplacedByTheDerivedOne() async throws {
        let object = try await encrypted(size: 1000)
        let stored = try XCTUnwrap(TransferLog.size(object.object))
        let destination = directory.appendingPathComponent("out-\(UUID().uuidString)")

        try await encryption.decrypt(file: object.object, to: destination, encryptionInfo: object.info, plaintextSize: stored)

        XCTAssertEqual(try Data(contentsOf: destination), object.plaintext)
    }

    func testTamperedObjectFailsAuthentication() async throws {
        let object = try await encrypted(size: 200_000)
        let original = try Data(contentsOf: object.object)
        // In the first segment, in a later one and in the very last tag.
        for index in [100, 140_000, original.count - 1] {
            var bytes = original
            bytes[index] ^= 0x80
            try bytes.write(to: object.object)
            let reason = reason(await decryptionError(object.object, info: object.info))
            XCTAssertEqual(reason?.domain, FileEncryptionErrorDomain, "byte \(index)")
            XCTAssertEqual(reason?.code, FileEncryptionError.authentication.rawValue, "byte \(index)")
        }
    }

    func testTamperedCommitmentOrHeaderIsRejected() async throws {
        let object = try await encrypted(size: 1000)
        let original = try Data(contentsOf: object.object)
        for index in [0, 31, 32, 71] {
            var bytes = original
            bytes[index] ^= 0x01
            try bytes.write(to: object.object)
            let error = await decryptionError(object.object, info: object.info)
            XCTAssertEqual(reason(error)?.domain, FileEncryptionErrorDomain, "byte \(index)")
        }
    }

    func testTruncatedObjectFails() async throws {
        let object = try await encrypted(size: 3 * 65_536)
        let original = try Data(contentsOf: object.object)
        // One byte off still has a valid size, so only authentication can catch it; a
        // whole segment off leaves a valid object of fewer segments.
        for cut in [1, 16, 65_536] {
            try original.prefix(original.count - cut).write(to: object.object)
            let reason = reason(await decryptionError(object.object, info: object.info))
            XCTAssertEqual(reason?.domain, FileEncryptionErrorDomain, "cut \(cut)")
        }
        // With the trusted size the truncation is caught without reading.
        try original.prefix(original.count - 1).write(to: object.object)
        let error = await decryptionError(object.object, info: object.info, plaintextSize: 3 * 65_536)
        XCTAssertEqual(reason(error)?.domain, FileEncryptionErrorDomain)
    }

    func testWrongKeyOrAttachmentIdFails() async throws {
        let object = try await encrypted(size: 1000)
        let other = try await encrypted(size: 1000)
        let wrongKey = EncryptedFileInfo(algorithm: object.info.algorithm, attachmentId: object.info.attachmentId, key: other.info.key)
        let wrongId = EncryptedFileInfo(algorithm: object.info.algorithm, attachmentId: other.info.attachmentId, key: object.info.key)
        let malformedKey = EncryptedFileInfo(algorithm: object.info.algorithm, attachmentId: object.info.attachmentId, key: "short")
        let unknownAlgorithm = EncryptedFileInfo(algorithm: "rot13", attachmentId: object.info.attachmentId, key: object.info.key)

        for info in [wrongKey, wrongId, malformedKey, unknownAlgorithm] {
            let error = await decryptionError(object.object, info: info)
            XCTAssertEqual(reason(error)?.domain, FileEncryptionErrorDomain, "\(info.key.prefix(4)) \(info.algorithm)")
        }
    }

    func testOpenFailureIsReportedAndTheSourceClosed() async throws {
        let object = try await encrypted(size: 1000)
        let provider = FailingProvider()
        provider.openError = NSError(domain: FileEncryptionErrorDomain, code: FileEncryptionError.invalidEncryption.rawValue)
        encryption = ChatSDKFileEncryption(provider: { provider })

        let reason = reason(await decryptionError(object.object, info: object.info))

        XCTAssertEqual(reason?.code, FileEncryptionError.invalidEncryption.rawValue)
        XCTAssertEqual(provider.openedSources.count, 1)
    }

    func testDecryptOfAMissingObjectFails() async {
        let info = EncryptedFileInfo(algorithm: StreamingAeadFileEncryptionProvider.format, attachmentId: "a", key: "7b64ReeCOhm0NOUU1jMyLzNHwQVjgtI9p8MEvF5k6C4")
        let reason = reason(await decryptionError(directory.appendingPathComponent("missing"), info: info))
        XCTAssertEqual(reason?.domain, NSCocoaErrorDomain)
    }

    func testDecryptIntoAMissingFolderFails() async throws {
        let object = try await encrypted(size: 1000)
        let destination = directory.appendingPathComponent("missing/out")
        do {
            try await encryption.decrypt(file: object.object, to: destination, encryptionInfo: object.info, plaintextSize: nil)
            XCTFail("the destination cannot be created")
        } catch {
            let reason = reason(error)
            XCTAssertEqual(reason?.domain, NSCocoaErrorDomain)
            XCTAssertEqual(reason?.code, CocoaError.fileWriteUnknown.rawValue)
        }
    }

    // MARK: - FileCiphertextSource

    func testCiphertextSourceReadsExactRanges() throws {
        let url = try file(size: 100)
        let bytes = try Data(contentsOf: url)
        let source = try FileCiphertextSource(url: url)
        defer { source.close() }

        XCTAssertEqual(source.ciphertextSize, 100)
        XCTAssertEqual(try source.readCiphertextRange(offset: 0, length: 100), bytes)
        XCTAssertEqual(try source.readCiphertextRange(offset: 99, length: 1), bytes.suffix(1))
        XCTAssertEqual(try source.readCiphertextRange(offset: 10, length: 0), Data())
        XCTAssertThrowsError(try source.readCiphertextRange(offset: 90, length: 20), "short read") { error in
            XCTAssertEqual((error as? CocoaError)?.code, .fileReadCorruptFile)
        }
        XCTAssertThrowsError(try source.readCiphertextRange(offset: 200, length: 1), "past the end")
        XCTAssertThrowsError(try FileCiphertextSource(url: directory.appendingPathComponent("missing")))
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

extension FileEncryptionTests {

    /// Encrypts, decrypts (fine, mis-sized, tampered, truncated), restores and discards with
    /// logging at its most verbose: no key or checkpoint ever reaches a log line.
    func testNoKeyOrCheckpointIsEverLogged() async throws {
        let capture = LogCapture()
        defer { capture.stop() }

        let object = try await encrypted(size: 200_000)
        let destination = directory.appendingPathComponent("out-\(UUID().uuidString)")
        try await encryption.decrypt(file: object.object, to: destination, encryptionInfo: object.info, plaintextSize: nil)
        _ = await decryptionError(object.object, info: object.info, plaintextSize: 1)
        var bytes = try Data(contentsOf: object.object)
        bytes[100] ^= 0x80
        try bytes.write(to: object.object)
        _ = await decryptionError(object.object, info: object.info)
        try bytes.prefix(bytes.count - 10).write(to: object.object)
        _ = await decryptionError(object.object, info: object.info)

        let source = try file(size: 5_000)
        let session = try await encryption.prepareEncryption(file: source)
        let checkpoint = session.checkpoint()
        _ = try await encryption.restoreEncryption(file: source, checkpoint: checkpoint)
        let corrupt = EncryptedFileCheckpoint(encryptionInfo: checkpoint.encryptionInfo, plaintextSize: checkpoint.plaintextSize, data: "{\"v\":1,\"transferId\":\"x\",\"sdkData\":\"\(checkpoint.encryptionInfo.key)\"}")
        _ = try? await encryption.restoreEncryption(file: source, checkpoint: corrupt)
        let unreadable = EncryptedFileCheckpoint(encryptionInfo: checkpoint.encryptionInfo, plaintextSize: 1, data: "not json \(checkpoint.encryptionInfo.key)")
        _ = try? await encryption.restoreEncryption(file: source, checkpoint: unreadable)
        encryption.discard(unreadable)
        session.close()
        encryption.discard(checkpoint)

        // `enc` that cannot be read, and metadata `enc` cannot be added to.
        let enc = AttachmentEncryption(info: object.info)
        let badEnc = "{\"enc\":{\"v\":2,\"alg\":\"x\",\"attachmentId\":\"y\",\"key\":\"\(object.info.key)\"}}"
        XCTAssertNil(ChatMessage.Attachment.encryption(inMetadata: badEnc))
        XCTAssertThrowsError(try ChatMessage.Attachment.metadata("[\"\(object.info.key)\"]", settingEncryption: enc))

        let lines = capture.lines
        XCTAssertFalse(lines.isEmpty, "the flows above log")
        XCTAssertTrue(lines.contains { $0.contains("[Encryption] xfer=- attachmentId=\(object.info.attachmentId) decrypt failed") }, "a failed decryption is logged")
        XCTAssertTrue(lines.filter { $0.hasPrefix("[ERROR]") }.isEmpty, "the caller reports a failure, once: \(lines.filter { $0.hasPrefix("[ERROR]") })")
        for secret in [object.info.key, checkpoint.encryptionInfo.key, checkpoint.data] {
            XCTAssertFalse(lines.contains { $0.contains(secret) }, "a secret reached the logs")
        }
    }

    func testRedactionDropsQueryFragmentAndCredentials() {
        XCTAssertEqual(
            TransferLog.redact("https://user:pw@cdn.example.com/a/b/file.jpg?Signature=SECRET&Key-Pair-Id=K#frag"),
            "https://cdn.example.com/a/b/file.jpg"
        )
        XCTAssertEqual(TransferLog.redact("download-urlhttps://cdn.example.com/x/y.pdf?X-Amz-Signature=SECRET"), "download-urlhttps://cdn.example.com/x/y.pdf")
        XCTAssertEqual(TransferLog.redact("transfer-123"), "transfer-123")
        XCTAssertEqual(TransferLog.redact(nil as String?), "-")
        let failing = URLError(.timedOut, userInfo: [NSURLErrorFailingURLStringErrorKey: "https://cdn.example.com/x?Signature=SECRET"])
        XCTAssertFalse(TransferLog.describe(failing).contains("SECRET"))
        XCTAssertFalse(TransferLog.describe(AttachmentEncryptionError.decryptionFailed(failing)).contains("SECRET"))
        XCTAssertTrue(TransferLog.describe(CocoaError(.fileWriteOutOfSpace)).contains("disk full"))
    }
}

// MARK: - Coverage: sizes, failure kinds, the snapshot purge, TransferLog

extension FileEncryptionTests {

    func testATrustedSizeForAnImpossibleObjectIsUsedAsIs() throws {
        // 10 bytes: no file encrypts to that, so nothing can be derived.
        XCTAssertEqual(try ChatSDKFileEncryption.plaintextSize(trusted: 4, ciphertextSize: 10, label: "t"), 4)
    }

    func testFailureKinds() {
        XCTAssertEqual(ChatSDKFileEncryption.failureKind(CocoaError(.fileReadCorruptFile)), "short read (truncated ciphertext)")
        XCTAssertEqual(ChatSDKFileEncryption.failureKind(NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))), "disk full")
        XCTAssertEqual(ChatSDKFileEncryption.failureKind(CocoaError(.fileWriteOutOfSpace)), "disk full")
    }

    func testThePurgeRemovesOnlyStaleSnapshots() throws {
        let root = directory.appendingPathComponent("transfers", isDirectory: true)
        let stale = root.appendingPathComponent("stale", isDirectory: true)
        let fresh = root.appendingPathComponent("fresh", isDirectory: true)
        for folder in [stale, fresh] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-AttachmentEncryptionFiles.staleSnapshotAge - 60)],
            ofItemAtPath: stale.path
        )

        AttachmentEncryptionFiles.purgeStaleSnapshots(in: root)

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
        // Nothing to purge: nothing removed, nothing logged.
        AttachmentEncryptionFiles.purgeStaleSnapshots(in: root)
        AttachmentEncryptionFiles.purgeStaleSnapshots(in: directory.appendingPathComponent("missing"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
    }

    func testDescribeNamesEveryDecodingError() {
        let context = DecodingError.Context(codingPath: [], debugDescription: "x")
        XCTAssertEqual(TransferLog.describe(DecodingError.typeMismatch(Int.self, context)), "DecodingError.typeMismatch(<root>)")
        XCTAssertEqual(TransferLog.describe(DecodingError.valueNotFound(Int.self, context)), "DecodingError.valueNotFound(<root>)")
    }

    func testARemoveFailureIsLoggedUnlessTheFileIsAlreadyGone() {
        let url = directory.appendingPathComponent("x")
        let gone: [Error] = [
            NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT)),
            NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError, userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT))]),
        ]
        for error in gone {
            XCTAssertTrue(TransferLog.remove(url, what: "f", context: "t", removeItem: { _ in throw error }), "\(error)")
        }
        let denied = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError, userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))])
        XCTAssertFalse(TransferLog.remove(url, what: "f", context: "t", removeItem: { _ in throw denied }))
        XCTAssertFalse(TransferLog.remove(url, what: "f", context: "t", level: .error, removeItem: { _ in throw denied }))
    }
}

extension FileEncryptionTests {

    func testWithoutACachesFolderTransfersUseTheTemporaryOne() {
        XCTAssertEqual(TransferDirectories.cachesOrTemporary(caches: { nil }).standardizedFileURL.path, URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL.path)
    }

    func testASessionThatCannotBeEncodedIsAnEmptyCheckpoint() {
        XCTAssertEqual(ChatSDKFileEncryption.SavedSession(transferId: "t", sdkData: "d").encoded(using: { _ in throw CocoaError(.coderInvalidValue) }), "")
    }
}
