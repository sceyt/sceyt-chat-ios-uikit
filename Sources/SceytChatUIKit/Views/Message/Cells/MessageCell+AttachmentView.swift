//
//  MessageCell+AttachmentView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit

/// De-duplicates on-disk thumbnail reloads across every attachment view in the app.
///
/// A reload is keyed by attachment identity + the size it is being generated for, so
/// the same attachment consumed at two design sizes (message bubble vs reply preview)
/// still gets one load each. Two things are suppressed:
///
/// - **Concurrent duplicates.** A reload only clears `isThumbnailLoadedFromFile` once it
///   lands, so every bind in between would otherwise start its own — and each one can be a
///   full-size decode + resize + JPEG encode. Scrolling a screenful of file messages fanned
///   this out across a dozen threads.
/// - **Hot retries of a hopeless attachment.** A file with no derivable preview fails every
///   time; the cooldown stops each subsequent bind from paying for that discovery again.
enum ThumbnailReloadGate {
    /// How long a failed reload is suppressed before another bind may retry it.
    static var failureCooldown: TimeInterval = 30

    private static let lock = NSLock()
    private static var inFlight = Set<String>()
    private static var cooldownUntil = [String: CFAbsoluteTime]()

    static func key(attachment: ChatMessage.Attachment, size: CGSize) -> String {
        "\(identity(of: attachment))@\(Int(size.width))x\(Int(size.height))"
    }

    /// Includes the location alongside id/tid: a locally-built attachment can carry
    /// id 0 and tid 0, and two of those must not share one ticket.
    private static func identity(of attachment: ChatMessage.Attachment) -> String {
        "\(attachment.id).\(attachment.tid).\(attachment.url ?? attachment.filePath ?? "")"
    }

    /// Claims the right to run a reload for `key`. False means one is already running, or
    /// the last one failed recently enough that retrying now would just burn CPU again.
    static func begin(_ key: String) -> Bool {
        let now = CFAbsoluteTimeGetCurrent()
        lock.lock()
        defer { lock.unlock() }
        if inFlight.contains(key) { return false }
        if let until = cooldownUntil[key] {
            if until > now { return false }
            cooldownUntil[key] = nil
        }
        inFlight.insert(key)
        return true
    }

    /// Releases the ticket without recording a failure — the work never got to run
    /// (the view died or was rebound), so the next bind deserves a fresh attempt.
    static func cancel(_ key: String) {
        lock.lock()
        inFlight.remove(key)
        lock.unlock()
    }

    static func end(_ key: String, succeeded: Bool) {
        lock.lock()
        inFlight.remove(key)
        if succeeded {
            cooldownUntil[key] = nil
        } else {
            cooldownUntil[key] = CFAbsoluteTimeGetCurrent() + failureCooldown
        }
        lock.unlock()
    }

    /// Drops all suppression. Call when something has changed on disk that could make a
    /// previously-failing attachment succeed (a download completing, a cache purge).
    static func reset() {
        lock.lock()
        inFlight.removeAll()
        cooldownUntil.removeAll()
        lock.unlock()
    }

    /// Clears suppression for one attachment, at every size it may have been generated for.
    static func invalidate(attachment: ChatMessage.Attachment) {
        let prefix = "\(identity(of: attachment))@"
        lock.lock()
        inFlight = inFlight.filter { !$0.hasPrefix(prefix) }
        cooldownUntil = cooldownUntil.filter { !$0.key.hasPrefix(prefix) }
        lock.unlock()
    }
}

extension MessageCell {
    open class AttachmentView: View, AttachmentSharpThumbnailObserver, AttachmentTransferStatusObserver {
        public lazy var appearance = Components.messageCell.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open lazy var imageView = ImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFill)
        
        open lazy var pauseButton = Button()
            .withoutAutoresizingMask
        
        open lazy var progressView = Components.circularProgressView
            .init()
            .withoutAutoresizingMask
        
