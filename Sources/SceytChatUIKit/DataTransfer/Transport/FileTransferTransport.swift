//
//  FileTransferTransport.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation

/// Whatever a transport needs to know about a transfer beyond the file itself. UIKit passes an
/// `AttachmentTransferContext`.
/// Handed to the transport's tasks with the request: it must be safe to share.
public protocol FileTransferContext: Sendable {}

/// The attachment a request transfers, for a transport that needs more than the file (a header
/// with the message id, a per-message-type route).
/// Safe to share: both fields are constants, and transports only read the message (the
/// attachment's own fields are locked).
public struct AttachmentTransferContext: FileTransferContext, @unchecked Sendable {
    public let message: ChatMessage
    public let attachment: ChatMessage.Attachment

    public init(message: ChatMessage, attachment: ChatMessage.Attachment) {
        self.message = message
        self.attachment = attachment
    }
}

public enum FileUploadType: Equatable, Sendable {
    case plain
    /// The transport encrypts the file with `FileEncryption` and returns its encryption.
    case encrypted
}

/// One upload. `sourceFile` is the final prepared plaintext file in both modes: resized,
/// exported or zipped already.
public struct FileUploadRequest: Sendable {
    /// Names this logical upload across attempts and relaunches: a retry finds what an earlier
    /// attempt saved by it. Never the same as a download's.
    public let operationId: String
    public let sourceFile: URL
    public let fileName: String
    public let mimeType: String?
    public let context: FileTransferContext?
    public let type: FileUploadType
    /// `.encrypted` only. In `prepareUpload`: the attachment's saved `enc` (an earlier attempt
    /// prepared it), nil before the first. In `upload`: what `prepareUpload` returned and UIKit
    /// saved in the attachment's metadata; the transport encrypts under exactly this key, or,
    /// when nil (a transport without a prepare step), under a key of its own.
    public let encryptionInfo: EncryptedFileInfo?

    public init(
        operationId: String,
        sourceFile: URL,
        fileName: String,
        mimeType: String?,
        context: FileTransferContext? = nil,
        type: FileUploadType = .plain,
        encryptionInfo: EncryptedFileInfo? = nil
    ) {
        self.operationId = operationId
        self.sourceFile = sourceFile
        self.fileName = fileName
        self.mimeType = mimeType
        self.context = context
        self.type = type
        self.encryptionInfo = encryptionInfo
    }

    /// The same upload under `encryptionInfo`.
    public func with(encryptionInfo: EncryptedFileInfo?) -> FileUploadRequest {
        FileUploadRequest(
            operationId: operationId, sourceFile: sourceFile, fileName: fileName, mimeType: mimeType,
            context: context, type: type, encryptionInfo: encryptionInfo
        )
    }
}

/// What `prepareUpload` settled before any byte is sent.
public struct FileUploadPreparation: Sendable {
    /// The encryption the upload will use. UIKit saves it in the attachment's `enc` (and the
    /// database) before it calls `upload`, so a retry or a relaunch prepares with it again.
    /// Nil: the transport makes its key during `upload` and returns it then.
    public let encryptionInfo: EncryptedFileInfo?

    public init(encryptionInfo: EncryptedFileInfo?) {
        self.encryptionInfo = encryptionInfo
    }
}

public struct FileUploadResult: Sendable {
    /// A URL, or whatever remote reference this transport's downloads understand. The message
    /// carries it as the attachment's url.
    public let url: String
    /// The encryption of the uploaded bytes: set exactly when the request was `.encrypted`.
    public let encryptionInfo: EncryptedFileInfo?
    /// The size of the plaintext that was encrypted, when the transport knows it (its
    /// encryption session does). Nil: the router uses the size it measured before the upload.
    public let plaintextSize: Int64?

    public init(url: String, encryptionInfo: EncryptedFileInfo? = nil, plaintextSize: Int64? = nil) {
        self.url = url
        self.encryptionInfo = encryptionInfo
        self.plaintextSize = plaintextSize
    }
}

/// One download of the remote bytes, as stored (architecture doc §4). The transport never
/// decrypts: for an encrypted attachment UIKit hands it a staging `destinationFile` and then
/// verifies and decrypts what it wrote (`EncryptedFileDownloader`).
public struct FileDownloadRequest: Sendable {
    public let operationId: String
    /// The attachment's url: the remote reference its upload returned.
    public let url: String
    /// Where the transport writes the downloaded bytes. Nothing may be there until all of them
    /// arrived: write elsewhere first, then move it here.
    public let destinationFile: URL
    public let context: FileTransferContext?
    /// HTTP headers to send with the request. Credentials: never forward them to another origin.
    public let headers: [String: String]

    public init(
        operationId: String,
        url: String,
        destinationFile: URL,
        context: FileTransferContext? = nil,
        headers: [String: String] = [:]
    ) {
        self.operationId = operationId
        self.url = url
        self.destinationFile = destinationFile
        self.context = context
        self.headers = headers
    }

    /// The same download, to another file.
    public func with(destinationFile: URL) -> FileDownloadRequest {
        FileDownloadRequest(operationId: operationId, url: url, destinationFile: destinationFile, context: context, headers: headers)
    }
}

public enum FileTransferResult<Success: Sendable>: Sendable {
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
/// - `upload` returns once the object is stored, `download` once `destinationFile` holds all of
///   the remote bytes as stored. An encrypted attachment's are ciphertext: UIKit verifies and
///   decrypts them before it reports the attachment downloaded.
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
/// - `prepareUpload` runs before every `upload` attempt, once the file is prepared. For an
///   encrypted upload it returns the key, which UIKit saves in the attachment's `enc` before
///   the upload starts; given the saved one (`request.encryptionInfo`) it must return it
///   unchanged. The default prepares nothing.
public protocol FileTransferTransport: AnyObject {
    func prepareUpload(_ request: FileUploadRequest) async -> FileTransferResult<FileUploadPreparation>

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
    /// The message carrying the upload `operationId` was sent: nothing will ask for that
    /// upload's result again, so what was kept to report it again (after a lost result, a
    /// relaunch) can go. Never called for a running upload; must tolerate an unknown id.
    func uploadDelivered(operationId: String)
}

public extension FileTransferTransport {
    func prepareUpload(_ request: FileUploadRequest) async -> FileTransferResult<FileUploadPreparation> {
        .success(FileUploadPreparation(encryptionInfo: nil))
    }

    func pause(operationId: String) -> Bool { false }
    func resume(operationId: String) -> Bool { false }
    func uploadDelivered(operationId: String) {}
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
