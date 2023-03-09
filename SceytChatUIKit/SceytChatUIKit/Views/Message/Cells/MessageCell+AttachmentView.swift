//
//  MessageCell+AttachmentView.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import SceytChat
import UIKit

extension MessageCell {
    open class AttachmentStackView: UIStackView, Configurable {
        override public init(frame: CGRect) {
            super.init(frame: frame)
            setup()
            setupAppearance()
        }
        
        public required init(coder: NSCoder) {
            super.init(coder: coder)
            setup()
            setupAppearance()
        }
        
        deinit {
//            loader?.remove(messageId: layoutModel.message.id)
        }

//        open var loader: AttachmentLoader!
        open var layoutModel: MessageLayoutModel!
        
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
            
            NotificationCenter.default
                .addObserver(
                    self,
                    selector: #selector(onTapPlayVoice),
                    name: .init("onTapPlayVoice"),
                    object: nil
                )
        }
        
        open func setupLayout() {}
        
        open func setupAppearance() {
            alignment = .center
            distribution = .fillProportionally
            axis = .vertical
            spacing = 4
        }
        
        open func setupDone() {}
        
        open func addImageView() -> AttachmentImageView {
            let v = AttachmentImageView()
                .withoutAutoresizingMask
            addArrangedSubview(v)
            v.heightAnchor.pin(constant: Components.messageLayoutModel.defaults.imageAttachmentSize.height)
            v.widthAnchor.pin(to: widthAnchor)
            v.pauseButton.addTarget(self, action: #selector(pauseAction(_:)), for: .touchUpInside)
            return v
        }
        
        open func addVideoView() -> AttachmentVideoView {
            let v = AttachmentVideoView()
                .withoutAutoresizingMask
            addArrangedSubview(v)
            v.heightAnchor.pin(constant: Components.messageLayoutModel.defaults.imageAttachmentSize.height)
            v.widthAnchor.pin(to: widthAnchor)
            v.pauseButton.addTarget(self, action: #selector(pauseAction(_:)), for: .touchUpInside)
            return v
        }
        
        open func addFileView() -> AttachmentFileView {
            let v = AttachmentFileView()
                .withoutAutoresizingMask
            addArrangedSubview(v)
            v.heightAnchor.pin(constant: Components.messageLayoutModel.defaults.fileAttachmentSize.height)
            v.widthAnchor.pin(to: widthAnchor)
            v.pauseButton.addTarget(self, action: #selector(pauseAction(_:)), for: .touchUpInside)
            return v
        }
        
        open func addAudioView() -> AttachmentAudioView {
            let v = AttachmentAudioView()
                .withoutAutoresizingMask
            addArrangedSubview(v)
            v.heightAnchor.pin(constant: Components.messageLayoutModel.defaults.audioAttachmentSize.height)
            v.widthAnchor.pin(to: widthAnchor)
            v.playPauseButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTapPlay)))
            v.pauseButton.addTarget(self, action: #selector(pauseAction(_:)), for: .touchUpInside)
            return v
        }
        
        open var previewer: AttachmentPreviewDataSource? {
            didSet {
                arrangedSubviews.forEach {
                    if let v = $0 as? AttachmentView {
                        v.previewer = previewer
                    }
                }
            }
        }
        
        open var data: MessageLayoutModel! {
            didSet {
                layoutModel = data
                guard let data = data,
                      let attachments = data.sortedAttachments,
                      attachments.count > 0
                else {
                    removeArrangedSubviews()
                    return
                }
                let needsToDownloadAttachments = attachments.filter {
                    $0.status != .pauseDownloading &&
                        $0.status != .failedDownloading &&
                        $0.status != .done
                }
                fileProvider
                    .downloadMessageAttachments(
                        message: data.message,
                        attachments: needsToDownloadAttachments
                    )
                
//                if arrangedSubviews.count == attachments.count {
//                    var needsToRecreate = false
//                    for c in zip(arrangedSubviews, attachments) {
//                        if let av = c.0 as? AttachmentView,
//                           av.data.localId == c.1.localId,
//                            av.data.filePath == c.1.filePath {
//                            av.update(status: c.1.status)
//                            setProgressHandler(attachment: c.1, view: av)
//                        } else {
//                            needsToRecreate = true
//                            break
//                        }
//                    }
//                    guard needsToRecreate else { return }
//                }
                removeArrangedSubviews()
                attachments.forEach { attachment in
                    var av: AttachmentView?
                    switch attachment.type {
                    case "image":
                        av = addImageView()
                    case "video":
                        av = addVideoView()
                    case "voice":
                        av = addAudioView()
                    default:
                        av = addFileView()
                    }
                    guard let av else { return }
                    av.data = attachment
                    switch attachment.status {
                    case .pending, .uploading, .downloading:
                        av.setProgress(0.0001)
                    case .pauseUploading, .failedUploading:
                        break
                    case .pauseDownloading, .failedDownloading:
                        break
                    case .done:
                        av.setProgress(0)
                    }
                    setProgressHandler(attachment: attachment, view: av)
                }
            }
        }
        
//        private var observers = [NSKeyValueObservation]()
        
//        open var data: MessageLayoutModel! {
//            didSet {
//                guard let data = data
//                else { return }
//                guard layoutModel?.message.id != data.message.id else { return }
//                layoutModel = data
//                loader = AttachmentLoader.default
//                removeArrangedSubviews()
//                guard let attachments = data.sortedAttachments, attachments.count > 0 else { return }
//                let map = attachments.reduce(into: [ChatMessage.Attachment: AttachmentView]()) {(d, attch) in
//                    var av: AttachmentView?
//                    let fileUrl = loader.fileLocalStorageUrl(attachment: attch, message: data.message)
//                    if attch.url.isImage {
//                        let v = addImageView()
//                        if let fileUrl = fileUrl {
//                            v.data = fileUrl
//                        } else {
//                            v.data = attch.url
//                        }
//                        av = v
//                    } else if attch.url.isVideo {
//                        let v = addVideoView()
//                        if let fileUrl = fileUrl {
//                            v.data = fileUrl
//                        } else {
//                            v.data = attch.url
//                        }
//                        av = v
//                    } else {
//                        let v = addFileView()
//                        v.data = (
//                            fileName(attachment: attch),
//                            Formatters.fileSize.format(fileSize(attachment: attch))
//                        )
//                        av = v
//                    }
//                    d[attch] = av
//                }
//                let items = loader.add(attachments: attachments, message: data.message)
//                    .compactMap { $0.progress == 1 ? nil : $0}
//                observers = items.map {
//                    $0.observe(\.progress, options: [.initial, .new, .old]) {[weak self] item, _  in
//                        guard let self = self, let v = map[item.attachment] else { return }
//                        func _bind() {
//                            v.setProgress(item.progress)
//                            if item.progress == 1, let url = item.fileUrl {
//                                switch v {
//                                case is AttachmentImageView:
//                                    (v as? AttachmentImageView)
//                                        .map { $0.data = url }
//                                case is AttachmentVideoView:
//                                    (v as? AttachmentVideoView)
//                                        .map { $0.data = url }
//                                default:
//                                    (v as? AttachmentFileView)
//                                        .map { $0.data = (
//                                            self.fileName(attachment: item.attachment),
//                                            Formatters.fileSize.format(self.fileSize(attachment: item.attachment))
//                                        )
//                                        }
//                                }
//                            }
//                        }
//                        if Thread.isMainThread {
//                            _bind()
//                        } else {
//                            DispatchQueue.main.async {
//                                _bind()
//                            }
//                        }
//                    }
//                }
//            }
//        }
        
        private func setProgressHandler(
            attachment: ChatMessage.Attachment,
            view: AttachmentView
        ) {
            fileProvider
                .progress(
                    message: data.message,
                    attachment: attachment
                ) { [weak view] progress in
                    view?.setProgress(progress.progress)
                }
        }
        
        @objc
        private func tapAction(_ sender: UITapGestureRecognizer) {
            let point = sender.location(in: self)
            if let index = arrangedSubviews.firstIndex(where: { $0.frame.contains(point) }) {
                onAction?(.userSelect(index))
            }
        }
        
        @objc
        private func onTapPlay() {
            guard let audioView = (arrangedSubviews.first(where: { $0 is AttachmentAudioView }) as? AttachmentAudioView)
            else { return }
            NotificationCenter.default.post(.init(name: .init("onTapPlayVoice"), object: audioView.data.originUrl))
            audioView.play()
        }
        
        @objc
        func onTapPlayVoice(_ n: Notification) {
            guard let audioView = (arrangedSubviews.first(where: { $0 is AttachmentAudioView }) as? AttachmentAudioView)
            else { return }
            
            if n.object as? URL != audioView.data.originUrl {
                audioView.stop()
            }
        }
        
        @objc
        open func pauseAction(_ sender: Button) {
            guard let av = sender.superview as? AttachmentView,
                  let index = arrangedSubviews.firstIndex(of: av)
            else { return }
            switch av.data.status {
            case .pauseUploading, .failedUploading, .pauseDownloading, .failedDownloading:
                onAction?(.resumeTransfer(index))
                let status = fileProvider.transferStatus(message: layoutModel.message, attachment: av.data) ?? av.data.status
                av.update(status: status)
            case .uploading, .downloading:
                onAction?(.pauseTransfer(index))
            default:
                break
            }
        }
    }
}

