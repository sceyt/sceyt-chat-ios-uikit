//
//  FileTransferTransport.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import CryptoKit
import Foundation

/// Whatever a transport needs to know about a transfer beyond the file itself. UIKit passes an
/// `AttachmentTransferContext`.
public protocol FileTransferContext {}

/// The attachment a request transfers, for a transport that needs more than the file (a header
/// with the message id, a per-message-type route).
public struct AttachmentTransferContext: FileTransferContext {
    public let message: ChatMessage
    public let attachment: ChatMessage.Attachment

    public init(message: ChatMessage, attachment: ChatMessage.Attachment) {
        self.message = message
        self.attachment = attachment
    }
}

public enum FileUploadType: Equatable {
    case plain
    /// The transport encrypts the file with `FileEncryption` and returns its encryption.
    case encrypted
}

/// One upload. `sourceFile` is the final prepared plaintext file in both modes: resized,
/// exported or zipped already.
public struct FileUploadRequest {
    /// Names this logical upload across attempts and relaunches: a retry finds what an earlier
    /// attempt saved by it. Never the same as a download's.
    public let operationId: String
    public let sourceFile: URL
    public let fileName: String
    public let mimeType: String?
    public let context: FileTransferContext?
    public let type: FileUploadType

    public init(
        operationId: String,
        sourceFile: URL,
        fileName: String,
        mimeType: String?,
        context: FileTransferContext? = nil,
        type: FileUploadType = .plain
    ) {
        self.operationId = operationId
        self.sourceFile = sourceFile
        self.fileName = fileName
        self.mimeType = mimeType
        self.context = context
        self.type = type
    }
}

public struct FileUploadResult {
    /// A URL, or whatever remote reference this transport's downloads understand. The message
    /// carries it as the attachment's url.
    public let remoteReference: String
    /// The encryption of the uploaded bytes: set exactly when the request was `.encrypted`.
    public let encryptionInfo: EncryptedFileInfo?

    public init(remoteReference: String, encryptionInfo: EncryptedFileInfo? = nil) {
        self.remoteReference = remoteReference
        self.encryptionInfo = encryptionInfo
    }
}

/// One download. With `encryptionInfo` the transport decrypts and verifies the object before
/// it publishes `destinationFile`.
public struct FileDownloadRequest {
    public let operationId: String
    /// The attachment's url: the remote reference its upload returned.
    public let url: String
    /// Where the final plaintext goes. Nothing is written there until the file is complete.
    public let destinationFile: URL
    public let encryptionInfo: EncryptedFileInfo?
    /// The original size, when the attachment carries it. Nil: derived from the stored object's
    /// size, which `enc` makes possible for its format.
    public let plaintextSize: Int64?
    public let context: FileTransferContext?

    public init(
        operationId: String,
        url: String,
        destinationFile: URL,
        encryptionInfo: EncryptedFileInfo? = nil,
        plaintextSize: Int64? = nil,
        context: FileTransferContext? = nil
    ) {
        self.operationId = operationId
        self.url = url
        self.destinationFile = destinationFile
        self.encryptionInfo = encryptionInfo
        self.plaintextSize = plaintextSize
        self.context = context
    }
}

public enum FileTransferResult<Success> {
    case success(Success)
    /// This attempt cannot complete normally.
    case failure(Error)
    /// Stopped with its recoverable work kept for another attempt of the same operation (a
    /// lost network, an unanswered completion). Not a success either.
    case interrupted(Error)
}

/// Moves the bytes of one file. UIKit prepares the file, schedules transfers, shows progress and
/// keeps the attachment records; a transport only executes. The default one,
/// `DefaultFileTransferTransport`, uses the Chat SDK's own transfers; an application can supply
/// its own (its backend, multipart protocol, saved sessions).
///
/// - `upload` returns once the object is stored, `download` once `destinationFile` holds the
///   complete, verified plaintext.
/// - Task cancellation stops reads, writes and network work. It does not mean the user
///   abandoned the file (it is also UIKit's pause fallback): keep what a retry can continue.
/// - `pause` returning true means the same invocation stays alive for `resume`; false lets
///   UIKit stop the attempt (cancelling its task) and call `upload` / `download` again later.
///   After a relaunch there is no invocation: UIKit calls again, with the same `operationId`,
///   and the transport restores what it saved.
/// - `cancel` is explicit abandonment, of a running or of a saved, inactive operation. It must
///   not block, must tolerate repeats and any order with the task's cancellation, and must end
///   a running invocation. Remote cleanup (an abort) is the transport's.
/// - Progress is a fraction, 0...1. A callback of an earlier attempt must not reach a later one.
public protocol FileTransferTransport: AnyObject {
    func upload(
        _ request: FileUploadRequest,
        progress: @escaping (Double) -> Void
    ) async -> FileTransferResult<FileUploadResult>

