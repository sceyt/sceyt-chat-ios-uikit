//
//  TransferRun.swift
//  SceytChatUIKit
//
//  One call that starts transfers (an upload or download of a message's attachments): it
//  takes each task's events, applies them to the task's attachment, and ends the task.
//

import Foundation

final class TransferRun {
    private weak var transfer: AttachmentTransfer?
    private let message: ChatMessage
    private let attachments: [ChatMessage.Attachment]
    private let completion: ((ChatMessage?, Error?) -> Void)?

    init(
        transfer: AttachmentTransfer,
        message: ChatMessage,
        attachments: [ChatMessage.Attachment],
        completion: ((ChatMessage?, Error?) -> Void)?
    ) {
        self.transfer = transfer
        self.message = message
        self.attachments = attachments
        self.completion = completion
    }

    /// Takes the events of `tasks`. Each task brings its own attachment: `tasks` and
    /// `attachments` are not parallel (an attachment already transferring has no task here).
    func observe(_ tasks: [SCTDataSessionTaskInfo]) {
        for taskInfo in tasks {
            // The run lives as long as one of its tasks can report.
            taskInfo.onEvent = { event in
                self.handle(event, of: taskInfo)
            }
            taskInfo.onTransferSize = { [weak taskInfo] size in
                guard let taskInfo else { return }
                self.recordTransferSize(size, of: taskInfo)
            }
            taskInfo.onUploadPrepared = { [weak taskInfo] entries, done in
                guard let taskInfo else {
                    done(CancellationError())
                    return
                }
                self.savePreparedEntries(entries, of: taskInfo, done: done)
            }
            taskInfo.onFilePrepared = { [weak taskInfo] file in
                guard let taskInfo else { return }
                await self.attachVideoPreview(of: taskInfo, file: file)
            }
        }
    }

    /// Merges the entries the provider's `prepareUpload` returned into the attachment's
    /// metadata (returned keys added or overwritten, the rest kept) and saves the row, before
    /// the upload sends a byte (spec: write-ahead, so a retry or a relaunch finds them on the
    /// attachment, and a crash at any later point can resume).
    private func savePreparedEntries(_ entries: [String: String], of taskInfo: SCTDataSessionTaskInfo, done: @escaping (Error?) -> Void) {
        guard let transfer else {
            done(CancellationError())
            return
        }
        let atch = taskInfo.attachment
        TransferLog.with(taskInfo.logContext) {
            // Keys only: a provider's values may carry keys.
            let keys = entries.keys.sorted().joined(separator: ",")
            if entries.allSatisfy({ atch.stringMetadataEntries[$0.key] == $0.value }) {
                logger.debug("[Attachment] \(taskInfo.logTag) upload prepared: entries [\(keys)] already saved")
                done(nil)
                return
            }
            do {
                atch.updateMetadata(try ChatMessage.Attachment.metadata(atch.metadata, merging: entries))
            } catch {
                logger.debug("[Attachment] \(taskInfo.logTag) upload cannot merge the prepared entries [\(keys)] into the metadata: \(TransferLog.describe(error))")
                done(AttachmentMetadataError.saveFailed(error))
                return
            }
            logger.debug("[Attachment] \(taskInfo.logTag) upload prepared entries [\(keys)], saving before the upload")
            transfer.store.save([atch], of: message) { error in
                if let error {
                    logger.debug("[Attachment] \(taskInfo.logTag) upload prepared entries could not be saved: \(TransferLog.describe(error))")
                    done(AttachmentMetadataError.saveFailed(error))
                } else {
                    done(nil)
                }
            }
        }
    }

    /// A sent video's poster, as its own preview attachment, before the video's bytes: the
    /// preview and the video's `pvw` are saved with the message, so the message the
    /// sender builds once the video lands carries both.
    private func attachVideoPreview(of taskInfo: SCTDataSessionTaskInfo, file: URL) async {
        guard let transfer else { return }
        let message = self.message
        await TransferLog.$current.withValue(taskInfo.logContext) {
            await transfer.posters.attachPreview(taskInfo: taskInfo, message: message, attachment: taskInfo.attachment, file: file) { attachments in
                await withCheckedContinuation { continuation in
                    transfer.store.save(attachments, of: message) { continuation.resume(returning: $0) }
                }
            }
        }
    }

