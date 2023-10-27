//
//  AttachmentVideoViewCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit
import Photos

extension MessageCell {
    open class AttachmentVideoView: AttachmentView {
        
        open lazy var playButton = UIImageView()
            .withoutAutoresizingMask
            
        open lazy var timeLabel = Components.timeLabel
            .init()
            .withoutAutoresizingMask
        
        private var progressViewHeightConstraint: NSLayoutConstraint?
        
        override open func setup() {
            super.setup()
            playButton.image = Images.videoPlayerPlay
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            progressView.contentInsets = .init(top: 4, left: 4, bottom: 4, right: 4)
            progressView.backgroundColor = .black.withAlphaComponent(0.3)
            
            timeLabel.backgroundColor = appearance.videoTimeBackgroundColor
            timeLabel.textLabel.font = appearance.videoTimeTextFont
            timeLabel.textLabel.textColor = appearance.videoTimeTextColor
        }

        override open func setupLayout() {
            super.setupLayout()
            addSubview(imageView)
            addSubview(playButton)
            addSubview(timeLabel)
            addSubview(progressView)
            addSubview(progressLabel)
            addSubview(pauseButton)
            imageView.pin(to: self)
            playButton.pin(to: imageView, anchors: [.centerX(), .centerY()])
            timeLabel.pin(to: imageView, anchors: [.top(8), .leading(8)])
            progressViewHeightConstraint = progressView.heightAnchor.pin(constant: 56)
            progressView.widthAnchor.pin(to: progressView.heightAnchor)
            playButton.heightAnchor.pin(to: progressView.heightAnchor)
            playButton.widthAnchor.pin(to: progressView.widthAnchor)
            progressView.pin(to: imageView, anchors: [.centerX(), .centerY()])
            pauseButton.pin(to: progressView)
            progressLabel.centerXAnchor.pin(to: centerXAnchor)
            progressLabel.topAnchor.pin(to: progressView.bottomAnchor, constant: 4)
            progressLabel.bottomAnchor.pin(lessThanOrEqualTo: bottomAnchor, constant: -2)
        }
        
        override open var data: MessageLayoutModel.AttachmentLayout! {
            didSet {
                setupPreviewer()
                let duration = data.mediaDuration
                if duration > 0 {
                    timeLabel.text = Formatters.videoAssetDuration.format(duration)
                }
                if let filePath = data.attachment.filePath,
                   filePath.hasPrefix("/local/"),
                   let asset = PHAsset.fetchAssets(withLocalIdentifiers: [filePath.substring(fromIndex: 7)], options: .none).firstObject {
                    PHImageManager.default().requestImage(for: asset, targetSize: imageView.frame.size, contentMode: .aspectFill, options: .none) { [weak self] image, _ in
                        guard let self else { return }
                        imageView.image = image ?? data.thumbnail
                    }
                } else {
                    imageView.image = data.thumbnail
                    data.onLoadThumbnail = { [weak self] thumbnail in
                        guard let self else {
                            log.verbose("[Attachment] onLoadThumbnail self is nil")
                            return
                        }
                        self.imageView.image = thumbnail
                    }
                }
            }
        }
        
        override open func setProgress(_ progress: CGFloat) {
            guard progressView.progress != progress
            else { return }
            if progress > 0, progress < 1 {
                playButton.isHidden = true
            }
            super.setProgress(progress)
        }
        
        open override func willHideProgressView() {
            super.willHideProgressView()
            UIView.performWithoutAnimation {
                playButton.transform = .init(scaleX: 0.01, y: 0.01)
                playButton.isHidden = false
            }
            UIView.animate(withDuration: progressView.animationDuration + 0.1) {
                self.playButton.transform = .init(scaleX: 1, y: 1)
            } completion: { _ in
                self.playButton.transform = .identity
            }
        }
        
        open override func didHideProgressView() {
            super.didHideProgressView()
            playButton.isHidden = false
        }
        
        open override func layoutSubviews() {
            super.layoutSubviews()
            progressViewHeightConstraint?.constant = min(56, bounds.height / 2)
        }
    }
}
