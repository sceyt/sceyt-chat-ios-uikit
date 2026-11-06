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

    /// Opens the completed local ciphertext `encryptedFile` for verified plaintext reads. No
    /// networking. `plaintextSize` is the original size; the object must hold exactly that.
    func prepareDecryption(encryptedFile: URL, encryptionInfo: EncryptedFileInfo, plaintextSize: Int64) async throws -> FileDecryptionSession

    /// Verifies and decrypts all of the stored object `file` into a new file at `destination`.
    /// A requirement (with a default built on `prepareDecryption`), so an implementation that
    /// has its own is called through `any FileEncryption`.
    func decrypt(file: URL, to destination: URL, encryptionInfo: EncryptedFileInfo, plaintextSize: Int64?) async throws

    // MARK: Streams (the prepare-hook flow)

    /// A new key bound to a new attachment id, for a file not encrypted yet. Nothing is read:
    /// the transport's `prepareUpload` makes it, UIKit saves it in the attachment's `enc`
    /// before any byte is sent, and `newEncryptingStream` encrypts with it.
    func newEncryptionInfo() async throws -> EncryptedFileInfo

    /// Encrypts exactly `plaintextSize` bytes, given in pieces, under `info`. Each new stream
    /// picks a new salt: two streams of the same plaintext give different bytes.
    func newEncryptingStream(info: EncryptedFileInfo, plaintextSize: Int64) throws -> FileEncryptingStream

    /// The stream saved in `checkpoint` (`FileEncryptingStream.checkpoint`): the same salt and
    /// nonces, so re-fed plaintext gives the same bytes again. It continues at the checkpoint's
    /// `ciphertextPosition`; feed it the plaintext from its `position`, byte-identical to the
    /// first time (different bytes would reuse nonces).
    func restoreEncryptingStream(info: EncryptedFileInfo, plaintextSize: Int64, checkpoint: String) throws -> FileEncryptingStream
}

/// Encrypts a stream given in pieces (the Chat SDK's `EncryptingStream`): all the bytes
/// `write` and `close` return, joined, are one stored object. Not safe to share: one caller at
/// a time. Its calls block: use it off the main thread.
public protocol FileEncryptingStream: AnyObject {
    /// Plaintext bytes written so far. On a restored stream: where to re-feed from.
    var position: Int64 { get }
    /// Ciphertext bytes returned so far, the restored-from stream's included.
    var ciphertextPosition: Int64 { get }
    /// The state at `ciphertextPosition`, for `restoreEncryptingStream`. Has no key: store it
    /// with the transfer, the key stays in the attachment's `enc`. Take it before `close`: a
    /// closed stream's does not restore.
    var checkpoint: String { get }

    /// The ciphertext `plaintext` completes (possibly none: the last segment is held back
    /// until more data comes or `close`).
    func write(_ plaintext: Data) throws -> Data
    /// The rest, sealed as the last segment. Without it the object does not decrypt.
    func close() throws -> Data
}

public extension FileEncryption {
    func newEncryptionInfo() async throws -> EncryptedFileInfo {
        try await FileEncryptionChunk.offMain {
            let info = try StreamingAeadFileEncryptionProvider.prepare(uniqueId: AttachmentEncryption.newAttachmentId())
            // The bound id only: never the key.
            logger.debug("[Encryption] \(TransferLog.currentTag) new key prepared attachmentId=\(info.data.uniqueId)")
            return EncryptedFileInfo(info)
        }
    }

    func newEncryptingStream(info: EncryptedFileInfo, plaintextSize: Int64) throws -> FileEncryptingStream {
        guard plaintextSize >= 0 else { throw AttachmentEncryptionError.invalidEncryptionInfo }
        let sdkInfo = ChatSDKFileEncryption.sdkInfo(info, plaintextSize: UInt64(plaintextSize))
        return ChatSDKEncryptingStream(try StreamingAeadFileEncryptionProvider.newEncryptingStream(info: sdkInfo))
    }