    /// An upload's prepared file is what the message carries and what its progress counts: a
    /// compressed video's is a small part of the original's size, which the attachment held
    /// until now. Saved, so a cell bound later (after a relaunch too) shows it.
    private func recordTransferSize(_ size: Int64, of taskInfo: SCTDataSessionTaskInfo) {
        guard let transfer, taskInfo.transferType == .upload else { return }
        let atch = taskInfo.attachment
        let size = UInt(size)
        guard atch.uploadedFileSize != size else { return }
        TransferLog.with(taskInfo.logContext) {
            logger.debug("[Attachment] \(taskInfo.logTag) upload size \(atch.uploadedFileSize) B -> \(size) B (the prepared file)")
        }
        atch.uploadedFileSize = size
        transfer.store.save([atch], of: message)
    }

    private func handle(_ event: SCTDataSessionTaskInfo.Event, of taskInfo: SCTDataSessionTaskInfo) {
        guard let transfer else { return }
        let atch = taskInfo.attachment
        // The hot path: no log context to build.
        if case .updateProgress(let progress) = event {
            report(progress: progress, of: taskInfo, transfer: transfer)
            return
        }
        // Every layer this event reaches (the checksum, the poster) tags its lines with
        // this transfer.
        TransferLog.with(taskInfo.logContext) {
            switch event {
            case .updateProgress:
                break
            case .updateLocalFileURL(let url, let previousPath):
                transfer.updateLocalFile(url, previousPath: previousPath, attachment: atch, taskInfo: taskInfo, message: message)
            case .successURL(let url):
                logger.verbose("[Attachment] \(taskInfo.logTag) success \(TransferLog.redact(url))")
                finishSuccess(uri: url.absoluteString, taskInfo: taskInfo, atch: atch, transfer: transfer)
            case .successURI(let uri):
                logger.verbose("[Attachment] \(taskInfo.logTag) success \(TransferLog.redact(uri))")
                finishSuccess(uri: uri, taskInfo: taskInfo, atch: atch, transfer: transfer)
            case .failure(let error):
                fail(taskInfo: taskInfo, atch: atch, error: error, transfer: transfer)
            }
        }
    }

    // MARK: Progress

    private func report(progress: Double, of taskInfo: SCTDataSessionTaskInfo, transfer: AttachmentTransfer) {
        guard progress > 0 else { return }
        let key = AttachmentTransfer.key(message: taskInfo.message, attachment: taskInfo.attachment)
        let observers = transfer.observers.record(progress: progress, forKey: key)
        if observers.isEmpty {
            if transfer.observers.markUnobserved(key) {
                // Normal when no cell for it is on screen. When one is, the emitter and the
                // subscriber disagree on the attachment's identity: the ring stays frozen at
                // its bind-time floor until the transfer completes.
                logger.verbose("[Attachment] \(taskInfo.logTag) progress has no observer for KEY \(TransferLog.redact(key)) (no cell on screen?)")
            }
            return
        }
        let attachmentProgress = AttachmentTransfer.AttachmentProgress(
            message: taskInfo.message,
            attachment: taskInfo.attachment,
            progress: progress,
            totalBytes: taskInfo.transferSize.map { UInt64($0) }
        )
        observers.forEach { $0(attachmentProgress) }
    }

    private func notifyCompletion(of taskInfo: SCTDataSessionTaskInfo, attachment: ChatMessage.Attachment, error: Error? = nil, transfer: AttachmentTransfer) {
        let key = AttachmentTransfer.key(message: taskInfo.message, attachment: taskInfo.attachment)
        let observers = transfer.observers.completionObservers(forKey: key)
        guard !observers.isEmpty else { return }
        let attachmentCompletion = AttachmentTransfer.AttachmentCompletion(message: message, attachment: attachment, error: error)
        observers.forEach { $0(attachmentCompletion) }
    }

    // MARK: Ending