        open lazy var progressLabel = Components.timeLabel
            .init()
            .withoutAutoresizingMask
        
        open var lastAttachmentTransferProgress: AttachmentTransfer.AttachmentProgress?

        /// Scheduled hide for a completed transfer, delayed so the stroke-fill
        /// animation gets to render the 100% state first. Cancelled whenever a
        /// newer progress value arrives (e.g. the attachment starts re-downloading).
        private var pendingHideWorkItem: DispatchWorkItem?
        
        override open func setup() {
            super.setup()

            progressView.isHidden = true
            progressLabel.isHidden = true
            pauseButton.isHidden = true
            progressView.animationDuration = 0.2
            progressView.rotationDuration = 2
            progressLabel.iconView.isHidden = true
            // Weak registration, lives for the view's whole lifetime — the relay prunes
            // deallocated observers itself, so no removal on reuse/teardown is needed.
            AttachmentSharpThumbnailRelay.default.add(self)
            AttachmentTransferStatusRelay.default.add(self)
        }

        /// Backstop delivery of a pause/resume/failure raised somewhere other than this cell
        /// (see `AttachmentTransferStatusRelay`). `update(status:)` otherwise runs only from
        /// `data`'s `didSet` — i.e. on bind — and a status-only change bumps no
        /// `contentVersion`, so nothing reconfigures this cell and it keeps rendering the
        /// state the transfer was in when it was last bound.
        open func attachmentTransferStatusDidChange(
            _ attachment: ChatMessage.Attachment,
            status: ChatMessage.Attachment.TransferStatus
        ) {
            guard let data,
                  AttachmentTransfer.transferIdentity(of: data.attachment)
                    == AttachmentTransfer.transferIdentity(of: attachment)
            else { return }
            data.attachment.status = status
            lastAttachmentTransferProgress = nil
            let rendered = applyTransferStatus(status)
            switch rendered {
            case .pending, .downloading, .uploading:
                if let message = data.ownerMessage,
                   let live = fileProvider.currentProgressPercent(message: message, attachment: data.attachment) {
                    setProgress(live)
                }
            default:
                break
            }
        }

        /// Backstop delivery of the blurry→sharp swap (see `AttachmentSharpThumbnailRelay`).
        /// The regular path — the bound layout's `onLoadThumbnail` — is a single overwritable
        /// slot: a sibling view that binds the same layout later and deallocates (cell reuse +
        /// back-to-back reconfigures) leaves the slot pointing at a dead owner, and a sharp load
        /// can also land on a duplicate layout instance this view never bound. The relay is keyed
        /// by attachment identity and per-view, so neither failure mode can steal it.
        open func attachmentSharpThumbnailDidLoad(_ attachment: ChatMessage.Attachment, image: UIImage) {
            guard let layout = data,
                  layout.type == .image || layout.type == .video,
                  layout.attachment == attachment
            else { return }
            // The relay is keyed by attachment identity only, but one attachment is consumed at
            // several design sizes (message bubble vs 40pt reply preview), each with its own
            // size-keyed thumbnail file. A sibling consumer's file-backed load is "sharp" for ITS
            // size yet far too small for this one — accepting it repaints the bubble at reply
            // resolution AND locks the layout file-backed so no reload path restores the right
            // thumbnail until the layout is rebuilt (Case 6). Compare max sides (aspect-safe;
            // generated files match the design's max side) with the LOW-RES PAINT tolerance.
            let displayScale = traitCollection.displayScale > 0 ? traitCollection.displayScale : UIScreen.main.scale
            let requiredPxMaxSide = max(layout.thumbnailSize.width, layout.thumbnailSize.height) * displayScale
            let imagePxMaxSide = max(image.size.width, image.size.height) * image.scale
            guard imagePxMaxSide >= requiredPxMaxSide * 0.9 else {
                logger.debug("[IMGQ] relay image ignored — too small for this consumer, id=\(attachment.id) imagePxMaxSide=\(Int(imagePxMaxSide)) requiredPxMaxSide=\(Int(requiredPxMaxSide)) layout=\(ObjectIdentifier(layout))")
                return
            }
            // Heal the bound layout instance first, so later rebinds/updates see the sharp,
            // file-backed state. setFileBackedThumbnail re-posts to the relay; on that nested
            // entry the state check below is already satisfied, so the recursion terminates.
            if !(layout.isThumbnailLoadedFromFile && layout.thumbnail === image) {
                layout.setFileBackedThumbnail(image)
            }
            // setFileBackedThumbnail normally paints via the layout's onLoadThumbnail fire, but
            // that slot may be owned by a dead view — paint directly so the screen never
            // depends on slot ownership.
            if imageView.image !== image {
                imageView.image = image
            }
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            pauseButton.setImage(appearance.overlayMediaLoaderAppearance.cancelIcon, for: .normal)
            progressView.progressColor = appearance.overlayMediaLoaderAppearance.progressColor
            progressView.trackColor = appearance.overlayMediaLoaderAppearance.trackColor
            progressLabel.backgroundColor = appearance.overlayMediaLoaderAppearance.backgroundColor
            progressLabel.textLabel.font = appearance.overlayMediaLoaderAppearance.progressLabelAppearance.font
            progressLabel.textLabel.textColor = appearance.overlayMediaLoaderAppearance.progressLabelAppearance.foregroundColor
            progressView.parentAppearance = appearance.overlayMediaLoaderAppearance
        }
        
