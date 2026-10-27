//
//  ChannelInfoViewController+FileCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import Combine

extension ChannelInfoViewController {
    open class FileCell: CollectionViewCell, AttachmentTransferStatusObserver {
        let event = PassthroughSubject<Event, Never>()
        
        open lazy var iconView = UIImageView()
            .contentMode(.scaleAspectFill)
        
        open lazy var titleLabel = UILabel()
        
        open lazy var detailLabel = UILabel()
        
        open lazy var downloadButton = UIButton()
            .withoutAutoresizingMask
        
        open lazy var progressView = Components.circularProgressView
            .init()
            .withoutAutoresizingMask
        
        open lazy var textVStack = UIStackView(column: [titleLabel, detailLabel])
        
        open lazy var contentHStack = {
            $0.setCustomSpacing(4, after: textVStack)
            return $0.withoutAutoresizingMask
        }(UIStackView(row: [iconView, textVStack, downloadButton], spacing: Components.channelInfoFileCollectionView.Layouts.horizontalPadding, alignment: .center))
        
        override open func setup() {
            super.setup()
            AttachmentTransferStatusRelay.default.add(self)
            
            selectedBackgroundView = UIView()
            titleLabel.lineBreakMode = .byTruncatingMiddle
            iconView.clipsToBounds = true
            
            downloadButton.layer.masksToBounds = true
            downloadButton.addTarget(self, action: #selector(onDownloadTapped), for: .touchUpInside)

            progressView.isUserInteractionEnabled = false
            progressView.animationDuration = 0.2
            progressView.rotationDuration = 2

            typealias AID = SceytChatUIKit.AccessibilityIdentifiers.ChannelInfo.FileCell
            accessibilityIdentifier = AID.root
            iconView.accessibilityIdentifier = AID.icon
            titleLabel.accessibilityIdentifier = AID.name
            detailLabel.accessibilityIdentifier = AID.detail
            downloadButton.accessibilityIdentifier = AID.downloadButton
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            selectedBackgroundView?.backgroundColor = appearance.selectedBackgroundColor
            
            iconView.layer.cornerRadius = Components.channelInfoFileCollectionView.Layouts.cornerRadius
            
            titleLabel.font = appearance.fileNameLabelAppearance.font
            titleLabel.textColor = appearance.fileNameLabelAppearance.foregroundColor
            
            detailLabel.font = appearance.subtitleLabelAppearance.font
            detailLabel.textColor = appearance.subtitleLabelAppearance.foregroundColor
            
            downloadButton.backgroundColor = appearance.loaderAppearance.backgroundColor
            downloadButton.layer.cornerRadius = Components.channelInfoFileCollectionView.Layouts.iconSize / 2
            
            progressView.progressColor = appearance.loaderAppearance.progressColor
            progressView.trackColor = appearance.loaderAppearance.trackColor
            progressView.contentInsets = .init(top: 4, left: 4, bottom: 4, right: 4)
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            contentView.addSubview(contentHStack)
            
            downloadButton.addSubview(progressView)
            
            contentHStack.pin(to: contentView, anchors: [.leading(Components.channelInfoFileCollectionView.Layouts.horizontalPadding), .trailing(-Components.channelInfoFileCollectionView.Layouts.horizontalPadding),
                                                         .top(Components.channelInfoFileCollectionView.Layouts.verticalPadding), .bottom(-Components.channelInfoFileCollectionView.Layouts.verticalPadding)])
            
            iconView.widthAnchor.pin(constant: Components.channelInfoFileCollectionView.Layouts.iconSize)
            iconView.heightAnchor.pin(constant: Components.channelInfoFileCollectionView.Layouts.iconSize)
            
            titleLabel.heightAnchor.pin(greaterThanOrEqualToConstant: 22)
            detailLabel.heightAnchor.pin(greaterThanOrEqualToConstant: 16)
            
            downloadButton.widthAnchor.pin(constant: Components.channelInfoFileCollectionView.Layouts.iconSize)
            downloadButton.heightAnchor.pin(to: downloadButton.widthAnchor)
            
            progressView.pin(to: downloadButton)
        }
        
        /// How long the row's state changes animate: the download button shrinking out while
        /// the text widens into its place, and the icon and text crossfading to new content.
        public static var transitionDuration: TimeInterval = 0.3

        /// The transfer identity this row last rendered. A bind of the same attachment is a state
        /// change of the row on screen (the grid re-binds a visible cell in place when its
        /// attachment updates) and animates; a bind of a different one is a reuse and doesn't.
        private var renderedIdentity: String?

        open var data: MessageLayoutModel.AttachmentLayout? {
            didSet {
                guard let data = data
                else { return }
                let attachment = data.attachment
                let identity = AttachmentTransfer.transferIdentity(of: attachment)
                let animated = identity == renderedIdentity && window != nil
                renderedIdentity = identity
                // The layout's thumbnail once it has one: on an in-place re-bind the row already
                // shows it, and the provider's generic icon would flash back over it.
                setIcon(data.thumbnail ?? appearance.iconProvider.provideVisual(for: attachment), animated: animated)
                setText(appearance.fileNameFormatter.format(attachment), on: titleLabel, animated: animated)
                setText(appearance.subtitleFormatter.format(attachment), on: detailLabel, animated: animated)

                renderStatus(animated: animated)
            }
        }

        /// Shows `image`, crossfading when the row is already showing an image — the blurred
        /// placeholder giving way to the downloaded file's thumbnail.
        open func setIcon(_ image: UIImage?, animated: Bool) {
            guard iconView.image !== image else { return }
            guard animated, window != nil, iconView.image != nil else {
                iconView.image = image
                return
            }
            UIView.transition(with: iconView, duration: Self.transitionDuration, options: [.transitionCrossDissolve, .allowUserInteraction]) {
                self.iconView.image = image
            }
        }

        open func setText(_ text: String?, on label: UILabel, animated: Bool) {
            guard label.text != text else { return }
            guard animated, window != nil else {
                label.text = text
                return
            }
            UIView.transition(with: label, duration: Self.transitionDuration, options: [.transitionCrossDissolve, .allowUserInteraction]) {
                label.text = text
            }
        }
        
        /// Backstop delivery of a pause/resume/failure raised on another screen (see
        /// `AttachmentTransferStatusRelay`). `updateStatus()` otherwise runs only from `data`'s
        /// `didSet` and from this cell's own download button, so a pause issued in the chat
        /// thread leaves this row rendering the state it was bound with.
        open func attachmentTransferStatusDidChange(
            _ attachment: ChatMessage.Attachment,
            status: ChatMessage.Attachment.TransferStatus
        ) {
            guard let data,
                  AttachmentTransfer.transferIdentity(of: data.attachment)
                    == AttachmentTransfer.transferIdentity(of: attachment)
            else { return }
            data.attachment.status = status
            renderStatus(animated: window != nil)
        }

        /// True while `updateStatus()` renders a state change of the row on screen, so the
        /// changes it makes animate — including a subclass's own `showDownloadButton(_:)` calls
        /// from an overridden `updateStatus()`.
        public private(set) var isAnimatingStatusChange = false

        /// Runs `updateStatus()` — the override point — with `isAnimatingStatusChange` set.
        private func renderStatus(animated: Bool) {
            isAnimatingStatusChange = animated
            defer { isAnimatingStatusChange = false }
            updateStatus()
        }

        open func updateStatus() {
            guard let attachment = data?.attachment,
                  let message = data?.ownerMessage
            else { return }
            
            switch attachment.status {
            case .uploading, .pauseUploading, .failedUploading, .done:
                showDownloadButton(false)
            case .downloading:
                showDownloadButton(true)
                downloadButton.setImage(appearance.loaderAppearance.cancelIcon, for: [])
                progressView.isHidden = false
                progressView.progress = fileProvider.currentProgressPercent(message: message, attachment: attachment) ?? attachment.transferProgress
                setProgressHandler()
            case .pending, .pauseDownloading, .failedDownloading:
                showDownloadButton(true)
                downloadButton.setImage(appearance.loaderAppearance.downloadIcon, for: [])
                progressView.isHidden = true
            }
        }
        
        /// Shows or hides the download button. Hiding it animated shrinks it out while the
        /// stack view collapses its slot in the same animation, so the title and subtitle widen
        /// smoothly into the freed space instead of jumping once the button is gone. `animated`
        /// defaults to whether a state change is being rendered (`isAnimatingStatusChange`).
        open func showDownloadButton(_ show: Bool, animated: Bool? = nil) {
            let animated = animated ?? isAnimatingStatusChange
            // Ends any shrink in flight: a button left at its shrunk scale would keep its slot
            // and draw nothing — the "row keeps empty space" leftover.
            downloadButton.layer.removeAllAnimations()
            downloadButton.transform = .identity
            downloadButton.alpha = 1
            guard !show else {
                downloadButton.isHidden = false
                return
            }
            guard animated, window != nil, !downloadButton.isHidden else {
                downloadButton.isHidden = true
                return
            }
            contentHStack.layoutIfNeeded()
            UIView.animate(
                withDuration: Self.transitionDuration,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                self.downloadButton.transform = .init(scaleX: 0.01, y: 0.01)
                self.downloadButton.alpha = 0
                self.downloadButton.isHidden = true
                self.contentHStack.layoutIfNeeded()
            } completion: { _ in
                self.downloadButton.transform = .identity
                self.downloadButton.alpha = 1
            }
        }
        
        open func setProgressHandler() {
            guard let data = self.data,
                  let message = data.ownerMessage
            else { return }
            let attachment = data.attachment
            progressView.rotateZ = true
            fileProvider
                .progress(
                    message: message,
                    attachment: attachment,
                    objectIdKey: AttachmentTransfer.observerKey(for: self, prefix: "infofile")
                ) { [weak self] progress in
                    guard let self, self.data == data
                    else {
                        return
                    }
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.progressView.progress = progress.progress
                    }
                } completion: { [weak self] result in
                    logger.debug("[Attachment] completion \(result.attachment.status)")
                    fileProvider.removeProgressObserver(
                        message: result.message,
                        attachment: result.attachment,
                        objectIdKey: self.map { AttachmentTransfer.observerKey(for: $0, prefix: "infofile") } ?? ""
                    )
                }
        }
        
