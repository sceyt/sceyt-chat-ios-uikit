//
//  ChannelInfoViewController+AttachmentCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 10.07.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit

extension ChannelInfoViewController {
    open class AttachmentCell: CollectionViewCell, AttachmentSharpThumbnailObserver, AttachmentTransferStatusObserver {
        /// Transfers and local files of the attachments shown here: the app's shared transfer
        /// unless the owner sets its own.
        public var attachmentTransfer: AttachmentTransfer = fileProvider


        open lazy var imageView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFill)

        open lazy var progressView = Components.circularProgressView
            .init()
            .withoutAutoresizingMask

        open lazy var pauseButton = Button()
            .withoutAutoresizingMask

        open var lastAttachmentTransferProgress: AttachmentTransfer.AttachmentProgress?

        /// Increments on every show (and on reuse). `hideProgressView` captures it when
        /// the hide animation is scheduled, and its completion applies the hide only if
        /// no newer show/reuse happened while the animation was in flight — a stale
        /// completion from a previous binding must not hide the next binding's ring.
        private var overlayGeneration = 0
        /// True while `hideProgressView`'s shrink-out is running.
        private var isHidingProgressView = false

        /// The largest value the ring has drawn for the transfer on screen. Progress reaches
        /// this cell from two places with different latency: the transfer's own ticks, each
        /// hopped onto main separately, and `syncTransferOverlay` reading the transfer's
        /// freshest cached percent on every database update. An older tick landing after a
        /// fresher sync used to animate the ring backwards. Reset whenever there is no drawn
        /// value left to regress from (reuse, hide, pause/failure).
        open private(set) var highestRenderedProgress: CGFloat = 0

        /// How far the ring may go before the transfer's completion arrives. The last byte
        /// arrives before the file is in place (decrypted, moved, saved), and a ring that
        /// filled and hid at that moment left a blurred thumbnail behind it and tried to
        /// load the sharp one from a file that wasn't there yet. Only the completion
        /// (`update(status: .done)`) takes the ring to 100%.
        public static var maxInFlightProgress: CGFloat = 0.9

        /// A transfer's progress as the ring shows it while in flight: scaled into
        /// `0...maxInFlightProgress` rather than clamped, so the ring moves at a steady pace
        /// the whole way instead of racing to the cap and sitting there; the jump from the
        /// cap to 100% on completion reads as "done".
        public static func inFlightProgress(_ progress: Double) -> CGFloat {
            CGFloat(min(max(progress, 0), 1)) * maxInFlightProgress
        }

        /// Hide scheduled after the ring fills to 100%, so the fill is seen before the
        /// shrink-out. Cancelled by any newer show, rebind or reuse.
        private var pendingHideWorkItem: DispatchWorkItem?

        /// How long the full ring stays on screen after its fill, before it shrinks out.
        public static var completedRingHold: TimeInterval = 0.15

        /// Drops the floor so the next value is drawn whatever it is.
        open func resetProgressFloor() {
            highestRenderedProgress = 0
        }

        open var overlayLoaderAppearance = CircularProgressView.Appearance(
            reference: CircularProgressView.appearance,
            progressColor: .onPrimary,
            trackColor: .clear,
            backgroundColor: .overlayBackground2,
            cancelIcon: .attachmentTransferPause,
            uploadIcon: .attachmentUpload,
            downloadIcon: .attachmentDownload
        ) {
            didSet { setupProgressAppearance() }
        }

        open var onPauseAction: (() -> Void)?
        
        open var data: MessageLayoutModel.AttachmentLayout!

        open var previewer: (() -> (any PreviewDataSource)?)?

        /// The attachment the image view's tap-to-preview recognizer was last set up with.
        /// The recognizer keeps that snapshot until the next bind, so when the layout's
        /// attachment changes identity (a pending upload gets its server id and url) the
        /// grid must rebind — the previewer can't match the stale snapshot and would open
        /// a different item.
        open var previewAttachment: ChatMessage.Attachment?

        // MARK: Progress ticks

