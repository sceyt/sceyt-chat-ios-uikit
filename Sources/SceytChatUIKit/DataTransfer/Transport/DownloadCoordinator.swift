//
//  DownloadCoordinator.swift
//  SceytChatUIKit
//
//  The download state machine: each attempt, its result (an encrypted attachment's decrypted
//  by `EncryptedFileDownloader`), and pause / resume / cancel. Every state change is one
//  `board` step.
//

import Foundation

/// Runs the session's downloads: each attempt, its result, and pause / resume / cancel. The
/// session owns it and stays the one customization point (its transport, hooks and reporting).
final class DownloadCoordinator: Sendable {
    unowned let session: TransportDataSession

    init(session: TransportDataSession) {
        self.session = session
    }

    private var board: JobBoard { session.board }
    private var transport: FileTransferTransport { session.transport }
    private var encryptedDownloader: EncryptedFileDownloader { session.encryptedDownloader }
    private var environment: TransferEnvironment { session.environment }
    private var willStartDownload: ((SCTDataSessionTaskInfo) -> Void)? { session.willStartDownload }

    private func attempt(of job: DownloadJob) -> Int { session.attempt(of: job) }
    private func tasks(of job: DownloadJob) -> [SCTDataSessionTaskInfo] { session.tasks(of: job) }
    private func report(_ tasks: [SCTDataSessionTaskInfo], _ event: SCTDataSessionTaskInfo.Event, interrupted: Bool = false) {
        session.report(tasks, event, interrupted: interrupted)
    }
    private static func describe<T: Sendable>(_ result: FileTransferResult<T>) -> String { TransportDataSession.describe(result) }
    private static func describe(_ event: SCTDataSessionTaskInfo.Event?) -> String { TransportDataSession.describe(event) }

    func start(_ job: DownloadJob) {
        let tag = job.taskInfo.logTag
        willStartDownload?(job.taskInfo)
        let encrypted = job.encryption != nil
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
            // Holds the session (weakly, strongly while it works): the coordinator reaches it
            // `unowned`, which is safe only while something keeps the session alive.
            let previous = job.replaceTask(Task { [weak session = self.session] in
                guard let session, let self = session.downloads else { return }
                // Every layer below (transport, encryption) tags its lines with this transfer.
                let report: (Double) -> Void = { [weak session] progress in
                    guard let self = session?.downloads, self.isRunning(job, attempt: attempt) else { return }
                    if let quarter = job.progressMilestone(progress) {
                        logger.debug("[Transfer] \(tag) download attempt=\(attempt) progress \(quarter)%")
                    }
                    // An encrypted download reaches 1 only once it is decrypted and published.
                    self.tasks(of: job).forEach { $0.updateProgress(progress) }
                }
                let result = await TransferLog.$current.withValue(context) {
                    if let encryption = job.encryption {
                        return await self.encryptedDownloader.download(
                            job.request,
                            encryption: encryption,
                            fileEncryption: self.environment.fileEncryption(),
                            progress: report
                        ) { request, progress in
                            await self.transport.download(request, progress: progress)
                        }
                    }
                    return await self.transport.download(job.request, progress: report)
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
            logger.debug("[Transfer] \(tag) download attempt=\(attempt) running -> finished (success) size=\(TransferLog.sizeText(file)) decrypted=\(job.encryption != nil)")
            for taskInfo in live {
                if job.encryption != nil {
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
        let task = job.currentTask
        job.cancelTask()
        if job.encryption != nil {
            // Its temporary files go once nothing writes them any more.
            let downloader = encryptedDownloader
            let operationId = job.request.operationId
            Task {
                await task?.value
                downloader.discard(operationId)
            }
        }
        report(tasks(of: job), .failure(URLError(.cancelled)))
    }
}
