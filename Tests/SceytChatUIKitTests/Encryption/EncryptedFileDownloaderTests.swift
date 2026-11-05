//
//  EncryptedFileDownloaderTests.swift
//  SceytChatUIKitTests
//
//  UIKit's encrypted download (architecture doc §10): the transport fetches ciphertext to
//  `<destination>.sceyt.enc.part`, UIKit verifies and decrypts it, resumably, and publishes
//  the plaintext only once every record was verified.
//

import XCTest
@testable import SceytChatUIKit

final class EncryptedFileDownloaderTests: XCTestCase {
    private var directory: URL!
    private var downloader: EncryptedFileDownloader!
    private let encryption = ChatSDKFileEncryption()

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("efd-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        downloader = EncryptedFileDownloader(directory: directory.appendingPathComponent("sessions", isDirectory: true))
        // A checkpoint per chunk, so a stop part way leaves a saved offset in small files.
        downloader.checkpointLength = Int64(EncryptedFileDownloader.chunkLength)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    // MARK: Fixtures

    private func object(size: Int) async throws -> (object: URL, info: EncryptedFileInfo, plaintext: Data) {
        let plaintext = Data((0..<size).map { UInt8(truncatingIfNeeded: $0 &* 31) })
        let source = directory.appendingPathComponent("plain-\(UUID().uuidString)")
        try plaintext.write(to: source)
        let object = directory.appendingPathComponent("object-\(UUID().uuidString)")
        let info = try await encryption.encrypt(file: source, to: object)
        return (object, info, plaintext)
    }

    private var destination: URL { directory.appendingPathComponent("files/report.pdf") }

    private func request(_ operationId: String = "download-1") -> FileDownloadRequest {
        FileDownloadRequest(operationId: operationId, url: "https://files.example/x", destinationFile: destination)
    }

    /// A transport that writes `object` where it is asked to.
    private func serving(_ object: URL, fetched: Locked<[FileDownloadRequest]>? = nil) -> (FileDownloadRequest, @escaping (Double) -> Void) async -> FileTransferResult<URL> {
        { request, progress in
            fetched?.wrapped.append(request)
            do {
                try FileManager.default.copyItem(at: object, to: request.destinationFile)
            } catch {
                return .failure(error)
            }
            progress(1)
            return .success(request.destinationFile)
        }
    }

    /// Runs `work` in a task cancelled from its progress callback once `condition` holds.
    private func cancelled(
        when condition: @escaping (Double) -> Bool,
        _ work: @escaping (@escaping (Double) -> Void) async -> FileTransferResult<URL>
    ) async -> FileTransferResult<URL> {
        let handle = Locked<Task<FileTransferResult<URL>, Never>?>(nil)
        let started = Locked(false)
        let task = Task {
            while !started.wrapped { await Task.yield() }
            return await work { value in
                if condition(value) { handle.wrapped?.cancel() }
            }
        }
        handle.wrapped = task
        started.wrapped = true
        return await task.value
    }

    private func leftovers() -> [String] {
        let folder = destination.deletingLastPathComponent()
        return ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted()
    }

    // MARK: Tests

    func testCiphertextIsFetchedToStagingThenDecryptedAndPublished() async throws {
        let (object, info, plaintext) = try await object(size: 3 * EncryptedFileDownloader.chunkLength + 17)
        let fetched = Locked<[FileDownloadRequest]>([])
        var progress = [Double]()

        let result = await downloader.download(
            request(),
            encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: Int64(plaintext.count)),
            fileEncryption: encryption,
            progress: { progress.append($0) },
            downloadCiphertext: serving(object, fetched: fetched)
        )

        guard case .success(let published) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(published, destination)
        XCTAssertEqual(try Data(contentsOf: destination), plaintext)
        XCTAssertEqual(fetched.wrapped.map(\.destinationFile.lastPathComponent), ["report.pdf.sceyt.enc.part"])
        XCTAssertEqual(leftovers(), ["report.pdf"], "no temporary file is left")
        XCTAssertNil(downloader.store.get("download-1"), "the session goes once published")
        XCTAssertEqual(progress.first, 0.9)
        XCTAssertEqual(progress.last, 1)
        XCTAssertEqual(progress, progress.sorted(), "progress never goes back")
    }

