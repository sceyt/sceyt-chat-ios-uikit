//
//  TransportDataSession+Downloads.swift
//  SceytChatUIKit
//
//  The download state machine: each attempt, its result (decrypted when encrypted), and
//  pause / resume / cancel. Every state change is one `board` step.
//

import Foundation

extension TransportDataSession {
    func start(_ job: DownloadJob) {
        let tag = job.taskInfo.logTag
        willStartDownload?(job.taskInfo)
        let encrypted = job.request.encryptionInfo != nil
        let context = job.taskInfo.logContext
        enum Start { case finished, started(attempt: Int, from: DownloadJob.State, previous: Task<Void, Never>?) }
        let start: Start = board.withState { _ in
            if case .finished = job.state { return .finished }
            job.attempt += 1
            let attempt = job.attempt
            let from = job.state
            job.state = .running
            ([job.taskInfo] + job.joined).forEach { $0.attempts = attempt }
            // Installed in the same step, so a pause or cancel that follows finds it (a cancel
            // that found no task let the download, and its decryption, run to the end).
            let previous = job.replaceTask(Task { [weak self] in
                guard let self else { return }
                // Every layer below (transport, encryption) tags its lines with this transfer.
                let result = await TransferLog.$current.withValue(context) {
                    await self.transport.download(job.request) { [weak self, weak job] progress in
                        guard let self, let job, self.isRunning(job, attempt: attempt) else { return }
                        if let quarter = job.progressMilestone(progress) {
                            logger.debug("[Transfer] \(tag) download attempt=\(attempt) progress \(quarter)%")
                        }
                        // Not done when the last byte arrives: it still has to be verified and
                        // decrypted, so the bar stops short of full until then.
                        self.tasks(of: job).forEach { $0.updateProgress(encrypted ? min(progress, 0.99) : progress) }
                    }
                }
                self.handle(result, of: job, attempt: attempt)
            })
            return .started(attempt: attempt, from: from, previous: previous)
        }
        guard case .started(let attempt, let from, let previous) = start else {
            logger.debug("[Transfer] \(tag) download attempt=\(attempt(of: job)) not started: already finished")
            return
        }
        logger.info("[Transfer] \(tag) download attempt=\(attempt) \(attempt == 1 ? "queued" : "\(from)") -> running encrypted=\(encrypted) url=\(TransferLog.redact(job.request.url))")
        previous?.cancel()
    }

    func isRunning(_ job: DownloadJob, attempt: Int) -> Bool {
        board.withState { _ in
            guard job.attempt == attempt, case .running = job.state else { return false }
            return true
        }
    }

    func handle(_ result: FileTransferResult<URL>, of job: DownloadJob, attempt: Int) {
        let tag = job.taskInfo.logTag
        let outcome = Self.describe(result)
        enum Verdict { case stale(current: Int), dropped(DownloadJob.State), ends([SCTDataSessionTaskInfo]) }
        let verdict: Verdict = board.withState { jobs in
            guard job.attempt == attempt else { return .stale(current: job.attempt) }
            switch job.state {
            case .finished, .paused(alive: false):
                // Cancelled, or stopped by a pause: a resume starts again.
                return .dropped(job.state)
            default:
                // A task left suspended long enough can be timed out by the system; that is a
                // failed download.
                job.state = .finished
                jobs.downloads[ObjectIdentifier(job.taskInfo)] = nil
                return .ends([job.taskInfo] + job.joined)
            }
        }
        let tasks: [SCTDataSessionTaskInfo]
        switch verdict {
        case .stale(let current):
            logger.debug("[Transfer] \(tag) download stale attempt=\(attempt) ended (\(outcome)) while attempt \(current) is current, dropped")
            return
        case .dropped(let state):
            logger.debug("[Transfer] \(tag) download attempt=\(attempt) ended (\(outcome)) while \(state), dropped")
            return
        case .ends(let ended):
            tasks = ended
        }
        // Failures are reported at the end, once, by `AttachmentTransfer`: debug here.
        switch result {
        case .success(let file):
            // Checked before anything replaces the task's event: `updateLocalFileLocation`
            // would hide that the task ended, and the success would be reported over it.
            let live = tasks.filter { !$0.isTerminal }
            guard !live.isEmpty else {
                logger.debug("[Transfer] \(tag) download attempt=\(attempt) succeeded after the task already ended (\(Self.describe(job.taskInfo.event))): result dropped")
                return
            }
            if !FileManager.default.fileExists(atPath: file.path) {
                logger.warn("[Transfer] \(tag) download attempt=\(attempt) transport reported success but its file does not exist")
            }
            logger.debug("[Transfer] \(tag) download attempt=\(attempt) running -> finished (success) size=\(TransferLog.sizeText(file)) decrypted=\(job.request.encryptionInfo != nil)")
            for taskInfo in live {
                if job.request.encryptionInfo != nil {
                    taskInfo.didDecryptDownload = true
                }
                taskInfo.updateLocalFileLocation(newPath: file.path)
            }
            report(live, .successURI(job.request.url))
        case .failure(let error):
            logger.debug("[Transfer] \(tag) download attempt=\(attempt) running -> finished (failure): \(TransferLog.describe(error))")
            report(tasks, .failure(error))
        case .interrupted(let error):
            logger.debug("[Transfer] \(tag) download attempt=\(attempt) running -> finished (interrupted): \(TransferLog.describe(error))")
            report(tasks, .failure(error), interrupted: true)
        }
    }

