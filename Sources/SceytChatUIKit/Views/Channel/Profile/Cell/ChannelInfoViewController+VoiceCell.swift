//
//  ChannelInfoViewController+VoiceCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import Combine

extension ChannelInfoViewController {
    open class VoiceCell: CollectionViewCell {
        typealias Layouts = ChannelInfoViewController.VoiceCollectionView.Layouts
        
        let event = PassthroughSubject<Event, Never>()
        
        open lazy var playButton = Button()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFill)
        
        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
        
        open lazy var dateLabel = UILabel()
            .withoutAutoresizingMask
        
        open lazy var durationLabel = UILabel()
            .withoutAutoresizingMask
        
        open lazy var downloadButton = UIButton()
            .withoutAutoresizingMask
        
        open lazy var progressView = Components.circularProgressView
            .init()
            .withoutAutoresizingMask
        
        public private(set) var isPlaying = false {
            didSet {
                playButton.setImage(isPlaying ? appearance.pauseIcon : appearance.playIcon, for: .normal)
                isPlaying ? play() : pause()
            }
        }
        
        override open func setup() {
            super.setup()
            
            titleLabel.lineBreakMode = .byTruncatingMiddle
            playButton.addTarget(self, action: #selector(playButtonAction(_:)), for: .touchUpInside)
            
            downloadButton.layer.masksToBounds = true
            downloadButton.addTarget(self, action: #selector(onDownloadTapped), for: .touchUpInside)
            
            progressView.isUserInteractionEnabled = false
            progressView.animationDuration = 0.2
            progressView.rotationDuration = 2
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            titleLabel.font = appearance.userNameLabelAppearance.font
            titleLabel.textColor = appearance.userNameLabelAppearance.foregroundColor
            
            dateLabel.font = appearance.subtitleLabelAppearance.font
            dateLabel.textColor = appearance.subtitleLabelAppearance.foregroundColor
            
            durationLabel.font = appearance.durationLabelAppearance.font
            durationLabel.textColor = appearance.durationLabelAppearance.foregroundColor
            
            downloadButton.backgroundColor = appearance.loaderAppearance.backgroundColor
            downloadButton.layer.cornerRadius = Layouts.iconSize / 2
            
            progressView.progressColor = appearance.loaderAppearance.progressColor
            progressView.trackColor = appearance.loaderAppearance.trackColor
            progressView.contentInsets = .init(top: 4, left: 4, bottom: 4, right: 4)
            
            playButton.setImage(isPlaying ? appearance.pauseIcon : appearance.playIcon, for: .normal)
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            contentView.addSubview(playButton)
            contentView.addSubview(titleLabel)
            contentView.addSubview(dateLabel)
            contentView.addSubview(durationLabel)
            contentView.addSubview(downloadButton)
            
            downloadButton.addSubview(progressView)
            
            playButton.topAnchor.pin(to: contentView.topAnchor, constant: Layouts.verticalPadding)
            playButton.leadingAnchor.pin(to: contentView.leadingAnchor, constant: Layouts.horizontalPadding)
            playButton.widthAnchor.pin(constant: Layouts.iconSize)
            playButton.heightAnchor.pin(to: playButton.widthAnchor)
            playButton.bottomAnchor.pin(to: contentView.bottomAnchor, constant: -Layouts.verticalPadding)
            
            titleLabel.leadingAnchor.pin(to: playButton.trailingAnchor, constant: Layouts.horizontalPadding)
            titleLabel.topAnchor.pin(to: playButton.topAnchor)
            titleLabel.trailingAnchor.pin(lessThanOrEqualTo: contentView.trailingAnchor, constant: -Layouts.horizontalPadding)
            titleLabel.heightAnchor.pin(greaterThanOrEqualToConstant: 22)
            
            dateLabel.leadingAnchor.pin(to: titleLabel.leadingAnchor)
            dateLabel.topAnchor.pin(to: titleLabel.bottomAnchor)
            dateLabel.heightAnchor.pin(greaterThanOrEqualToConstant: 16)
            
            durationLabel.trailingAnchor.pin(to: contentView.trailingAnchor, constant: -Layouts.horizontalPadding)
            durationLabel.centerYAnchor.pin(to: playButton.centerYAnchor)
            durationLabel.heightAnchor.pin(greaterThanOrEqualToConstant: 16)
            
            downloadButton.pin(to: playButton)
            progressView.pin(to: downloadButton)
        }
        
        open var data: MessageLayoutModel.AttachmentLayout? {
            didSet {
                guard let attachment = data?.attachment
                else { return }
                
                if let user = attachment.user {
                    titleLabel.text = appearance.userNameFormatter.format(user)
                } else {
                    titleLabel.text = attachment.userId
                }
                
                dateLabel.text = appearance.subtitleFormatter.format(attachment)
                
                reset()
                if let fileUrl = attachment.fileUrl, fileUrl == SimpleSinglePlayer.url, SimpleSinglePlayer.isPlaying {
                    isPlaying = true
                    SimpleSinglePlayer.set(durationBlock: setDuration, stopBlock: stop)
                } else {
                    isPlaying = false
                }
                
                updateStatus()
            }
        }
        
        open func setDuration(duration: TimeInterval, progress: Double) {
            durationLabel.text = appearance.durationFormatter.format(duration)
        }
        
        @objc
        open func playButtonAction(_ sender: Button) {
            isPlaying.toggle()
        }
        
        open func play() {
            guard let fileUrl = data?.attachment.fileUrl else { return }
            SimpleSinglePlayer.play(fileUrl, durationBlock: setDuration, stopBlock: stop)
        }
        
        open func pause() {
            SimpleSinglePlayer.pause()
        }
        
        open func stop() {
            isPlaying = false
            reset()
        }
        
        open func reset() {
            if let duration = data?.attachment.voiceDecodedMetadata?.duration, duration > 0 {
                durationLabel.text = appearance.durationFormatter.format(TimeInterval(duration))
            } else {
                durationLabel.text = ""
            }
        }
        
        open func updateStatus() {
            guard let attachment = data?.attachment,
                  let message = data?.ownerMessage
            else { return }
            
            downloadButton.isHidden = false
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
            playButton.isHidden = !downloadButton.isHidden
        }
        
        open func showDownloadButton(_ show: Bool, animated: Bool = false) {
            if show {
                downloadButton.isHidden = false
            } else {
                if animated {
                    UIView.performWithoutAnimation {
                        downloadButton.transform = .identity
                        downloadButton.isHidden = false
                        layoutIfNeeded()
                    }
                    UIView.animate(withDuration: progressView.animationDuration + 0.1) { [weak self] in
                        guard let self else { return }
                        self.downloadButton.transform = .init(scaleX: 0.01, y: 0.01)
                    } completion: { [weak self] completed in
                        guard let self else { return }
                        if completed {
                            self.downloadButton.isHidden = true
                            self.playButton.isHidden = !self.downloadButton.isHidden
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

public extension ChannelInfoViewController.VoiceCell {
    enum Event {
        case pause(MessageLayoutModel.AttachmentLayout), resume(MessageLayoutModel.AttachmentLayout)
    }
}
