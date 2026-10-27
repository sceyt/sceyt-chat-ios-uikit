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
            data.attachment.status = status
            lastAttachmentTransferProgress = nil
            update(status: status)
            switch status {
            case .pending, .downloading, .uploading:
                let live = data.ownerMessage.flatMap {
                    fileProvider.currentProgressPercent(message: $0, attachment: data.attachment)
                }
                setProgress(live ?? 0.0001)
            default:
                break
            }
        }

        /// Repaints when a sharp, file-backed thumbnail lands for the bound attachment —
        /// most visibly the downloaded "video_thumb" poster, which arrives long after the
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
            if imageView.image !== image {
                imageView.image = image
            }
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
                setProgress(0.0001)
                progressView.isHiddenProgress = true
                pauseButton.setImage(overlayLoaderAppearance.uploadIcon ?? .attachmentUpload, for: .normal)
            case .pauseDownloading, .failedDownloading:
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
        /// small downloaded "video_thumb" poster (file-backed) before the video itself is
        /// local, and once it is, a grid-sized frame can replace it.
        open func refreshThumbnailFromFile() {
            guard let data, data.type == .image || data.type == .video else { return }
            if data.isThumbnailLoadedFromFile,
               let thumbnail = data.thumbnail,
               // A reload that already ran is final: a source without size metadata and
               // smaller than the cell never meets the size, and must not reload forever.
               meetsCellResolution(thumbnail, for: data) || reloadedThumbnailAttachment == data.attachment {
                if imageView.image !== thumbnail {
                    imageView.image = thumbnail
                }
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
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let path = fileProvider.thumbnailFile(for: attachment, preferred: preferred),
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
                    if let thumbnail = layout.thumbnail, self.imageView.image !== thumbnail {
                        self.imageView.image = thumbnail
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
            progressView.progress = progress
            if progress <= 0 || progress >= 1 {
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
                self.progressView.transform = .identity
                self.pauseButton.transform = .identity
                self.refreshThumbnailFromFile()
            }
        }

        open func setProgressHandler() {
            guard let data = data,
                  let message = data.ownerMessage
            else { return }
            fileProvider
                .progress(
                    message: message,
                    attachment: data.attachment,
                    objectIdKey: AttachmentTransfer.observerKey(for: self, prefix: "infoattachment")
                ) { [weak self] progress in
                    guard let self, self.data?.attachment.id == data.attachment.id else { return }
                    DispatchQueue.main.async { [weak self] in
                        self?.setProgress(progress.progress)
                        self?.lastAttachmentTransferProgress = progress
                    }
                } completion: { [weak self] done in
                    guard self?.data?.attachment.id == data.attachment.id else { return }
                    if done.error == nil {
                        fileProvider.removeProgressObserver(
                            message: done.message,
                            attachment: done.attachment,
                            objectIdKey: self.map { AttachmentTransfer.observerKey(for: $0, prefix: "infoattachment") } ?? ""
                        )
                    }
                    data.update(attachment: done.attachment)
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        // The transfer is over — its last progress tick must not keep
                        // driving the pause button's status resolution.
                        self.lastAttachmentTransferProgress = nil
                        if let thumbnail = self.data?.thumbnail {
                            self.imageView.image = thumbnail
                        }
                        self.update(status: done.attachment.status)
                    }
                }
        }

        override open func prepareForReuse() {
            super.prepareForReuse()
            // Invalidate any in-flight hide animation of the previous binding so its
            // completion can't hide the next binding's overlay (or load the wrong
            // thumbnail), and drop its shrink so the next binding starts at full size.
            cancelHideAnimation()
            if let message = data?.ownerMessage, let attachment = data?.attachment {
                fileProvider.removeProgressObserver(
                    message: message,
                    attachment: attachment,
                    objectIdKey: AttachmentTransfer.observerKey(for: self, prefix: "infoattachment")
                )
            }
            lastAttachmentTransferProgress = nil
            progressView.isHidden = true
            pauseButton.isHidden = true
            progressView.isHiddenProgress = false
            progressView.progress = 0
        }

        deinit {
            if let message = data?.ownerMessage, let attachment = data?.attachment {
                fileProvider.removeProgressObserver(
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