    func pause(_ job: DownloadJob) {
        let tag = job.taskInfo.logTag
        let notRunning: DownloadJob.State? = board.withState { _ in
            if case .running = job.state { return nil }
            return job.state
        }
        if let notRunning {
            logger.debug("[Transfer] \(tag) download attempt=\(attempt(of: job)) pause ignored while \(notRunning)")
            return
        }
        // Asked outside the lock: the transport may call back into this session.
        let alive = transport.pause(operationId: job.request.operationId)
        let raced: DownloadJob.State? = board.withState { _ in
            guard case .running = job.state else { return job.state }
            job.state = .paused(alive: alive)
            return nil
        }
        if let raced {
            logger.debug("[Transfer] \(tag) download attempt=\(attempt(of: job)) pause raced to \(raced), ignored")
            return
        }
        logger.info("[Transfer] \(tag) download attempt=\(attempt(of: job)) running -> paused(alive: \(alive))\(alive ? "" : ", task cancelled")")
        if !alive {
            job.cancelTask()
        }
    }

    func resume(_ job: DownloadJob) {
        let tag = job.taskInfo.logTag
        enum Resumed { case ignored(DownloadJob.State), paused(alive: Bool) }
        let resumed: Resumed = board.withState { _ in
            guard case .paused(let alive) = job.state else { return .ignored(job.state) }
            if alive {
                job.state = .running
            }
            return .paused(alive: alive)
        }
        guard case .paused(let alive) = resumed else {
            if case .ignored(let state) = resumed {
                logger.debug("[Transfer] \(tag) download attempt=\(attempt(of: job)) resume ignored while \(state)")
            }
            return
        }
        if alive, transport.resume(operationId: job.request.operationId) {
            logger.info("[Transfer] \(tag) download attempt=\(attempt(of: job)) paused -> running (resumed the live invocation)")
            return
        }
        let cancelled: Bool = board.withState { _ in
            if case .finished = job.state { return true }
            job.state = .paused(alive: false)
            return false
        }
        if cancelled {
            // Cancelled while the transport was asked to resume: it stays cancelled.
            logger.debug("[Transfer] \(tag) download attempt=\(attempt(of: job)) cancelled during the resume, not restarted")
            return
        }
        logger.info("[Transfer] \(tag) download attempt=\(attempt(of: job)) \(alive ? "transport could not resume the invocation" : "no live invocation"), starting a new attempt")
        start(job)
    }

    func cancel(_ job: DownloadJob) {
        let tag = job.taskInfo.logTag
        let previous: DownloadJob.State? = board.withState { jobs in
            if case .finished = job.state { return nil }
            let previous = job.state
            job.state = .finished
            jobs.downloads[ObjectIdentifier(job.taskInfo)] = nil
            return previous
        }
        guard let previous else {
            logger.debug("[Transfer] \(tag) download attempt=\(attempt(of: job)) cancel ignored: already finished")
            return
        }
        logger.debug("[Transfer] \(tag) download attempt=\(attempt(of: job)) \(previous) -> finished (cancelled)")
        transport.cancel(operationId: job.request.operationId)
        job.cancelTask()
        report(tasks(of: job), .failure(URLError(.cancelled)))
    }
}