    func restoreEncryptingStream(info: EncryptedFileInfo, plaintextSize: Int64, checkpoint: String) throws -> FileEncryptingStream {
        guard plaintextSize >= 0 else { throw AttachmentEncryptionError.invalidEncryptionInfo }
        let sdkInfo = ChatSDKFileEncryption.sdkInfo(info, plaintextSize: UInt64(plaintextSize))
        let stream = try StreamingAeadFileEncryptionProvider.restoreEncryptingStream(
            checkpoint: SceytChat.FileEncryptionCheckpoint(encryptionInfo: sdkInfo, data: checkpoint)
        )
        return ChatSDKEncryptingStream(stream)
    }
}

/// The Chat SDK's `EncryptingStream`.
final class ChatSDKEncryptingStream: FileEncryptingStream {
    private let stream: EncryptingStream

    init(_ stream: EncryptingStream) {
        self.stream = stream
    }

    var position: Int64 { Int64(stream.position) }
    var ciphertextPosition: Int64 { Int64(stream.ciphertextPosition) }
    var checkpoint: String { stream.checkpoint.data }

    func write(_ plaintext: Data) throws -> Data {
        try stream.write(plaintext)
    }

    func close() throws -> Data {
        try stream.close()
    }
}

/// Verified plaintext of a completed encrypted file. Owns its open file until `close`.
public protocol FileDecryptionSession: AnyObject {
    /// The ciphertext file it reads, as it was when opened.
    var sourceId: String { get }
    var plaintextSize: Int64 { get }

    /// Exactly `length` authenticated plaintext bytes from `offset`, or a throw. Blocks: call off
    /// the main thread.
    func read(offset: Int64, length: Int) throws -> Data

    func close()
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
    /// Verifies and decrypts all of the stored object `file` into a new file at `destination`
    /// (a video poster, a test). `plaintextSize` nil, or the object's own size: derived from the
    /// object's. On a throw (`AttachmentEncryptionError.decryptionFailed` or
    /// `.invalidCiphertextSize`) nothing is left at `destination`.
    func decrypt(file: URL, to destination: URL, encryptionInfo: EncryptedFileInfo, plaintextSize: Int64?) async throws {
        // The bound id and sizes only: never the key.
        let label = "\(TransferLog.currentTag) attachmentId=\(encryptionInfo.attachmentId)"
        logger.info("[Encryption] \(label) decrypt start ciphertext=\(TransferLog.sizeText(file)) trustedPlaintext=\(plaintextSize.map { "\($0) B" } ?? "derived")")
        let ciphertextSize: UInt64
        do {
            ciphertextSize = try FileCiphertextSource.size(of: file)
        } catch {
            logger.debug("[Encryption] \(label) decrypt cannot read the object: \(TransferLog.describe(error))")
            throw AttachmentEncryptionError.decryptionFailed(error)
        }
        let session: FileDecryptionSession
        do {
            let size = try ChatSDKFileEncryption.plaintextSize(trusted: plaintextSize, ciphertextSize: ciphertextSize, label: label)
            session = try await prepareDecryption(encryptedFile: file, encryptionInfo: encryptionInfo, plaintextSize: Int64(size))
        } catch {
            logger.debug("[Encryption] \(label) decrypt failed to open, verification kind: \(ChatSDKFileEncryption.failureKind(error)) (\(TransferLog.describe(error)))")
            throw AttachmentEncryptionError.wrappingDecryption(error)
        }
        defer { session.close() }
        do {
            try await FileEncryptionChunk.offMain { try session.write(to: destination) }
        } catch {
            // The caller reports the failure, with this kind (`TransferLog.describe`).
            logger.debug("[Encryption] \(label) decrypt failed, verification kind: \(ChatSDKFileEncryption.failureKind(error)) (\(TransferLog.describe(error)))")
            TransferLog.remove(destination, what: "the partial plaintext", context: "[Encryption] \(label) decrypt", level: .error)
            throw AttachmentEncryptionError.wrappingDecryption(error)
        }
        logger.debug("[Encryption] \(label) decrypt finished plaintext=\(TransferLog.sizeText(destination))")
    }