        /// Paints a thumbnail that arrived outside the bind path (a transfer completing, an
        /// async load landing). Subclasses override to apply their own rules about what the
        /// slot may show. The default keeps the historical behaviour of ignoring a nil value
        /// rather than clearing whatever is on screen.
        open func applyThumbnail(_ thumbnail: UIImage?) {
            guard let thumbnail else { return }
            imageView.image = thumbnail
        }

        /// Whether this view's `imageView` is a slot that holds (or will hold) a real preview,
        /// and so should carry the placeholder background while that preview is missing.
        /// True for image/video; `AttachmentFileView` widens it to previewable documents.
        open var showsMediaPlaceholderBackground: Bool {
            guard let data else { return false }
            return data.type == .image || data.type == .video
        }

        /// Fills the media slot with the reply-preview bubble color so the translucent loader
        /// always has something to sit on. Without it, an attachment whose sender shipped no
        /// thumbHash in metadata (older clients) has no preview to show — the icon provider
        /// returns nil for image/video — so the slot is transparent and the only thing on
        /// screen is the loader's own dark disc floating over the bubble. Harmless once a
        /// thumbnail exists: `imageView` is `.scaleAspectFill` + `clipsToBounds`, so the
        /// image covers the color completely. Always assigns (clearing when not applicable)
        /// so a reused cell cannot keep a previous binding's color.
        open func updateThumbnailPlaceholderBackground() {
            guard showsMediaPlaceholderBackground, let data else {
                imageView.backgroundColor = nil
                return
            }
            let incoming = data.ownerMessage?.incoming ?? true
            imageView.backgroundColor = incoming
                ? appearance.incomingReplyBackgroundColor
                : appearance.outgoingReplyBackgroundColor
        }

        open func setupPreviewer() {
            guard (data.type == .image || data.type == .video)
            else { return }
            imageView.setup(
                previewer: previewer,
                item: PreviewItem.attachment(data.attachment),
                viewOnce: data.ownerMessage?.isViewOnceMessage ?? false,
                messageText: data.ownerMessage?.body
            )
        }
        
        open func setProgress(_ progress: AttachmentTransfer.AttachmentProgress) {
            let total = progress.attachment.uploadedFileSize
            if total <= 0 {
                progressLabel.text = L10n.Upload.preparing
            } else {
                let downloaded = UInt(progress.progress * Double(total))
                progressLabel.text = "\(appearance.attachmentFileSizeFormatter.format(UInt64(downloaded))) / \(appearance.attachmentFileSizeFormatter.format(UInt64(total)))"
            }
            setProgress(progress.progress)
        }
        
