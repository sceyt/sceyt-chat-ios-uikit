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
    open class AttachmentView: View {
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
        
        override open func setup() {
            super.setup()
            
            progressView.isHidden = true
            progressLabel.isHidden = true
            pauseButton.isHidden = true
            progressView.animationDuration = 0.2
            progressView.rotationDuration = 2
            progressLabel.iconView.isHidden = true
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
                item: PreviewItem.attachment(data.attachment)
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
            progressView.progress = progress
            if progress <= 0 || progress >= 1 {
                hideProgressView()
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
                self.progressView.isHidden = true
                self.pauseButton.isHidden = true
                self.progressView.transform = .identity
                self.pauseButton.transform = .identity
                self.didHideProgressView()
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
        
        open func setProgressHandler() {
            guard let data = data,
                  let message = data.ownerMessage
            else { return }
            var needsToUpdateStatus = false
            fileProvider
                .progress(
                    message: message,
                    attachment: data.attachment,
                    objectIdKey: data.attachment.description
                ) { [weak self] progress in
                    guard let self, self.data == data
                    else {
                        logger.verbose("[Attachment] progress self is nil thumbnail load from filePath \(data.attachment.description)")
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
                } completion: {[weak self] done in
                    guard self?.data == data
                    else {
                        logger.verbose("[Attachment] completion self is nil \(data.attachment.description)")
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
                        self?.update(status: done.attachment.status)
                        self?.setCompletion(done)
                    }
                    RunLoop.main.perform { [weak self] in
                        self?.setupPreviewer()
                    }
                }
        }
    }
}
