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
                // Rebind in place when the attachment set is unchanged (the common
                // reconfigure: transfer status edge, delivery tick, reaction, edit).
                // Tearing the views down would kill the in-flight progress ring and its
                // completion animation mid-frame — reconfigures are applied inside
                // CATransaction.setDisableActions(true), so the teardown is what makes
                // transfers appear to finish with no animation at all.
                if let existing = rebindableAttachmentViews(for: data.attachments) {
                    for (av, layout) in zip(existing, data.attachments) {
                        bind(layout: layout, to: av)
                    }
                } else {
                    subviews.forEach {
                        $0.removeFromSuperview()
                    }
                    addAttachmentViews(layouts: data.attachments)
                }
            }
        }

        /// The current subviews, if and only if they can represent `layouts` by rebinding:
        /// same count and, pairwise, the same type and thumbnail size (the height constraint
        /// was pinned to it at creation).
        ///
        /// A *file* view may be rebound to a different attachment — a file row paints every
        /// pixel it owns from the new layout, so recycling it is safe, and it saves rebuilding
        /// six subviews and twelve constraints for every file cell the user scrolls past.
        /// Media and voice views still require attachment identity: they carry playback and
        /// preview state that a rebind does not fully reset.
        private func rebindableAttachmentViews(for layouts: [MessageLayoutModel.AttachmentLayout]) -> [AttachmentView]? {
            let views = subviews.compactMap { $0 as? AttachmentView }
            guard views.count == subviews.count,
                  views.count == layouts.count
            else { return nil }
            for (av, layout) in zip(views, layouts) {
                guard let bound = av.data, bound.type == layout.type
                else { return nil }
                if layout.type == .file, av is AttachmentFileView {
                    // Only the height was baked into a constraint; a file row's width comes
                    // from the stack view (and so from the bubble, which the cell re-lays out
                    // for every binding), so it does not have to match to recycle the view.
                    guard bound.thumbnailSize.height == layout.thumbnailSize.height
                    else { return nil }
                } else {
                    guard bound.attachment == layout.attachment,
                          bound.thumbnailSize == layout.thumbnailSize
                    else { return nil }
                }
            }
            return views
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
                bind(layout: layout, to: av)
            }
        }

        private func bind(layout: MessageLayoutModel.AttachmentLayout, to av: AttachmentView) {
            // Recycled onto a different attachment: drop the previous one's transfer visuals
            // so its progress ring (or a pending shrink-out) cannot bleed into this binding.
            if let bound = av.data, bound.attachment != layout.attachment {
                av.prepareForRebind()
            }
            av.data = layout
            av.setProgressHandler()
            switch av.renderedTransferStatus(for: layout.transferStatus) {
            case .pending, .uploading, .downloading:
                if let progress = fileProvider.currentProgressPercent(message: data.message, attachment: layout.attachment) {
                    av.setProgress(.init(message: data.message, attachment: layout.attachment, progress: progress))
                } else if fileProvider.filePath(attachment: layout.attachment) == nil {
                    // Through the AttachmentProgress overload so the "0 B / 12.4 MB"
                    // label is seeded too. The CGFloat overload only moves the ring,
                    // which left the byte count blank until the next tick — and blank
                    // forever when the transfer had already delivered its last one.
                    av.setProgress(.init(message: data.message, attachment: layout.attachment, progress: 0.0001))
                } else if fileProvider.taskFor(message: data.message, attachment: layout.attachment) != nil {
                    // An upload always has a local file, so the `filePath == nil` fallback
                    // above only ever fires for downloads. Bind a live upload to the same
                    // floor, otherwise a cell that binds before the first progress event —
                    // a fresh send, or reuse while the task is still preparing/queued —
                    // shows a bare thumbnail with no ring.
                    av.setProgress(0.0001)
                }
            case .pauseUploading, .failedUploading:
                break
            case .pauseDownloading, .failedDownloading:
                break
            case .done:
                // Completion is resolved by update(status:) inside `av.data`'s didSet:
                // a surviving ring fills to 100% and shrinks out. Forcing 0 here would
                // cut that animation short on in-place rebinds (on fresh views it was
                // a no-op anyway — progress is already 0).
                break
            }
        }
        
        private func openPreview(sourceView: UIImageView) {
            // Create preview item directly from the audio attachment
            guard let attachment = self.data.message.attachments?.first else {
                return
            }
            let previewItem = PreviewItem.attachment(attachment)

            // Create the media previewer carousel
            let imageCarousel = Components.mediaPreviewerCarouselViewController.init(
                sourceView: sourceView,
                previewDataSource: SingleItemPreviewDataSource(item: previewItem),
                initialIndex: 0,
                viewOnce: true,
                messageText: nil)

            // Present the previewer
            if let viewController = window?.rootViewController {
                UIApplication.shared.sendAction(#selector(resignFirstResponder), to: nil, from: nil, for: nil)
                let presentFrom = viewController.presentedViewController ?? viewController
                presentFrom.present(Components.mediaPreviewerNavigationController.init(imageCarousel), animated: true)
            }
        }
        
        @objc
        private func onTapPlay() {
            guard let audioView = (subviews.first(where: { $0 is AttachmentAudioView }) as? AttachmentAudioView) else { return }

            guard previewer?()?.canShowPreviewer() ?? true else { return }

            // Check if we're already inside a previewer
            let isInsidePreviewer = sequence(first: window?.rootViewController, next: { $0?.presentedViewController })
                .contains { $0 is MediaPreviewerNavigationController }

            // Check if this is a view_once audio message
            let isViewOnce = audioView.data?.ownerMessage?.isViewOnceMessage ?? false

            if isViewOnce && !isInsidePreviewer {
                // Open the previewer for view_once audio (only if not already in previewer)
                guard let attachment = audioView.data?.attachment,
                      attachment.status == .done // Only open if downloaded
                else { return }

                // Trigger the openedViewOnce action
                onAction?(.openedViewOnce(attachment))

                self.openPreview(sourceView: UIImageView())
            } else {
                // Regular playback for non-view_once audio or when already in previewer
                audioView.play(onPlayed: { url in
                    onAction?(.playedAudio(url))
                })
            }
        }
        
        @objc
        private func tapAction(_ sender: UITapGestureRecognizer) {
            let point = sender.location(in: self)
            if let index = subviews.firstIndex(where: { $0.frame.contains(point) }) {
                // Check if we're already inside a previewer
                let isInsidePreviewer = sequence(first: window?.rootViewController, next: { $0?.presentedViewController })
                    .contains { $0 is MediaPreviewerNavigationController }

                // Check if tapped view is an audio attachment with view_once message
                if let audioView = subviews[index] as? AttachmentAudioView,
                   let attachment = audioView.data?.attachment,
                   audioView.data?.ownerMessage?.isViewOnceMessage == true,
                   attachment.status == .done,
                   !isInsidePreviewer,
                   previewer?()?.canShowPreviewer() ?? true {
                    // Handle view_once audio: open previewer (only if not already in previewer)
                    onAction?(.openedViewOnce(attachment))

                    let sourceView = UIImageView()
                    sourceView.frame = audioView.bounds

                    openPreview(sourceView: sourceView)
                } else {
                    // Default behavior for other attachments or when already in previewer
                    onAction?(.userSelect(index))
                }
            }
        }
        
        @objc
        open func pauseAction(_ sender: Button) {
            guard let av = sender.superview as? AttachmentView
            else { return }
            let status = av.renderedTransferStatus(
                for: av.lastAttachmentTransferProgress?.attachment.status ?? av.data.transferStatus
            )
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
        case openedViewOnce(ChatMessage.Attachment)
    }
}
