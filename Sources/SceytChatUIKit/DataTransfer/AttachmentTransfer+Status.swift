//
//  AttachmentTransfer+Status.swift
//  SceytChatUIKit
//
//  What a transfer ends as: the attachment status after a failure, and the one summary
//  line every transfer logs.
//

import Foundation
import OSLog
import SceytChat
import UIKit.UIImage

extension AttachmentTransfer {
    /// The status of an upload that failed with `error`. Being offline is not a refusal: the
    /// upload fails the instant there is no network, and `.failedUploading` would swap the
    /// loader for a retry arrow on a message the app resends by itself on the next connect
    /// (`SyncService.resendPendingMessage`), so it is parked back in the queue. A refusal by
    /// encryption, or a file that is gone, fails.
    ///
    /// A cancel by the user (`SCTDataSessionTaskInfo.cancel`, or a cancellation the session did
    /// not report as an interruption) is `.pauseUploading`: the one upload status
    /// `SyncService.resendPendingMessage` skips, so a reconnect never sends what the user
    /// abandoned; a tap on it resends, as on `.failedUploading`. A cancellation reported as an
    /// interruption is parked like an offline failure: it is resent.
    static func uploadStatus(
        afterFailure error: Error?,
        userCancelled: Bool = false,
        interrupted: Bool = false,
        isOffline: Bool
    ) -> ChatMessage.Attachment.TransferStatus {
        if userCancelled || (TransferLog.isCancellation(error) && !interrupted) {
            return .pauseUploading
        }
        if TransferLog.isCancellation(error) {
            return .pending
        }
        if error is AttachmentEncryptionError {
            return .failedUploading
        }
        if case .missingSourceFile? = error as? TransportDataSessionError {
            return .failedUploading
        }
        return isOffline ? .pending : .failedUploading
    }

    /// The status of a download that failed with `error`. Only a real refusal is
    /// `.failedDownloading` (a retry arrow, never retried by itself). An interruption or a
    /// connectivity error (no network, connection lost) is `.pending`: the next bind of the
    /// message downloads it again. A cancel by the user is `.pauseDownloading`: a tap resumes it.
    static func downloadStatus(
        afterFailure error: Error?,
        userCancelled: Bool = false,
        interrupted: Bool = false
    ) -> ChatMessage.Attachment.TransferStatus {
        if userCancelled || (TransferLog.isCancellation(error) && !interrupted) {
            return .pauseDownloading
        }
        if interrupted {
            return .pending
        }
        return TransferLog.isConnectivity(error) ? .pending : .failedDownloading
    }

    /// The one line a transfer ends with: info for a success, warn for an interruption, a
    /// pause or a cancel, error for a failure, which it reports with its whole cause chain.
    /// How a transfer ended, and the log level that says it: info for a success, warning for an
    /// interruption, a pause or a cancel, error for a failure.
    static func outcome(
        error: Error?,
        status: ChatMessage.Attachment.TransferStatus,
        interrupted: Bool
    ) -> (result: String, level: SceytChatUIKit.Logger.LogLevel) {
        if error == nil {
            return ("success", .info)
        }
        if TransferLog.isCancellation(error) {
            return ("cancelled", .warning)
        }
        if status == .pauseUploading || status == .pauseDownloading {
            return ("paused", .warning)
        }
        if interrupted || status == .pending {
            return ("interrupted", .warning)
        }
        return ("failure", .error)
    }

    /// Logs the one line a transfer ends with, emits its signpost, and returns its numbers.
    @discardableResult
    static func logSummary(_ taskInfo: SCTDataSessionTaskInfo, attachment atch: ChatMessage.Attachment, error: Error?, reference: String? = nil, now: Date = Date()) -> TransferMetrics {
        let duration = Int((now.timeIntervalSince(taskInfo.startedAt) * 1000).rounded())
        var size = Int64(atch.uploadedFileSize)
        if size <= 0, let filePath = atch.filePath, error == nil {
            size = TransferLog.size(URL(fileURLWithPath: filePath)) ?? 0
        }
        let (result, level) = outcome(error: error, status: atch.status, interrupted: taskInfo.wasInterrupted)
        var line = "[Attachment] \(taskInfo.logTag) transfer finished"
        line += " dir=\(taskInfo.transferType == .upload ? "upload" : "download")"
        line += " type=\(taskInfo.encryption == .required ? "encrypted" : "plain")"
        line += " size=\(size > 0 ? "\(size)" : "-")"
        line += " attempts=\(taskInfo.attempts)"
        line += " duration=\(duration)ms"
        let category = TransferFailureCategory.of(error)
        line += " result=\(result)"
        line += " category=\(category.rawValue)"
        line += " error=\(error.map { TransferLog.describe($0) } ?? "-")"
        line += " status=\(atch.status)"
        if let reference {
            line += " ref=\(TransferLog.redact(reference))"
        }
        line += " tid=\(atch.tid) id=\(atch.id) kind=\(atch.type)"
        switch level {
        case .error:
            logger.error(line)
        case .warning:
            logger.warn(line)
        default:
            logger.info(line)
        }
        let metrics = TransferMetrics(
            operationId: taskInfo.operationId,
            direction: taskInfo.transferType == .upload ? .upload : .download,
            isEncrypted: taskInfo.encryption == .required,
            bytes: size > 0 ? size : nil,
            attempts: taskInfo.attempts,
            durationMs: duration,
            result: result,
            category: category
        )
        TransferLog.signposter.emitEvent(
            "transfer",
            "xfer=\(metrics.operationId, privacy: .public) dir=\(metrics.direction.rawValue, privacy: .public) bytes=\(metrics.bytes ?? -1) ms=\(duration) result=\(result, privacy: .public) category=\(category.rawValue, privacy: .public)"
        )
        return metrics
    }
}
