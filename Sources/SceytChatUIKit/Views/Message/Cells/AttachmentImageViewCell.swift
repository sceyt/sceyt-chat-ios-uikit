//
//  AttachmentImageViewCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit

extension MessageCell {
    open class AttachmentImageView: AttachmentView {
        
        override open func setupAppearance() {
            super.setupAppearance()
            imageView.clipsToBounds = true

            progressView.contentInsets = .init(top: 4, left: 4, bottom: 4, right: 4)
            progressView.backgroundColor = .black.withAlphaComponent(0.3)
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
        
        private var filePath: String?

        override open var data: MessageLayoutModel.AttachmentLayout! {
            didSet {
                setupPreviewer()
                filePath = data.attachment.filePath
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
}
