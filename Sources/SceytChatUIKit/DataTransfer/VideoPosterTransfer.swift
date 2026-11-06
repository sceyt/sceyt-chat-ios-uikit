//
//  VideoPosterTransfer.swift
//  SceytChatUIKit
//
//  A video's poster frame: made and sent with a sent video (encrypted when the video is), and
//  fetched (decrypted when it must be) for a received one. Every piece of work it starts is
//  owned: `cancelAll` stops it and `waitForWork` waits for it.
//

import Foundation
import SceytChat
import UIKit.UIImage

/// What the poster transfer needs from the transfer it serves.
protocol VideoPosterHost: AnyObject {
    var environment: TransferEnvironment { get }
    func dataSession(for message: ChatMessage?, forAttachment: ChatMessage.Attachment?) -> SCTDataSession?
    /// The poster frame of a local video, written to a new file.
    func makeVideoThumbnailFile(for attachment: ChatMessage.Attachment) -> URL?
    /// The attachment's own file, when it is on disk.
    func filePath(attachment: ChatMessage.Attachment) -> String?
}

final class VideoPosterTransfer: @unchecked Sendable {
    /// Set once, by the transfer that owns this, right after both exist.
    weak var host: VideoPosterHost?
    /// How long a sent video waits for its poster before it goes out without one.
    @Atomic var timeout: TimeInterval = 30
    /// Origins being fetched, so a poster is never fetched twice at once.
    @Atomic private var fetching = Set<String>()
    private let work = TaskBag()

    // MARK: Sent videos

    /// The poster a sent video's upload carries: uploaded, then its origin (and, encrypted, its
    /// rendition) merged into the attachment. Gives up after `timeout`: the video then goes
    /// without it, and a poster that lands later is never attached (only the winner of the
    /// race is applied, here, after it).
    func attach(taskInfo: SCTDataSessionTaskInfo, message: ChatMessage, attachment atch: ChatMessage.Attachment) async {
        guard let job = posterJob(taskInfo: taskInfo, message: message, attachment: atch) else { return }
        await attach(taskInfo: taskInfo, attachment: atch, decoded: job.decoded, dataSession: job.dataSession)
    }

    /// What a poster upload needs, or nil when this upload sends none (not a video, a
    /// view-once message, or one whose metadata already names a poster).
    private func posterJob(
        taskInfo: SCTDataSessionTaskInfo,
        message: ChatMessage,
        attachment atch: ChatMessage.Attachment
    ) -> PosterJob? {
        // The metadata string is decoded fresh: a dedupe hit replaces only the string, and one
        // that reused a thumbnailed upload already carries "video_thumb".
        guard taskInfo.transferType == .upload, atch.kind == .video, !message.isViewOnceMessage else { return nil }
        let decoded = Self.decodedMetadata(of: atch)
        guard decoded?.videoThumbnail == nil,
              let dataSession = host?.dataSession(for: message, forAttachment: atch)
        else { return nil }
        return PosterJob(decoded: decoded, dataSession: dataSession)
    }

    private struct PosterJob {
        let decoded: ChatMessage.Attachment.Metadata<String>?
        let dataSession: AttachmentThumbnailTransferring
    }

