//
//  MessageCell+AttachmentView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit

extension MessageCell {
    open class AttachmentView: View, AttachmentSharpThumbnailObserver {
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
                update(status: data.attachment.status)
            }
        }
        
        open var previewer: (() -> AttachmentPreviewDataSource?)?
        
        /// Loads the on-disk thumbnail for `attachment` on a background queue and applies it to the
        /// visible cell's layout via `setFileBackedThumbnail`, keyed by attachment identity. This
        /// updates the model state (so later rebinds stay sharp) AND notifies the cell. Robust to
        /// the duplicate-`AttachmentLayout`-instance routing problem where the download completion /
        /// observer fan-out updates a different layout instance than the one bound to the visible
        /// cell, which would otherwise leave the cell on the blurry thumbHash placeholder.
        /// No-op for non image/video attachments (their imageView is an icon, not a photo).
        open func reloadThumbnailFromFile(for attachment: ChatMessage.Attachment, retriesLeft: Int = 2) {
            guard let data, data.type == .image || data.type == .video else { return }
            let preferred = data.thumbnailSize == .zero
                ? MessageLayoutModel.defaults.imageAttachmentSize
                : data.thumbnailSize
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
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
                        return
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                        guard let self, let layout = self.data, layout.attachment == attachment
                        else {
                            logger.verbose("[Attachment] reloadThumbnailFromFile retry dropped — view died or rebound \(attachment.description)")
                            return
                        }
                        self.reloadThumbnailFromFile(for: attachment, retriesLeft: retriesLeft - 1)
                    }
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self, let layout = self.data, layout.attachment == attachment
                    else {
                        logger.verbose("[Attachment] reloadThumbnailFromFile apply dropped — view died or rebound \(attachment.description)")
                        return
                    }
                    layout.setFileBackedThumbnail(image)
                }
            }
        }

        open func setProgressHandler() {
            guard let data = data,
                  let message = data.ownerMessage
            else { return }
            var needsToUpdateStatus = false
            fileProvider
                .progress(
                    message: message,
                    attachment: data.attachment,
                    objectIdKey: "messagecell." + data.attachment.description
                ) { [weak self, weak data] progress in
                    guard let self, let data, self.data == data
                    else {
                        logger.verbose("[Attachment] progress self is nil thumbnail load from filePath \(progress.attachment.description)")
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
                        fileProvider.removeProgressObserver(message: done.message, attachment: done.attachment)
                    } else {
                        needsToUpdateStatus = true
                    }
                    self?.data.update(attachment: done.attachment)
                    DispatchQueue.main.async {
                        if let thumbnail = self?.data?.thumbnail {
                            self?.imageView.image = thumbnail
                        }
                        self?.update(status: done.attachment.status)
                        self?.setCompletion(done)
                        if done.error == nil {
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