    /// Encrypts all of `file` into a new file at `destination` under a new key, e.g. a video
    /// poster. Returns what to send in `enc`.
    func encrypt(file: URL, to destination: URL) async throws -> EncryptedFileInfo {
        let session = try await prepareEncryption(file: file)
        defer { session.close() }
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

public extension FileEncryption {
    /// Encrypts all of `file` into a new file at `destination` with the Chat SDK's encrypting
    /// stream, under a new key (`newEncryptionInfo`), e.g. a video poster. The same format as
    /// every upload, so it decrypts like one. Returns what to send in `enc`. On a throw nothing
    /// is left at `destination`.
    func encryptStream(file: URL, to destination: URL) async throws -> EncryptedFileInfo {
        let info = try await newEncryptionInfo()
        let tag = TransferLog.currentTag
        try await FileEncryptionChunk.offMain {
            TransferLog.remove(destination, what: "the old ciphertext file", context: "[Encryption] \(tag) encryptStream")
            let size = try FileCiphertextSource.size(of: file)
            let stream = try self.newEncryptingStream(info: info, plaintextSize: Int64(size))
            guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: destination.path])
            }
            do {
                let input = try FileHandle(forReadingFrom: file)
                defer { try? input.close() }
                let output = try FileHandle(forWritingTo: destination)
                defer { try? output.close() }
                var read: UInt64 = 0
                while read < size {
                    try autoreleasepool {
                        let chunk = try input.read(upToCount: Int(min(UInt64(FileEncryptionChunk.length), size - read))) ?? Data()
                        guard !chunk.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
                        read += UInt64(chunk.count)
                        try output.write(contentsOf: stream.write(chunk))
                    }
                }
                try output.write(contentsOf: stream.close())
            } catch {
                logger.debug("[Encryption] \(tag) encryptStream \(file.lastPathComponent) failed attachmentId=\(info.attachmentId): \(TransferLog.describe(error))")
                TransferLog.remove(destination, what: "the partial ciphertext", context: "[Encryption] \(tag) encryptStream", level: .error)
                throw error
            }
            // Sizes and the bound id only: never the key.
            logger.debug("[Encryption] \(tag) encryptStream \(file.lastPathComponent) \(size) B -> \(TransferLog.sizeText(destination)) attachmentId=\(info.attachmentId)")
        }
        return info
    }
}

public extension FileDecryptionSession {
    /// Writes all of the plaintext to a new file at `destination`. On a throw `destination`
    /// holds a prefix: remove it.
    func write(to destination: URL) throws {
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            logger.debug("[Encryption] \(TransferLog.currentTag) decrypt cannot create \(destination.lastPathComponent) (folder missing or disk full)")
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: destination.path])
        }
        // The same loop a download decrypts with, without its checkpoints.
        try EncryptedFileDownloader.writePlaintext(
            from: self, to: destination, start: 0, total: plaintextSize,
            checkpointLength: .max, cancelled: CancelFlag(), checkpoint: { _ in }, progress: { _ in }
        )
    }
}

