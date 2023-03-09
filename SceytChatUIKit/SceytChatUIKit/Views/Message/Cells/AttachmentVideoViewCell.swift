//
//  AttachmentVideoViewCell.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import SceytChat
import UIKit

extension MessageCell {
    open class AttachmentVideoView: AttachmentView {
        public lazy var appearance = MessageCell.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open lazy var playButton = UIImageView()
            .withoutAutoresizingMask
            
        open lazy var timeLabel = Components.timeLabel
            .init()
            .withoutAutoresizingMask

        override open func setup() {
            super.setup()
            playButton.image = Images.videoPlayerPlay
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            progressView.contentInsets = .init(top: 5, left: 5, bottom: 5, right: 5)
            progressView.backgroundColor = .black.withAlphaComponent(0.3)
            progressView.trackColor = .white
            progressView.progressColor = .kitBlue
            
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
            addSubview(pauseButton)
            imageView.pin(to: self)
            playButton.pin(to: imageView, anchors: [.centerX(), .centerY()])
            timeLabel.pin(to: imageView, anchors: [.top(8), .leading(8)])
            progressView.resize(anchors: [.width(56), .height(56)])
            progressView.pin(to: imageView, anchors: [.centerX(), .centerY()])
            pauseButton.pin(to: progressView)
        }
        
        override open var data: ChatMessage.Attachment! {
            didSet {
                guard oldValue != data
                else { return }
                if let duration = data.imageDecodedMetadata?.duration, duration > 0 {
                    timeLabel.text = Formatters.videoAssetDuration.format(TimeInterval(duration))
                }
                guard let path = fileProvider.thumbnailFile(for: data, preferred: Components.messageLayoutModel.defaults.imageAttachmentSize)
                else {
                    if let data = data.imageDecodedMetadata?.thumbnailData {
                        imageView.image = UIImage(data: data)
                    } else if let thumbnail = data.imageDecodedMetadata?.thumbnail,
                              let image = Components.imageBuilder.image(from: thumbnail)
                    {
                        imageView.image = image
                    } else {
                        imageView.image = nil
                    }
                    return
                }
                if let image = UIImage(contentsOfFile: path) {
                    imageView.image = image
                }
            }
        }
        
        override open var previewer: AttachmentPreviewDataSource? {
            didSet {
                imageView.imageView.setup(
                    previewer: previewer,
                    item: PreviewItem.attachment(data)
                )
            }
        }
        
        override open func setProgress(_ progress: CGFloat) {
            super.setProgress(progress)
            playButton.isHidden = !progressView.isHidden
        }
    }
}
