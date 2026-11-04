//
//  FileEncryption.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

public enum AttachmentEncryptionError: Error {
    /// Encryption is required but the data session cannot do it. Nothing was uploaded.
    case encryptionUnsupportedBySession
    /// The transport reported success without encrypting the upload (or without decrypting a
    /// download). The message is not sent / the file is not shown.
    case encryptionBypassed
    /// A checkpoint this build cannot read.
    case invalidCheckpoint
    /// `enc` is malformed, of an unknown version or algorithm. Nothing was fetched; show the
    /// attachment as unavailable.
    case invalidEncryptionInfo
    /// No file encrypts to a stored object of this size: truncated or not this format.
    case invalidCiphertextSize(UInt64)
    case snapshotFailed(Error)
    /// The attachment's metadata isn't a JSON object, so `enc` cannot be added to it.
    case metadataNotAnObject
    /// `enc` could not be written into the attachment's metadata, so the receiver would get
    /// a file it cannot decrypt. The upload is not reported sent.
    case metadataFailed(Error)
    /// Verification or decryption failed; the reason is in `FileEncryptionErrorDomain`.
    case decryptionFailed(Error)
}

// MARK: - Contract

/// Cryptography for transports, UIKit's own: a transport never needs the Chat SDK's types. It
/// makes no requests and stores no transfer state; the transport saves the checkpoints.
/// Used from the transport's tasks and the transfer's queues: it must be safe to share.
public protocol FileEncryption: AnyObject, Sendable {
    /// A new session, under a new key, for `file`. Nothing is encrypted ahead: the bytes are
    /// made when they are read.
    func prepareEncryption(file: URL) async throws -> FileEncryptionSession

    /// The session saved in `checkpoint`: the same key, attachment id and parameters, so the
    /// ranges an earlier attempt sent stay valid next to the ones this one sends. Throws when
    /// the source changed; start a new session (and a new remote upload) then.
    func restoreEncryption(file: URL, checkpoint: EncryptedFileCheckpoint) async throws -> FileEncryptionSession

    /// Removes what only the session saved in `checkpoint` needed. Call when its upload is
    /// over: stored, or abandoned for good. Restoring it fails afterwards.
    func discard(_ checkpoint: EncryptedFileCheckpoint)

    /// Verifies and decrypts the stored object `file` into a new file at `destination`. On a
    /// throw nothing is left at `destination`. `plaintextSize` nil: derived from the object's.
    func decrypt(file: URL, to destination: URL, encryptionInfo: EncryptedFileInfo, plaintextSize: Int64?) async throws
}

/// The encrypted bytes of one file.
public protocol FileEncryptionSession: AnyObject {
    /// The encrypted source; the same when the session is restored.
    var sourceId: String { get }
    var plaintextSize: Int64 { get }
    /// The size of the stored object: plan ranges and progress on it.
    var ciphertextSize: Int64 { get }
    /// What goes into the attachment's `enc`.
    var encryptionInfo: EncryptedFileInfo { get }

    /// Exactly the ciphertext bytes `offset..<offset + length`, encryption overhead included;
    /// a range read again gives the same bytes. Blocks: call off the main thread.
    func read(offset: Int64, length: Int) throws -> Data

    /// What `restoreEncryption` needs. Save it after a `read` and before sending that range. It carries
    /// the key: store it as privately as the message itself and never log it.
    func checkpoint() -> EncryptedFileCheckpoint

    /// Releases the session. Saved state (`checkpoint`) stays restorable.
    func close()
}

/// One encrypted file: its algorithm, the id its encryption is bound to and its key.
public struct EncryptedFileInfo: Codable, Equatable, Sendable {
    public let algorithm: String
    public let attachmentId: String
    /// The 32-byte key, base64url without padding.
    public let key: String

    public init(algorithm: String, attachmentId: String, key: String) {
        self.algorithm = algorithm
        self.attachmentId = attachmentId
        self.key = key
    }

    init(_ info: FileEncryptionInfo) {
        self.init(algorithm: info.format, attachmentId: info.data.uniqueId, key: info.data.key)
    }
}

