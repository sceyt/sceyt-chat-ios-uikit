//
//  FileTransferProvider.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation

/// Whatever a provider needs to know about a transfer beyond the file itself. UIKit passes an
/// `AttachmentTransferContext`.
/// Handed to the provider's tasks with the request: it must be safe to share.
public protocol FileTransferContext: Sendable {}

/// The attachment a request transfers, for a provider that needs more than the file (a header
/// with the message id, a per-message-type route).
/// Safe to share: both fields are constants, and providers only read the message (the
/// attachment's own fields are locked).
public struct AttachmentTransferContext: FileTransferContext, @unchecked Sendable {
    public let message: ChatMessage
    public let attachment: ChatMessage.Attachment

    public init(message: ChatMessage, attachment: ChatMessage.Attachment) {
        self.message = message
        self.attachment = attachment
    }
}

/// One upload. `sourceFile` is the final prepared file: resized, exported or zipped already.
public struct FileUploadRequest: Sendable {
    /// Names this logical upload across attempts and relaunches: a retry finds what an earlier
    /// attempt saved by it. Never the same as a download's.
    public let operationId: String
    public let sourceFile: URL
    public let fileName: String
    public let mimeType: String?
    public let context: FileTransferContext?
    /// The attachment's metadata entries that have string values. In `prepareUpload`: as saved
    /// before this attempt (what an earlier `prepareUpload` returned included). In `upload`:
    /// with this attempt's `prepareUpload` result merged in and saved.
    public let metadata: [String: String]
    /// Set when this upload is part of another one, the upload `parentOperationId`: a video's
    /// poster, sent inside the video's own attempt and slot. It is not an upload of its own
    /// for the user: a provider that shows uploads (a background activity, a count of files)
    /// shows it as part of its parent, not as one more file.
    public let parentOperationId: String?

    public init(
        operationId: String,
        sourceFile: URL,
        fileName: String,
        mimeType: String?,
        context: FileTransferContext? = nil,
        metadata: [String: String] = [:],
        parentOperationId: String? = nil
    ) {
        self.operationId = operationId
        self.sourceFile = sourceFile
        self.fileName = fileName
        self.mimeType = mimeType
        self.context = context
        self.metadata = metadata
        self.parentOperationId = parentOperationId
    }

    /// The same upload with `entries` merged into its metadata (added or overwritten).
    public func merging(metadata entries: [String: String]) -> FileUploadRequest {
        FileUploadRequest(
            operationId: operationId, sourceFile: sourceFile, fileName: fileName, mimeType: mimeType,
            context: context, metadata: metadata.merging(entries) { _, new in new },
            parentOperationId: parentOperationId
        )
    }
}

public struct FileUploadResult: Sendable {
    /// A URL, or whatever remote reference this provider's downloads understand. UIKit saves it
    /// as the attachment's url.
    public let url: String

    public init(url: String) {
        self.url = url
    }
}

/// One download, to `destinationFile`. The provider writes the file as the user should see it:
/// whatever it stored differently (encrypted, say) it turns back first.
public struct FileDownloadRequest: Sendable {
    public let operationId: String
    /// The attachment's url: the remote reference its upload returned.
    public let url: String
    /// Where the provider writes the file. Nothing may be there until all of it arrived (and,
    /// for an encrypted file, verified): write elsewhere first, then move it here.
    public let destinationFile: URL
    public let context: FileTransferContext?
    /// HTTP headers to send with the request. Credentials: never forward them to another origin.
    public let headers: [String: String]
    /// The received attachment's metadata entries that have string values: the provider finds
    /// its own entries here (whether the file is encrypted, and how).
    public let metadata: [String: String]

    public init(
        operationId: String,
        url: String,
        destinationFile: URL,
        context: FileTransferContext? = nil,
        headers: [String: String] = [:],
        metadata: [String: String] = [:]
    ) {
        self.operationId = operationId
        self.url = url
        self.destinationFile = destinationFile
        self.context = context
        self.headers = headers
        self.metadata = metadata
    }

    /// The same download, to another file.
    public func with(destinationFile: URL) -> FileDownloadRequest {
        FileDownloadRequest(
            operationId: operationId, url: url, destinationFile: destinationFile,
            context: context, headers: headers, metadata: metadata
        )
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
/// keeps the attachment records; a provider only executes. The default one,
/// `DefaultFileTransferProvider`, uses the Chat SDK's own transfers; an application can supply
/// its own (its backend, multipart protocol, saved sessions, encryption).
///
/// - `prepareUpload` runs before every `upload` attempt of the final source file, retries
///   included; not on pause or resume. `request.metadata` is the attachment's current metadata.
///   UIKit merges the returned entries into it (returned keys are added or overwritten, every
///   other key is kept) and saves them, in its database and on the attachment, before it calls
///   `upload`. Nil saves nothing. A throw fails the attempt; nothing is uploaded. UIKit never
///   reads the entries: they are the provider's (an encryption key, say), and travel to the
///   recipients in the message.
/// - `upload` returns once the object is stored, with its remote reference: UIKit saves it as
///   the attachment's url.
/// - `download` returns once `destinationFile` holds the file. The provider decides from its
///   own metadata entries how to turn what it stored back into it; data it cannot verify fails
///   the download, never falls back to the stored bytes.
/// - Task cancellation stops reads, writes and network work. It does not mean the user
///   abandoned the file (it is also UIKit's pause fallback): keep what a retry can continue.
/// - `pause` returning true means the same invocation stays alive for `resume`; false lets
///   UIKit stop the attempt (cancelling its task) and call `upload` / `download` again later,
///   an upload as a retry (`prepareUpload` runs first). After a relaunch there is no
///   invocation: UIKit calls again, with the same `operationId`, and the provider restores
///   what it saved.
/// - `cancel` is explicit abandonment, of a running or of a saved, inactive operation. It must
///   not block, must tolerate repeats and any order with the task's cancellation, and must end
///   a running invocation. Remote cleanup (an abort) is the provider's.
/// - Progress is a fraction, 0...1. A callback of an earlier attempt must not reach a later one.
public protocol FileTransferProvider: AnyObject {
    func prepareUpload(_ request: FileUploadRequest) async throws -> [String: String]?

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

public extension FileTransferProvider {
    func prepareUpload(_ request: FileUploadRequest) async throws -> [String: String]? { nil }

    func pause(operationId: String) -> Bool { false }
    func resume(operationId: String) -> Bool { false }
    func uploadDelivered(operationId: String) {}
}

public enum FileTransferError: Error {
    /// `cancel(operationId:)` ended the transfer.
    case cancelled
    /// The request has nothing this provider can transfer (no url, no file).
    case invalidRequest
    /// An invocation of the same `operationId` is still running: the new one was rejected so
    /// the two never share a record (pause / resume / cancel would reach only one of them).
    case duplicateOperation
}
