//
//  MessageCell+AttachmentStackView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit

extension MessageCell {
    open class AttachmentStackView: View {
        
        public lazy var appearance = Components.messageCell.appearance {
            didSet {
                setupAppearance()
            }
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
        
        open override func setup() {
            super.setup()
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
            addGestureRecognizer(tap)
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
//            alignment = .center
//            distribution = .fillProportionally
//            axis = .vertical
//            spacing = 4
        }
        
        open func addImageView(layout: MessageLayoutModel.AttachmentLayout) -> AttachmentImageView {
            let v = Components.messageCellAttachmentImageView.init()
                .withoutAutoresizingMask
            v.appearance = appearance
            addSubview(v)
            v.pin(to: self)
            v.heightAnchor.pin(constant: layout.thumbnailSize.height)
            v.widthAnchor.pin(to: widthAnchor)
            v.pauseButton.addTarget(self, action: #selector(pauseAction(_:)), for: .touchUpInside)
            return v
        }
        
        open func addVideoView(layout: MessageLayoutModel.AttachmentLayout) -> AttachmentVideoView {
            let v = Components.messageCellAttachmentVideoView.init()
                .withoutAutoresizingMask
            v.appearance = appearance
            addSubview(v)
            v.pin(to: self)
            v.heightAnchor.pin(constant: layout.thumbnailSize.height)
            v.widthAnchor.pin(to: widthAnchor)
            v.pauseButton.addTarget(self, action: #selector(pauseAction(_:)), for: .touchUpInside)
            return v
        }
        
        open func addFileView(layout: MessageLayoutModel.AttachmentLayout) -> AttachmentFileView {
            let v = Components.messageCellAttachmentFileView.init()
                .withoutAutoresizingMask
            v.appearance = appearance
            addSubview(v)
            v.pin(to: self)
            v.heightAnchor.pin(constant: layout.thumbnailSize.height)
            v.widthAnchor.pin(to: widthAnchor)
            v.pauseButton.addTarget(self, action: #selector(pauseAction(_:)), for: .touchUpInside)
            return v
        }
        
        open func addAudioView(layout: MessageLayoutModel.AttachmentLayout) -> AttachmentAudioView {
            let v = Components.messageCellAttachmentAudioView.init()
                .withoutAutoresizingMask
            v.appearance = appearance
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
                onAction?(.playedAudio(url))
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
        case playedAudio(URL)
    }
}
