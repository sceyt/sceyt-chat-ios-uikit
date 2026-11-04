//
//  TransportDataSession+Uploads.swift
//  SceytChatUIKit
//
//  The upload state machine: the slot queue, each attempt (checksum, preparation, the
//  transport), its result, and pause / resume / cancel. Every state change is one `board` step.
//

import Foundation
import UniformTypeIdentifiers

extension TransportDataSession {
    func enqueue(_ job: UploadJob) {
        let slots = max(1, maxConcurrentUploads)
        let queued: (depth: Int, holders: String)? = board.withState { jobs in
            guard jobs.active.count >= slots else {
                jobs.active.append(job)
                return nil
            }
            jobs.waiting.append(job)
            return (jobs.waiting.count, jobs.active.map(\.operationId).joined(separator: ","))
        }
        if let queued {
            logger.debug("[Transfer] \(job.taskInfo.logTag) upload waiting for an upload slot (position \(queued.depth), \(slots) held by \(queued.holders))")
            return
        }
        begin(job)
    }

    /// Gives up the slot `job` holds and starts the next waiting upload.
    func releaseSlot(of job: UploadJob) {
        let slots = max(1, maxConcurrentUploads)
        let released: (held: Bool, next: UploadJob?) = board.withState { jobs in
            guard jobs.active.contains(where: { $0 === job }) else { return (false, nil) }
            jobs.active.removeAll { $0 === job }
            guard jobs.active.count < slots, !jobs.waiting.isEmpty else { return (true, nil) }
            let next = jobs.waiting.removeFirst()
            jobs.active.append(next)
            return (true, next)
        }
        guard released.held else { return }
        logger.debug("[Transfer] \(job.taskInfo.logTag) upload released its upload slot, next=\(released.next?.operationId ?? "-")")
        if let next = released.next {
            begin(next)
        }
    }