extension AttachmentEncryptionError {
    /// `error` as a decryption failure (its reason inside), unless it is one already or a
    /// cancellation.
    static func wrappingDecryption(_ error: Error) -> Error {
        if error is CancellationError { return error }
        if case .decryptionFailed = error as? AttachmentEncryptionError { return error }
        return AttachmentEncryptionError.decryptionFailed(error)
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
/// session reads the file itself, as the architecture doc (§5) has it: the SDK records the
/// source, and a restore against a changed file throws, so the transport starts a new session
/// and a new remote upload.
/// Safe to share: it holds only the provider lookup, a constant.
final class ChatSDKFileEncryption: FileEncryption, @unchecked Sendable {
    private let provider: () -> FileEncryptionProvider

    init(provider: @escaping () -> FileEncryptionProvider = { Components.fileEncryptionProvider }) {
        self.provider = provider
    }

    func prepareEncryption(file: URL) async throws -> FileEncryptionSession {
        try await FileEncryptionChunk.offMain {
            LegacyEncryptionSnapshots.removeOnce
            let transferId = UUID().uuidString
            do {
                // A new key per session, made by the SDK.
                let provider = self.provider()
                let upload = try provider.prepareUpload(
                    fileURL: file,
                    uniqueId: AttachmentEncryption.newAttachmentId()
                )
                let session = ChatSDKEncryptionSession(upload: upload, transferId: transferId, isSDKStreaming: provider is StreamingAeadFileEncryptionProvider)
                logger.debug("[Encryption] \(TransferLog.currentTag) session \(transferId) prepared: \(session.plaintextSize) B -> \(session.ciphertextSize) B attachmentId=\(session.encryptionInfo.attachmentId)")
                if session.plaintextSize == 0 {
                    logger.warn("[Encryption] \(TransferLog.currentTag) session \(transferId) encrypts an empty file")
                }
                return session
            } catch {
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
            // The SDK checks the file against what the session recorded.
            let upload: PreparedUpload
            let provider = self.provider()
            do {
                upload = try provider.restoreUpload(
                    fileURL: file,
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

    func prepareDecryption(encryptedFile: URL, encryptionInfo: EncryptedFileInfo, plaintextSize: Int64) async throws -> FileDecryptionSession {
        guard plaintextSize >= 0 else { throw AttachmentEncryptionError.invalidEncryptionInfo }
        return try await FileEncryptionChunk.offMain {
            let source = try FileCiphertextSource(url: encryptedFile)
            do {
                let reader = try self.provider().openDownload(
                    source: source,
                    encryptionInfo: Self.sdkInfo(encryptionInfo, plaintextSize: UInt64(plaintextSize))
                )
                return ChatSDKDecryptionSession(reader: reader, source: source)
            } catch {
                // On failure the source stays ours to close.
                source.close()
                throw error
            }
        }
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

    /// `EncryptedFileCheckpoint.data`: the SDK's own checkpoint data and the session's id (for
    /// logs; checkpoints of builds that kept a snapshot under it still decode).
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

/// Verified plaintext of a downloaded object, read by the Chat SDK.
final class ChatSDKDecryptionSession: FileDecryptionSession {
    private let reader: PlaintextReader
    let sourceId: String
    let plaintextSize: Int64

    init(reader: PlaintextReader, source: FileCiphertextSource) {
        self.reader = reader
        sourceId = source.sourceId
        plaintextSize = Int64(reader.plaintextSize)
    }

    private let lock = NSLock()
    private var closed = false

    deinit {
        close()
    }

    func read(offset: Int64, length: Int) throws -> Data {
        try reader.read(offset: UInt64(offset), length: UInt(length))
    }

    /// Closes the reader (and its ciphertext source) once, however often it is called.
    func close() {
        lock.lock()
        guard !closed else { lock.unlock(); return }
        closed = true
        lock.unlock()
        reader.close()
    }
}

/// Reads a downloaded encrypted file for `FileEncryptionProvider.openDownload`.
final class FileCiphertextSource: NSObject, CiphertextRangeSource {

    let ciphertextSize: UInt64
    private let handle: FileHandle
    // The SDK may read from several threads; a seek and its read must stay together.
    private let lock = NSLock()

    /// The file as opened: path, size and modification time.
    let sourceId: String

    static func size(of url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.uint64Value ?? 0
    }

    init(url: URL) throws {
        handle = try FileHandle(forReadingFrom: url)
        ciphertextSize = try handle.seekToEnd()
        // Read from the file system each time: `URL.resourceValues` caches per URL instance,
        // and a changed file must not keep its old identity.
        let modified = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        sourceId = "\(url.path):\(ciphertextSize):\(modified?.timeIntervalSince1970 ?? 0)"
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

/// Builds before the architecture-doc alignment encrypted from a copy ("snapshot") of the
/// file under `Caches/encrypted-transfers`. Nothing reads them any more: the folder is removed
/// once per process. Drop this once no installed build can have left one.
enum LegacyEncryptionSnapshots {
    static let directory: URL = {
        TransferDirectories.cachesOrTemporary().appendingPathComponent("encrypted-transfers", isDirectory: true)
    }()

    static let removeOnce: Void = remove(directory)

    static func remove(_ directory: URL) {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        if TransferLog.remove(directory, what: "the legacy snapshot folder", context: "[Encryption] legacy snapshots") {
            logger.info("[Encryption] legacy snapshot folder removed")
        }
    }
}