/// A saved session. A transport serializes it as a whole and never reads `data`.
public struct EncryptedFileCheckpoint: Codable, Equatable {
    public let encryptionInfo: EncryptedFileInfo
    public let plaintextSize: Int64
    /// Opaque to everyone but the `FileEncryption` that made it.
    public let data: String

    public init(encryptionInfo: EncryptedFileInfo, plaintextSize: Int64, data: String) {
        self.encryptionInfo = encryptionInfo
        self.plaintextSize = plaintextSize
        self.data = data
    }
}

public extension FileEncryptionSession {
    /// Writes the ciphertext in `range` to a new file at `url`, for a transport that can only
    /// send files (a background `URLSession`).
    func write(_ range: Range<Int64>, to url: URL) throws {
        let fileManager = FileManager.default
        let tag = TransferLog.currentTag
        TransferLog.remove(url, what: "the old ciphertext file", context: "[Encryption] \(tag) write")
        guard fileManager.createFile(atPath: url.path, contents: nil) else {
            logger.debug("[Encryption] \(tag) write \(range.lowerBound)..<\(range.upperBound) of \(ciphertextSize) B: cannot create \(url.lastPathComponent)")
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
        do {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            var offset = range.lowerBound
            while offset < range.upperBound {
                let end = min(offset + FileEncryptionChunk.length, range.upperBound)
                try autoreleasepool {
                    try handle.write(contentsOf: read(offset: offset, length: Int(end - offset)))
                }
                offset = end
            }
        } catch {
            logger.debug("[Encryption] \(tag) write \(range.lowerBound)..<\(range.upperBound) of \(ciphertextSize) B to \(url.lastPathComponent) failed: \(TransferLog.describe(error))")
            TransferLog.remove(url, what: "the partial ciphertext", context: "[Encryption] \(tag) write", level: .error)
            throw error
        }
    }

    /// Writes the whole encrypted file to `url`.
    func materialize(to url: URL) throws {
        try write(0..<ciphertextSize, to: url)
    }
}

public extension FileEncryption {
    /// Encrypts all of `file` into a new file at `destination` under a new key, e.g. a video
    /// poster. Returns what to send in `enc`.
    func encrypt(file: URL, to destination: URL) async throws -> EncryptedFileInfo {
        let session = try await prepareEncryption(file: file)
        let checkpoint = session.checkpoint()
        defer {
            session.close()
            discard(checkpoint)
        }
        // Sizes and the bound id only: never the key.
        let tag = TransferLog.currentTag
        logger.debug("[Encryption] \(tag) encrypt \(file.lastPathComponent) start plaintext=\(session.plaintextSize) B ciphertext=\(session.ciphertextSize) B attachmentId=\(session.encryptionInfo.attachmentId)")
        do {
            try await FileEncryptionChunk.offMain { try session.materialize(to: destination) }
        } catch {
            // The caller reports the failure.
            logger.debug("[Encryption] \(tag) encrypt \(file.lastPathComponent) failed attachmentId=\(session.encryptionInfo.attachmentId): \(TransferLog.describe(error))")
            throw error
        }
        logger.debug("[Encryption] \(tag) encrypt \(file.lastPathComponent) finished, wrote \(TransferLog.sizeText(destination)) attachmentId=\(session.encryptionInfo.attachmentId)")
        return session.encryptionInfo
    }
}

enum FileEncryptionChunk {
    static let length: Int64 = 1 << 20

    /// Runs blocking crypto or file work off the caller's thread, with the caller's transfer
    /// log context bound there too.
    static func offMain<T>(_ work: @escaping () throws -> T) async throws -> T {
        let context = TransferLog.current
        // The result goes through a lock rather than the continuation's payload: the order is
        // the same, and the Thread Sanitizer sees it every time (it can miss a resume made on
        // a dispatch thread, and report what `work` built as racing with its reader).
        let box = ResultBox<T>()
        // Handed to the worker thread: the caller waits and does not run it.
        let work = Handoff(work)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                box.set(Result { try TransferLog.with(context) { try work.value() } })
                continuation.resume()
            }
        }
        return try box.take().get()
    }
}

/// One result handed from one thread to another under a lock.
private final class ResultBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<T, Error>?

    func set(_ result: Result<T, Error>) {
        lock.lock(); self.result = result; lock.unlock()
    }

    func take() -> Result<T, Error> {
        lock.lock(); defer { lock.unlock() }
        guard let result else {
            preconditionFailure("offMain resumed before its work set a result")
        }
        return result
    }
}

