//
//  EncryptedFileDownloader.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//
//  An encrypted attachment's download (architecture doc §10, current flow; Android's
//  `EncryptedFileDownloader`): the transport fetches the ciphertext, then UIKit verifies and
//  decrypts it through `FileEncryption.prepareDecryption` and publishes the plaintext.
//

import CryptoKit
import Foundation

/// What an encrypted download is decrypted with.
struct FileDownloadEncryption: Sendable {
    let info: EncryptedFileInfo
    /// The original size the message carries; nil (or the stored object's own size) when the
    /// sender could not tell: it is then derived from the object's size.
    let trustedPlaintextSize: Int64?
}

/// Downloads ciphertext through a transport, then publishes verified plaintext.
///
/// Files next to the destination (the same names as on Android):
/// - `<destination>.sceyt.enc.part`: the transport writes the ciphertext here;
/// - `<destination>.sceyt.enc`: the complete ciphertext, kept until it is decrypted;
/// - `<destination>.sceyt.part`: the plaintext while it is decrypted, resumable.
/// The destination itself appears only once every record was verified.
final class EncryptedFileDownloader: @unchecked Sendable {
    /// Plaintext decrypted and written per step.
    static let chunkLength = 1024 * 1024
    /// Plaintext written between two synced checkpoints: what a crash can make the next
    /// attempt decrypt again.
    static let defaultCheckpointLength: Int64 = 8 * 1024 * 1024
    var checkpointLength = EncryptedFileDownloader.defaultCheckpointLength

    let store: EncryptedDownloadSessionStore
    private let runsLock = NSLock()
    /// The operations a run works on: one run per operation at a time.
    private var running = Set<String>()
    /// Runs waiting for the one working on their operation, in order.
    private var waiting = [String: [CheckedContinuation<Void, Never>]]()

    func isRunning(_ operationId: String) -> Bool {
        runsLock.lock(); defer { runsLock.unlock() }
        return running.contains(operationId)
    }