    func download(
        _ request: FileDownloadRequest,
        progress: @escaping (Double) -> Void
    ) async -> FileTransferResult<URL>

    func pause(operationId: String) -> Bool
    func resume(operationId: String) -> Bool
    func cancel(operationId: String)
}

public extension FileTransferTransport {
    func pause(operationId: String) -> Bool { false }
    func resume(operationId: String) -> Bool { false }
}

public enum FileTransferError: Error {
    /// `cancel(operationId:)` ended the transfer.
    case cancelled
    /// The request has nothing this transport can transfer (no url, no file).
    case invalidRequest
    /// An invocation of the same `operationId` is still running: the new one was rejected so
    /// the two never share a record (pause / resume / cancel would reach only one of them).
    case duplicateOperation
}

// MARK: - Diagnostics

/// What the transfer and encryption logs may say about a URL, an error or an attachment.
///
/// Never logged: keys (`EncryptedFileInfo.key`, `enc`), checkpoints, file contents, and the
/// query or fragment of a URL — a presigned or signed URL carries its credentials there.
enum TransferLog {

    /// The transfer the current task (or, outside a task, the current thread) works for. Bound
    /// by `TransportDataSession` around a transport call and by `AttachmentTransfer` around its
    /// event handling, so the layers below it (`FileEncryption`, the checksum, `enc` parsing)
    /// tag their lines with the same `xfer=` without a parameter in their public API.
    @TaskLocal static var current: TransferLogContext?

    /// The tag of `current`: `xfer=<operation> msg=<id>/<tid> channel=<id>`, or `xfer=-`.
    static var currentTag: String {
        current?.tag ?? "xfer=-"
    }

    /// Runs `body` with `context` as `current`, in a task or on the calling thread.
    static func with<T>(_ context: TransferLogContext?, _ body: () throws -> T) rethrows -> T {
        try $current.withValue(context, operation: body)
    }

    /// `reference` without its query, fragment or credentials: `scheme://host/path` for a URL,
    /// the reference up to its first `?` / `#` otherwise.
    static func redact(_ reference: String?) -> String {
        guard let reference, !reference.isEmpty else { return "-" }
        if var components = URLComponents(string: reference), components.host != nil {
            components.query = nil
            components.fragment = nil
            components.user = nil
            components.password = nil
            if let string = components.string {
                return string
            }
        }
        let end = reference.firstIndex(where: { $0 == "?" || $0 == "#" }) ?? reference.endIndex
        return String(reference[..<end])
    }

    static func redact(_ url: URL?) -> String {
        redact(url?.absoluteString)
    }

    /// An operation id as logs show it. Operation ids carry no url any more, but one made by
    /// an application's own session might.
    static func operation(_ operationId: String) -> String {
        redact(operationId)
    }