    func testWithoutATrustedSizeItIsDerivedFromTheObject() async throws {
        let (object, info, plaintext) = try await object(size: 70_000)
        let result = await downloader.download(
            request(),
            encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: nil),
            fileEncryption: encryption,
            progress: { _ in },
            downloadCiphertext: serving(object)
        )
        guard case .success = result else { return XCTFail("\(result)") }
        XCTAssertEqual(try Data(contentsOf: destination), plaintext)
    }

    func testATamperedObjectPublishesNothingAndDiscardsItsFiles() async throws {
        let (object, info, plaintext) = try await object(size: 5000)
        var bytes = try Data(contentsOf: object)
        bytes[200] ^= 0x01
        try bytes.write(to: object)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("previous".utf8).write(to: destination)

        let result = await downloader.download(
            request(),
            encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: Int64(plaintext.count)),
            fileEncryption: encryption,
            progress: { _ in },
            downloadCiphertext: serving(object)
        )

        guard case .failure(let error) = result, case .decryptionFailed = error as? AttachmentEncryptionError else {
            return XCTFail("\(result)")
        }
        XCTAssertEqual(try Data(contentsOf: destination), Data("previous".utf8), "an unverified object never replaces a file")
        XCTAssertEqual(leftovers(), ["report.pdf"])
        XCTAssertNil(downloader.store.get("download-1"))
    }

    func testATransportFailureDiscardsAndAnInterruptionKeeps() async throws {
        let (_, info, _) = try await object(size: 100)
        let encryptionSpec = FileDownloadEncryption(info: info, trustedPlaintextSize: 100)

        let interrupted = await downloader.download(request(), encryption: encryptionSpec, fileEncryption: encryption, progress: { _ in }) { request, _ in
            try? Data("half".utf8).write(to: request.destinationFile)
            return .interrupted(URLError(.networkConnectionLost))
        }
        guard case .interrupted = interrupted else { return XCTFail("\(interrupted)") }
        XCTAssertNotNil(downloader.store.get("download-1"), "kept for the next attempt")
        XCTAssertTrue(leftovers().contains("report.pdf.sceyt.enc.part"), "the transport's partial file is its own to resume")

        let failed = await downloader.download(request(), encryption: encryptionSpec, fileEncryption: encryption, progress: { _ in }) { _, _ in
            .failure(URLError(.badServerResponse))
        }
        guard case .failure = failed else { return XCTFail("\(failed)") }
        XCTAssertNil(downloader.store.get("download-1"))
        XCTAssertEqual(leftovers(), [], "a failure removes the partial ciphertext")
    }

    /// A decryption stopped part way continues from the saved offset; the ciphertext is not
    /// fetched again.
    func testAStoppedDecryptionResumesFromItsSavedOffset() async throws {
        let size = 4 * EncryptedFileDownloader.chunkLength + 5
        let (object, info, plaintext) = try await object(size: size)
        let spec = FileDownloadEncryption(info: info, trustedPlaintextSize: Int64(size))
        let fetched = Locked<[FileDownloadRequest]>([])

        // First attempt: cancelled once two chunks are written.
        let first = await cancelled(when: { $0 >= 0.9 + 0.1 * 2 / 4 }) { progress in
            await self.downloader.download(self.request(), encryption: spec, fileEncryption: self.encryption, progress: progress, downloadCiphertext: self.serving(object, fetched: fetched))
        }
        guard case .interrupted = first else { return XCTFail("\(first)") }
        let saved = try XCTUnwrap(downloader.store.get("download-1"))
        XCTAssertGreaterThan(saved.plaintextOffset, 0)
        XCTAssertLessThan(saved.plaintextOffset, Int64(size))
        XCTAssertTrue(leftovers().contains("report.pdf.sceyt.enc"), "the complete ciphertext is kept")
        XCTAssertFalse(leftovers().contains("report.pdf"))

        var progress = [Double]()
        let second = await downloader.download(request(), encryption: spec, fileEncryption: encryption, progress: { progress.append($0) }, downloadCiphertext: serving(object, fetched: fetched))
        guard case .success = second else { return XCTFail("\(second)") }
        XCTAssertEqual(try Data(contentsOf: destination), plaintext)
        XCTAssertEqual(fetched.wrapped.count, 1, "the ciphertext was not fetched again")
        XCTAssertGreaterThan(try XCTUnwrap(progress.dropFirst().first), 0.9, "resumed past the start")
        XCTAssertEqual(leftovers(), ["report.pdf"])
    }

    func testDiscardRemovesEveryTemporaryFileButNotThePublishedOne() throws {
        let folder = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for name in ["report.pdf", "report.pdf.sceyt.enc", "report.pdf.sceyt.enc.part", "report.pdf.sceyt.part"] {
            try Data("x".utf8).write(to: folder.appendingPathComponent(name))
        }
        try downloader.store.save("download-1", EncryptedDownloadSession(source: "s", destination: destination.path))

        downloader.discard("download-1")
        downloader.discard("download-1")

        XCTAssertEqual(leftovers(), ["report.pdf"])
        XCTAssertNil(downloader.store.get("download-1"))
    }

    func testASessionOfAnotherDestinationIsDiscardedFirst() async throws {
        let (object, info, plaintext) = try await object(size: 300)
        let other = directory.appendingPathComponent("other/file.bin")
        try FileManager.default.createDirectory(at: other.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("stale".utf8).write(to: URL(fileURLWithPath: other.path + ".sceyt.enc"))
        try downloader.store.save("download-1", EncryptedDownloadSession(source: "s", destination: other.path, plaintextOffset: 7))

        let result = await downloader.download(request(), encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: 300), fileEncryption: encryption, progress: { _ in }, downloadCiphertext: serving(object))

        guard case .success = result else { return XCTFail("\(result)") }
        XCTAssertEqual(try Data(contentsOf: destination), plaintext)
        XCTAssertFalse(FileManager.default.fileExists(atPath: other.path + ".sceyt.enc"), "the other destination's files went with its session")
    }

    func testThePurgeRemovesOnlyStaleSessionsAndTheirFiles() throws {
        let folder = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let staleFile = folder.appendingPathComponent("report.pdf.sceyt.enc")
        try Data("x".utf8).write(to: staleFile)
        try downloader.store.save("stale", EncryptedDownloadSession(source: "s", destination: destination.path))
        try downloader.store.save("fresh", EncryptedDownloadSession(source: "s", destination: directory.appendingPathComponent("f").path))

        downloader.purgeStale(olderThan: 60, now: Date().addingTimeInterval(120))
        XCTAssertNil(downloader.store.get("stale"))
        XCTAssertNil(downloader.store.get("fresh"), "both are older than 60 s at that time")
        XCTAssertFalse(FileManager.default.fileExists(atPath: staleFile.path))

        try downloader.store.save("fresh", EncryptedDownloadSession(source: "s", destination: directory.appendingPathComponent("f").path))
        downloader.purgeStale(olderThan: 60)
        XCTAssertNotNil(downloader.store.get("fresh"))
    }

    func testTheSessionNeverHoldsTheKey() async throws {
        let (object, info, _) = try await object(size: 3 * EncryptedFileDownloader.chunkLength)
        _ = await cancelled(when: { $0 > 0.9 }) { progress in
            await self.downloader.download(self.request(), encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: nil), fileEncryption: self.encryption, progress: progress, downloadCiphertext: self.serving(object))
        }
        let files = try FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent("sessions"), includingPropertiesForKeys: nil)
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let text = try String(contentsOf: file)
            XCTAssertFalse(text.contains(info.key))
        }
    }
}

