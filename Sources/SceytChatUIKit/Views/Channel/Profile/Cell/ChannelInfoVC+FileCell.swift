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
    open class FileCell: CollectionViewCell {
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
        
        public lazy var appearance = Components.channelInfoFileCollectionView.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        override open func setup() {
            super.setup()
            
            selectedBackgroundView = UIView()
            iconView.image = .file
            titleLabel.lineBreakMode = .byTruncatingMiddle
            iconView.clipsToBounds = true
            
            downloadButton.layer.masksToBounds = true
            downloadButton.addTarget(self, action: #selector(onDownloadTapped), for: .touchUpInside)
            
            progressView.isUserInteractionEnabled = false
            progressView.animationDuration = 0.2
            progressView.rotationDuration = 2
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            selectedBackgroundView?.backgroundColor = UIColor.surface2
            
            iconView.layer.cornerRadius = Components.channelInfoFileCollectionView.Layouts.cornerRadius
            
            titleLabel.font = appearance.titleFont
            titleLabel.textColor = appearance.titleTextColor
            
            detailLabel.font = appearance.detailFont
            detailLabel.textColor = appearance.detailTextColor
            
            downloadButton.backgroundColor = appearance.downloadBackgroundColor
            downloadButton.layer.cornerRadius = Components.channelInfoFileCollectionView.Layouts.iconSize / 2
            
            progressView.progressColor = appearance.progressColor
            progressView.trackColor = appearance.trackColor
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
        
        open var data: MessageLayoutModel.AttachmentLayout? {
            didSet {
                guard let data = data
                else { return }
                let attachment = data.attachment
                iconView.image = data.thumbnail
                titleLabel.text = attachment.name ?? attachment.originUrl.lastPathComponent
                detailLabel.text = SceytChatUIKit.shared.formatters.fileSizeFormatter.format(UInt64(attachment.uploadedFileSize)) + " • " + SceytChatUIKit.shared.formatters.channelInfoMediaDateFormatter.format(attachment.createdAt)
                
                updateStatus()
            }
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
                downloadButton.setImage(.downloadStop, for: [])
                progressView.isHidden = false
                progressView.progress = fileProvider.currentProgressPercent(message: message, attachment: attachment) ?? attachment.transferProgress
                setProgressHandler()
            case .pending, .pauseDownloading, .failedDownloading:
                showDownloadButton(true)
                downloadButton.setImage(.downloadStart, for: [])
                progressView.isHidden = true
            }
        }
        
        open func showDownloadButton(_ show: Bool, animated: Bool = false) {
            if show {
                downloadButton.isHidden = false
            } else {
                if animated {
                    UIView.performWithoutAnimation {
                        layoutIfNeeded()
                        downloadButton.transform = .identity
                        downloadButton.isHidden = false
                    }
                    UIView.animate(withDuration: progressView.animationDuration + 0.1) { [weak self] in
                        guard let self else { return }
                        self.downloadButton.transform = .init(scaleX: 0.01, y: 0.01)
                    } completion: { [weak self] completed in
                        guard let self else { return }
                        if completed {
                            self.downloadButton.isHidden = true
                        }
                    }
                } else {
                    downloadButton.isHidden = true
                }
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
                    attachment: attachment
                ) { [weak self] progress in
                    guard let self, self.data == data
                    else {
                        logger.verbose("[Attachment] progress self is nil thumbnail load from filePath \(attachment.description)")
                        return
                    }
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.progressView.progress = progress.progress
                    }
                } completion: { result in
                    logger.debug("[Attachment] completion \(result.attachment.status)")
                    fileProvider.removeProgressObserver(message: result.message, attachment: result.attachment)
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
            
            if let message = data?.ownerMessage, let attachment = data?.attachment {
                fileProvider.removeProgressObserver(
                    message: message,
                    attachment: attachment)
            }
        }
    }
}

public extension ChannelInfoViewController.FileCell {
    enum Event {
        case pause(MessageLayoutModel.AttachmentLayout), resume(MessageLayoutModel.AttachmentLayout)
    }
}
