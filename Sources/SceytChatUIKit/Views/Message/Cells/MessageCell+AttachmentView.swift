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
    open class AttachmentStackView: UIView, Configurable {
        
        override public init(frame: CGRect) {
            super.init(frame: frame)
            setup()
            setupAppearance()
        }
        
        public required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
            setupAppearance()
        }
        
        open var onAction: ((Action) -> Void)?
        
        open private(set) var attachments = [Attachment]()
        
        private var isConfigured = false
        
        override open func willMove(toSuperview newSuperview: UIView?) {
            super.willMove(toSuperview: newSuperview)
            guard !isConfigured, newSuperview != nil else { return }
            setupLayout()
            setupDone()
            isConfigured = true
        }
        
        open func setup() {
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
            addGestureRecognizer(tap)
        }
        
        open func setupLayout() {}
        
        open func setupAppearance() {
//            alignment = .center
//            distribution = .fillProportionally
//            axis = .vertical
//            spacing = 4
        }
        
        open func setupDone() {}
        
        open func addImageView(layout: MessageLayoutModel.AttachmentLayout) -> AttachmentImageView {
            let v = AttachmentImageView()
                .withoutAutoresizingMask
            addSubview(v)
            v.pin(to: self)
            v.heightAnchor.pin(constant: layout.thumbnailSize.height)
            v.widthAnchor.pin(to: widthAnchor)
            v.pauseButton.addTarget(self, action: #selector(pauseAction(_:)), for: .touchUpInside)
            return v
        }
        
        open func addVideoView(layout: MessageLayoutModel.AttachmentLayout) -> AttachmentVideoView {
            let v = AttachmentVideoView()
                .withoutAutoresizingMask
            addSubview(v)
            v.pin(to: self)
            v.heightAnchor.pin(constant: layout.thumbnailSize.height)
            v.widthAnchor.pin(to: widthAnchor)
            v.pauseButton.addTarget(self, action: #selector(pauseAction(_:)), for: .touchUpInside)
            return v
        }
        
        open func addFileView(layout: MessageLayoutModel.AttachmentLayout) -> AttachmentFileView {
            let v = AttachmentFileView()
                .withoutAutoresizingMask
            addSubview(v)
            v.pin(to: self)
            v.heightAnchor.pin(constant: layout.thumbnailSize.height)
            v.widthAnchor.pin(to: widthAnchor)
            v.pauseButton.addTarget(self, action: #selector(pauseAction(_:)), for: .touchUpInside)
            return v
        }
        
        open func addAudioView(layout: MessageLayoutModel.AttachmentLayout) -> AttachmentAudioView {
            let v = AttachmentAudioView()
                .withoutAutoresizingMask
            addSubview(v)
            v.pin(to: self)
            v.heightAnchor.pin(constant: layout.thumbnailSize.height)
            v.widthAnchor.pin(to: widthAnchor)
            v.playPauseButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTapPlay)))
            v.pauseButton.addTarget(self, action: #selector(pauseAction(_:)), for: .touchUpInside)
            return v
        }

        open var previewer: (() -> AttachmentPreviewDataSource?)?
        
        open var data: MessageLayoutModel! {
            didSet {
                guard let data = data,
                      !data.attachments.isEmpty
                else {
                    subviews.forEach {
                        $0.removeFromSuperview()
                    }
                    return
                }
                subviews.forEach {
                    $0.removeFromSuperview()
                }
                addAttachmentViews(layouts: data.attachments)
            }
        }
        
        private func addAttachmentViews(layouts: [MessageLayoutModel.AttachmentLayout]) {
            layouts.forEach { layout in
                var av: AttachmentView?
                switch layout.type {
                case .image:
                    av = addImageView(layout: layout)
                case .video:
                    av = addVideoView(layout: layout)
                case .voice:
                    av = addAudioView(layout: layout)
                default:
                    av = addFileView(layout: layout)
                }
                av?.previewer = { [weak self] in
                    self?.previewer?()
                }
                guard let av else { return }
                av.data = layout
                av.setProgressHandler()
                switch layout.transferStatus {
                case .pending, .uploading, .downloading:
                    if let progress = fileProvider.currentProgressPercent(message: data.message, attachment: layout.attachment) {
                        av.setProgress(.init(message: data.message, attachment: layout.attachment, progress: progress))
                    }
                case .pauseUploading, .failedUploading:
                    break
                case .pauseDownloading, .failedDownloading:
                    break
                case .done:
                    av.setProgress(0)
                }
            }
        }
        
        @objc
        private func tapAction(_ sender: UITapGestureRecognizer) {
            let point = sender.location(in: self)
            if let index = subviews.firstIndex(where: { $0.frame.contains(point) }) {
                onAction?(.userSelect(index))
            }
        }
        
        @objc
        private func onTapPlay() {
            guard let audioView = (subviews.first(where: { $0 is AttachmentAudioView }) as? AttachmentAudioView)
            else { return }
			audioView.play(onPlayed: { url in
				onAction?(.playAudio(url))
			})
        }
        
        @objc
        open func pauseAction(_ sender: Button) {
            guard let av = sender.superview as? AttachmentView
            else { return }
            let status = av.lastAttachmentTransferProgress?.attachment.status ?? av.data.transferStatus
            var message: ChatMessage {
                data.message
            }
            var attachment: ChatMessage.Attachment {
                av.data.attachment
            }
            switch status {
            case .pauseUploading, .failedUploading:
                av.update(status: .uploading)
                av.setProgressHandler()
                onAction?(.resumeTransfer(message, attachment))
            case .pauseDownloading, .failedDownloading:
                av.update(status: .downloading)
                av.setProgressHandler()
                onAction?(.resumeTransfer(message, attachment))
            case .uploading:
                av.update(status: .pauseUploading)
                av.setProgressHandler()
                onAction?(.pauseTransfer(message, attachment))
            case .downloading:
                av.update(status: .pauseDownloading)
                av.setProgressHandler()
                onAction?(.pauseTransfer(message, attachment))
            default:
                break
            }
        }
    }
}