// MARK: - Verification failures, restarts, edge cases

extension EncryptedFileDownloaderTests {

    private func expectDecryptionFailure(
        _ result: FileTransferResult<URL>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(let error) = result, case .decryptionFailed = error as? AttachmentEncryptionError else {
            return XCTFail("expected decryptionFailed, got \(result)", file: file, line: line)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path), "nothing unverified is published", file: file, line: line)
        XCTAssertEqual(leftovers(), [], "a failure leaves no temporary file", file: file, line: line)
        XCTAssertNil(downloader.store.get("download-1"), file: file, line: line)
    }

    func testAWrongKeyFailsVerification() async throws {
        let (object, info, plaintext) = try await object(size: 5000)
        let wrong = EncryptedFileInfo(algorithm: info.algorithm, attachmentId: info.attachmentId, key: "7b64ReeCOhm0NOUU1jMyLzNHwQVjgtI9p8MEvF5k6C4")
        let result = await downloader.download(request(), encryption: FileDownloadEncryption(info: wrong, trustedPlaintextSize: Int64(plaintext.count)), fileEncryption: encryption, progress: { _ in }, downloadCiphertext: serving(object))
        expectDecryptionFailure(result)
    }

    func testAWrongAttachmentIdFailsVerification() async throws {
        let (object, info, plaintext) = try await object(size: 5000)
        let (_, other, _) = try await self.object(size: 10)
        let wrong = EncryptedFileInfo(algorithm: info.algorithm, attachmentId: other.attachmentId, key: info.key)
        let result = await downloader.download(request(), encryption: FileDownloadEncryption(info: wrong, trustedPlaintextSize: Int64(plaintext.count)), fileEncryption: encryption, progress: { _ in }, downloadCiphertext: serving(object))
        expectDecryptionFailure(result)
    }

    func testAWrongTrustedSizeFailsVerification() async throws {
        let (object, info, plaintext) = try await object(size: 70_000)
        let result = await downloader.download(request(), encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: Int64(plaintext.count - 1)), fileEncryption: encryption, progress: { _ in }, downloadCiphertext: serving(object))
        expectDecryptionFailure(result)
    }

    func testATruncatedObjectFailsVerification() async throws {
        let (object, info, plaintext) = try await object(size: 200_000)
        let bytes = try Data(contentsOf: object)
        try bytes.prefix(bytes.count - 100).write(to: object)
        let result = await downloader.download(request(), encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: Int64(plaintext.count)), fileEncryption: encryption, progress: { _ in }, downloadCiphertext: serving(object))
        expectDecryptionFailure(result)
    }

    func testAnObjectNoFileEncryptsToFailsWithoutATrustedSize() async throws {
        let (_, info, _) = try await object(size: 10)
        let junk = directory.appendingPathComponent("junk")
        try Data(repeating: 1, count: 10).write(to: junk)
        let result = await downloader.download(request(), encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: nil), fileEncryption: encryption, progress: { _ in }, downloadCiphertext: serving(junk))
        expectDecryptionFailure(result)
    }

    func testAnEmptyFileIsPublished() async throws {
        let (object, info, plaintext) = try await object(size: 0)
        let result = await downloader.download(request(), encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: 0), fileEncryption: encryption, progress: { _ in }, downloadCiphertext: serving(object))
        guard case .success = result else { return XCTFail("\(result)") }
        XCTAssertEqual(try Data(contentsOf: destination), plaintext)
        XCTAssertEqual(leftovers(), ["report.pdf"])
    }

    /// The saved offset is past what the partial plaintext holds (it was cut): start over.
    func testAPartialPlaintextShorterThanItsSavedOffsetStartsOver() async throws {
        let size = 3 * EncryptedFileDownloader.chunkLength
        let (object, info, plaintext) = try await object(size: size)
        let spec = FileDownloadEncryption(info: info, trustedPlaintextSize: Int64(size))
        _ = await cancelled(when: { $0 >= 0.9 + 0.1 * 2 / 3 }) { progress in
            await self.downloader.download(self.request(), encryption: spec, fileEncryption: self.encryption, progress: progress, downloadCiphertext: self.serving(object))
        }
        let saved = try XCTUnwrap(downloader.store.get("download-1"))
        XCTAssertGreaterThan(saved.plaintextOffset, 0)
        let partial = EncryptedFileDownloader.partialPlaintextFile(for: destination)
        try FileHandle(forWritingTo: partial).truncate(atOffset: 10)

        var progress = [Double]()
        let result = await downloader.download(request(), encryption: spec, fileEncryption: encryption, progress: { progress.append($0) }, downloadCiphertext: serving(object))
        guard case .success = result else { return XCTFail("\(result)") }
        XCTAssertEqual(try Data(contentsOf: destination), plaintext)
        // The first decrypted chunk is a third of the bar's last tenth: it started at 0.
        XCTAssertLessThan(try XCTUnwrap(progress.dropFirst().first), 0.9 + 0.1 * 0.5, "decrypted from the start again")
    }

    /// The complete ciphertext changed under a stopped decryption (another object): the
    /// plaintext written from the old one is not kept.
    func testAReplacedCiphertextRestartsTheDecryption() async throws {
        let size = 3 * EncryptedFileDownloader.chunkLength
        let (object, info, _) = try await object(size: size)
        _ = await cancelled(when: { $0 >= 0.9 + 0.1 * 2 / 3 }) { progress in
            await self.downloader.download(self.request(), encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: Int64(size)), fileEncryption: self.encryption, progress: progress, downloadCiphertext: self.serving(object))
        }
        XCTAssertGreaterThan(try XCTUnwrap(downloader.store.get("download-1")).plaintextOffset, 0)

        let (replacement, newInfo, newPlaintext) = try await self.object(size: size)
        let ciphertext = EncryptedFileDownloader.ciphertextFile(for: destination)
        try FileManager.default.removeItem(at: ciphertext)
        try FileManager.default.copyItem(at: replacement, to: ciphertext)

        let result = await downloader.download(request(), encryption: FileDownloadEncryption(info: newInfo, trustedPlaintextSize: Int64(size)), fileEncryption: encryption, progress: { _ in }, downloadCiphertext: serving(replacement))
        guard case .success = result else { return XCTFail("\(result)") }
        XCTAssertEqual(try Data(contentsOf: destination), newPlaintext)
    }

    /// A cleanup that could not finish is finished before the next download of the operation.
    func testASessionMarkedForDiscardIsCleanedFirst() async throws {
        let (object, info, plaintext) = try await object(size: 500)
        let folder = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("stale plaintext".utf8).write(to: EncryptedFileDownloader.partialPlaintextFile(for: destination))
        try Data("stale ciphertext".utf8).write(to: EncryptedFileDownloader.ciphertextFile(for: destination))
        try downloader.store.save("download-1", EncryptedDownloadSession(source: "old", destination: destination.path, plaintextOffset: 5, discardRequested: true))
        let fetched = Locked<[FileDownloadRequest]>([])

        let result = await downloader.download(request(), encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: 500), fileEncryption: encryption, progress: { _ in }, downloadCiphertext: serving(object, fetched: fetched))

        guard case .success = result else { return XCTFail("\(result)") }
        XCTAssertEqual(try Data(contentsOf: destination), plaintext)
        XCTAssertEqual(fetched.wrapped.count, 1, "the stale ciphertext was not trusted: fetched again")
    }

    /// The transport stopped because the task was cancelled: interrupted, kept.
    func testACancelledFetchIsAnInterruptionThatKeepsItsSession() async throws {
        let (_, info, _) = try await object(size: 100)
        let result = await cancelled(when: { _ in true }) { progress in
            await self.downloader.download(self.request(), encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: 100), fileEncryption: self.encryption, progress: progress) { _, progress in
                progress(0.5)
                return .interrupted(CancellationError())
            }
        }
        guard case .interrupted = result else { return XCTFail("\(result)") }
        XCTAssertNotNil(downloader.store.get("download-1"))
    }

    // MARK: prepareDecryption

    private func session(size: Int) async throws -> (FileDecryptionSession, Data) {
        let (object, info, plaintext) = try await object(size: size)
        return (try await encryption.prepareDecryption(encryptedFile: object, encryptionInfo: info, plaintextSize: Int64(size)), plaintext)
    }

    func testADecryptionSessionReadsExactRangesAtTheEdges() async throws {
        let (session, plaintext) = try await session(size: 2 * 65_536 + 3)
        defer { session.close() }
        XCTAssertEqual(session.plaintextSize, Int64(plaintext.count))
        XCTAssertFalse(session.sourceId.isEmpty)
        XCTAssertEqual(try session.read(offset: 0, length: plaintext.count), plaintext)
        XCTAssertEqual(try session.read(offset: 0, length: 1), plaintext.prefix(1))
        XCTAssertEqual(try session.read(offset: 65_535, length: 2), plaintext.subdata(in: 65_535..<65_537), "across a record boundary")
        XCTAssertEqual(try session.read(offset: Int64(plaintext.count - 1), length: 1), plaintext.suffix(1))
        XCTAssertEqual(try session.read(offset: 100, length: 50), try session.read(offset: 100, length: 50), "a range read again is the same")
        XCTAssertThrowsError(try session.read(offset: Int64(plaintext.count), length: 1), "past the end")
    }

    func testAClosedDecryptionSessionCannotBeRead() async throws {
        let (session, _) = try await session(size: 100)
        session.close()
        session.close()
        XCTAssertThrowsError(try session.read(offset: 0, length: 10))
    }

    func testPrepareDecryptionRefusesANegativeSizeAndAMissingFile() async throws {
        let (object, info, _) = try await object(size: 10)
        do {
            _ = try await encryption.prepareDecryption(encryptedFile: object, encryptionInfo: info, plaintextSize: -1)
            XCTFail("a negative size")
        } catch {
            guard case .invalidEncryptionInfo = error as? AttachmentEncryptionError else { return XCTFail("\(error)") }
        }
        do {
            _ = try await encryption.prepareDecryption(encryptedFile: directory.appendingPathComponent("missing"), encryptionInfo: info, plaintextSize: 10)
            XCTFail("nothing to open")
        } catch {}
    }

    func testTheSourceIdNamesTheFileAsOpened() async throws {
        let (object, info, _) = try await object(size: 100)
        let first = try await encryption.prepareDecryption(encryptedFile: object, encryptionInfo: info, plaintextSize: 100)
        let second = try await encryption.prepareDecryption(encryptedFile: object, encryptionInfo: info, plaintextSize: 100)
        XCTAssertEqual(first.sourceId, second.sourceId)
        first.close(); second.close()
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000)], ofItemAtPath: object.path)
        let touched = try await encryption.prepareDecryption(encryptedFile: object, encryptionInfo: info, plaintextSize: 100)
        XCTAssertNotEqual(touched.sourceId, first.sourceId, "a changed file is another source")
        touched.close()
    }
}