        /// Folds the transfer's progress ticks into at most one main-queue update per pass.
        public private(set) lazy var progressTicks = MainQueueLatestValue<AttachmentTransfer.AttachmentProgress> { [weak self] progress in
            // A tick queued for the previous binding of a reused cell is dropped.
            guard let self, let data = self.data,
                  AttachmentTransfer.transferIdentity(of: data.attachment)
                    == AttachmentTransfer.transferIdentity(of: progress.attachment)
            else { return }
            self.setProgress(Self.inFlightProgress(progress.progress))
            self.lastAttachmentTransferProgress = progress
        }

        // MARK: Thumbnail

        /// Draws grid thumbnails off the main thread at the tile's size.
        open var thumbnailRenderer: ThumbnailRenderer { .shared }

        /// Bumped on every `setThumbnail`, so a render that finishes after a newer image was
        /// asked for (or after the cell was rebound) is dropped.
        private var thumbnailRequest = 0
        /// The renderer key of what the image view shows, when it is a rendered bitmap.
        private var displayedThumbnailKey: NSString?
        /// The attachment whose picture the image view shows.
        private var displayedThumbnailIdentity: String?

        /// The size, in pixels, a thumbnail is drawn at for this tile.
        open var thumbnailTargetPixelSize: CGSize {
            let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : UIScreen.main.scale
            return CGSize(width: bounds.width * scale, height: bounds.height * scale)
        }

        /// The one way this cell puts a picture on screen. An image clearly bigger than the tile
        /// is drawn at the tile's size in the background (`ThumbnailRenderer`), so the main
        /// thread never decodes a full-size file mid-scroll; a small one is shown directly.
        /// While a render runs the tile keeps what it shows if that is the same attachment (the
        /// blur stays until the sharp image is ready), and is cleared if it was another one.
        open func setThumbnail(_ image: UIImage?) {
            thumbnailRequest &+= 1
            let identity = data.map { AttachmentTransfer.transferIdentity(of: $0.attachment) }
            guard let image, let identity else {
                showThumbnail(image, key: nil, identity: identity)
                return
            }
            let target = thumbnailTargetPixelSize
            guard thumbnailRenderer.needsRendering(image, targetPixelSize: target) else {
                showThumbnail(image, key: nil, identity: identity)
                return
            }
            let key = thumbnailRenderer.key(identity: identity, image: image, targetPixelSize: target)
            if key == displayedThumbnailKey, imageView.image != nil { return }
            if let cached = thumbnailRenderer.cachedImage(forKey: key) {
                showThumbnail(cached, key: key, identity: identity)
                return
            }
            if displayedThumbnailIdentity != identity {
                showThumbnail(nil, key: nil, identity: nil)
            }
            let request = thumbnailRequest
            thumbnailRenderer.render(image, key: key, targetPixelSize: target) { [weak self] rendered in
                guard let self, self.thumbnailRequest == request else { return }
                self.showThumbnail(rendered, key: key, identity: identity)
            }
        }

        private func showThumbnail(_ image: UIImage?, key: NSString?, identity: String?) {
            imageView.image = image
            displayedThumbnailKey = key
            displayedThumbnailIdentity = image == nil ? nil : identity
        }