public extension MessageCell.AttachmentStackView {
    enum Action {
        case userSelect(Int)
        case pauseTransfer(Int)
        case resumeTransfer(Int)
        case play(URL)
    }
}

extension MessageCell {
    open class AttachmentView: View {
        open lazy var imageView = ImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFill)
        
        open lazy var pauseButton = Button()
            .withoutAutoresizingMask
        
        open lazy var progressView = Components.circularProgressView
            .init()
            .withoutAutoresizingMask
        
        override open func setup() {
            super.setup()
            pauseButton.setImage(.attachmentTransferPause, for: .normal)
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            progressView.progressColor = progressView.appearance.progressColor
            progressView.trackColor = progressView.appearance.trackColor
            progressView.animationDuration = 0.2
            progressView.rotationDuration = 2
            progressView.isHidden = true
            pauseButton.isHidden = true
        }
        
        open func setProgress(_ progress: CGFloat) {
            progressView.isHidden = progress <= 0 || progress >= 1
            progressView.progress = progress
            pauseButton.isHidden = progressView.isHidden
        }
        
        open func update(status: ChatMessage.Attachment.TransferStatus) {
            progressView.isHiddenProgress = false
            progressView.rotateZ = true
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
                pauseButton.setImage(.attachmentUpload, for: .normal)
            case .pauseDownloading, .failedDownloading:
                setProgress(0.0001)
                progressView.isHiddenProgress = true
                pauseButton.setImage(.attachmentDownload, for: .normal)
            case .done:
                setProgress(0)
            }
        }
        
        open var data: ChatMessage.Attachment! {
            didSet {
                guard let data else { return }
                update(status: data.status)
            }
        }
        
        open var previewer: AttachmentPreviewDataSource?
    }
}