// MARK: - Audit fixes: a cancel's cleanup vs a restart, checkpoints

extension EncryptedFileDownloaderTests {

    /// A cancel's cleanup that lands while a new run of the same operation works leaves that
    /// run's files alone; it applies once nothing runs.
    func testACleanupDuringANewerRunSkipsItsFiles() async throws {
        let (object, info, plaintext) = try await object(size: 1000)
        let gate = Locked(false)
        let run = Task {
            await self.downloader.download(self.request(), encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: 1000), fileEncryption: self.encryption, progress: { _ in }) { request, progress in
                try? Data("partial".utf8).write(to: request.destinationFile)
                while !gate.wrapped { try? await Task.sleep(nanoseconds: 2_000_000) }
                try? FileManager.default.removeItem(at: request.destinationFile)
                return await self.serving(object)(request, progress)
            }
        }
        while !FileManager.default.fileExists(atPath: EncryptedFileDownloader.partialCiphertextFile(for: destination).path) {
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        XCTAssertTrue(downloader.isRunning("download-1"))

        downloader.discard("download-1")
        XCTAssertNotNil(downloader.store.get("download-1"), "the running download keeps its session")
        XCTAssertTrue(FileManager.default.fileExists(atPath: EncryptedFileDownloader.partialCiphertextFile(for: destination).path))

        gate.wrapped = true
        let result = await run.value
        guard case .success = result else { return XCTFail("\(result)") }
        XCTAssertEqual(try Data(contentsOf: destination), plaintext)
        XCTAssertFalse(downloader.isRunning("download-1"))
    }