    /// `job` holds the slot: continue its paused invocation, or start a new attempt.
    func begin(_ job: UploadJob) {
        willBeginUpload?(job.taskInfo)
        enum Slot { case notWaiting(UploadJob.State), resumeLive, newAttempt }
        let slot: Slot = board.withState { _ in
            guard case .waiting(let alive) = job.state else { return .notWaiting(job.state) }
            guard alive else { return .newAttempt }
            job.state = .uploading
            return .resumeLive
        }
        switch slot {
        case .notWaiting(let state):
            logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) got the slot while \(state), not starting")
            releaseSlot(of: job)
            return
        case .resumeLive:
            if transport.resume(operationId: job.operationId) {
                logger.info("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) waiting -> uploading (resumed the live invocation)")
                return
            }
            logger.info("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) transport could not resume the paused invocation, starting a new attempt")
            let moved: UploadJob.State? = board.withState { _ in
                if case .uploading = job.state { return nil }
                return job.state
            }
            if let moved {
                logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) became \(moved) during the failed resume, no new attempt")
                return
            }
        case .newAttempt:
            break
        }
        startAttempt(job)
    }

    /// A new attempt of `job`: its counter, its preparation state and its task, installed in
    /// one step so a pause or cancel that follows finds them.
    private func startAttempt(_ job: UploadJob) {
        let context = job.taskInfo.logContext
        // Each attempt gets its own export state: a cancelled one stays cancelled, so reusing
        // it would fail the next export and send the uncompressed original.
        let videoProcessInfo = SCVideoProcessInfo()
        let (attempt, previous) = board.withState { _ -> (Int, AttemptWork.Snapshot) in
            job.attempt += 1
            let attempt = job.attempt
            job.state = .preparing
            ([job.taskInfo] + job.joined).forEach { $0.attempts = attempt }
            let previous = job.replaceWork(videoProcessInfo: videoProcessInfo, task: Task { [weak self] in
                // Every layer below (transport, encryption) tags its lines with this transfer.
                await TransferLog.$current.withValue(context) {
                    await self?.run(job, attempt: attempt, videoProcessInfo: videoProcessInfo)
                }
            })
            return (attempt, previous)
        }
        logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt) waiting -> preparing \(job.attachment.transferLogDescription)")
        previous.stop()
    }

    func isCurrent(_ job: UploadJob, attempt: Int) -> Bool {
        board.withState { _ in
            guard job.attempt == attempt else { return false }
            switch job.state {
            case .preparing, .uploading:
                return true
            default:
                return false
            }
        }
    }

    func run(_ job: UploadJob, attempt: Int, videoProcessInfo: SCVideoProcessInfo) async {
        let tag = job.taskInfo.logTag
        if checksumsBeforeUpload, await endedByChecksum(job, attempt: attempt) {
            return
        }
        guard isCurrent(job, attempt: attempt) else {
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt) dropped after the checksum: stale or no longer preparing")
            return
        }
        guard let prepared = await prepare(job, attempt: attempt, videoProcessInfo: videoProcessInfo) else {
            return
        }
        // Measured before the transport sees the file: an encrypted upload's message carries
        // the plaintext size, and the staged file is moved (or gone) once the upload lands.
        let preparedSize = Self.fileSize(prepared.file)
        if preparedSize == 0 {
            // Sent as is. The checksum step never dedupes an empty file.
            logger.warn("[Transfer] \(tag) upload attempt=\(attempt) prepared file is 0 bytes \(job.attachment.transferLogDescription)")
        }
        guard startUploading(job, attempt: attempt) else {
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt) paused, cancelled or superseded during preparation, not uploading")
            return
        }
        let request = uploadRequest(for: job, prepared: prepared)
        logger.info("[Transfer] \(tag) upload attempt=\(attempt) preparing -> uploading type=\(request.type) staged=\(prepared.isStaged) size=\(preparedSize.map { "\($0) B" } ?? "unknown") mime=\(request.mimeType ?? "-") \(job.attachment.transferLogDescription)")
        // The transport's progress is of the prepared file, not of the original: a compressed
        // video can be a small part of it, and its size is what the message carries.
        if let preparedSize, preparedSize > 0 {
            tasks(of: job).forEach { $0.reportTransferSize(preparedSize) }
        }
        let result = await transport.upload(request) { [weak self, weak job] progress in
            guard let self, let job, self.isUploading(job, attempt: attempt) else { return }
            if let quarter = job.progressMilestone(progress) {
                logger.debug("[Transfer] \(tag) upload attempt=\(attempt) progress \(quarter)%")
            }
            self.tasks(of: job).forEach { $0.updateProgress(progress) }
        }
        handle(result, of: job, attempt: attempt, prepared: prepared, preparedSize: preparedSize, type: request.type)
    }

    /// Runs the checksum step. True when it ended the attempt: a stored copy was found, or
    /// the step failed the task (both reported by the checksum itself).
    private func endedByChecksum(_ job: UploadJob, attempt: Int) async -> Bool {
        let taskInfo = job.taskInfo
        let tag = taskInfo.logTag
        let stored = await withCheckedContinuation { continuation in
            taskInfo.startChecksum { continuation.resume(returning: $0) }
        }
        guard stored || isTerminal(taskInfo) else {
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt) checksum miss, uploading")
            return false
        }
        logger.debug("[Transfer] \(tag) upload attempt=\(attempt) -> finished (\(stored ? "checksum hit, nothing uploaded" : "checksum step failed the task"))")
        finish(job, attempt: attempt)
        // A task that joined this one ends the same way.
        if let event = taskInfo.event {
            report(joined(of: job), event)
        }
        return true
    }

    /// The file to send, or nil when the attempt ended (failed, or dropped as stale).
    private func prepare(_ job: UploadJob, attempt: Int, videoProcessInfo: SCVideoProcessInfo) async -> PreparedUploadFile? {
        let tag = job.taskInfo.logTag
        let prepared: PreparedUploadFile
        do {
            prepared = try await prepareUploadFile(job, videoProcessInfo: videoProcessInfo)
        } catch {
            guard isCurrent(job, attempt: attempt) else {
                logger.debug("[Transfer] \(tag) upload attempt=\(attempt) preparation ended (\(TransferLog.describe(error))) after a pause/cancel/new attempt, dropped")
                return nil
            }
            // Reported at the end, once, by `AttachmentTransfer`.
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt) preparing -> finished (failure): preparation failed \(TransferLog.describe(error))")
            finish(job, attempt: attempt)
            report(tasks(of: job), .failure(error))
            return nil
        }
        guard FileManager.default.fileExists(atPath: prepared.file.path) else {
            guard isCurrent(job, attempt: attempt) else { return nil }
            // Nothing to send: the source was deleted, or a video export fell back to a
            // Photos-library path that is not a file.
            logger.warn("[Transfer] \(tag) upload attempt=\(attempt) preparing -> finished (failure): the prepared file does not exist (missingSourceFile) \(job.attachment.transferLogDescription)")
            finish(job, attempt: attempt)
            report(tasks(of: job), .failure(TransportDataSessionError.missingSourceFile))
            return nil
        }
        return prepared
    }

    private func uploadRequest(for job: UploadJob, prepared: PreparedUploadFile) -> FileUploadRequest {
        let taskInfo = job.taskInfo
        let name = job.attachment.name ?? ""
        let fileName = name.isEmpty ? prepared.file.lastPathComponent : name
        return FileUploadRequest(
            operationId: job.operationId,
            sourceFile: prepared.file,
            fileName: fileName,
            mimeType: Self.mimeType(of: prepared, fileName: fileName),
            context: AttachmentTransferContext(message: taskInfo.message, attachment: job.attachment),
            type: taskInfo.encryption == .required ? .encrypted : .plain
        )
    }

    /// A prepared file's type follows its own extension (a resized image is a JPEG whatever
    /// its source was); a file sent in place is typed by the name it is sent under, its own
    /// extension when that name has none.
    static func mimeType(of prepared: PreparedUploadFile, fileName: String) -> String? {
        let named = (fileName as NSString).pathExtension
        let ext = prepared.isStaged || named.isEmpty ? prepared.file.pathExtension : named
        return UTType(filenameExtension: ext)?.preferredMIMEType
    }

    /// Preparation is over and nothing paused or cancelled the attempt meanwhile.
    func startUploading(_ job: UploadJob, attempt: Int) -> Bool {
        board.withState { _ in
            guard job.attempt == attempt, case .preparing = job.state else { return false }
            job.state = .uploading
            return true
        }
    }

    func isUploading(_ job: UploadJob, attempt: Int) -> Bool {
        board.withState { _ in
            guard job.attempt == attempt, case .uploading = job.state else { return false }
            return true
        }
    }

    func handle(
        _ result: FileTransferResult<FileUploadResult>,
        of job: UploadJob,
        attempt: Int,
        prepared: PreparedUploadFile,
        preparedSize: Int64?,
        type: FileUploadType
    ) {
        guard ends(job, attempt: attempt, with: result) else { return }
        finish(job, attempt: attempt)
        let tag = job.taskInfo.logTag
        // Failures are reported at the end, once, by `AttachmentTransfer`: debug here.
        let tasks = tasks(of: job)
        switch result {
        case .success(let uploaded):
            landed(uploaded, job: job, attempt: attempt, tasks: tasks, prepared: prepared, preparedSize: preparedSize, type: type)
        case .failure(let error):
            // The staged file stays: the next attempt sends it again.
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt) uploading -> finished (failure): \(TransferLog.describe(error))")
            report(tasks, .failure(error))
        case .interrupted(let error):
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt) uploading -> finished (interrupted, work kept for a retry): \(TransferLog.describe(error))")
            report(tasks, .failure(error), interrupted: true)
        }
    }

    /// Whether the transport's result ends the attempt. A stale attempt's, or a finished
    /// job's, is dropped; a paused invocation that ended without the file leaves the job
    /// paused with nothing alive, for a resume to start a new attempt.
    private func ends(_ job: UploadJob, attempt: Int, with result: FileTransferResult<FileUploadResult>) -> Bool {
        let outcome = Self.describe(result)
        let tag = job.taskInfo.logTag
        enum Verdict { case stale(current: Int), afterFinish, ends, pausedEnded, waitingEnded }
        let verdict: Verdict = board.withState { _ in
            guard job.attempt == attempt else { return .stale(current: job.attempt) }
            switch (result, job.state) {
            case (_, .finished):
                return .afterFinish
            case (.success, _):
                // Landed, even while paused: the file is stored.
                return .ends
            case (_, .paused):
                job.state = .paused(alive: false)
                return .pausedEnded
            case (_, .waiting):
                job.state = .waiting(alive: false)
                return .waitingEnded
            default:
                return .ends
            }
        }
        switch verdict {
        case .stale(let current):
            logger.debug("[Transfer] \(tag) upload stale attempt=\(attempt) ended (\(outcome)) while attempt \(current) is current, dropped")
            return false
        case .afterFinish:
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt) ended (\(outcome)) after it was finished (cancelled/interrupted), dropped")
            return false
        case .pausedEnded:
            logger.info("[Transfer] \(tag) upload attempt=\(attempt) paused -> paused(alive: false): the paused invocation ended (\(outcome))")
            return false
        case .waitingEnded:
            logger.info("[Transfer] \(tag) upload attempt=\(attempt) waiting -> waiting(alive: false): the paused invocation ended (\(outcome))")
            return false
        case .ends:
            return true
        }
    }

    /// The file is stored: its tasks that still run take the reference, the encryption and
    /// the plaintext size.
    private func landed(
        _ uploaded: FileUploadResult,
        job: UploadJob,
        attempt: Int,
        tasks: [SCTDataSessionTaskInfo],
        prepared: PreparedUploadFile,
        preparedSize: Int64?,
        type: FileUploadType
    ) {
        let tag = job.taskInfo.logTag
        if type == .encrypted, uploaded.encryptionInfo == nil {
            // Encrypted bytes without their key could never be opened.
            logger.debug("[Encryption] \(tag) upload attempt=\(attempt) -> finished (failure): transport reported success without encryptionInfo, rejected (encryptionBypassed)")
            report(tasks, .failure(AttachmentEncryptionError.encryptionBypassed))
            return
        }
        if type == .plain, uploaded.encryptionInfo != nil {
            logger.warn("[Encryption] \(tag) upload attempt=\(attempt) plain upload came back with encryptionInfo; it is kept \(job.attachment.transferLogDescription)")
        }
        // Checked before anything replaces the task's event: an event after the terminal
        // one would hide that the task ended, and the success would be reported over it.
        let live = tasks.filter { !$0.isTerminal }
        guard !live.isEmpty else {
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt) landed after the task already ended (\(Self.describe(job.taskInfo.event))): result dropped")
            staging.discard(operationId: job.operationId)
            return
        }
        if prepared.isStaged {
            adopt(prepared.file, job: job, tasks: live)
        }
        staging.discard(operationId: job.operationId)
        let plaintextSize = type == .encrypted ? Self.plaintextSize(uploaded, preparedSize: preparedSize, tag: tag, attempt: attempt) : nil
        for taskInfo in live {
            taskInfo.uploadedEncryption = uploaded.encryptionInfo
            if type == .encrypted {
                taskInfo.uploadedPlaintextSize = plaintextSize
            }
        }
        logger.debug("[Transfer] \(tag) upload attempt=\(attempt) uploading -> finished (success) ref=\(TransferLog.redact(uploaded.url)) encrypted=\(uploaded.encryptionInfo != nil)")
        report(live, .successURI(uploaded.url))
    }

    /// The size an encrypted upload's message carries: the transport's count of the bytes it
    /// encrypted, else the prepared file's.
    private static func plaintextSize(_ uploaded: FileUploadResult, preparedSize: Int64?, tag: String, attempt: Int) -> Int64? {
        if let reported = uploaded.plaintextSize, let preparedSize, reported != preparedSize {
            logger.warn("[Transfer] \(tag) upload attempt=\(attempt) transport encrypted \(reported) B of a \(preparedSize) B prepared file; the message carries \(reported) B")
        }
        let size = uploaded.plaintextSize ?? preparedSize
        if size == nil {
            logger.warn("[Transfer] \(tag) upload attempt=\(attempt) plaintext size unknown: the message carries the stored size")
        }
        return size
    }

    /// The attempt is over: the job leaves the queue and the session.
    func finish(_ job: UploadJob, attempt: Int) {
        enum Ended { case stale(current: Int), finished(previous: UploadJob.State) }
        let ended: Ended = board.withState { jobs in
            guard job.attempt == attempt else { return .stale(current: job.attempt) }
            let previous = job.state
            job.state = .finished
            jobs.uploads[ObjectIdentifier(job.taskInfo)] = nil
            return .finished(previous: previous)
        }
        switch ended {
        case .stale(let current):
            logger.debug("[Transfer] \(job.taskInfo.logTag) upload finish of stale attempt=\(attempt) ignored (current \(current))")
        case .finished(let previous):
            logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt) \(previous) -> finished")
            releaseSlot(of: job)
        }
    }

    func pause(_ job: UploadJob) {
        enum Step { case dequeued(alive: Bool), stopPreparing, askTransport, ignored(UploadJob.State) }
        let step: Step = board.withState { jobs in
            switch job.state {
            case .waiting(let alive):
                jobs.waiting.removeAll { $0 === job }
                job.state = .paused(alive: alive)
                return .dequeued(alive: alive)
            case .preparing:
                job.state = .paused(alive: false)
                return .stopPreparing
            case .uploading:
                return .askTransport
            case .paused, .finished:
                return .ignored(job.state)
            }
        }
        let tag = job.taskInfo.logTag
        switch step {
        case .dequeued(let alive):
            logger.info("[Transfer] \(tag) upload attempt=\(attempt(of: job)) waiting -> paused(alive: \(alive))")
        case .stopPreparing:
            logger.info("[Transfer] \(tag) upload attempt=\(attempt(of: job)) preparing -> paused(alive: false), preparation stopped")
            job.stopWork()
            releaseSlot(of: job)
        case .askTransport:
            // Asked outside the lock: the transport may call back into this session.
            let alive = transport.pause(operationId: job.operationId)
            let raced: UploadJob.State? = board.withState { _ in
                guard case .uploading = job.state else { return job.state }
                job.state = .paused(alive: alive)
                return nil
            }
            if let raced {
                logger.debug("[Transfer] \(tag) upload attempt=\(attempt(of: job)) pause raced to \(raced), ignored")
                return
            }
            logger.info("[Transfer] \(tag) upload attempt=\(attempt(of: job)) uploading -> paused(alive: \(alive))\(alive ? "" : ", invocation stopped")")
            if !alive {
                job.stopWork()
            }
            releaseSlot(of: job)
        case .ignored(let state):
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt(of: job)) pause ignored while \(state)")
        }
    }

    func resume(_ job: UploadJob) {
        enum Resumed { case ignored(UploadJob.State), waiting(alive: Bool) }
        let resumed: Resumed = board.withState { _ in
            guard case .paused(let alive) = job.state else { return .ignored(job.state) }
            job.state = .waiting(alive: alive)
            return .waiting(alive: alive)
        }
        switch resumed {
        case .ignored(let state):
            logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) resume ignored while \(state)")
        case .waiting(let alive):
            logger.info("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) paused -> waiting(alive: \(alive)) (resumed)")
            enqueue(job)
        }
    }

    func cancel(_ job: UploadJob) {
        let previous: UploadJob.State? = board.withState { jobs in
            if case .finished = job.state { return nil }
            let previous = job.state
            job.state = .finished
            jobs.waiting.removeAll { $0 === job }
            jobs.uploads[ObjectIdentifier(job.taskInfo)] = nil
            return previous
        }
        guard let previous else {
            logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) cancel ignored: already finished")
            return
        }
        logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) \(previous) -> finished (cancelled)")
        transport.cancel(operationId: job.operationId)
        job.stopWork()
        staging.discard(operationId: job.operationId)
        releaseSlot(of: job)
        // A terminal event, like a cancelled download's: the task leaves `AttachmentTransfer`,
        // so a later upload of the same file is a new one.
        report(tasks(of: job), .failure(URLError(.cancelled)))
    }
}
