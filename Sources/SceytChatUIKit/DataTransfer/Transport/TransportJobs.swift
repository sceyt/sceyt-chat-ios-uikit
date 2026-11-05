//
//  TransportJobs.swift
//  SceytChatUIKit
//
//  The state `TransportDataSession` keeps per transfer. A job's `state`, `joined` and
//  `attempt` change only inside `JobBoard.withState`; each job's attempt work has its own lock.
//

import Foundation

/// Every transfer of one `TransportDataSession`: the jobs, the upload queue and its slots, and
/// (by rule) each job's `state`, `joined` and `attempt`. One lock guards all of it and
/// `withState` is the only way in, so a decision and the change it makes are one step and no
/// path can leave the lock held. Not re-entrant: a step only reads and writes state; logging,
/// the transport and callbacks run after it.
final class JobBoard: @unchecked Sendable {
    struct Jobs {
        var uploads = [ObjectIdentifier: UploadJob]()
        var waiting = [UploadJob]()
        /// The uploads holding a slot, at most `maxConcurrentUploads`.
        var active = [UploadJob]()
        var downloads = [ObjectIdentifier: DownloadJob]()
    }

    private let lock = NSLock()
    private var jobs = Jobs()

    func withState<T>(_ step: (inout Jobs) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try step(&jobs)
    }
}

/// What every transfer job has: its task, the tasks that joined it, and its attempt count.
protocol TransferJob: AnyObject {
    var taskInfo: SCTDataSessionTaskInfo { get }
    var joined: [SCTDataSessionTaskInfo] { get }
    var attempt: Int { get }
}

/// Logs progress at 25 / 50 / 75 / 100 % only, never per chunk.
final class ProgressMilestones {
    private let lock = NSLock()
    private var logged = 0

    /// The milestone `progress` just crossed, once per attempt's climb.
    func crossed(_ progress: Double) -> Int? {
        let quarter = min(4, max(0, Int(progress * 4)))
        lock.lock(); defer { lock.unlock() }
        if quarter < logged {
            // A new attempt starts from the beginning again.
            logged = quarter
            return nil
        }
        guard quarter > logged else { return nil }
        logged = quarter
        return quarter * 25
    }
}


/// Safe to share: its constants never change, its state only inside a board step, and its
/// attempt work behind its own lock.
final class UploadJob: TransferJob, @unchecked Sendable {
    enum State {
        /// In the queue; `alive` when a paused invocation is there to resume.
        case waiting(alive: Bool)
        case preparing
        case uploading
        case paused(alive: Bool)
        case finished
    }

    let attachment: ChatMessage.Attachment
    let taskInfo: SCTDataSessionTaskInfo
    let operationId: String
    /// Changed only inside `JobBoard.withState`, like `attempt` and `joined`.
    var state = State.waiting(alive: false)
    /// Tasks that started the same operation while this job ran: they get its events.
    /// Changed only inside `JobBoard.withState`.
    var joined = [SCTDataSessionTaskInfo]()

    var isFinished: Bool {
        if case .finished = state { return true }
        return false
    }
    /// Bumped by every new attempt, so a callback of an earlier one is ignored.
    var attempt = 0
    /// The current attempt's work. Replaced inside a board step, read (to stop it) from any
    /// thread, hence its own lock.
    private let work = AttemptWork()
    private let milestones = ProgressMilestones()

    func progressMilestone(_ progress: Double) -> Int? {
        milestones.crossed(progress)
    }

    init(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo, operationId: String) {
        self.attachment = attachment
        self.taskInfo = taskInfo
        self.operationId = operationId
    }

    /// Installs a new attempt's work and returns the previous attempt's, for the caller to stop.
    func replaceWork(videoProcessInfo: SCVideoProcessInfo, task: Task<Void, Never>) -> AttemptWork.Snapshot {
        work.replace(videoProcessInfo: videoProcessInfo, task: task)
    }