    /// A run whose task was cancelled and whose transport then failed leaves its files for
    /// whoever cancelled it (a restart may be using them).
    func testACancelledRunDoesNotDiscardOnItsWayOut() async throws {
        let (_, info, _) = try await object(size: 100)
        let result = await cancelled(when: { _ in true }) { progress in
            await self.downloader.download(self.request(), encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: 100), fileEncryption: self.encryption, progress: progress) { request, progress in
                try? Data("half".utf8).write(to: request.destinationFile)
                progress(0.5)
                return .failure(FileTransferError.cancelled)
            }
        }
        guard case .interrupted = result else { return XCTFail("\(result)") }
        XCTAssertNotNil(downloader.store.get("download-1"))
        XCTAssertTrue(leftovers().contains("report.pdf.sceyt.enc.part"))
    }

    /// Progress is synced and saved every `checkpointLength` bytes and at the end, not per chunk.
    func testCheckpointsAreSavedEveryCheckpointLengthAndAtTheEnd() throws {
        let chunk = Int64(EncryptedFileDownloader.chunkLength)
        let total = EncryptedFileDownloader.defaultCheckpointLength * 2 + chunk + 5
        let session = ZeroSession(plaintextSize: total)
        let partial = directory.appendingPathComponent("partial")
        FileManager.default.createFile(atPath: partial.path, contents: nil)
        var saved = [Int64]()
        try EncryptedFileDownloader.writePlaintext(from: session, to: partial, start: 0, total: total, cancelled: CancelFlag(), checkpoint: { saved.append($0) }, progress: { _ in })
        XCTAssertEqual(saved, [0, EncryptedFileDownloader.defaultCheckpointLength, EncryptedFileDownloader.defaultCheckpointLength * 2, total])
        XCTAssertEqual(try FileCiphertextSource.size(of: partial), UInt64(total))
    }

    func testWritingResumesAtTheStartAndDropsATailPastIt() throws {
        let session = ZeroSession(plaintextSize: 100, byte: 7)
        let partial = directory.appendingPathComponent("partial")
        try Data(repeating: 1, count: 80).write(to: partial)
        var saved = [Int64]()
        try EncryptedFileDownloader.writePlaintext(from: session, to: partial, start: 40, total: 100, cancelled: CancelFlag(), checkpoint: { saved.append($0) }, progress: { _ in })
        let bytes = try Data(contentsOf: partial)
        XCTAssertEqual(bytes.count, 100)
        XCTAssertEqual(bytes.prefix(40), Data(repeating: 1, count: 40), "what was saved stays")
        XCTAssertEqual(bytes.suffix(60), Data(repeating: 7, count: 60), "the rest is written again")
        XCTAssertEqual(saved, [40, 100])
    }

    func testACancelFlagStopsTheWriting() {
        let flag = CancelFlag()
        flag.set()
        let partial = directory.appendingPathComponent("partial")
        FileManager.default.createFile(atPath: partial.path, contents: nil)
        XCTAssertThrowsError(try EncryptedFileDownloader.writePlaintext(from: ZeroSession(plaintextSize: 10), to: partial, start: 0, total: 10, cancelled: flag, checkpoint: { _ in }, progress: { _ in })) {
            XCTAssertTrue($0 is CancellationError)
        }
    }

    func testDiscardAlsoRemovesTheTransportsResumeData() throws {
        let folder = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let resume = DefaultFileTransferTransport.resumeDataFile(operationId: "download-1")
        try FileManager.default.createDirectory(at: resume.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("resume".utf8).write(to: resume)
        try downloader.store.save("download-1", EncryptedDownloadSession(source: "s", destination: destination.path))
        downloader.discard("download-1")
        XCTAssertFalse(FileManager.default.fileExists(atPath: resume.path))
    }
}