    /// Waits until no other run works on `operationId` (a restart right after a pause or a
    /// cancel: the stopped run may still be writing its files), then claims it.
    private func begin(_ operationId: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            runsLock.lock()
            if running.contains(operationId) {
                waiting[operationId, default: []].append(continuation)
                runsLock.unlock()
            } else {
                running.insert(operationId)
                runsLock.unlock()
                continuation.resume()
            }
        }
    }

    /// Hands `operationId` to the next waiting run, or releases it.
    private func end(_ operationId: String) {
        runsLock.lock()
        if var queue = waiting[operationId], !queue.isEmpty {
            let next = queue.removeFirst()
            waiting[operationId] = queue.isEmpty ? nil : queue
            runsLock.unlock()
            next.resume()
        } else {
            running.remove(operationId)
            runsLock.unlock()
        }
    }

    /// Discards sessions not touched for `age`, except those of operations a run works on.
    /// The directory is listed without the run lock; each session is checked and removed under
    /// it, so no run of a session being removed can start meanwhile.
    func purgeStale(olderThan age: TimeInterval, now: Date = Date()) {
        for file in store.staleFiles(olderThan: age, now: now) {
            runsLock.lock()
            let busy = running.contains { Self.hash([$0]) + ".json" == file.lastPathComponent }
            if !busy { store.purge(file) }
            runsLock.unlock()
        }
    }

    init(directory: URL) {
        store = EncryptedDownloadSessionStore(directory: directory)
    }

    static func ciphertextFile(for destination: URL) -> URL {
        URL(fileURLWithPath: destination.path + ".sceyt.enc")
    }

    static func partialCiphertextFile(for destination: URL) -> URL {
        URL(fileURLWithPath: destination.path + ".sceyt.enc.part")
    }

    static func partialPlaintextFile(for destination: URL) -> URL {
        URL(fileURLWithPath: destination.path + ".sceyt.part")
    }

    /// Every file a download of `destination` may leave next to it before it is published:
    /// what a cleanup removes (with the default transport's resume data, kept by operation).
    static func temporaryFiles(for destination: URL) -> [URL] {
        [
            partialPlaintextFile(for: destination),
            ciphertextFile(for: destination),
            partialCiphertextFile(for: destination),
        ]
    }

    /// Fetches `request`'s ciphertext with `downloadCiphertext` (the transport) unless an
    /// earlier attempt finished it, then decrypts it into `request.destinationFile`, resuming a
    /// decryption an earlier attempt stopped. Progress: 90% fetching, 10% decrypting.
    ///
    /// An interruption (task cancelled, network lost) keeps everything for the next attempt; a
    /// failure discards it.
    func download(
        _ request: FileDownloadRequest,
        encryption: FileDownloadEncryption,
        fileEncryption: FileEncryption,
        progress: @escaping (Double) -> Void,
        downloadCiphertext: (FileDownloadRequest, @escaping (Double) -> Void) async -> FileTransferResult<URL>
    ) async -> FileTransferResult<URL> {
        let operationId = request.operationId
        await begin(operationId)
        defer { end(operationId) }
        let tag = TransferLog.currentTag
        let destination = request.destinationFile
        let encrypted = Self.ciphertextFile(for: destination)
        let partial = Self.partialCiphertextFile(for: destination)
        do {
            var saved = store.get(operationId)
            if let stale = saved, stale.discardRequested || stale.destination != destination.path {
                logger.debug("[Encryption] \(tag) download session of another destination or abandoned: discarded")
                try store.discard(operationId)
                saved = nil
            }
            // Saved before any writer starts, so a cancel after a relaunch finds the files.
            try store.save(operationId, EncryptedDownloadSession(
                source: saved?.source ?? "",
                destination: destination.path,
                plaintextOffset: saved?.plaintextOffset ?? 0
            ))
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

            if FileManager.default.fileExists(atPath: encrypted.path) {
                logger.debug("[Encryption] \(tag) download ciphertext already complete (\(TransferLog.sizeText(encrypted))), decrypting")
            } else {
                let result = await downloadCiphertext(request.with(destinationFile: partial)) { fraction in
                    progress(min(max(fraction, 0), 1) * 0.9)
                }
                switch result {
                case .success(let fetched):
                    try DefaultFileTransferTransport.replace(encrypted, with: fetched)
                case .failure(let error):
                    if Task.isCancelled {
                        // Stopped by a cancel of this run: whoever cancelled it decides what goes.
                        return .interrupted(error)
                    }
                    discardFiles(operationId)
                    return .failure(error)
                case .interrupted(let error):
                    return .interrupted(error)
                }
            }
            progress(0.9)
            try Task.checkCancellation()
            let published = try await decrypt(
                operationId: operationId,
                destination: destination,
                encryptedFile: encrypted,
                fileEncryption: fileEncryption,
                encryption: encryption,
                progress: { progress(0.9 + $0 * 0.1) }
            )
            progress(1)
            return .success(published)
        } catch {
            if error is CancellationError || Task.isCancelled {
                logger.debug("[Encryption] \(tag) download interrupted, kept for the next attempt")
                return .interrupted(error)
            }
            logger.debug("[Encryption] \(tag) download failed, its files are discarded: \(TransferLog.describe(error))")
            discardFiles(operationId)
            return .failure(error)
        }
    }

    private func decrypt(
        operationId: String,
        destination: URL,
        encryptedFile: URL,
        fileEncryption: FileEncryption,
        encryption: FileDownloadEncryption,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let label = "\(TransferLog.currentTag) attachmentId=\(encryption.info.attachmentId)"
        let partial = Self.partialPlaintextFile(for: destination)
        // Earlier builds decrypted into hidden `.<uuid>-<name>` files; one a crash left behind is
        // plaintext at rest, and only a download of the same destination can find it.
        TransferDirectories.removeStaleDecryptionFiles(for: destination, tag: TransferLog.currentTag)
        let plaintextSize: UInt64
        let session: FileDecryptionSession
        do {
            let ciphertextSize = try FileCiphertextSource.size(of: encryptedFile)
            plaintextSize = try ChatSDKFileEncryption.plaintextSize(trusted: encryption.trustedPlaintextSize, ciphertextSize: ciphertextSize, label: label)
            session = try await fileEncryption.prepareDecryption(
                encryptedFile: encryptedFile,
                encryptionInfo: encryption.info,
                plaintextSize: Int64(plaintextSize)
            )
        } catch {
            logger.debug("[Encryption] \(label) download decrypt cannot open, verification kind: \(ChatSDKFileEncryption.failureKind(error)) (\(TransferLog.describe(error)))")
            throw AttachmentEncryptionError.wrappingDecryption(error)
        }
        defer { session.close() }
        guard session.plaintextSize == Int64(plaintextSize) else {
            logger.debug("[Encryption] \(label) download decrypt: the session holds \(session.plaintextSize) B, expected \(plaintextSize) B")
            throw AttachmentEncryptionError.decryptionFailed(AttachmentEncryptionError.invalidCiphertextSize(UInt64(max(session.plaintextSize, 0))))
        }
        let identity = EncryptedDownloadSession(
            // What the plaintext written so far was decrypted from: never the key itself.
            source: Self.hash([session.sourceId, encryption.info.algorithm, encryption.info.attachmentId, Self.hash([encryption.info.key]), String(plaintextSize)]),
            destination: destination.path
        )
        let saved = store.get(operationId)
        let partialSize = (try? FileCiphertextSource.size(of: partial)) ?? 0
        let resumable = saved.map {
            $0.source == identity.source && $0.destination == identity.destination
                && $0.plaintextOffset >= 0 && UInt64($0.plaintextOffset) <= plaintextSize
                && partialSize >= UInt64($0.plaintextOffset)
        } ?? false
        let start: Int64 = resumable ? (saved?.plaintextOffset ?? 0) : 0
        logger.info("[Encryption] \(label) download decrypt \(start > 0 ? "resumes at \(start) B of" : "starts,") \(plaintextSize) B")

        if !FileManager.default.fileExists(atPath: partial.path) {
            guard FileManager.default.createFile(atPath: partial.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: partial.path])
            }
        }
        let total = Int64(plaintextSize)
        // The loop runs on a worker thread, where the task's cancellation can't be seen.
        let cancelled = CancelFlag()
        do {
            try await withTaskCancellationHandler {
                let checkpointLength = self.checkpointLength
                try await FileEncryptionChunk.offMain { [store] in
                    try Self.writePlaintext(
                        from: session, to: partial, start: start, total: total, checkpointLength: checkpointLength, cancelled: cancelled,
                        checkpoint: { try store.save(operationId, identity.with(plaintextOffset: $0)) },
                        progress: progress
                    )
                }
            } onCancel: {
                cancelled.set()
            }
        } catch {
            logger.debug("[Encryption] \(label) download decrypt stopped: \(ChatSDKFileEncryption.failureKind(error)) (\(TransferLog.describe(error)))")
            throw AttachmentEncryptionError.wrappingDecryption(error)
        }
        try Task.checkCancellation()
        try DefaultFileTransferTransport.replace(destination, with: partial)
        // The ciphertext goes before the session: without the session nothing finds it again.
        TransferLog.remove(encryptedFile, what: "the decrypted ciphertext", context: "[Encryption] \(label) download")
        store.delete(operationId)
        logger.debug("[Encryption] \(label) download decrypted and verified, published \(TransferLog.sizeText(destination))")
        return destination
    }

    /// Writes the plaintext from `start` to `total` into `partial`, saving the offset reached
    /// (`checkpoint`, after a sync) every `checkpointLength` bytes and at the end. A crash loses
    /// at most that much: the next attempt drops the tail written past the saved offset.
    static func writePlaintext(
        from session: FileDecryptionSession,
        to partial: URL,
        start: Int64,
        total: Int64,
        checkpointLength: Int64 = defaultCheckpointLength,
        cancelled: CancelFlag,
        checkpoint: (Int64) throws -> Void,
        progress: (Double) -> Void
    ) throws {
        let output = try FileHandle(forWritingTo: partial)
        defer { try? output.close() }
        var offset = start
        // A tail written before a crash, past the saved offset, is dropped.
        try output.truncate(atOffset: UInt64(offset))
        try output.synchronize()
        try checkpoint(offset)
        try output.seek(toOffset: UInt64(offset))
        var saved = offset
        while offset < total {
            if cancelled.isSet { throw CancellationError() }
            let length = Int(min(Int64(chunkLength), total - offset))
            try autoreleasepool {
                let bytes = try session.read(offset: offset, length: length)
                guard bytes.count == length else {
                    throw AttachmentEncryptionError.decryptionFailed(CocoaError(.fileReadCorruptFile))
                }
                try output.write(contentsOf: bytes)
            }
            offset += Int64(length)
            if offset - saved >= checkpointLength || offset == total {
                try output.synchronize()
                try checkpoint(offset)
                saved = offset
            }
            progress(total > 0 ? Double(offset) / Double(total) : 1)
        }
    }

    /// Removes what an abandoned download of `operationId` left: its temporary files and its
    /// session. Leaves a published plaintext alone, and skips an operation a newer run of it
    /// is working on (a cancel's cleanup that lands after a restart). Call once no writer of
    /// the abandoned run is left.
    func discard(_ operationId: String) {
        // Checked and removed under the lock a run takes to start: none can start in between.
        runsLock.lock(); defer { runsLock.unlock() }
        guard !running.contains(operationId) else {
            logger.debug("[Encryption] xfer=\(TransferLog.operation(operationId)) download cleanup skipped: a newer run of it is working on its files")
            return
        }
        discardFiles(operationId)
    }

    private func discardFiles(_ operationId: String) {
        do {
            try store.discard(operationId)
        } catch {
            logger.error("[Encryption] xfer=\(TransferLog.operation(operationId)) download cleanup remains pending: \(TransferLog.describe(error))")
        }
    }

    static func hash(_ parts: [String]) -> String {
        SHA256.hash(data: Data(parts.joined(separator: "\u{0}").utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Set once, read from any thread.
final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
    func set() { lock.lock(); value = true; lock.unlock() }
}

/// A saved encrypted download: local file identity and progress, never the key.
struct EncryptedDownloadSession: Codable, Equatable {
    var source: String
    var destination: String
    var plaintextOffset: Int64 = 0
    var discardRequested = false

    func with(plaintextOffset: Int64) -> EncryptedDownloadSession {
        var copy = self
        copy.plaintextOffset = plaintextOffset
        return copy
    }
}

/// One JSON file per download operation, named by the hash of its id.
final class EncryptedDownloadSessionStore: @unchecked Sendable {
    let directory: URL
    private let lock = NSLock()

    init(directory: URL) {
        self.directory = directory
    }

    func get(_ operationId: String) -> EncryptedDownloadSession? {
        lock.lock(); defer { lock.unlock() }
        return read(operationId)
    }

    func save(_ operationId: String, _ session: EncryptedDownloadSession) throws {
        lock.lock(); defer { lock.unlock() }
        try write(operationId, session)
    }

    func delete(_ operationId: String) {
        lock.lock(); defer { lock.unlock() }
        TransferLog.remove(file(operationId), what: "the download session", context: "[Encryption] xfer=\(TransferLog.operation(operationId))")
    }

    /// Removes the temporary files of `operationId` and then its session. A failed removal
    /// leaves the session marked, so a later attempt finishes the cleanup first.
    func discard(_ operationId: String) throws {
        lock.lock(); defer { lock.unlock() }
        guard var session = read(operationId) else { return }
        if !session.discardRequested {
            session.discardRequested = true
            try write(operationId, session)
        }
        let destination = URL(fileURLWithPath: session.destination)
        var failed = false
        for file in EncryptedFileDownloader.temporaryFiles(for: destination) where FileManager.default.fileExists(atPath: file.path) {
            do {
                try FileManager.default.removeItem(at: file)
            } catch {
                failed = true
            }
        }
        TransferLog.remove(DefaultFileTransferTransport.resumeDataFile(operationId: operationId), what: "the resume data", context: "[Encryption] xfer=\(TransferLog.operation(operationId))")
        if failed {
            throw CocoaError(.fileWriteNoPermission, userInfo: [NSLocalizedDescriptionKey: "Cannot remove a temporary download file"])
        }
        TransferLog.remove(file(operationId), what: "the download session", context: "[Encryption] xfer=\(TransferLog.operation(operationId))")
    }

    /// Discards sessions not touched for `age` (their downloads were never tried again).
    func purge(olderThan age: TimeInterval, now: Date = Date(), skipping: (URL) -> Bool = { _ in false }) {
        for file in staleFiles(olderThan: age, now: now) where !skipping(file) {
            purge(file)
        }
    }

    /// The session files not touched for `age`.
    func staleFiles(olderThan age: TimeInterval, now: Date = Date()) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files.filter { file in
            guard file.pathExtension == "json" else { return false }
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? now
            return now.timeIntervalSince(modified) > age
        }
    }

    /// Removes one session file and the temporary files it names.
    func purge(_ file: URL) {
        lock.lock()
        defer { lock.unlock() }
        let session = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(EncryptedDownloadSession.self, from: $0) }
        if let session {
            for temporary in EncryptedFileDownloader.temporaryFiles(for: URL(fileURLWithPath: session.destination)) {
                TransferLog.remove(temporary, what: "a stale download file", context: "[Encryption] download session purge")
            }
        }
        TransferLog.remove(file, what: "a stale download session", context: "[Encryption] download session purge")
        logger.info("[Encryption] download session purge removed a stale session")
    }

    private func file(_ operationId: String) -> URL {
        directory.appendingPathComponent(EncryptedFileDownloader.hash([operationId]) + ".json")
    }

    private func read(_ operationId: String) -> EncryptedDownloadSession? {
        let url = file(operationId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let session = try? JSONDecoder().decode(EncryptedDownloadSession.self, from: data) else {
            // Its files can't be found without it: the next attempt starts over.
            logger.warn("[Encryption] xfer=\(TransferLog.operation(operationId)) download session unreadable (\(data.count) B): removed, the download starts over")
            TransferLog.remove(url, what: "an unreadable download session", context: "[Encryption] xfer=\(TransferLog.operation(operationId))")
            return nil
        }
        return session
    }

    private func write(_ operationId: String, _ session: EncryptedDownloadSession) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        try JSONEncoder().encode(session).write(to: file(operationId), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