    /// Stops preparation and the current invocation. To the transport this is an interruption,
    /// not an abandonment.
    func stopWork() {
        work.current.stop()
    }
}

/// One attempt's cancellable work: its task and its video export state.
final class AttemptWork: @unchecked Sendable {
    struct Snapshot {
        let videoProcessInfo: SCVideoProcessInfo?
        let task: Task<Void, Never>?

        func stop() {
            videoProcessInfo?.cancel()
            task?.cancel()
        }
    }

    private let lock = NSLock()
    private var snapshot = Snapshot(videoProcessInfo: nil, task: nil)

    var current: Snapshot {
        lock.lock(); defer { lock.unlock() }
        return snapshot
    }

    func replace(videoProcessInfo: SCVideoProcessInfo?, task: Task<Void, Never>) -> Snapshot {
        lock.lock(); defer { lock.unlock() }
        let previous = snapshot
        snapshot = Snapshot(videoProcessInfo: videoProcessInfo, task: task)
        return previous
    }
}

/// Safe to share, like `UploadJob`.
final class DownloadJob: TransferJob, @unchecked Sendable {
    enum State {
        case running
        case paused(alive: Bool)
        case finished
    }

    let request: FileDownloadRequest
    /// Set for an encrypted attachment: UIKit decrypts what the transport fetched.
    let encryption: FileDownloadEncryption?
    let taskInfo: SCTDataSessionTaskInfo
    var state = State.running
    /// Tasks that started the same operation while this job ran: they get its events.
    /// Changed only inside `JobBoard.withState`.
    var joined = [SCTDataSessionTaskInfo]()

    var isFinished: Bool {
        if case .finished = state { return true }
        return false
    }
    var attempt = 0
    /// Replaced inside a board step, read (to cancel it) from any thread.
    private let work = AttemptWork()
    private let milestones = ProgressMilestones()

    func progressMilestone(_ progress: Double) -> Int? {
        milestones.crossed(progress)
    }

    /// Installs a new attempt's task and returns the previous one, for the caller to cancel.
    func replaceTask(_ task: Task<Void, Never>) -> Task<Void, Never>? {
        work.replace(videoProcessInfo: nil, task: task).task
    }

    func cancelTask() {
        work.current.task?.cancel()
    }

    /// The current attempt's task, to wait for it to stop.
    var currentTask: Task<Void, Never>? {
        work.current.task
    }

    init(request: FileDownloadRequest, encryption: FileDownloadEncryption? = nil, taskInfo: SCTDataSessionTaskInfo) {
        self.request = request
        self.encryption = encryption
        self.taskInfo = taskInfo
    }
}

/// One answer for one waiter, whichever comes first: the answer is kept until the waiter
/// arrives, and every later answer is dropped.
final class OnceAnswer<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Never>?
    private var value: T?
    private var given = false

    func wait(_ continuation: CheckedContinuation<T, Never>) {
        lock.lock()
        if let value {
            lock.unlock()
            continuation.resume(returning: value)
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    private var reserved = false

    var isGiven: Bool {
        lock.lock(); defer { lock.unlock() }
        return given
    }

    /// Claims the answer before its value is known: every `give` after it is dropped, and only
    /// `fulfill` delivers. False when an answer was given (or claimed) already.
    func reserve() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !given else { return false }
        given = true
        reserved = true
        return true
    }

    /// Delivers the value of a `reserve`d answer.
    func fulfill(_ answer: T) {
        lock.lock()
        guard reserved else { lock.unlock(); return }
        reserved = false
        let continuation = self.continuation
        self.continuation = nil
        if continuation == nil { value = answer }
        lock.unlock()
        continuation?.resume(returning: answer)
    }

    /// False when an answer was given already.
    @discardableResult
    func give(_ answer: T) -> Bool {
        lock.lock()
        guard !given else { lock.unlock(); return false }
        given = true
        let continuation = self.continuation
        self.continuation = nil
        if continuation == nil { value = answer }
        lock.unlock()
        continuation?.resume(returning: answer)
        return true
    }
}