/// Plaintext of one repeated byte.
private final class ZeroSession: FileDecryptionSession {
    let sourceId = "zero"
    let plaintextSize: Int64
    let byte: UInt8
    init(plaintextSize: Int64, byte: UInt8 = 0) {
        self.plaintextSize = plaintextSize
        self.byte = byte
    }
    func read(offset: Int64, length: Int) throws -> Data { Data(repeating: byte, count: length) }
    func close() {}
}

// MARK: - Review fixes: one run per operation, purge

extension EncryptedFileDownloaderTests {

    /// A second run of an operation (a restart right after a stop) waits for the first to end
    /// instead of writing the same files at the same time.
    func testRunsOfOneOperationDoNotOverlap() async throws {
        let (object, info, plaintext) = try await object(size: 2000)
        let active = Locked(0)
        let peak = Locked(0)
        let fetch: (FileDownloadRequest, @escaping (Double) -> Void) async -> FileTransferResult<URL> = { request, progress in
            active.wrapped += 1
            peak.wrapped = max(peak.wrapped, active.wrapped)
            try? await Task.sleep(nanoseconds: 50_000_000)
            active.wrapped -= 1
            return await self.serving(object)(request, progress)
        }
        let spec = FileDownloadEncryption(info: info, trustedPlaintextSize: 2000)
        async let first = downloader.download(request(), encryption: spec, fileEncryption: encryption, progress: { _ in }, downloadCiphertext: fetch)
        async let second = downloader.download(request(), encryption: spec, fileEncryption: encryption, progress: { _ in }, downloadCiphertext: fetch)
        let (a, b) = await (first, second)
        guard case .success = a, case .success = b else { return XCTFail("\(a) \(b)") }
        XCTAssertEqual(peak.wrapped, 1, "never two runs of one operation at once")
        XCTAssertEqual(try Data(contentsOf: destination), plaintext)
    }