// MARK: - Chat SDK adapter

/// `FileEncryption` by a Chat SDK `FileEncryptionProvider` (the app's by default). Each
/// session encrypts a transfer-owned snapshot of the file, so a later change to the prepared
/// file cannot change the bytes under it mid-upload.
/// Safe to share: it holds only the provider lookup, a constant.
final class ChatSDKFileEncryption: FileEncryption, @unchecked Sendable {
    private let provider: () -> FileEncryptionProvider

    init(provider: @escaping () -> FileEncryptionProvider = { Components.fileEncryptionProvider }) {
        self.provider = provider
    }

    func prepareEncryption(file: URL) async throws -> FileEncryptionSession {
        try await FileEncryptionChunk.offMain {
            AttachmentEncryptionFiles.purgeStaleSnapshots
            let transferId = UUID().uuidString
            do {
                let snapshot = try AttachmentEncryptionFiles.makeSnapshot(of: file, transferId: transferId)
                // A new key per session, made by the SDK.
                let provider = self.provider()
                let upload = try provider.prepareUpload(
                    fileURL: snapshot,
                    uniqueId: AttachmentEncryption.newAttachmentId()
                )
                let session = ChatSDKEncryptionSession(upload: upload, transferId: transferId, isSDKStreaming: provider is StreamingAeadFileEncryptionProvider)
                logger.debug("[Encryption] \(TransferLog.currentTag) session \(transferId) prepared: \(session.plaintextSize) B -> \(session.ciphertextSize) B attachmentId=\(session.encryptionInfo.attachmentId)")
                if session.plaintextSize == 0 {
                    logger.warn("[Encryption] \(TransferLog.currentTag) session \(transferId) encrypts an empty file")
                }
                return session
            } catch {
                AttachmentEncryptionFiles.discard(transferId: transferId)
                // The caller reports the failure.
                logger.debug("[Encryption] \(TransferLog.currentTag) session \(transferId) prepare failed (\(TransferLog.size(path: file.path))): \(TransferLog.describe(error))")
                throw error
            }
        }
    }

    func restoreEncryption(file: URL, checkpoint: EncryptedFileCheckpoint) async throws -> FileEncryptionSession {
        let saved: SavedSession
        do {
            saved = try SavedSession(checkpoint)
        } catch {
            // Never the checkpoint itself: it carries the key.
            logger.debug("[Encryption] \(TransferLog.currentTag) restore rejected: unreadable checkpoint (attachmentId=\(checkpoint.encryptionInfo.attachmentId)): \(TransferLog.describe(error))")
            throw error
        }
        return try await FileEncryptionChunk.offMain {
            // The snapshot the session read; the file itself if it is gone, which the SDK then
            // checks against what the session recorded.
            let snapshot = AttachmentEncryptionFiles.snapshot(transferId: saved.transferId)
            let hasSnapshot = FileManager.default.fileExists(atPath: snapshot.path)
            let source = hasSnapshot ? snapshot : file
            if !hasSnapshot {
                logger.warn("[Encryption] \(TransferLog.currentTag) restore \(saved.transferId): snapshot gone, restoring from the file itself")
            }
            let upload: PreparedUpload
            let provider = self.provider()
            do {
                upload = try provider.restoreUpload(
                    fileURL: source,
                    checkpoint: SceytChat.FileEncryptionCheckpoint(
                        encryptionInfo: Self.sdkInfo(checkpoint.encryptionInfo, plaintextSize: UInt64(checkpoint.plaintextSize)),
                        data: saved.sdkData
                    )
                )
            } catch {
                logger.debug("[Encryption] \(TransferLog.currentTag) restore \(saved.transferId) failed (source changed or checkpoint corrupt): \(TransferLog.describe(error))")
                throw error
            }
            logger.info("[Encryption] \(TransferLog.currentTag) session \(saved.transferId) restored plaintext=\(checkpoint.plaintextSize) B")
            return ChatSDKEncryptionSession(upload: upload, transferId: saved.transferId, isSDKStreaming: provider is StreamingAeadFileEncryptionProvider)
        }
    }

