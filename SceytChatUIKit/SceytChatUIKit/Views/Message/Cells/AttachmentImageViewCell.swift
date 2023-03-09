//
//  AttachmentImageViewCell.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import SceytChat
import UIKit

extension MessageCell {
    open class AttachmentImageView: AttachmentView {
        override open func setupAppearance() {
            super.setupAppearance()
            imageView.clipsToBounds = true

            progressView.contentInsets = .init(top: 5, left: 5, bottom: 5, right: 5)
            progressView.backgroundColor = .black.withAlphaComponent(0.3)
            progressView.trackColor = .white
            progressView.progressColor = .kitBlue
        }

        override open func setupLayout() {
            super.setupLayout()
            addSubview(imageView)
            addSubview(progressView)
            addSubview(pauseButton)
            imageView.pin(to: self)
            progressView.resize(anchors: [.width(56), .height(56)])
            progressView.pin(to: imageView, anchors: [.centerX, .centerY])
            pauseButton.pin(to: progressView)
        }

        override open var data: ChatMessage.Attachment! {
            didSet {
                guard oldValue != data
                else { return }
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
                imageView.image = UIImage(contentsOfFile: path)
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
    }
}