    /// A short, stable, non-reversible id for `text` (a url): 12 hex digits of its SHA-256.
    static func shortHash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).prefix(6).map { String(format: "%02x", $0) }.joined()
    }

    /// Whether `error` means the transfer was abandoned (`cancel`), not that it failed.
    static func isCancellation(_ error: Error?) -> Bool {
        switch error {
        case let error as URLError:
            return error.code == .cancelled
        case let error as FileTransferError:
            return error == .cancelled
        default:
            return false
        }
    }

    /// The kind of `error`, without its user info (a `URLError` carries the failing URL, query
    /// included): the case of UIKit's own errors, `domain/code` of any other, and the chain of
    /// underlying errors.
    static func describe(_ error: Error?) -> String {
        guard let error else { return "nil" }
        switch error {
        case let error as AttachmentEncryptionError:
            switch error {
            case .snapshotFailed(let underlying):
                return "AttachmentEncryptionError.snapshotFailed(\(describe(underlying)))"
            case .metadataFailed(let underlying):
                return "AttachmentEncryptionError.metadataFailed(\(describe(underlying)))"
            case .decryptionFailed(let underlying):
                return "AttachmentEncryptionError.decryptionFailed(\(ChatSDKFileEncryption.failureKind(underlying)): \(describe(underlying)))"
            case .invalidCiphertextSize(let size):
                return "AttachmentEncryptionError.invalidCiphertextSize(\(size))"
            case .encryptionUnsupportedBySession:
                return "AttachmentEncryptionError.encryptionUnsupportedBySession"
            case .encryptionBypassed:
                return "AttachmentEncryptionError.encryptionBypassed"
            case .invalidCheckpoint:
                return "AttachmentEncryptionError.invalidCheckpoint"
            case .invalidEncryptionInfo:
                return "AttachmentEncryptionError.invalidEncryptionInfo"
            case .metadataNotAnObject:
                return "AttachmentEncryptionError.metadataNotAnObject"
            }
        case let error as FileTransferError:
            return "FileTransferError.\(error)"
        case let error as TransportDataSessionError:
            return "TransportDataSessionError.\(error)"
        case is CancellationError:
            return "CancellationError"
        case let error as DecodingError:
            switch error {
            case .dataCorrupted(let context):
                return "DecodingError.dataCorrupted(\(path(context)))"
            case .keyNotFound(let key, let context):
                return "DecodingError.keyNotFound(\(key.stringValue) at \(path(context)))"
            case .typeMismatch(_, let context):
                return "DecodingError.typeMismatch(\(path(context)))"
            case .valueNotFound(_, let context):
                return "DecodingError.valueNotFound(\(path(context)))"
            @unknown default:
                return "DecodingError"
            }
        default:
            let ns = error as NSError
            var text = "\(ns.domain)/\(ns.code)"
            if isOutOfSpace(ns) {
                text += " (disk full)"
            }
            if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
                text += " <- \(describe(underlying))"
            }
            return text
        }
    }

    private static func path(_ context: DecodingError.Context) -> String {
        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        return path.isEmpty ? "<root>" : path
    }

    static func isOutOfSpace(_ error: NSError) -> Bool {
        (error.domain == NSCocoaErrorDomain && error.code == NSFileWriteOutOfSpaceError)
            || (error.domain == NSPOSIXErrorDomain && error.code == Int(ENOSPC))
    }

    /// The size of the file at `url`, nil when it cannot be read. Read from the file system,
    /// not `URL.resourceValues`: those are cached on the URL, so a log line would freeze the
    /// size the transfer code reads later from the same URL.
    static func size(_ url: URL?) -> Int64? {
        guard let url, url.isFileURL,
              let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber
        else { return nil }
        return size.int64Value
    }

    static func size(path: String?) -> String {
        size(path.map { URL(fileURLWithPath: $0) }).map { "\($0) B" } ?? "unknown"
    }

    static func sizeText(_ url: URL?) -> String {
        size(url).map { "\($0) B" } ?? "unknown"
    }

    /// Removes a file. A test seam: `FileManager.removeItem` in production.
    static var removeItem: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }

    /// Removes `url`, logging a failure instead of swallowing it. A file that is already gone
    /// is not a failure.
    @discardableResult
    static func remove(_ url: URL, what: String, context: String, level: SceytChatUIKit.Logger.LogLevel = .warning) -> Bool {
        do {
            try removeItem(url)
            return true
        } catch {
            let ns = error as NSError
            if ns.domain == NSCocoaErrorDomain, ns.code == NSFileNoSuchFileError {
                return true
            }
            if ns.domain == NSPOSIXErrorDomain, ns.code == Int(ENOENT) {
                return true
            }
            if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError,
               underlying.domain == NSPOSIXErrorDomain, underlying.code == Int(ENOENT) {
                return true
            }
            let line = "\(context) could not remove \(what) \(url.lastPathComponent): \(describe(error))"
            if level == .error {
                logger.error(line)
            } else {
                logger.warn(line)
            }
            return false
        }
    }
}

/// Who a transfer log line is about: the operation, and the message and channel when known.
/// Identifiers only: never a url, a key or a file name.
struct TransferLogContext: Sendable {
    let operationId: String
    /// `<message id>/<message tid>`.
    let message: String?
    let channel: String?

    init(operationId: String, message: ChatMessage?) {
        self.operationId = TransferLog.operation(operationId)
        self.message = message.map { "\($0.id)/\($0.tid)" }
        self.channel = message.map { "\($0.channelId)" }
    }

    init(operationId: String, context: FileTransferContext?) {
        self.init(operationId: operationId, message: (context as? AttachmentTransferContext)?.message)
    }

    init(_ request: FileUploadRequest) {
        self.init(operationId: request.operationId, context: request.context)
    }

    init(_ request: FileDownloadRequest) {
        self.init(operationId: request.operationId, context: request.context)
    }

    /// `xfer=<operation> msg=<id>/<tid> channel=<id>`, the prefix of every transfer line.
    var tag: String {
        var tag = "xfer=\(operationId)"
        if let message { tag += " msg=\(message)" }
        if let channel { tag += " channel=\(channel)" }
        return tag
    }
}

extension ChatMessage.Attachment {
    /// The attachment as transfer logs show it: identifiers only, never its url (it can be
    /// signed) or metadata (it can carry `enc`).
    var transferLogDescription: String {
        "tid=\(tid) id=\(id) type=\(type)"
    }
}
