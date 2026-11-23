//
//  UploadCoordinator+Control.swift
//  SceytChatUIKit
//
//  What the user does to a running upload: pause, resume and cancel. Each is one `board`
//  step that moves the job's state, then the slot, queue and provider calls that follow it.
//

import Foundation

extension UploadCoordinator {

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
            reportQueue()
        case .stopPreparing:
            logger.info("[Transfer] \(tag) upload attempt=\(attempt(of: job)) preparing -> paused(alive: false), preparation stopped")
            job.stopWork()
            releaseSlot(of: job)
        case .askTransport:
            // Asked outside the lock: the provider may call back into this session.
            let alive = provider.pause(operationId: job.operationId)
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
        provider.cancel(operationId: job.operationId)
        job.stopWork()
        staging.discard(operationId: job.operationId)
        releaseSlot(of: job)
        // A queued upload held no slot: its leaving the queue is reported here.
        reportQueue()
        // A terminal event, like a cancelled download's: the task leaves `AttachmentTransfer`,
        // so a later upload of the same file is a new one.
        report(tasks(of: job), .failure(URLError(.cancelled)))
    }
}
