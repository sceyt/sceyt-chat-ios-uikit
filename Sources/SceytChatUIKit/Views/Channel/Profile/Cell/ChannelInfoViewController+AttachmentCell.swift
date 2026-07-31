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
    open class AttachmentCell: CollectionViewCell {

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

        open var overlayLoaderAppearance = CircularProgressView.Appearance(
            reference: CircularProgressView.appearance,
            progressColor: .onPrimary,
            trackColor: .clear,
            backgroundColor: .overlayBackground2,
            cancelIcon: .attachmentTransferPause,
            downloadIcon: .attachmentDownload
        ) {
            didSet { setupProgressAppearance() }
        }

        open var onPauseAction: (() -> Void)?
        
        open var data: MessageLayoutModel.AttachmentLayout!

        open var previewer: (() -> (any PreviewDataSource)?)?

        override open func setup() {
            super.setup()
            imageView.isUserInteractionEnabled = true
            imageView.clipsToBounds = true
            progressView.isHidden = true
            pauseButton.isHidden = true
            progressView.animationDuration = 0.2
            progressView.rotationDuration = 2
            pauseButton.addTarget(self, action: #selector(pauseButtonTapped), for: .touchUpInside)

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

        open func update(status: ChatMessage.Attachment.TransferStatus) {
            progressView.isHiddenProgress = false
            progressView.rotateZ = true
            switch status {
            case .pending:
                break
            case .downloading:
                pauseButton.setImage(overlayLoaderAppearance.cancelIcon, for: .normal)
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
            default:
                break
            }
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
            overlayGeneration &+= 1
            progressView.isHidden = false
            pauseButton.isHidden = false
        }

        open func hideProgressView() {
            guard !progressView.isHidden else { return }
            overlayGeneration &+= 1
            let generation = overlayGeneration
            UIView.animate(withDuration: progressView.animationDuration + 0.1) { [weak self] in
                self?.progressView.transform = .init(scaleX: 0.01, y: 0.01)
                self?.pauseButton.transform = .init(scaleX: 0.01, y: 0.01)
            } completion: { [weak self] _ in
                guard let self else { return }
                guard generation == self.overlayGeneration else {
                    // The ring was shown again (or the cell rebound) while this hide
                    // was animating — the hide no longer applies. Undo the shrink and
                    // leave the current binding's state alone.
                    self.progressView.transform = .identity
                    self.pauseButton.transform = .identity
                    return
                }
                self.progressView.isHidden = true
                self.pauseButton.isHidden = true
                self.progressView.transform = .identity
                self.pauseButton.transform = .identity
                self.data.loadThumbnail()
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
                    objectIdKey: data.attachment.description
                ) { [weak self] progress in
                    guard let self, self.data?.attachment.id == data.attachment.id else { return }
                    DispatchQueue.main.async { [weak self] in
                        self?.setProgress(progress.progress)
                        self?.lastAttachmentTransferProgress = progress
                    }
                } completion: { [weak self] done in
                    guard self?.data?.attachment.id == data.attachment.id else { return }
                    if done.error == nil {
                        fileProvider.removeProgressObserver(message: done.message, attachment: done.attachment)
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
            // thumbnail).
            overlayGeneration &+= 1
            if let message = data?.ownerMessage, let attachment = data?.attachment {
                fileProvider.removeProgressObserver(message: message, attachment: attachment)
            }
            lastAttachmentTransferProgress = nil
            progressView.isHidden = true
            pauseButton.isHidden = true
            progressView.isHiddenProgress = false
            progressView.progress = 0
        }

        deinit {
            if let message = data?.ownerMessage, let attachment = data?.attachment {
                fileProvider.removeProgressObserver(message: message, attachment: attachment)
            }
        }

        @objc open func pauseButtonTapped() {
            onPauseAction?()
        }
    }
}
