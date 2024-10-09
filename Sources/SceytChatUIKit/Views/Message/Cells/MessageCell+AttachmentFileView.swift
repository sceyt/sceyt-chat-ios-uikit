//
//  MessageCell+AttachmentFileView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageCell {

    open class AttachmentFileView: AttachmentView {

        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var sizeLabel = UILabel()
            .withoutAutoresizingMask

        open override func setupAppearance() {
            super.setupAppearance()
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 4

            titleLabel.font = appearance.attachmentFileNameLabelAppearance.font
            titleLabel.textColor = appearance.attachmentFileNameLabelAppearance.foregroundColor
            titleLabel.lineBreakMode = .byTruncatingMiddle

            sizeLabel.font = appearance.attachmentFileSizeLabelAppearance.font
            sizeLabel.textColor = appearance.attachmentFileSizeLabelAppearance.foregroundColor

            progressView.backgroundColor = appearance.mediaLoaderAppearance.backgroundColor
            progressView.contentInsets = .init(top: 4, left: 4, bottom: 4, right: 4)
        }

        open override func setupLayout() {
            super.setupLayout()

            addSubview(imageView)
            addSubview(titleLabel)
            addSubview(sizeLabel)
            addSubview(progressView)
            addSubview(pauseButton)

            imageView.pin(to: self, anchors: [.leading(Layouts.horizontalPadding), .centerY(-1)])
            imageView.resize(anchors: [.height(Layouts.attachmentIconSize), .width(Layouts.attachmentIconSize)])
            titleLabel.leadingAnchor.pin(to: imageView.trailingAnchor, constant: Layouts.horizontalPadding)
            titleLabel.topAnchor.pin(to: imageView.topAnchor, constant: 2)
            titleLabel.trailingAnchor.pin(lessThanOrEqualTo: trailingAnchor, constant: -Layouts.horizontalPadding)
            sizeLabel.leadingAnchor.pin(to: titleLabel.leadingAnchor)
            sizeLabel.topAnchor.pin(to: titleLabel.bottomAnchor, constant: 4)

            progressView.pin(to: imageView)
            pauseButton.pin(to: progressView)
        }

        open override var data: MessageLayoutModel.AttachmentLayout! {
            didSet {
                imageView.image = appearance.attachmentIconProvider.provideVisual(for: data.attachment)
                titleLabel.text = data.name
                sizeLabel.text = data.fileSize(using: appearance.attachmentFileSizeFormatter)
            }
        }
        
        open override func setProgress(_ progress: AttachmentTransfer.AttachmentProgress) {
            super.setProgress(progress)
            
            let message: String
            if progress.progress <= 0.01 || progress.progress >= 1 {
                message = data.fileSize(using: appearance.attachmentFileSizeFormatter)
            } else {
                let total = progress.attachment.uploadedFileSize
                let downloaded = UInt(progress.progress * Double(total))
                message = "\(appearance.attachmentFileSizeFormatter.format(UInt64(downloaded))) • \(appearance.attachmentFileSizeFormatter.format(UInt64(total)))"
            }
            sizeLabel.text = message
        }
        
        open override func setCompletion(_ completion: AttachmentTransfer.AttachmentCompletion) {
            super.setCompletion(completion)
            guard completion.error == nil
            else { return }
            sizeLabel.text = data.fileSize(using: appearance.attachmentFileSizeFormatter)
        }
    }
}