        override open func setup() {
            super.setup()
            imageView.isUserInteractionEnabled = true
            imageView.clipsToBounds = true
            progressView.isHidden = true
            pauseButton.isHidden = true
            progressView.animationDuration = 0.2
            progressView.rotationDuration = 2
            pauseButton.addTarget(self, action: #selector(pauseButtonTapped), for: .touchUpInside)
            // Weak registration, lives for the cell's whole lifetime — the relay prunes
            // deallocated observers itself, so no removal on reuse/teardown is needed.
            AttachmentSharpThumbnailRelay.default.add(self)
            AttachmentTransferStatusRelay.default.add(self)

            typealias AID = SceytChatUIKit.AccessibilityIdentifiers.ChannelInfo.MediaCell
            accessibilityIdentifier = AID.root
            imageView.accessibilityIdentifier = AID.image
            pauseButton.accessibilityIdentifier = AID.downloadButton
        }

        override open func setupLayout() {
            super.setupLayout()
            contentView.addSubview(imageView)
            contentView.addSubview(progressView)
            contentView.addSubview(pauseButton)
            imageView.pin(to: contentView)
            progressView.resize(anchors: [.width(44), .height(44)])
            progressView.pin(to: contentView, anchors: [.centerX, .centerY])
            pauseButton.pin(to: progressView)
        }

        override open func setupAppearance() {
            super.setupAppearance()
            setupProgressAppearance()
        }

        open func setupProgressAppearance() {
            progressView.progressColor = overlayLoaderAppearance.progressColor
            progressView.trackColor = overlayLoaderAppearance.trackColor
            progressView.backgroundColor = overlayLoaderAppearance.backgroundColor
            progressView.parentAppearance = overlayLoaderAppearance
            pauseButton.setImage(overlayLoaderAppearance.cancelIcon, for: .normal)
        }

        /// Backstop delivery of a pause/resume/failure raised on another screen — most often
        /// the chat thread's own pause button (see `AttachmentTransferStatusRelay`). This grid
        /// otherwise learns a status only through its own `AttachmentDTO` observer or a rebind.
        open func attachmentTransferStatusDidChange(
            _ attachment: ChatMessage.Attachment,
            status: ChatMessage.Attachment.TransferStatus
        ) {
            guard let data,
                  AttachmentTransfer.transferIdentity(of: data.attachment)
                    == AttachmentTransfer.transferIdentity(of: attachment)
            else { return }
            // The relay is keyed by the stored object, which several attachments can share
            // (one file sent in several messages). A failed or paused transfer of one of them
            // says nothing about a sibling whose bytes are already on disk: taking it would put
            // the download button over a finished image (and stamp the failure on its status).
            // Not for an unsent upload, whose local file is the upload's source.
            switch status {
            case .failedDownloading, .pauseDownloading, .failedUploading, .pauseUploading:
                if !data.attachment.isPendingUpload,
                   attachmentTransfer.filePath(attachment: data.attachment) != nil {
                    return
                }
            default:
                break
            }
            data.attachment.status = status
            lastAttachmentTransferProgress = nil
            update(status: status)
            switch status {
            case .pending, .downloading, .uploading:
                let live = data.ownerMessage.flatMap {
                    self.attachmentTransfer.currentProgressPercent(message: $0, attachment: data.attachment)
                }
                setProgress(live.map(Self.inFlightProgress) ?? 0.0001)
            default:
                break
            }
        }

        /// Repaints when a sharp, file-backed thumbnail lands for the bound attachment —
        /// most visibly the downloaded "pvw" poster, which arrives long after the
        /// cell was bound and while the video itself is still transferring (or not
        /// transferring at all).
        ///
        /// The bound layout's `onLoadThumbnail` cannot carry this on its own: the grid
        /// builds its own `AttachmentLayout` instances, so a load that lands on the chat
        /// list's instance for the same attachment never reaches here, and the slot is a
        /// single overwritable one that cell reuse can leave pointing at a dead owner.
        /// The relay is keyed by attachment identity and per-cell, so neither applies.
        open func attachmentSharpThumbnailDidLoad(_ attachment: ChatMessage.Attachment, image: UIImage) {
            guard let layout = data,
                  layout.type == .image || layout.type == .video,
                  layout.attachment == attachment
            else { return }
            // One attachment is consumed at several design sizes, each with its own
            // size-keyed thumbnail file, and the relay carries no size. A sibling
            // consumer's load is "sharp" for ITS size yet can be far too small for this
            // grid — accepting it would repaint at that resolution AND lock the layout
            // file-backed, so no reload path restores the right thumbnail. Compare max
            // sides (aspect-safe) with the same tolerance the message cell uses.
            //
            guard meetsCellResolution(image, for: layout) else { return }
            // Heal the layout first so later rebinds see the sharp, file-backed state.
            // setFileBackedThumbnail re-posts to the relay; on that nested entry the
            // state check below is already satisfied, so the recursion terminates.
            if !(layout.isThumbnailLoadedFromFile && layout.thumbnail === image) {
                layout.setFileBackedThumbnail(image)
            }
            // setFileBackedThumbnail normally paints via the layout's onLoadThumbnail
            // fire, but that slot may be owned by a dead cell — paint directly so the
            // screen never depends on slot ownership.
            setThumbnail(image)
        }

        open func update(status: ChatMessage.Attachment.TransferStatus) {
            progressView.isHiddenProgress = false
            progressView.rotateZ = true
            switch status {
            case .pending:
                break
            case .downloading, .uploading:
                pauseButton.setImage(overlayLoaderAppearance.cancelIcon, for: .normal)
            case .pauseUploading:
                // A paused upload keeps its task (and its last cached percent) alive so
                // it can resume — the ring must stop and offer "tap to upload" instead
                // of spinning on as if bytes were still going out.
                resetProgressFloor()
                setProgress(0.0001)
                progressView.isHiddenProgress = true
                pauseButton.setImage(overlayLoaderAppearance.uploadIcon ?? .attachmentUpload, for: .normal)
            case .pauseDownloading, .failedDownloading:
                resetProgressFloor()
                setProgress(0.0001)
                progressView.isHiddenProgress = true
                pauseButton.setImage(overlayLoaderAppearance.downloadIcon, for: .normal)
            case .done:
                if progressView.progress > 0 {
                    setProgress(1)
                } else {
                    setProgress(0)
                }
                // Not left to the ring's hide: the ring can be gone before the data session
                // hands the file over, and a hide-time reload then finds no file yet.
                refreshThumbnailFromFile()
            default:
                break
            }
        }

        /// Brings the image up to the downloaded file. Reloads the layout's thumbnail
        /// when it is still a placeholder; when the layout is already sharp, paints it
        /// directly — its `onLoadThumbnail` paint may have gone to a slot this cell no
        /// longer owns.
        ///
        /// "Already sharp" means file-backed AND big enough for this cell: a video shows its
        /// small downloaded "pvw" poster (file-backed) before the video itself is
        /// local, and once it is, a grid-sized frame can replace it.
        open func refreshThumbnailFromFile() {
            guard let data, data.type == .image || data.type == .video else { return }
            if data.isThumbnailLoadedFromFile,
               let thumbnail = data.thumbnail,
               // A reload that already ran is final: a source without size metadata and
               // smaller than the cell never meets the size, and must not reload forever.
               meetsCellResolution(thumbnail, for: data) || reloadedThumbnailAttachment == data.attachment {
                setThumbnail(thumbnail)
                return
            }
            reloadThumbnailFromFile(for: data.attachment)
        }

        /// The attachment whose thumbnail `reloadThumbnailFromFile` last applied.
        private var reloadedThumbnailAttachment: ChatMessage.Attachment?

        /// Delayed retries of a reload whose thumbnail couldn't be made yet.
        public static let thumbnailReloadRetryCount = 3

        /// Builds the thumbnail from the downloaded file and applies it to the bound layout,
        /// the same way `MessageCell.AttachmentView.reloadThumbnailFromFile` does for chat
        /// bubbles: one reload per attachment and size at a time (`ThumbnailReloadGate` —
        /// every bind, re-sync and ring hide of a done cell asks for one), a few delayed
        /// retries because a video's frame extraction can fail on a just-downloaded file,
        /// and `.utility` QoS since it can be a full-size decode and encode.
        open func reloadThumbnailFromFile(for attachment: ChatMessage.Attachment, retriesLeft: Int = thumbnailReloadRetryCount) {
            guard let data else { return }
            let preferred = data.thumbnailSize
            let gateKey = ThumbnailReloadGate.key(attachment: attachment, size: preferred)
            let isRetry = retriesLeft < Self.thumbnailReloadRetryCount
            if !isRetry, !ThumbnailReloadGate.begin(gateKey) { return }
            DispatchQueue.global(qos: .utility).async { [weak self, transfer = attachmentTransfer] in
                guard let path = transfer.thumbnailFile(for: attachment, preferred: preferred),
                      let image = UIImage(contentsOfFile: path)
                else {
                    guard retriesLeft > 0 else {
                        ThumbnailReloadGate.end(gateKey, succeeded: false)
                        return
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                        guard let self, let layout = self.data, layout.attachment == attachment else {
                            ThumbnailReloadGate.cancel(gateKey)
                            return
                        }
                        self.reloadThumbnailFromFile(for: attachment, retriesLeft: retriesLeft - 1)
                    }
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    ThumbnailReloadGate.end(gateKey, succeeded: true)
                    guard let self, let layout = self.data, layout.attachment == attachment else { return }
                    // Never downgrades a bigger file-backed thumbnail, and paints through the
                    // slot and the relay; paint directly too — the slot may not be ours.
                    layout.setFileBackedThumbnail(image)
                    self.reloadedThumbnailAttachment = attachment
                    if let thumbnail = layout.thumbnail {
                        self.setThumbnail(thumbnail)
                    }
                }
            }
        }

        /// The pixel size (longer side) a thumbnail needs to look sharp in this cell. From the
        /// cell's own bounds rather than `layout.thumbnailSize`, whose units are not consistent
        /// across consumers: the chat list fills it in points, `MediaCollectionView` in device
        /// pixels. Capped at the source's own size — a source smaller than the cell can't
        /// produce a bigger thumbnail, and one at full source resolution is as sharp as it gets.
        open func requiredThumbnailPxMaxSide(for layout: MessageLayoutModel.AttachmentLayout) -> CGFloat {
            let displayScale = traitCollection.displayScale > 0 ? traitCollection.displayScale : UIScreen.main.scale
            var required = max(bounds.width, bounds.height) * displayScale
            if let metadata = layout.attachment.imageDecodedMetadata,
               metadata.width > 0, metadata.height > 0 {
                required = min(required, CGFloat(max(metadata.width, metadata.height)))
            }
            return required
        }

        /// Whether `image` is big enough for this cell, with the same 10% tolerance the
        /// message cell uses. Compares longer sides, so it is aspect-safe.
        open func meetsCellResolution(_ image: UIImage, for layout: MessageLayoutModel.AttachmentLayout) -> Bool {
            max(image.size.width, image.size.height) * image.scale >= requiredThumbnailPxMaxSide(for: layout) * 0.9
        }

        open func setProgress(_ progress: CGFloat) {
            if progress > 0, progress < 1, !progressView.isHidden, progress < highestRenderedProgress {
                // A stale value: the ring already drew more for this transfer.
                return
            }
            highestRenderedProgress = progress <= 0 ? 0 : max(highestRenderedProgress, progress)
            guard progressView.progress != progress else {
                if progress > 0, progress < 1, progressView.isHidden {
                    // A stale hide-animation completion beat the show that set this
                    // same value (the cell was rebound during the hide's ~0.3s
                    // animation window). The value is already right — only the
                    // visibility was clobbered. Re-show.
                    showProgressView()
                }
                return
            }
            if progress > 0, progress < 1, progressView.isHidden {
                // Coming back on screen (a reused cell, a scrolled-in transfer): the ring
                // still holds the previous binding's value, and animating from it plays a
                // fill from 0 — read as the transfer starting over.
                progressView.setProgressWithoutAnimation(progress)
            } else {
                progressView.progress = progress
            }
            if progress >= 1, !progressView.isHidden, !progressView.isHiddenProgress, !isHidingProgressView {
                // Fill-through: let the stroke reach 100% (it animates over
                // `animationDuration`), hold it briefly, then shrink out. Hiding on the same
                // tick hid the ring mid-fill, so it vanished from 90%.
                pendingHideWorkItem?.cancel()
                let item = DispatchWorkItem { [weak self] in
                    guard let self, self.progressView.progress >= 1 else { return }
                    self.pendingHideWorkItem = nil
                    self.hideProgressView()
                }
                pendingHideWorkItem = item
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + progressView.animationDuration + Self.completedRingHold,
                    execute: item
                )
            } else if progress <= 0 || progress >= 1 {
                hideProgressView()
            } else {
                showProgressView()
            }
        }