        @objc
        open func onDownloadTapped() {
            guard let layout = data else { return }
            
            switch layout.attachment.status {
            case .uploading, .pauseUploading, .failedUploading, .done:
                break
            case .downloading:
                event.send(.pause(layout))
            case .pending, .pauseDownloading, .failedDownloading:
                event.send(.resume(layout))
            }
        }
        
        open override func prepareForReuse() {
            super.prepareForReuse()
            // The next bind is a new row as far as the user can tell, even for the same file.
            renderedIdentity = nil

            if let message = data?.ownerMessage, let attachment = data?.attachment {
                fileProvider.removeProgressObserver(
                    message: message,
                    attachment: attachment,
                    objectIdKey: AttachmentTransfer.observerKey(for: self, prefix: "infofile"))
            }
        }

        deinit {
            // prepareForReuse only runs on reuse (scrolling); cells visible at screen
            // dismiss are deallocated without it, so remove the observer here too.
            if let message = data?.ownerMessage, let attachment = data?.attachment {
                fileProvider.removeProgressObserver(
                    message: message,
                    attachment: attachment,
                    objectIdKey: AttachmentTransfer.observerKey(for: self, prefix: "infofile"))
            }
        }
    }
}

public extension ChannelInfoViewController.FileCell {
    enum Event {
        case pause(MessageLayoutModel.AttachmentLayout)
        case resume(MessageLayoutModel.AttachmentLayout)
    }
}