    func discard(_ checkpoint: EncryptedFileCheckpoint) {
        guard let saved = try? SavedSession(checkpoint) else {
            logger.warn("[Encryption] \(TransferLog.currentTag) discard ignored: unreadable checkpoint (attachmentId=\(checkpoint.encryptionInfo.attachmentId))")
            return
        }
        AttachmentEncryptionFiles.discard(transferId: saved.transferId)
        logger.debug("[Encryption] \(TransferLog.currentTag) session \(saved.transferId) discarded")
    }

    func decrypt(file: URL, to destination: URL, encryptionInfo: EncryptedFileInfo, plaintextSize: Int64?) async throws {
        // The bound id and sizes only: never the key.
        let label = "\(TransferLog.currentTag) attachmentId=\(encryptionInfo.attachmentId)"
        logger.info("[Encryption] \(label) decrypt start ciphertext=\(TransferLog.sizeText(file)) trustedPlaintext=\(plaintextSize.map { "\($0) B" } ?? "derived")")
        try await FileEncryptionChunk.offMain {
            do {
                try Self.decrypt(file, to: destination, provider: self.provider()) { ciphertextSize in
                    let size = try Self.plaintextSize(trusted: plaintextSize, ciphertextSize: ciphertextSize, label: label)
                    return Self.sdkInfo(encryptionInfo, plaintextSize: size)
                }
            } catch {
                // The caller reports the failure, with this kind (`TransferLog.describe`).
                logger.debug("[Encryption] \(label) decrypt failed, verification kind: \(Self.failureKind(error)) (\(TransferLog.describe(error)))")
                TransferLog.remove(destination, what: "the partial plaintext", context: "[Encryption] \(label) decrypt", level: .error)
                throw AttachmentEncryptionError.decryptionFailed(error)
            }
        }
        logger.debug("[Encryption] \(label) decrypt finished plaintext=\(TransferLog.sizeText(destination))")
    }

    /// The plaintext size to decrypt a stored object of `ciphertextSize` bytes with: the
    /// trusted size the message carries, so the object must hold exactly that many bytes, or
    /// the size derived from the object when there is none.
    ///
    /// A message whose sender could not tell the plaintext size carries the stored object's
    /// size instead. No file encrypts to its own size, so that value is never a real trusted
    /// size: the derived one is used, as without one.
    static func plaintextSize(trusted: Int64?, ciphertextSize: UInt64, label: String) throws -> UInt64 {
        let derived = AttachmentEncryption.plaintextSize(ciphertextSize: ciphertextSize)
        if let trusted, trusted >= 0 {
            let size = UInt64(trusted)
            if size == ciphertextSize, let derived {
                logger.debug("[Encryption] \(label) decrypt: the trusted size is the stored object's (\(ciphertextSize) B), using the derived \(derived) B")
                return derived
            }
            if let derived, derived != size {
                logger.warn("[Encryption] \(label) decrypt size mismatch: trusted plaintext \(size) B, the stored \(ciphertextSize) B object holds \(derived) B")
            } else if derived == nil {
                logger.warn("[Encryption] \(label) decrypt size mismatch: no file encrypts to \(ciphertextSize) B (trusted plaintext \(size) B)")
            }
            return size
        }
        guard let derived else {
            logger.debug("[Encryption] \(label) decrypt rejected: no file encrypts to \(ciphertextSize) B (truncated or not this format)")
            throw AttachmentEncryptionError.invalidCiphertextSize(ciphertextSize)
        }
        return derived
    }

    /// The reason a decryption failed, for logs.
    static func failureKind(_ error: Error) -> String {
        if case .invalidCiphertextSize = error as? AttachmentEncryptionError {
            return "invalid ciphertext size"
        }
        let ns = error as NSError
        if ns.domain == FileEncryptionErrorDomain {
            if ns.code == FileEncryptionError.authentication.rawValue {
                return "authentication failed (tampered, truncated or wrong key/id)"
            }
            return "rejected by the SDK (code \(ns.code))"
        }
        if ns.domain == NSCocoaErrorDomain, ns.code == CocoaError.fileReadCorruptFile.rawValue {
            return "short read (truncated ciphertext)"
        }
        if TransferLog.isOutOfSpace(ns) {
            return "disk full"
        }
        return "I/O"
    }