public extension MessageCell.AttachmentStackView {
    enum Action {
        case userSelect(Int)
        case pauseTransfer(ChatMessage, ChatMessage.Attachment)
        case resumeTransfer(ChatMessage, ChatMessage.Attachment)
        case play(URL)
		case playAudio(URL)
    }
}

extension MessageCell {
    open class AttachmentView: View {
        public lazy var appearance = MessageCell.appearance {
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
            pauseButton.setImage(.attachmentTransferPause, for: .normal)
            progressView.isHidden = true
            progressLabel.isHidden = true
            pauseButton.isHidden = true
            progressView.animationDuration = 0.2
            progressView.rotationDuration = 2
            progressLabel.iconView.isHidden = true
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            progressView.progressColor = progressView.appearance.progressColor
            progressView.trackColor = progressView.appearance.trackColor
            progressLabel.backgroundColor = appearance.videoTimeBackgroundColor
            progressLabel.textLabel.font = appearance.videoTimeTextFont
            progressLabel.textLabel.textColor = appearance.videoTimeTextColor
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
                progressLabel.text = "\(Formatters.fileSize.format(downloaded)) / \(Formatters.fileSize.format(total))"
            }
            setProgress(progress.progress)
        }
        
        open func setCompletion(_ completion: AttachmentTransfer.AttachmentCompletion) {
            guard completion.error == nil
            else { return }
            let total = completion.attachment.uploadedFileSize
            if total > 0 {
                progressLabel.text = "\(Formatters.fileSize.format(total)) / \(Formatters.fileSize.format(total))"
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
                pauseButton.setImage(.attachmentTransferPause, for: .normal)
            case .downloading:
                pauseButton.setImage(.attachmentTransferPause, for: .normal)
            case .pauseUploading, .failedUploading:
                setProgress(0.0001)
                progressView.isHiddenProgress = true
                progressLabel.isHidden = true
                pauseButton.setImage(.attachmentUpload, for: .normal)
            case .pauseDownloading, .failedDownloading:
                setProgress(0.0001)
                progressView.isHiddenProgress = true
                progressLabel.isHidden = true
                pauseButton.setImage(.attachmentDownload, for: .normal)
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
