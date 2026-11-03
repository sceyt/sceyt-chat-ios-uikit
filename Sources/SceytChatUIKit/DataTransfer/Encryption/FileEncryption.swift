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
public protocol FileEncryption: AnyObject {
    /// A new session, under a new key, for `file`. Nothing is encrypted ahead: the bytes are
    /// made when they are read.
    func prepare(file: URL) async throws -> FileEncryptionSession

    /// The session saved in `checkpoint`: the same key, attachment id and parameters, so the
    /// ranges an earlier attempt sent stay valid next to the ones this one sends. Throws when
    /// the source changed; start a new session (and a new remote upload) then.
    func restore(file: URL, checkpoint: EncryptedFileCheckpoint) async throws -> FileEncryptionSession

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

    /// What `restore` needs. Save it after a `read` and before sending that range. It carries
    /// the key: store it as privately as the message itself and never log it.
    func checkpoint() -> EncryptedFileCheckpoint

    /// Releases the session. Saved state (`checkpoint`) stays restorable.
    func close()
}

/// One encrypted file: its algorithm, the id its encryption is bound to and its key.
public struct EncryptedFileInfo: Codable, Equatable {
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
        try? fileManager.removeItem(at: url)
        guard fileManager.createFile(atPath: url.path, contents: nil) else {
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
            try? fileManager.removeItem(at: url)
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
        let session = try await prepare(file: file)
        let checkpoint = session.checkpoint()
        defer {
            session.close()
            discard(checkpoint)
        }
        try await FileEncryptionChunk.offMain { try session.materialize(to: destination) }
        return session.encryptionInfo
    }
}

enum FileEncryptionChunk {
    static let length: Int64 = 1 << 20

    /// Runs blocking crypto or file work off the caller's thread.
    static func offMain<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try work() })
            }
        }
    }
}

// MARK: - Chat SDK adapter

/// `FileEncryption` by the Chat SDK's `Components.fileEncryptionProvider`. Each session encrypts
/// a transfer-owned snapshot of the file, so a later change to the prepared file cannot change
/// the bytes under it mid-upload.
final class ChatSDKFileEncryption: FileEncryption {

    func prepare(file: URL) async throws -> FileEncryptionSession {
        try await FileEncryptionChunk.offMain {
            AttachmentEncryptionFiles.purgeStaleSnapshots
            let transferId = UUID().uuidString
            do {
                let snapshot = try AttachmentEncryptionFiles.makeSnapshot(of: file, transferId: transferId)
                // A new key per session, made by the SDK.
                let upload = try Components.fileEncryptionProvider.prepareUpload(
                    fileURL: snapshot,
                    uniqueId: AttachmentEncryption.newAttachmentId()
                )
                let session = ChatSDKEncryptionSession(upload: upload, transferId: transferId)
                logger.verbose("[Encryption] session \(transferId): \(session.plaintextSize) B -> \(session.ciphertextSize) B")
                return session
            } catch {
                AttachmentEncryptionFiles.discard(transferId: transferId)
                logger.errorIfNotNil(error, "[Encryption] prepare failed")
                throw error
            }
        }
    }

    func restore(file: URL, checkpoint: EncryptedFileCheckpoint) async throws -> FileEncryptionSession {
        let saved = try SavedSession(checkpoint)
        return try await FileEncryptionChunk.offMain {
            // The snapshot the session read; the file itself if it is gone, which the SDK then
            // checks against what the session recorded.
            let snapshot = AttachmentEncryptionFiles.snapshot(transferId: saved.transferId)
            let source = FileManager.default.fileExists(atPath: snapshot.path) ? snapshot : file
            let upload = try Components.fileEncryptionProvider.restoreUpload(
                fileURL: source,
                checkpoint: SceytChat.FileEncryptionCheckpoint(
                    encryptionInfo: Self.sdkInfo(checkpoint.encryptionInfo, plaintextSize: UInt64(checkpoint.plaintextSize)),
                    data: saved.sdkData
                )
            )
            logger.verbose("[Encryption] restored session \(saved.transferId)")
            return ChatSDKEncryptionSession(upload: upload, transferId: saved.transferId)
        }
    }

    func discard(_ checkpoint: EncryptedFileCheckpoint) {
        guard let saved = try? SavedSession(checkpoint) else { return }
        AttachmentEncryptionFiles.discard(transferId: saved.transferId)
    }

    func decrypt(file: URL, to destination: URL, encryptionInfo: EncryptedFileInfo, plaintextSize: Int64?) async throws {
        try await FileEncryptionChunk.offMain {
            do {
                try Self.decrypt(file, to: destination) { ciphertextSize in
                    let size: UInt64
                    if let plaintextSize {
                        size = UInt64(plaintextSize)
                    } else if let derived = AttachmentEncryption.plaintextSize(ciphertextSize: ciphertextSize) {
                        size = derived
                    } else {
                        throw AttachmentEncryptionError.invalidCiphertextSize(ciphertextSize)
                    }
                    return Self.sdkInfo(encryptionInfo, plaintextSize: size)
                }
            } catch {
                try? FileManager.default.removeItem(at: destination)
                throw AttachmentEncryptionError.decryptionFailed(error)
            }
        }
    }

    static func sdkInfo(_ info: EncryptedFileInfo, plaintextSize: UInt64) -> FileEncryptionInfo {
        FileEncryptionInfo(format: info.algorithm, data: FileEncryptionData(uniqueId: info.attachmentId, key: info.key, plainSize: plaintextSize))
    }

    /// Decrypts `file` into a new file at `destination`, with the info `info` makes for the
    /// file's size. Every record is verified before its plaintext is written; on a throw
    /// `destination` holds a prefix and must be removed.
    static func decrypt(_ file: URL, to destination: URL, info: (UInt64) throws -> FileEncryptionInfo) throws {
        let source = try FileCiphertextSource(url: file)
        let reader: PlaintextReader
        do {
            let info = try info(source.ciphertextSize)
            reader = try Components.fileEncryptionProvider.openDownload(source: source, encryptionInfo: info)
        } catch {
            // On failure the source stays ours to close.
            source.close()
            throw error
        }
        defer { reader.close() }

        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
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

        var encoded: String {
            // Plain strings and a number: encoding cannot fail.
            String(data: (try? JSONEncoder().encode(self)) ?? Data(), encoding: .utf8) ?? ""
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

    init(upload: PreparedUpload, transferId: String) {
        self.upload = upload
        self.transferId = transferId
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
    public static var transfersDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return caches.appendingPathComponent("encrypted-transfers", isDirectory: true)
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
    static let purgeStaleSnapshots: Void = {
        let fileManager = FileManager.default
        let cutoff = Date().addingTimeInterval(-staleSnapshotAge)
        let directories = (try? fileManager.contentsOfDirectory(
            at: transfersDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        for directory in directories {
            let modified = (try? directory.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff {
                try? fileManager.removeItem(at: directory)
            }
        }
    }()

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
            try? fileManager.removeItem(at: snapshot)
            try fileManager.copyItem(at: file, to: snapshot)
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication, .posixPermissions: 0o400],
                ofItemAtPath: snapshot.path
            )
        } catch {
            throw AttachmentEncryptionError.snapshotFailed(error)
        }
        return snapshot
    }

    /// Removes the snapshot. Call once the transfer is over (sent, or abandoned for good).
    public static func discard(transferId: String) {
        try? FileManager.default.removeItem(at: directory(transferId: transferId))
    }
}