    static func sdkInfo(_ info: EncryptedFileInfo, plaintextSize: UInt64) -> FileEncryptionInfo {
        FileEncryptionInfo(format: info.algorithm, data: FileEncryptionData(uniqueId: info.attachmentId, key: info.key, plainSize: plaintextSize))
    }

    /// Decrypts `file` into a new file at `destination`, with the info `info` makes for the
    /// file's size. Every record is verified before its plaintext is written; on a throw
    /// `destination` holds a prefix and must be removed.
    static func decrypt(_ file: URL, to destination: URL, provider: FileEncryptionProvider, info: (UInt64) throws -> FileEncryptionInfo) throws {
        let source = try FileCiphertextSource(url: file)
        let reader: PlaintextReader
        do {
            let info = try info(source.ciphertextSize)
            reader = try provider.openDownload(source: source, encryptionInfo: info)
        } catch {
            // On failure the source stays ours to close.
            source.close()
            throw error
        }
        defer { reader.close() }

        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            logger.debug("[Encryption] \(TransferLog.currentTag) decrypt cannot create \(destination.lastPathComponent) (folder missing or disk full)")
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: destination.path])
        }
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }
        let size = reader.plaintextSize
        var offset: UInt64 = 0
        while offset < size {
            let length = min(UInt64(FileEncryptionChunk.length), size - offset)
            try autoreleasepool {
                try output.write(contentsOf: reader.read(offset: offset, length: UInt(length)))
            }
            offset += length
        }
    }

    /// `EncryptedFileCheckpoint.data`: the SDK's own checkpoint data and the snapshot it reads.
    struct SavedSession: Codable {
        static let version = 1

        let v: Int
        let transferId: String
        let sdkData: String

        init(transferId: String, sdkData: String) {
            v = Self.version
            self.transferId = transferId
            self.sdkData = sdkData
        }

        init(_ checkpoint: EncryptedFileCheckpoint) throws {
            guard let decoded = try? JSONDecoder().decode(Self.self, from: Data(checkpoint.data.utf8)),
                  decoded.v == Self.version
            else { throw AttachmentEncryptionError.invalidCheckpoint }
            self = decoded
        }

        var encoded: String { encoded() }

        /// The session as JSON text, empty when it can't be encoded (plain strings and a
        /// number: `JSONEncoder` does not fail on them; tests pass a failing encoder).
        func encoded(using encode: (SavedSession) throws -> Data = { try JSONEncoder().encode($0) }) -> String {
            (try? encode(self)).flatMap(MetadataJSON.live.string) ?? ""
        }
    }
}

/// A session of the Chat SDK. `upload` is what `ChatClient.uploadEncrypted` sends.
final class ChatSDKEncryptionSession: FileEncryptionSession {
    let upload: PreparedUpload
    let transferId: String
    let encryptionInfo: EncryptedFileInfo
    let plaintextSize: Int64
    let ciphertextSize: Int64
    /// Prepared by the SDK's own streaming provider: the only kind `ChatClient.uploadEncrypted`
    /// can send.
    let isSDKStreaming: Bool

    init(upload: PreparedUpload, transferId: String, isSDKStreaming: Bool) {
        self.upload = upload
        self.transferId = transferId
        self.isSDKStreaming = isSDKStreaming
        encryptionInfo = EncryptedFileInfo(upload.encryptionInfo)
        plaintextSize = Int64(upload.plaintextSize)
        ciphertextSize = Int64(upload.ciphertextSize)
    }

    deinit {
        upload.close()
    }

    var sourceId: String { upload.sourceId }

    func read(offset: Int64, length: Int) throws -> Data {
        try upload.readCiphertextRange(offset: UInt64(offset), length: UInt(length))
    }

    func checkpoint() -> EncryptedFileCheckpoint {
        let sdk = upload.checkpoint
        return EncryptedFileCheckpoint(
            encryptionInfo: EncryptedFileInfo(sdk.encryptionInfo),
            plaintextSize: Int64(sdk.encryptionInfo.data.plainSize),
            data: ChatSDKFileEncryption.SavedSession(transferId: transferId, sdkData: sdk.data).encoded
        )
    }

