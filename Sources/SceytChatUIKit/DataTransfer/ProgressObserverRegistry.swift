//
//  ProgressObserverRegistry.swift
//  SceytChatUIKit
//
//  Who listens to which transfer: the progress and completion observers of each attachment,
//  the last progress a transfer reported (a rebound cell restores its ring from it), and the
//  callers waiting for a transfer that was already running when they asked. Every operation is
//  one locked step.
//

import Foundation

final class ProgressObserverRegistry {
    typealias ProgressBlock = AttachmentTransfer.ProgressBlock
    typealias CompletionBlock = AttachmentTransfer.CompletionBlock
    typealias Callback = (ChatMessage?, Error?) -> Void

    /// One observer: its callbacks, and the key that replaces it on a rebind.
    private struct Subscription {
        var progress: ProgressBlock?
        var completion: CompletionBlock?
        var idKey: String
    }

    @Atomic private var subscriptions = [String: [Subscription]]()
    @Atomic private var lastProgress = [String: Double]()
    @Atomic private var unobserved = Set<String>()
    @Atomic private var waitingUploads = [String: [Callback]]()
    @Atomic private var waitingDownloads = [String: [Callback]]()

    // MARK: Observers

    /// Adds an observer of `key`. A non-empty `idKey` replaces that observer's earlier
    /// registration (a reused cell re-binding the same attachment) instead of adding another.
    func register(key: String, idKey: String, progress: ProgressBlock?, completion: CompletionBlock?) {
        let subscription = Subscription(progress: progress, completion: completion, idKey: idKey)
        _subscriptions.mutate { subscriptions in
            var list = subscriptions[key, default: []]
            if !idKey.isEmpty, let index = list.firstIndex(where: { $0.idKey == idKey }) {
                list[index] = subscription
            } else {
                list.append(subscription)
            }
            subscriptions[key] = list
        }
    }

    /// Removes the observer `idKey` of `key`; every observer of `key` when `idKey` is empty.
    /// - Returns: how many observers were removed.
    @discardableResult
    func remove(key: String, idKey: String) -> Int {
        var removed = 0
        _subscriptions.mutate { subscriptions in
            let existing = subscriptions[key] ?? []
            let remaining = idKey.isEmpty ? [] : existing.filter { $0.idKey != idKey }
            removed = existing.count - remaining.count
            subscriptions[key] = remaining.isEmpty ? nil : remaining
        }
        return removed
    }

    func completionObservers(forKey key: String) -> [CompletionBlock] {
        (subscriptions[key] ?? []).compactMap(\.completion)
    }

    // MARK: Progress

    /// The last progress `key`'s transfer reported, while it runs.
    func progress(forKey key: String) -> Double? {
        lastProgress[key]
    }

    /// Keeps `progress` for `key` and returns the observers to tell.
    func record(progress: Double, forKey key: String) -> [ProgressBlock] {
        lastProgress[key] = progress
        return (subscriptions[key] ?? []).compactMap(\.progress)
    }

    /// The furthest an upload got: its progress, and the bytes that progress was of.
    struct UploadHighWater: Equatable {
        var progress: Double
        var totalBytes: Int64?
    }

    /// The furthest each upload has shown, kept across its attempts: a resent part counts its
    /// bytes again from 0, and a retry resumes from what the server stored, both less than
    /// what the bubble already showed. Dropped when the upload succeeds or is cancelled
    /// (`endProgress`), or when an attempt sends a file of another size.
    @Atomic private var uploadHighWater = [String: UploadHighWater]()

    /// `progress` of `key`'s upload, raised to the furthest the upload has already shown, and
    /// the bytes it is of (the earlier attempt's while this one has not reported its file).
    func floorUpload(progress: Double, totalBytes: Int64?, forKey key: String) -> UploadHighWater {
        var shown = UploadHighWater(progress: progress, totalBytes: totalBytes)
        _uploadHighWater.mutate { marks in
            if let mark = marks[key],
               totalBytes == nil || mark.totalBytes == nil || mark.totalBytes == totalBytes {
                shown.totalBytes = totalBytes ?? mark.totalBytes
                shown.progress = max(progress, mark.progress)
            }
            marks[key] = shown
        }
        return shown
    }

    /// The furthest `key`'s upload has shown with a known byte count, while it has a floor.
    func uploadHighWater(forKey key: String) -> UploadHighWater? {
        uploadHighWater[key]
    }

    /// Notes that `key` reported progress with no observer. True the first time.
    func markUnobserved(_ key: String) -> Bool {
        var inserted = false
        _unobserved.mutate { inserted = $0.insert(key).inserted }
        return inserted
    }

    /// `key`'s transfer is over: no progress comes for it again. `keepingUploadFloor` for an
    /// upload that will be tried again (failed, interrupted, paused): its next attempt does not
    /// show less than this one did.
    func endProgress(forKey key: String, keepingUploadFloor: Bool = false) {
        lastProgress[key] = nil
        _unobserved.mutate { $0.remove(key) }
        if !keepingUploadFloor {
            _uploadHighWater.mutate { $0[key] = nil }
        }
    }

    /// Forgets the progress of `key` without ending anything (its last observer went and no
    /// transfer runs for it).
    func forgetProgress(forKey key: String) {
        lastProgress[key] = nil
    }

    // MARK: Callers waiting for a running transfer

    func wait(forKey key: String, of type: SCTDataSessionTaskInfo.TransferType, _ callback: @escaping Callback) {
        switch type {
        case .upload:
            _waitingUploads.mutate { $0[key, default: []].append(callback) }
        case .download:
            _waitingDownloads.mutate { $0[key, default: []].append(callback) }
        }
    }

    /// The callers waiting on `key`'s end, taken in one step: a caller added meanwhile is in
    /// this batch or kept for the next end of the key.
    func takeWaiting(forKey key: String, of type: SCTDataSessionTaskInfo.TransferType) -> [Callback] {
        var callbacks: [Callback]?
        switch type {
        case .upload:
            _waitingUploads.mutate { callbacks = $0.removeValue(forKey: key) }
        case .download:
            _waitingDownloads.mutate { callbacks = $0.removeValue(forKey: key) }
        }
        return callbacks ?? []
    }
}