        open func setCompletion(_ completion: AttachmentTransfer.AttachmentCompletion) {
            guard completion.error == nil
            else { return }
            let total = completion.attachment.uploadedFileSize
            if total > 0 {
                progressLabel.text = "\(appearance.attachmentFileSizeFormatter.format(UInt64(total))) / \(appearance.attachmentFileSizeFormatter.format(UInt64(total)))"
            }
        }
        
        open func setProgress(_ progress: CGFloat) {
            if let message = data.ownerMessage,
               let task = AttachmentTransfer.default.taskFor(message: message, attachment: data.attachment),
               task.transferType == .upload,
               [.pending, .uploading].contains(data.transferStatus),
                progress <= 0.01 {
                progressLabel.text = L10n.Upload.preparing
            }
            guard progressView.progress != progress
            else { return }
            pendingHideWorkItem?.cancel()
            pendingHideWorkItem = nil
            progressView.progress = progress
            if progress <= 0 {
                hideProgressView()
            } else if progress >= 1 {
                if progressView.isHidden || progressView.isHiddenProgress {
                    hideProgressView()
                } else {
                    // Fill-through: fast transfers deliver all their progress in a terminal
                    // burst, so hiding on the same tick that carries the 1.0 value means the
                    // fill animation is never rendered. Let the stroke reach 100% first,
                    // then shrink out.
                    let item = DispatchWorkItem { [weak self] in
                        guard let self, self.progressView.progress >= 1 else { return }
                        self.hideProgressView()
                    }
                    pendingHideWorkItem = item
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + progressView.animationDuration,
                        execute: item
                    )
                }
            } else {
                progressView.isHidden = false
                progressLabel.isHidden = (progressLabel.text ?? "").isEmpty || progressView.isHidden || progressView.isHiddenProgress
                pauseButton.isHidden = false
            }
        }
        
        open func hideProgressView() {
            progressLabel.isHidden = true
            guard !progressView.isHidden
            else { return }
            willHideProgressView()
            UIView.animate(withDuration: progressView.animationDuration + 0.1) { [weak self] in
                guard let self else { return }
                self.progressView.transform = .init(scaleX: 0.01, y: 0.01)
                self.pauseButton.transform = .init(scaleX: 0.01, y: 0.01)
            } completion: { [weak self] _ in
                guard let self else { return }
                // A progress tick may have re-shown the ring mid-shrink (the same
                // attachment started transferring again); leave it visible then.
                let progress = self.progressView.progress
                if progress <= 0 || progress >= 1 {
                    self.progressView.isHidden = true
                    self.pauseButton.isHidden = true
                    self.progressView.transform = .identity
                    self.pauseButton.transform = .identity
                    self.didHideProgressView()
                } else {
                    self.progressView.transform = .identity
                    self.pauseButton.transform = .identity
                }
            }
        }
        
        open func willHideProgressView() {}
        
        open func didHideProgressView() {
            pauseButton.isHidden = true
        }
        
        open func update(status: ChatMessage.Attachment.TransferStatus) {
            progressView.isHiddenProgress = false
            progressView.rotateZ = true
            progressLabel.isHidden = true
            switch status {
            case .pending:
                break
            case .uploading:
                pauseButton.setImage(appearance.overlayMediaLoaderAppearance.cancelIcon, for: .normal)
            case .downloading:
                pauseButton.setImage(appearance.overlayMediaLoaderAppearance.cancelIcon, for: .normal)
            case .pauseUploading, .failedUploading:
                setProgress(0.0001)
                progressView.isHiddenProgress = true
                progressLabel.isHidden = true
                pauseButton.setImage(appearance.overlayMediaLoaderAppearance.uploadIcon, for: .normal)
            case .pauseDownloading, .failedDownloading:
                setProgress(0.0001)
                progressView.isHiddenProgress = true
                progressLabel.isHidden = true
                pauseButton.setImage(appearance.overlayMediaLoaderAppearance.downloadIcon, for: .normal)
            case .done:
                if progressView.progress > 0 {
                    setProgress(1)
                } else {
                    setProgress(0)
                }
            }
        }
        
        open var data: MessageLayoutModel.AttachmentLayout! {
            didSet {
                guard let data else { return }
                applyTransferStatus(data.attachment.status)
            }
        }
        
        open var previewer: (() -> AttachmentPreviewDataSource?)?
        
        /// Loads the on-disk thumbnail for `attachment` on a background queue and applies it to the
        /// visible cell's layout via `setFileBackedThumbnail`, keyed by attachment identity. This
        /// updates the model state (so later rebinds stay sharp) AND notifies the cell. Robust to
        /// the duplicate-`AttachmentLayout`-instance routing problem where the download completion /
        /// observer fan-out updates a different layout instance than the one bound to the visible
        /// cell, which would otherwise leave the cell on the blurry thumbHash placeholder.
        /// No-op for voice/link attachments (their imageView is an icon, not a photo). File
        /// attachments are included: previewable documents (image/video files) get an on-disk
        /// thumbnail after download and need the same blurred→sharp recovery.
        public static let thumbnailReloadRetryCount = 2

        open func reloadThumbnailFromFile(for attachment: ChatMessage.Attachment, retriesLeft: Int = thumbnailReloadRetryCount) {
            guard let data, data.type == .image || data.type == .video || data.type == .file else { return }
            let preferred = data.thumbnailSize == .zero
                ? MessageLayoutModel.defaults.imageAttachmentSize
                : data.thumbnailSize
            // Only the outermost call takes the gate; the delayed retries below run under the
            // ticket it already holds. Without it every bind of the same attachment — i.e.
            // every scroll pass over it — starts another full thumbnail generation, because
            // the layout only flips to `isThumbnailLoadedFromFile` once one of them lands.
            let gateKey = ThumbnailReloadGate.key(attachment: attachment, size: preferred)
            let isRetry = retriesLeft < Self.thumbnailReloadRetryCount
            if !isRetry, !ThumbnailReloadGate.begin(gateKey) { return }
            // `.utility`, not `.userInteractive`: this can be a full-size decode + resize +
            // JPEG encode. At userInteractive it competes with the render loop for CPU on
            // exactly the frames the user is scrolling, which is what it was doing.
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let path = fileProvider.thumbnailFile(for: attachment, preferred: preferred),
                      let image = UIImage(contentsOfFile: path)
                else {
                    // Video frame extraction (copyFrame) can transiently fail on a just-downloaded
                    // file (cold I/O cache + several concurrent extractions of the same fresh file).
                    // The file is on disk, so a sharp thumbnail IS obtainable — retry shortly instead
                    // of leaving the blurry placeholder until the user scrolls (the only other thing
                    // that re-runs this). setFileBackedThumbnail is idempotent, so a retry that races
                    // a successful sibling load is harmless.
                    guard retriesLeft > 0 else {
                        logger.debug("[Attachment] reloadThumbnailFromFile gave up, no thumbnail yet \(attachment.description)")
                        ThumbnailReloadGate.end(gateKey, succeeded: false)
                        return
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                        guard let self, let layout = self.data, layout.attachment == attachment
                        else {
                            logger.verbose("[Attachment] reloadThumbnailFromFile retry dropped — view died or rebound \(attachment.description)")
                            ThumbnailReloadGate.cancel(gateKey)
                            return
                        }
                        self.reloadThumbnailFromFile(for: attachment, retriesLeft: retriesLeft - 1)
                    }
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    ThumbnailReloadGate.end(gateKey, succeeded: true)
                    guard let self, let layout = self.data, layout.attachment == attachment
                    else {
                        logger.verbose("[Attachment] reloadThumbnailFromFile apply dropped — view died or rebound \(attachment.description)")
                        return
                    }
                    layout.setFileBackedThumbnail(image)
                }
            }
        }

        /// Clears the transfer visuals left behind by the attachment this view was previously
        /// bound to. Only needed when a recycled view is handed a *different* attachment —
        /// otherwise an in-flight ring (or its pending shrink-out) from the old one bleeds
        /// onto the new one for a frame.
        open func prepareForRebind() {
            clearTransferOverlay()
            imageView.image = nil
            imageView.backgroundColor = nil
        }

        /// Takes the transfer overlay off screen at once — no fill-through, no shrink-out.
        ///
        /// `update(status: .done)` deliberately animates a surviving ring to 100% before hiding
        /// it, because a fast transfer delivers its last progress in a terminal burst and the
        /// fill would otherwise never render. That is right for a transfer that finished *here*.
        /// It is wrong for a status resolved to `.done` because the bytes turned out to already
        /// be on disk: there was no transfer, so animating one to completion flashes a ring the
        /// user never started.
        open func clearTransferOverlay() {
            pendingHideWorkItem?.cancel()
            pendingHideWorkItem = nil
            lastAttachmentTransferProgress = nil
            progressView.transform = .identity
            pauseButton.transform = .identity
            // Assigning `progress` installs a strokeEnd animation from the old value, so the
            // reset has to happen with actions off and the animation cleared afterwards —
            // otherwise recycling a view mid-transfer plays its ring rewinding to empty.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            progressView.progress = 0
            progressView.progressLayer.removeAnimation(forKey: "animateprogress")
            progressView.layer.removeAllAnimations()
            pauseButton.layer.removeAllAnimations()
            CATransaction.commit()
            progressView.isHidden = true
            progressView.isHiddenProgress = false
            progressLabel.isHidden = true
            progressLabel.text = nil
            pauseButton.isHidden = true
        }

        /// The status this view should *render* for `stored`, resolved from the transfer rather
        /// than from the stored value — the rule `syncTransferOverlay` already applies on the
        /// media gallery: live percent → bytes on disk → stored status.
        ///
        /// A stored status can outlive its transfer (the process was killed mid-download, a
        /// completion never reached this view), and rendering it puts a progress ring or a
        /// download button over a file the user can already open. No live percent and no task
        /// means whatever the status describes is over; with the bytes on disk it succeeded.
        ///
        /// Only download-shaped statuses are resolved. An upload's local file is its *source*,
        /// not proof of delivery, so a `.failedUploading` over a local file has to keep its
        /// retry affordance — hiding it would show a sent-looking attachment that never left
        /// the device.
        open func renderedTransferStatus(
            for stored: ChatMessage.Attachment.TransferStatus
        ) -> ChatMessage.Attachment.TransferStatus {
            guard let data,
                  let message = data.ownerMessage,
                  AttachmentTransfer.healableDownloadStatuses.contains(stored),
                  fileProvider.currentProgressPercent(message: message, attachment: data.attachment) == nil,
                  fileProvider.taskFor(message: message, attachment: data.attachment) == nil,
                  fileProvider.filePath(attachment: data.attachment) != nil
            else { return stored }
            return .done
        }

        /// Renders `stored` through `renderedTransferStatus`, and returns what was actually
        /// rendered so the caller can branch on the same value. A status resolved to `.done`
        /// out of staleness clears the overlay outright rather than animating a completion that
        /// never happened.
        @discardableResult
        open func applyTransferStatus(
            _ stored: ChatMessage.Attachment.TransferStatus
        ) -> ChatMessage.Attachment.TransferStatus {
            let rendered = renderedTransferStatus(for: stored)
            if rendered == .done, stored != .done {
                clearTransferOverlay()
            } else {
                update(status: rendered)
            }
            return rendered
        }

        open func setProgressHandler() {
            guard let data = data,
                  let message = data.ownerMessage
            else {
                // Without a subscription this view can never show progress: the ring
                // stays on whatever `bind` seeded until the transfer completes.
                logger.error("[Attachment] setProgressHandler skipped, no progress will be shown — data=\(data == nil ? "nil" : "set") ownerMessage=\(data?.ownerMessage == nil ? "nil" : "set")")
                return
            }
            var needsToUpdateStatus = false
            fileProvider
                .progress(
                    message: message,
                    attachment: data.attachment,
                    objectIdKey: AttachmentTransfer.observerKey(for: self, prefix: "messagecell")
                ) { [weak self, weak data] progress in
                    guard let self, let data, self.data == data
                    else {
                        logger.verbose("[Attachment] progress self is nil thumbnail load from filePath \(progress.attachment.description)")
                        return
                    }
                    // A tick for a different attachment is not ours to render: its
                    // percent against this attachment's total would produce a byte
                    // count belonging to neither.
                    //
                    // Compared by transfer identity rather than `==`: the tick carries
                    // the task's copy of the attachment, which can be missing the `id`
                    // this cell's database-backed copy already has. `==` is `id`-first
                    // and would reject every tick of the very transfer we are showing.
                    guard AttachmentTransfer.transferIdentity(of: data.attachment)
                            == AttachmentTransfer.transferIdentity(of: progress.attachment)
                    else {
                        logger.warn("[Attachment] dropping a tick for another attachment — bound \(AttachmentTransfer.transferIdentity(of: data.attachment)) received \(AttachmentTransfer.transferIdentity(of: progress.attachment))")
                        return
                    }

                    // A paused transfer must not keep moving the ring. The default download
                    // session cannot truly suspend on every transport, and a pause raised on
                    // another screen races the bytes already in flight, so ticks can arrive
                    // after this view has correctly rendered the paused state.
                    guard ![.pauseDownloading, .pauseUploading,
                            .failedDownloading, .failedUploading].contains(data.attachment.status)
                    else {
                        logger.verbose("[Attachment] dropping a tick for a paused transfer \(AttachmentTransfer.transferIdentity(of: data.attachment))")
                        return
                    }

                    DispatchQueue.main.async { [weak self] in
                        if needsToUpdateStatus {
                            needsToUpdateStatus = false
                            self?.update(status: progress.attachment.status)
                        }
                        self?.setProgress(progress)
                        self?.lastAttachmentTransferProgress = progress
                    }
                } completion: {[weak self, weak data] done in
                    guard let data, self?.data == data
                    else {
                        logger.verbose("[Attachment] completion self is nil \(done.attachment.description)")
                        return
                    }
                    logger.debug("[Attachment] completion \(done.attachment.status)")
                    if done.error == nil {
                        fileProvider.removeProgressObserver(
                            message: done.message,
                            attachment: done.attachment,
                            objectIdKey: self.map { AttachmentTransfer.observerKey(for: $0, prefix: "messagecell") } ?? ""
                        )
                    } else {
                        needsToUpdateStatus = true
                    }
                    self?.data.update(attachment: done.attachment)
                    DispatchQueue.main.async {
                        // Via applyThumbnail, not a direct assignment: subclasses have their own
                        // rules for what may be painted. A previewable file with no thumbHash
                        // resolves `data.thumbnail` to the generic file icon here, and painting
                        // it would flash that icon between the loader disappearing and the sharp
                        // preview arriving from reloadThumbnailFromFile just below.
                        self?.applyThumbnail(self?.data?.thumbnail)
                        self?.update(status: done.attachment.status)
                        self?.setCompletion(done)
                        if done.error == nil {
                            // The bytes just landed on disk, so a reload that failed before the
                            // download (nothing to derive a preview from) can now succeed — lift
                            // its cooldown rather than making the user wait it out.
                            ThumbnailReloadGate.invalidate(attachment: done.attachment)
                            self?.reloadThumbnailFromFile(for: done.attachment)
                        }
                    }
                    RunLoop.main.perform { [weak self] in
                        self?.setupPreviewer()
                    }
                }
        }
    }
}