    private func attach(
        taskInfo: SCTDataSessionTaskInfo,
        attachment atch: ChatMessage.Attachment,
        decoded: ChatMessage.Attachment.Metadata<String>?,
        dataSession: AttachmentThumbnailTransferring
    ) async {
        let tag = taskInfo.logTag
        let timeout = self.timeout
        let outcome = await withTaskGroup(of: Race.self) { group -> Race in
            group.addTask { .poster(await self.upload(taskInfo: taskInfo, attachment: atch, dataSession: dataSession)) }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return .timedOut
            }
            let first = await group.next() ?? .timedOut
            group.cancelAll()
            return first
        }
        switch outcome {
        case .timedOut:
            logger.warn("[Attachment] \(tag) video_thumb timed out after \(Int(timeout)) s, sending without it")
        case .poster(nil):
            break
        case .poster(let poster?):
            var meta = decoded ?? ChatMessage.Attachment.Metadata<String>(thumbnail: "")
            meta.videoThumbnail = poster.origin
            AttachmentTransfer.updateMetadata(of: atch, rebuiltFrom: meta)
            if let info = poster.encryption {
                taskInfo.thumbnailRendition = AttachmentEncryption.Rendition(role: AttachmentEncryption.Rendition.thumbnailRole, info: info)
            }
            logger.verbose("[Attachment] \(tag) \(poster.encryption == nil ? "" : "encrypted ")video_thumb uploaded, origin \(TransferLog.redact(poster.origin))")
        }
    }

    /// Calls `completion` at once when the upload sends no poster (most uploads); otherwise
    /// runs the poster upload as owned work and calls it once that is over.
    func attach(taskInfo: SCTDataSessionTaskInfo, message: ChatMessage, attachment: ChatMessage.Attachment, completion: @escaping () -> Void) {
        guard let job = posterJob(taskInfo: taskInfo, message: message, attachment: attachment) else {
            completion()
            return
        }
        let handoff = Handoff(PosterWork(taskInfo: taskInfo, attachment: attachment, job: job, completion: completion))
        work.run {
            let work = handoff.value
            await self.attach(taskInfo: work.taskInfo, attachment: work.attachment, decoded: work.job.decoded, dataSession: work.job.dataSession)
            work.completion()
        }
    }

    private struct PosterWork {
        let taskInfo: SCTDataSessionTaskInfo
        let attachment: ChatMessage.Attachment
        let job: PosterJob
        let completion: () -> Void
    }

    private enum Race: Sendable {
        case timedOut
        case poster(UploadedPoster?)
    }

    private struct UploadedPoster: @unchecked Sendable {
        let origin: String
        /// The poster's own key, when the video is encrypted.
        let encryption: EncryptedFileInfo?
    }

    /// Makes, encrypts when needed, and uploads the poster. Nil when it could not: why is logged.
    private func upload(taskInfo: SCTDataSessionTaskInfo, attachment atch: ChatMessage.Attachment, dataSession: AttachmentThumbnailTransferring) async -> UploadedPoster? {
        let tag = taskInfo.logTag
        let context = taskInfo.logContext
        guard let host, let frame = host.makeVideoThumbnailFile(for: atch) else {
            logger.warn("[Attachment] \(tag) video_thumb: no poster frame could be made, sending without it")
            return nil
        }
        // A dedupe hit can reuse an encrypted object even for a plain send: its poster must
        // then be encrypted too, or the receiver could not show it. A plaintext poster of an
        // encrypted video would show its content.
        guard taskInfo.encryption == .required || atch.isEncrypted else {
            return await send(frame, what: "the poster frame", attachment: atch, dataSession: dataSession, context: context, tag: tag)
                .map { UploadedPoster(origin: $0, encryption: nil) }
        }
        let ciphertext = frame.deletingPathExtension().appendingPathExtension("enc")
        let info: EncryptedFileInfo
        do {
            info = try await TransferLog.$current.withValue(context) {
                try await host.environment.fileEncryption().encryptStream(file: frame, to: ciphertext)
            }
        } catch {
            TransferLog.remove(frame, what: "the poster frame", context: "[Encryption] \(tag) video_thumb")
            logger.warn("[Encryption] \(tag) video_thumb encryption failed, sending without it: \(TransferLog.describe(error))")
            return nil
        }
        TransferLog.remove(frame, what: "the plaintext poster frame", context: "[Encryption] \(tag) video_thumb")
        guard let origin = await send(ciphertext, what: "the encrypted poster", attachment: atch, dataSession: dataSession, context: context, tag: tag) else {
            return nil
        }
        logger.verbose("[Encryption] \(tag) video_thumb encrypted, attachmentId=\(info.attachmentId)")
        return UploadedPoster(origin: origin, encryption: info)
    }

    /// Uploads `file` and removes it once the session answers. Nil on a failure (logged) or
    /// once the attach gave up waiting.
    private func send(_ file: URL, what: String, attachment atch: ChatMessage.Attachment, dataSession: AttachmentThumbnailTransferring, context: TransferLogContext, tag: String) async -> String? {
        let result: Result<String, Error> = await Self.awaitCallback(cancelled: .failure(CancellationError())) { done in
            TransferLog.with(context) {
                dataSession.uploadAttachmentThumbnail(for: atch, fileUrl: file) { result in
                    TransferLog.remove(file, what: what, context: "[Attachment] \(tag) video_thumb")
                    done(result)
                }
            }
        }
        switch result {
        case .success(let origin):
            return origin
        case .failure(let error as CancellationError):
            logger.debug("[Attachment] \(tag) video_thumb upload no longer awaited: \(TransferLog.describe(error))")
            return nil
        case .failure(let error):
            logger.warn("[Attachment] \(tag) video_thumb upload failed, sending without it: \(TransferLog.describe(error))")
            return nil
        }
    }

    // MARK: Received videos

    /// Local cache path of a downloaded "video_thumb" poster, or nil if not cached.
    func cachedPath(attachment: ChatMessage.Attachment) -> String? {
        guard attachment.kind == .video,
              let origin = attachment.imageDecodedMetadata?.videoThumbnail,
              !origin.isEmpty
        else { return nil }
        let path = FileStorage.default.videoThumbnailCachePath(origin: origin)
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    /// Whether `fetch` would get anything for this attachment, answered from it alone.
    func needsFetch(attachment: ChatMessage.Attachment) -> Bool {
        guard attachment.kind == .video,
              let origin = attachment.imageDecodedMetadata?.videoThumbnail,
              !origin.isEmpty,
              cachedPath(attachment: attachment) == nil,
              host?.filePath(attachment: attachment) == nil,
              !fetching.contains(origin)
        else { return false }
        return true
    }

    /// Fetches the poster of each received video whose file is not local yet, so a sharp
    /// preview shows while the much larger video downloads. A failure is dropped and retried
    /// on the next bind.
    func fetch(message: ChatMessage, attachments: [ChatMessage.Attachment]?) {
        guard !message.isViewOnceMessage,
              let attachments = attachments ?? message.attachments,
              let dataSession = host?.dataSession(for: message, forAttachment: nil)
        else { return }
        for atch in attachments where atch.kind == .video {
            guard let origin = atch.imageDecodedMetadata?.videoThumbnail,
                  !origin.isEmpty,
                  dataSession.getFilePath(attachment: atch) == nil,
                  cachedPath(attachment: atch) == nil,
                  claim(origin)
            else { continue }
            let attachment = Handoff(atch)
            let session = Handoff(dataSession as AttachmentThumbnailTransferring)
            work.run {
                await self.fetch(origin: origin, of: attachment.value, dataSession: session.value)
            }
        }
    }

    /// Marks `origin` as being fetched; false when it already is.
    private func claim(_ origin: String) -> Bool {
        var claimed = false
        _fetching.mutate { claimed = $0.insert(origin).inserted }
        return claimed
    }

    private func fetch(origin: String, of atch: ChatMessage.Attachment, dataSession: AttachmentThumbnailTransferring) async {
        let result: Result<URL, Error> = await Self.awaitCallback(cancelled: .failure(CancellationError())) { done in
            dataSession.downloadAttachmentThumbnail(for: atch, origin: origin) { result in
                // Released as soon as the session answers, so a failure is retried on the
                // next bind.
                self._fetching.mutate { $0.remove(origin) }
                done(result)
            }
        }
        let localUrl: URL
        switch result {
        case .success(let url):
            localUrl = url
        case .failure(let error):
            logger.warn("[Attachment] video_thumb download failed, origin \(TransferLog.redact(origin)): \(TransferLog.describe(error)) \(atch.transferLogDescription)")
            return
        }
        guard let host else { return }
        let destination = URL(fileURLWithPath: FileStorage.default.videoThumbnailCachePath(origin: origin))
        do {
            try await Self.store(localUrl, of: atch, at: destination, encryption: host.environment.fileEncryption())
        } catch {
            logger.warn("[Attachment] video_thumb store failed, origin \(TransferLog.redact(origin)): \(TransferLog.describe(error)) \(atch.transferLogDescription)")
            return
        }
        let handoff = Handoff(atch)
        await MainActor.run {
            if let image = UIImage(contentsOfFile: destination.path) {
                AttachmentSharpThumbnailRelay.default.post(handoff.value, image: image)
            }
        }
    }

    /// Writes a downloaded poster to the cache: decrypted with its `enc.renditions` entry when
    /// the video is encrypted, as is otherwise.
    static func store(_ localUrl: URL, of attachment: ChatMessage.Attachment, at destination: URL, encryption fileEncryption: FileEncryption) async throws {
        defer { TransferLog.remove(localUrl, what: "the downloaded poster", context: "[Attachment] video_thumb") }
        guard attachment.isEncrypted else {
            // Atomic write so a concurrent loadThumbnail never observes a partially written
            // JPEG (same pattern as SCTSession.thumbnailFile).
            try Data(contentsOf: localUrl).write(to: destination, options: .atomic)
            return
        }
        guard let encryption = attachment.encryption,
              let rendition = encryption.thumbnail
        else {
            logger.debug("[Encryption] video_thumb of \(attachment.transferLogDescription) cannot be decrypted: \(attachment.encryption == nil ? "enc unreadable" : "no thumbnail rendition in enc")")
            throw AttachmentEncryptionError.invalidEncryptionInfo
        }
        // Decrypted next to the cache and moved in whole: a reader never sees a prefix.
        let decrypted = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString)-\(destination.lastPathComponent)")
        do {
            try await fileEncryption.decrypt(
                file: localUrl,
                to: decrypted,
                encryptionInfo: encryption.info(of: rendition),
                plaintextSize: nil
            )
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: decrypted)
            } else {
                try FileManager.default.moveItem(at: decrypted, to: destination)
            }
        } catch {
            // The caller reports it (and retries on the next bind).
            logger.debug("[Encryption] video_thumb of \(attachment.transferLogDescription) decrypt/store failed: \(TransferLog.describe(error))")
            TransferLog.remove(decrypted, what: "the partial poster", context: "[Encryption] video_thumb", level: .error)
            throw error
        }
    }

    // MARK: Owned work

    /// Stops every poster upload and fetch in progress.
    func cancelAll() {
        work.cancelAll()
    }

    /// Returns once every poster upload and fetch started so far is over.
    func waitForWork() async {
        await work.waitAll()
    }

    // MARK: Helpers

    static func decodedMetadata(of atch: ChatMessage.Attachment) -> ChatMessage.Attachment.Metadata<String>? {
        guard let metadata = atch.metadata else { return nil }
        do {
            return try ChatMessage.Attachment.Metadata<String>.decode(metadata)
        } catch {
            logger.debug("[Attachment] \(TransferLog.currentTag) metadata not readable as poster metadata, taken as none: \(TransferLog.describe(error))")
            return nil
        }
    }

    /// Bridges a callback API to `async`. Resumes with `cancelled` as soon as the calling task
    /// is cancelled; a callback after that is dropped.
    static func awaitCallback<T: Sendable>(cancelled: T, _ start: (@escaping (T) -> Void) -> Void) async -> T {
        let once = ResumeOnce<T>()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                once.install(continuation)
                start { once.resume(with: $0) }
            }
        } onCancel: {
            once.resume(with: cancelled)
        }
    }
}

