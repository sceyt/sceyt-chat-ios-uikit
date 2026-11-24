//
//  AttachmentTransfer+Start.swift
//  SceytChatUIKit
//
//  Starting a message's uploads and downloads: each attachment is planned (joins a running
//  transfer, fails before any session sees it, or starts), then the plan is launched.
//

import Foundation

/// The tasks one start call makes, sorted by what happens to them.
struct TransferPlan {
    /// Every task made: all are tracked, observed and end through `handle(tasks:)`.
    private(set) var tasks = [SCTDataSessionTaskInfo]()
    /// Handed to the data session.
    private(set) var starts = [SCTDataSessionTaskInfo]()
    /// Failed before any session sees them, with why.
    private(set) var rejected = [(SCTDataSessionTaskInfo, Error)]()

    mutating func start(_ taskInfo: SCTDataSessionTaskInfo) {
        tasks.append(taskInfo)
        starts.append(taskInfo)
    }

    mutating func reject(_ taskInfo: SCTDataSessionTaskInfo, _ error: Error) {
        tasks.append(taskInfo)
        rejected.append((taskInfo, error))
    }
}

extension AttachmentTransfer {

    // MARK: Uploads

    func startUploads(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment],
        completion: ((ChatMessage?, Error?) -> Void)?
    ) {
        guard let dataSession = dataSession(for: message) else {
            logger.error("[Attachment] upload: no data session, nothing uploads for message \(message.id)/\(message.tid) channel=\(message.channelId)")
            completion?(message, AttachmentTransferError.externalTransferrerNotImplemented)
            return
        }
        let existTasks = tasks(inGroup: Self.groupKey(of: message))
        var plan = TransferPlan()
        for attachment in attachments {
            planUpload(of: attachment, message: message, dataSession: dataSession, existTasks: existTasks, completion: completion, into: &plan)
        }
        guard !plan.tasks.isEmpty else {
            logger.info("[Attachment] upload: no new task for message \(message.id)/\(message.tid) channel=\(message.channelId), every attachment is already uploading")
            completion?(message, AttachmentTransferError.alreadyTransferring)
            return
        }
        launchUploads(plan, message: message, attachments: attachments, dataSession: dataSession, completion: completion)
    }

    private func planUpload(
        of attachment: ChatMessage.Attachment,
        message: ChatMessage,
        dataSession: SCTDataSession,
        existTasks: [SCTDataSessionTaskInfo]?,
        completion: ((ChatMessage?, Error?) -> Void)?,
        into plan: inout TransferPlan
    ) {
        repairAttachmentFilePathIfNeeded(attachment, dataSession: dataSession)
        if let resolvedFilePath = dataSession.getFilePath(attachment: attachment),
           resolvedFilePath != attachment.filePath {
            attachment.filePath = resolvedFilePath
        }
        // A task that already ended (a cancelled one included) does not count: a new upload of
        // its file is a new upload.
        if let filePath = attachment.filePath,
           let running = existTasks?.first(where: { !$0.isTerminal && $0.attachment.filePath == filePath }) {
            // Appended: an earlier caller waiting on the same upload keeps its completion.
            if let completion {
                observers.wait(forKey: Self.key(message: message, attachment: attachment), of: .upload, completion)
            }
            logger.info("[Attachment] \(running.logTag) upload already running for this file, waiting for it \(attachment.transferLogDescription)")
            return
        }
        let taskInfo = makeTask(.upload, message: message, attachment: attachment, dataSession: dataSession)
        let tag = taskInfo.logTag
        guard attachment.filePath != nil else {
            // Failed, not skipped: without a task nothing would ever change its status.
            logger.debug("[Attachment] \(tag) upload has no local file (source deleted?): failing it (missingSourceFile) \(attachment.transferLogDescription)")
            plan.reject(taskInfo, TransportDataSessionError.missingSourceFile)
            return
        }
        attachment.status = .uploading
        logger.info("[Attachment] \(tag) upload start size=\(TransferLog.size(path: attachment.filePath)) session=\(type(of: dataSession)) \(attachment.transferLogDescription)")
        plan.start(taskInfo)
    }

    private func launchUploads(
        _ plan: TransferPlan,
        message: ChatMessage,
        attachments: [ChatMessage.Attachment],
        dataSession: SCTDataSession,
        completion: ((ChatMessage?, Error?) -> Void)?
    ) {
        store.save(attachments, of: message)
        // A rejected task never joins the group: it ends below, before any session sees it.
        let rejected = Set(plan.rejected.map { ObjectIdentifier($0.0) })
        merge(plan.tasks.filter { !rejected.contains(ObjectIdentifier($0)) }, intoGroup: Self.groupKey(of: message))
        // The hooks go in before any session sees a task: an event it reports at once (a fast
        // failure) is never lost.
        handle(tasks: plan.tasks, message: message, attachments: attachments) { message, error in
            guard let message else {
                completion?(nil, error)
                return
            }
            // Deleted while it uploaded: the caller gets no message to send.
            self.store.messageExists(message) { exists in
                completion?(exists ? message : nil, error)
            }
        }
        for (taskInfo, error) in plan.rejected {
            taskInfo.failure(error: error)
        }
        // Seed a starting progress, so the ring shows for the whole pre-transfer window: the
        // checksum round-trip, the image resize / video export, and the wait for an upload slot.
        for taskInfo in plan.starts where taskInfo.attachment.status == .uploading {
            taskInfo.updateProgress(Self.initialUploadProgress)
        }
        for taskInfo in plan.starts {
            dataSession.upload(attachment: taskInfo.attachment, taskInfo: taskInfo)
        }
    }

    // MARK: Downloads

    func startDownloads(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment],
        completion: ((ChatMessage?, Error?) -> Void)?
    ) {
        guard let dataSession = dataSession(for: message) else {
            logger.error("[Attachment] download: no data session, nothing will download for message \(message.id)/\(message.tid) channel=\(message.channelId)")
            completion?(message, AttachmentTransferError.externalTransferrerNotImplemented)
            return
        }
        let existTasks = tasks(inGroup: Self.groupKey(of: message))
        var plan = TransferPlan()
        for attachment in attachments {
            planDownload(of: attachment, message: message, dataSession: dataSession, existTasks: existTasks, completion: completion, into: &plan)
        }
        guard !plan.tasks.isEmpty else {
            logger.verbose("[Attachment] download: no new task for message \(message.id)/\(message.tid) channel=\(message.channelId), every requested attachment is already transferring or on disk")
            completion?(message, AttachmentTransferError.alreadyTransferring)
            return
        }
        store.save(attachments, of: message)
        // A rejected task never joins the group: it ends below, before any session sees it, and
        // a concurrent call must not wait on it as if it ran.
        let rejected = Set(plan.rejected.map { ObjectIdentifier($0.0) })
        merge(plan.tasks.filter { !rejected.contains(ObjectIdentifier($0)) }, intoGroup: Self.groupKey(of: message))
        // The hooks go in before any session sees a task: an event it reports at once (a fast
        // failure) is never lost.
        handle(tasks: plan.tasks, message: message, attachments: attachments, completion: completion)
        for (taskInfo, error) in plan.rejected {
            taskInfo.failure(error: error)
        }
        for taskInfo in plan.starts {
            dataSession.download(attachment: taskInfo.attachment, taskInfo: taskInfo)
        }
    }

    private func planDownload(
        of attachment: ChatMessage.Attachment,
        message: ChatMessage,
        dataSession: SCTDataSession,
        existTasks: [SCTDataSessionTaskInfo]?,
        completion: ((ChatMessage?, Error?) -> Void)?,
        into plan: inout TransferPlan
    ) {
        if Self.isAwaitingUpload(attachment) {
            // Never sent: there is nothing to download, and failing it would put a download
            // button on it. Its status belongs to its upload and is left alone.
            logger.warn("[Attachment] download skipped: the attachment is an outgoing one that has not been uploaded \(attachment.transferLogDescription)")
            return
        }
        let taskInfo = makeTask(.download, message: message, attachment: attachment, dataSession: dataSession)
        let tag = taskInfo.logTag
        guard let url = attachment.url, !url.isEmpty else {
            // Failed like any download, not skipped: a skipped attachment would keep
            // `.downloading` (a spinner) with nothing left to end it.
            logger.error("[Attachment] \(tag) download failed before fetching: the attachment has no url \(attachment.transferLogDescription)")
            attachment.status = .downloading
            plan.reject(taskInfo, AttachmentTransferError.missingURL)
            return
        }
        if existTasks?.contains(where: { !$0.isTerminal && $0.attachment.url == attachment.url }) == true {
            // The running task's end calls this completion too.
            if let completion {
                observers.wait(forKey: Self.key(message: message, attachment: attachment), of: .download, completion)
            }
            logger.verbose("[Attachment] \(tag) download: task already exists, waiting for it")
            return
        }
        if filePath(attachment: attachment) != nil {
            // Nothing will ever end a task for this key: the completion is not kept (it would
            // leak, and fire on some later download).
            logger.verbose("[Attachment] \(tag) download: file already on disk")
            return
        }
        let size = Int64(clamping: attachment.uploadedFileSize)
        let available = environment.availableStorage()
        if StorageSpace.cannotFit(size, available: available), let available {
            // Failed like any download (a retry arrow, the app's "storage full" alert), without
            // fetching a part that could never be written.
            logger.error("[Attachment] \(tag) download failed before fetching: \(size) B does not fit in \(available) B free \(attachment.transferLogDescription)")
            attachment.status = .downloading
            plan.reject(taskInfo, StorageSpace.outOfSpaceError(needed: size, available: available))
            return
        }
        attachment.status = .downloading
        logger.info("[Attachment] \(tag) download start size=\(attachment.uploadedFileSize) url=\(TransferLog.redact(attachment.url)) session=\(type(of: dataSession)) \(attachment.transferLogDescription)")
        plan.start(taskInfo)
    }

    // MARK: Shared

    /// The key of the message's task group: its id, or its tid until it has one.
    static func groupKey(of message: ChatMessage) -> Int64 {
        message.id != 0 ? Int64(message.id) : message.tid
    }

    private func makeTask(
        _ type: SCTDataSessionTaskInfo.TransferType,
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        dataSession: SCTDataSession
    ) -> SCTDataSessionTaskInfo {
        let taskInfo = SCTDataSessionTaskInfo(
            transferType: type,
            message: message,
            attachment: attachment,
            startedAt: now(),
            checksumProvider: environment.checksumProvider().init()
        )
        Self.assignOperationId(to: taskInfo, dataSession: dataSession)
        return taskInfo
    }
}
