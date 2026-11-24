//
//  TransferLog.swift
//  SceytChatUIKit
//
//  Diagnostics shared by every transfer layer: one log tag per transfer, error descriptions
//  without user info (no signed URLs), redaction, and the folders transfers keep files in.
//

import CryptoKit
import Foundation
import OSLog

// MARK: - Diagnostics

/// What the transfer logs may say about a URL, an error or an attachment.
///
/// Never logged: a provider's metadata values (they may carry keys), file contents, and the
/// query or fragment of a URL — a presigned or signed URL carries its credentials there.
enum TransferLog {

    /// The transfer the current task (or, outside a task, the current thread) works for. Bound
    /// by `TransportDataSession` around a transport call and by `AttachmentTransfer` around its
    /// event handling, so the layers below it (the provider, the checksum, the poster)
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

    /// The SHA-256 of `parts`, joined by NUL, in hex: a file name made from ids.
    static func hash(_ parts: [String]) -> String {
        SHA256.hash(data: Data(parts.joined(separator: "\u{0}").utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Whether `error` means the transfer was abandoned (`cancel`), not that it failed.
    /// The device could not reach the server (no network, connection lost, timed out):
    /// worth trying again by itself once the network is back, unlike a refusal.
    static func isConnectivity(_ error: Error?) -> Bool {
        guard let error else { return false }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return [
                NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
                NSURLErrorTimedOut, NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost,
                NSURLErrorDNSLookupFailed, NSURLErrorInternationalRoamingOff,
                NSURLErrorDataNotAllowed, NSURLErrorCallIsActive
            ].contains(nsError.code)
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isConnectivity(underlying)
        }
        return false
    }

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
        case let error as AttachmentMetadataError:
            switch error {
            case .notAnObject:
                return "AttachmentMetadataError.notAnObject"
            case .saveFailed(let underlying):
                return "AttachmentMetadataError.saveFailed(\(describe(underlying)))"
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

    /// The file was not there: nothing to remove or read, not a failure.
    static func isNotFound(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain, ns.code == NSFileNoSuchFileError || ns.code == NSFileReadNoSuchFileError {
            return true
        }
        if ns.domain == NSPOSIXErrorDomain, ns.code == Int(ENOENT) {
            return true
        }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            return underlying.domain == NSPOSIXErrorDomain && underlying.code == Int(ENOENT)
        }
        return false
    }

    /// Removes `url`, logging a failure instead of swallowing it. A file that is already gone
    /// is not a failure.
    @discardableResult
    static func remove(
        _ url: URL,
        what: String,
        context: String,
        level: SceytChatUIKit.Logger.LogLevel = .warning,
        removeItem: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }
    ) -> Bool {
        do {
            try removeItem(url)
            return true
        } catch {
            if isNotFound(error) {
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

/// The folders transfers keep their files in.
enum TransferDirectories {

    /// How old a decryption file must be before it counts as left behind.
    static let staleDecryptionAge: TimeInterval = 10 * 60

    /// Removes the hidden `.<uuid>-<name>` decryption files of `destination` that builds before
    /// the encrypted downloader left after a crash: nothing else would.
    static func removeStaleDecryptionFiles(for destination: URL, now: Date = Date(), tag: String) {
        let folder = destination.deletingLastPathComponent()
        let suffix = "-\(destination.lastPathComponent)"
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return }
        for name in names where name.hasPrefix(".") && name.hasSuffix(suffix) && name.count == 37 + suffix.count {
            let file = folder.appendingPathComponent(name)
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? now
            guard now.timeIntervalSince(modified) > staleDecryptionAge else { continue }
            TransferLog.remove(file, what: "a decryption file left behind", context: "[Transfer] \(tag) download")
        }
    }

    /// The caches folder, the temporary one without it.
    static func cachesOrTemporary(
        caches: () -> URL? = { FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first }
    ) -> URL {
        caches() ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }
}

// MARK: - Failure categories and metrics

/// What kind of failure ended a transfer: the one vocabulary summary lines and metrics use, so
/// "no network" is counted apart from "the server said no".
public enum TransferFailureCategory: String {
    /// It did not fail.
    case none
    /// The device could not reach the server (offline, timed out, connection lost).
    case connectivity
    /// The server answered and refused, or there was nothing to transfer (no url).
    case refusal
    /// The bytes or their encryption did not check out.
    case integrity
    /// The user or the app stopped it.
    case cancelled
    /// A file was missing, or the device ran out of space.
    case storage
    /// Anything else.
    case unknown

    public static func of(_ error: Error?) -> TransferFailureCategory {
        guard let error else { return .none }
        if TransferLog.isCancellation(error) || error is CancellationError {
            return .cancelled
        }
        // Data that didn't verify: tampered, truncated, or a wrong key (the Chat SDK's
        // file encryption, used by a provider).
        if (error as NSError).domain == "com.sceyt.chat.fileencryption" {
            return .integrity
        }
        if error is TransportDataSessionError || TransferLog.isOutOfSpace(error as NSError) {
            return .storage
        }
        if error is AttachmentTransferError {
            return .refusal
        }
        if TransferLog.isConnectivity(error) {
            return .connectivity
        }
        if error is URLError || (error as NSError).domain == NSURLErrorDomain {
            return .refusal
        }
        return .unknown
    }
}

/// The numbers of one finished transfer.
public struct TransferMetrics: Equatable {
    public enum Direction: String {
        case upload, download
    }

    public let operationId: String
    public let direction: Direction
    /// The upload went with provider metadata entries (an encryption key, say), new or kept
    /// from an earlier attempt. Always false for a download.
    public let hasProviderEntries: Bool
    /// The size shown for the file, nil when unknown.
    public let bytes: Int64?
    public let attempts: Int
    public let durationMs: Int
    /// success, cancelled, paused, interrupted or failure.
    public let result: String
    public let category: TransferFailureCategory
}

/// Told about every transfer that ends, e.g. to count failures by category.
public protocol TransferMetricsObserver: AnyObject {
    func transferDidEnd(_ metrics: TransferMetrics)
}

extension TransferLog {
    /// Transfers in Instruments, one event each.
    static let signposter = OSSignposter(subsystem: "com.sceyt.chat.uikit", category: "transfer")
}