/// One continuation, resumed once by whichever of a callback and a cancellation comes first.
/// A value that arrives before the continuation is installed is kept for it.
private final class ResumeOnce<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Never>?
    private var early: T?
    private var done = false

    func install(_ continuation: CheckedContinuation<T, Never>) {
        lock.lock()
        if let early, !done {
            done = true
            lock.unlock()
            continuation.resume(returning: early)
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func resume(with value: T) {
        lock.lock()
        guard !done else {
            lock.unlock()
            return
        }
        guard let continuation else {
            if early == nil {
                early = value
            }
            lock.unlock()
            return
        }
        done = true
        self.continuation = nil
        lock.unlock()
        continuation.resume(returning: value)
    }
}

/// Unstructured work with an owner: each task is kept until it ends, so it can be cancelled
/// and waited for.
final class TaskBag: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks = [UUID: Task<Void, Never>]()

    func run(_ operation: @escaping @Sendable () async -> Void) {
        let id = UUID()
        lock.lock()
        let task = Task { [weak self] in
            await operation()
            self?.finished(id)
        }
        tasks[id] = task
        lock.unlock()
    }

    private func finished(_ id: UUID) {
        lock.lock(); tasks[id] = nil; lock.unlock()
    }

    func cancelAll() {
        running().forEach { $0.cancel() }
    }

    private func running() -> [Task<Void, Never>] {
        lock.lock(); defer { lock.unlock() }
        return Array(tasks.values)
    }

    func waitAll() async {
        for task in running() {
            await task.value
        }
    }
}

/// A value handed to another thread or task by a sender that no longer touches it. Marks the
/// handover where it happens, instead of declaring the value's whole type safe to share.
struct Handoff<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