    func close() {
        upload.close()
    }
}

/// Reads a downloaded encrypted file for `FileEncryptionProvider.openDownload`.
final class FileCiphertextSource: NSObject, CiphertextRangeSource {

    let ciphertextSize: UInt64
    private let handle: FileHandle
    // The SDK may read from several threads; a seek and its read must stay together.
    private let lock = NSLock()

    init(url: URL) throws {
        handle = try FileHandle(forReadingFrom: url)
        ciphertextSize = try handle.seekToEnd()
    }

    func readCiphertextRange(offset: UInt64, length: UInt) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        try handle.seek(toOffset: offset)
        let data = try handle.read(upToCount: Int(length)) ?? Data()
        guard data.count == length else {
            logger.debug("[Encryption] \(TransferLog.currentTag) ciphertext short read at \(offset): \(data.count) of \(length) B (object \(ciphertextSize) B)")
            throw CocoaError(.fileReadCorruptFile)
        }
        return data
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }
        try? handle.close()
    }
}

/// Snapshots of encrypted uploads.
public enum AttachmentEncryptionFiles {

    /// `Caches/encrypted-transfers`: transfer-owned copies, never the user's assets.
    nonisolated(unsafe) public static var transfersDirectory: URL = {
        TransferDirectories.cachesOrTemporary().appendingPathComponent("encrypted-transfers", isDirectory: true)
    }()

    public static func directory(transferId: String) -> URL {
        transfersDirectory.appendingPathComponent(transferId, isDirectory: true)
    }

    static func snapshot(transferId: String) -> URL {
        directory(transferId: transferId).appendingPathComponent("snapshot")
    }

    /// How long a snapshot nobody finished or abandoned is kept: one whose transport kept
    /// it for a retry that never came.
    static let staleSnapshotAge: TimeInterval = 7 * 24 * 60 * 60

    /// Removes the snapshots older than `staleSnapshotAge`, once per process.
    static let purgeStaleSnapshots: Void = purgeStaleSnapshots(in: transfersDirectory)

    /// Removes the snapshot folders in `directory` older than `staleSnapshotAge`.
    static func purgeStaleSnapshots(in directory: URL) {
        let fileManager = FileManager.default
        let cutoff = Date().addingTimeInterval(-staleSnapshotAge)
        let directories = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        var purged = 0
        for directory in directories {
            let modified = (try? directory.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff,
               TransferLog.remove(directory, what: "a stale snapshot", context: "[Encryption] snapshot purge") {
                purged += 1
            }
        }
        if purged > 0 {
            logger.info("[Encryption] snapshot purge removed \(purged) of \(directories.count) snapshot(s)")
        }
    }

    /// An immutable, transfer-owned copy of `file`. `copyItem` clones on APFS, so it costs
    /// no disk until one side changes; never a hard link, which shares the inode and so
    /// would follow an in-place rewrite of the original.
    static func makeSnapshot(of file: URL, transferId: String) throws -> URL {
        let fileManager = FileManager.default
        let directory = directory(transferId: transferId)
        let snapshot = snapshot(transferId: transferId)
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
            TransferLog.remove(snapshot, what: "the old snapshot", context: "[Encryption] \(TransferLog.currentTag) snapshot \(transferId)")
            try fileManager.copyItem(at: file, to: snapshot)
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication, .posixPermissions: 0o400],
                ofItemAtPath: snapshot.path
            )
        } catch {
            logger.debug("[Encryption] \(TransferLog.currentTag) snapshot \(transferId) of \(file.lastPathComponent) failed (source exists: \(fileManager.fileExists(atPath: file.path))): \(TransferLog.describe(error))")
            throw AttachmentEncryptionError.snapshotFailed(error)
        }
        logger.debug("[Encryption] \(TransferLog.currentTag) snapshot \(transferId) created (\(TransferLog.sizeText(snapshot)))")
        return snapshot
    }

    /// Removes the snapshot. Call once the transfer is over (sent, or abandoned for good).
    public static func discard(transferId: String) {
        TransferLog.remove(directory(transferId: transferId), what: "the snapshot", context: "[Encryption] \(TransferLog.currentTag) snapshot \(transferId)")
    }
}