        open func showProgressView() {
            cancelHideAnimation()
            progressView.isHidden = false
            pauseButton.isHidden = false
        }

        /// Invalidates any running shrink-out and puts the overlay back at full size. The
        /// in-flight animation has to be removed, not just overridden — see
        /// `resetTransformCancellingAnimations`; otherwise a ring shown (or a cell reused)
        /// mid-shrink draws its background disc oversized and shrinks it back.
        private func cancelHideAnimation() {
            pendingHideWorkItem?.cancel()
            pendingHideWorkItem = nil
            overlayGeneration &+= 1
            isHidingProgressView = false
            progressView.resetTransformCancellingAnimations()
            pauseButton.resetTransformCancellingAnimations()
        }

        open func hideProgressView() {
            // One shrink at a time: a second one has nothing left to animate, so its
            // completion fired at once and reset the transform under the first.
            guard !progressView.isHidden, !isHidingProgressView else { return }
            overlayGeneration &+= 1
            let generation = overlayGeneration
            isHidingProgressView = true
            UIView.animate(withDuration: progressView.animationDuration + 0.1) { [weak self] in
                self?.progressView.transform = .init(scaleX: 0.01, y: 0.01)
                self?.pauseButton.transform = .init(scaleX: 0.01, y: 0.01)
            } completion: { [weak self] _ in
                guard let self else { return }
                guard generation == self.overlayGeneration else {
                    // The ring was shown again (or the cell rebound) while this hide
                    // was animating; `cancelHideAnimation` already restored it.
                    return
                }
                self.isHidingProgressView = false
                self.progressView.isHidden = true
                self.pauseButton.isHidden = true
                self.resetProgressFloor()
                self.progressView.transform = .identity
                self.pauseButton.transform = .identity
                self.refreshThumbnailFromFile()
            }
        }

