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
            guard progressView.progress != progress else { return }
            progressView.progress = progress
            if progress <= 0 || progress >= 1 {
                hideProgressView()
            } else {
                progressView.isHidden = false
                pauseButton.isHidden = false
            }
        }

        open func hideProgressView() {
            guard !progressView.isHidden else { return }
            UIView.animate(withDuration: progressView.animationDuration + 0.1) { [weak self] in
                self?.progressView.transform = .init(scaleX: 0.01, y: 0.01)
                self?.pauseButton.transform = .init(scaleX: 0.01, y: 0.01)
            } completion: { [weak self] _ in
                self?.progressView.isHidden = true
                self?.pauseButton.isHidden = true
                self?.progressView.transform = .identity
                self?.pauseButton.transform = .identity
                self?.data.loadThumbnail()
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
                        if let thumbnail = self.data?.thumbnail {
                            self.imageView.image = thumbnail
                        }
                        self.update(status: done.attachment.status)
                    }
                }
        }

        override open func prepareForReuse() {
            super.prepareForReuse()
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