    private func fail(taskInfo: SCTDataSessionTaskInfo, atch: ChatMessage.Attachment, error: Error?, transfer: AttachmentTransfer) {
        switch taskInfo.transferType {
        case .download:
            if atch.status != .pauseDownloading {
                atch.status = AttachmentTransfer.downloadStatus(
                    afterFailure: error,
                    userCancelled: taskInfo.action == .cancel,
                    interrupted: taskInfo.wasInterrupted
                )
            }
        case .upload:
            if atch.status != .pauseUploading {
                atch.status = AttachmentTransfer.uploadStatus(
                    afterFailure: error,
                    userCancelled: taskInfo.action == .cancel,
                    interrupted: taskInfo.wasInterrupted,
                    isOffline: transfer.isDeviceOffline
                )
            }
        }
        // The one line for this failure, with its whole cause chain: the layers below logged
        // it at debug.
        // Logged whether or not anyone observes the metrics (an optional call would skip it).
        let metrics = AttachmentTransfer.logSummary(taskInfo, attachment: atch, error: error, now: transfer.now())
        transfer.metricsObserver?.transferDidEnd(metrics)
        notifyCompletion(of: taskInfo, attachment: atch, error: error, transfer: transfer)
        AttachmentTransferStatusRelay.default.post(atch, status: atch.status)
        end(taskInfo, error: error, transfer: transfer)
    }

    private func finishSuccess(uri: String, taskInfo: SCTDataSessionTaskInfo, atch: ChatMessage.Attachment, transfer: AttachmentTransfer) {
        // For a just-uploaded video, upload its poster frame too before completing, so the
        // merged "pvw" metadata is persisted by `end` and rides the wire message the
        // sender builds from this attachment.
        transfer.attachVideoThumbnailIfNeeded(taskInfo: taskInfo, message: message, attachment: atch) { [self] in
            TransferLog.with(taskInfo.logContext) {
                atch.url = uri
                atch.transferProgress = 1
                atch.status = .done
                notifyCompletion(of: taskInfo, attachment: atch, transfer: transfer)
                let metrics = AttachmentTransfer.logSummary(taskInfo, attachment: atch, error: nil, reference: uri, now: transfer.now())
                transfer.metricsObserver?.transferDidEnd(metrics)
                // `.done` is relayed once, by `end`, after it is persisted.
                end(taskInfo, error: nil, transfer: transfer)
            }
        }
    }

    /// The task is over: its attachment is persisted, the callers hear the end, and it
    /// leaves the transfer.
    private func end(_ taskInfo: SCTDataSessionTaskInfo, error: Error?, transfer: AttachmentTransfer) {
        let key = AttachmentTransfer.key(message: taskInfo.message, attachment: taskInfo.attachment)
        let groupKey = message.id != 0 ? Int64(message.id) : message.tid
        let tag = taskInfo.logTag
        // No progress or completion event will fire for this key again: drop the cached
        // percent, so a rebind reading a stale `.downloading` can't restore a ring nothing
        // would ever hide.
        transfer.observers.endProgress(forKey: key)
        // Only this task's attachment: the message's others belong to their own transfers.
        let identity = AttachmentTransfer.transferIdentity(of: taskInfo.attachment)
        let owned = attachments.filter { AttachmentTransfer.transferIdentity(of: $0) == identity }
        transfer.store.saveEnd(of: owned.isEmpty ? [taskInfo.attachment] : owned, of: message) { [self] storedMessage, dbError in
            if let dbError {
                logger.error("[Attachment] \(tag) \(taskInfo.transferType) end could not be persisted: \(TransferLog.describe(dbError)) \(taskInfo.attachment.transferLogDescription)")
            }
            // The one relay of a successful transfer, and its last word: a pause that slipped
            // in just before the success relayed `.pauseUploading`.
            if error == nil, taskInfo.attachment.status == .done {
                AttachmentTransferStatusRelay.default.post(taskInfo.attachment, status: .done)
            }
            completion?(storedMessage ?? message, error)
            for callback in transfer.observers.takeWaiting(forKey: key, of: taskInfo.transferType) {
                callback(storedMessage ?? message, error)
            }
        }
        if let survivors = transfer.removeTask(taskInfo, fromGroup: groupKey) {
            logger.verbose("[Attachment] \(tag) task removed, \(survivors) other task(s) of the message still running")
        }
    }
}