        open func setProgressHandler() {
            guard let data = data,
                  let message = data.ownerMessage
            else { return }
            // Resolved here, on main: the tick block below runs on the transfer's thread and
            // must not be the first to touch the lazy property.
            let ticks = progressTicks
            self.attachmentTransfer
                .progress(
                    message: message,
                    attachment: data.attachment,
                    objectIdKey: AttachmentTransfer.observerKey(for: self, prefix: "infoattachment")
                ) { progress in
                    // Called on the transfer's thread for every tick (every 0.5% of every
                    // running download). Only the newest tick matters, so the ticks are folded
                    // into one main-queue update per pass instead of one hop each — dozens of
                    // downloads ticking at once used to flood main during a scroll.
                    ticks.submit(progress)
                } completion: { [weak self, transfer = attachmentTransfer] done in
                    guard self?.data?.attachment.id == data.attachment.id else { return }
                    if done.error == nil {
                        transfer.removeProgressObserver(
                            message: done.message,
                            attachment: done.attachment,
                            objectIdKey: self.map { AttachmentTransfer.observerKey(for: $0, prefix: "infoattachment") } ?? ""
                        )
                    }
                    data.update(attachment: done.attachment)
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.progressTicks.discardPending()
                        // The transfer is over — its last progress tick must not keep
                        // driving the pause button's status resolution.
                        self.lastAttachmentTransferProgress = nil
                        if let thumbnail = self.data?.thumbnail {
                            self.setThumbnail(thumbnail)
                        }
                        if done.error == nil {
                            // The bytes just landed on disk, so a reload that failed before
                            // (nothing to derive a thumbnail from yet) can now succeed: lift
                            // its cooldown instead of leaving the image blurred for it. The
                            // `.done` update below reloads.
                            ThumbnailReloadGate.invalidate(attachment: done.attachment)
                        }
                        self.update(status: done.attachment.status)
                    }
                }
        }

        override open func prepareForReuse() {
            super.prepareForReuse()
            progressTicks.discardPending()
            // Invalidate any in-flight hide animation of the previous binding so its
            // completion can't hide the next binding's overlay (or load the wrong
            // thumbnail), and drop its shrink so the next binding starts at full size.
            cancelHideAnimation()
            if let message = data?.ownerMessage, let attachment = data?.attachment {
                self.attachmentTransfer.removeProgressObserver(
                    message: message,
                    attachment: attachment,
                    objectIdKey: AttachmentTransfer.observerKey(for: self, prefix: "infoattachment")
                )
            }
            lastAttachmentTransferProgress = nil
            progressView.isHidden = true
            pauseButton.isHidden = true
            progressView.isHiddenProgress = false
            progressView.setProgressWithoutAnimation(0)
            resetProgressFloor()
        }

        deinit {
            if let message = data?.ownerMessage, let attachment = data?.attachment {
                self.attachmentTransfer.removeProgressObserver(
                    message: message,
                    attachment: attachment,
                    objectIdKey: AttachmentTransfer.observerKey(for: self, prefix: "infoattachment")
                )
            }
        }

        @objc open func pauseButtonTapped() {
            onPauseAction?()
        }
    }
}