    /// The startup purge leaves alone a stale session whose operation is running.
    func testThePurgeSkipsAnOperationThatIsRunning() async throws {
        let (object, info, _) = try await object(size: 500)
        let gate = Locked(false)
        let run = Task {
            await self.downloader.download(self.request(), encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: 500), fileEncryption: self.encryption, progress: { _ in }) { request, progress in
                while !gate.wrapped { try? await Task.sleep(nanoseconds: 2_000_000) }
                return await self.serving(object)(request, progress)
            }
        }
        while downloader.store.get("download-1") == nil { try await Task.sleep(nanoseconds: 2_000_000) }

        downloader.purgeStale(olderThan: 0, now: Date().addingTimeInterval(3600))
        XCTAssertNotNil(downloader.store.get("download-1"), "its run is using it")

        gate.wrapped = true
        guard case .success = await run.value else { return XCTFail("the run was disturbed") }
    }

    func testTheTemporaryFilesAreTheOnesADownloadLeaves() {
        let names = EncryptedFileDownloader.temporaryFiles(for: destination).map(\.lastPathComponent)
        XCTAssertEqual(Set(names), ["report.pdf.sceyt.part", "report.pdf.sceyt.enc", "report.pdf.sceyt.enc.part"])
    }
}

extension EncryptedFileDownloaderTests {
    /// Builds before `EncryptedFileDownloader` decrypted into hidden `.<uuid>-<name>` files; a
    /// download of the same destination removes the ones a crash left.
    func testOldHiddenDecryptionFilesOfTheDestinationAreRemoved() async throws {
        let (object, info, _) = try await object(size: 100)
        let folder = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let old = folder.appendingPathComponent(".\(UUID().uuidString)-report.pdf")
        let young = folder.appendingPathComponent(".\(UUID().uuidString)-report.pdf")
        try Data("x".utf8).write(to: old)
        try Data("x".utf8).write(to: young)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-3600)], ofItemAtPath: old.path)
        _ = await downloader.download(request(), encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: 100), fileEncryption: encryption, progress: { _ in }, downloadCiphertext: serving(object))
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: young.path), "may belong to a publish still running")
    }

    /// The ciphertext goes before the session record: a crash in between can't leave a copy
    /// nothing finds.
    func testAPublishedDownloadLeavesNeitherCiphertextNorSession() async throws {
        let (object, info, _) = try await object(size: 3000)
        _ = await downloader.download(request(), encryption: FileDownloadEncryption(info: info, trustedPlaintextSize: 3000), fileEncryption: encryption, progress: { _ in }, downloadCiphertext: serving(object))
        XCTAssertFalse(FileManager.default.fileExists(atPath: EncryptedFileDownloader.ciphertextFile(for: destination).path))
        XCTAssertNil(downloader.store.get("download-1"))
    }

    func testADecryptionSessionIsClosedOnceHoweverOftenItIsClosed() async throws {
        let (object, info, _) = try await object(size: 100)
        let session = try await encryption.prepareDecryption(encryptedFile: object, encryptionInfo: info, plaintextSize: 100)
        session.close()
        session.close()
        XCTAssertThrowsError(try session.read(offset: 0, length: 1))
    }
}
