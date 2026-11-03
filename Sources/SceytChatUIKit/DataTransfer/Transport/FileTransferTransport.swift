//
//  FileTransferTransport.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

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
}
