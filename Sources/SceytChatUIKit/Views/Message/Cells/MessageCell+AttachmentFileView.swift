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

        open lazy var playButton = UIImageView()
            .withoutAutoresizingMask

        open override func setupAppearance() {
            super.setupAppearance()
            imageView.clipsToBounds = true
            imageView.cornerRadius = 8

            titleLabel.font = appearance.attachmentFileNameLabelAppearance.font
            titleLabel.textColor = appearance.attachmentFileNameLabelAppearance.foregroundColor
            titleLabel.lineBreakMode = .byTruncatingMiddle

            sizeLabel.font = appearance.attachmentFileSizeLabelAppearance.font
            sizeLabel.textColor = appearance.attachmentFileSizeLabelAppearance.foregroundColor

            progressView.backgroundColor = appearance.mediaLoaderAppearance.backgroundColor
            progressView.contentInsets = .init(top: 4, left: 4, bottom: 4, right: 4)

            playButton.image = .videoPlayerPlay
            playButton.isHidden = true
        }

        open override func setupLayout() {
            super.setupLayout()

            addSubview(imageView)
            addSubview(titleLabel)
            addSubview(sizeLabel)
            addSubview(progressView)
            addSubview(pauseButton)
            addSubview(playButton)

            imageView.pin(to: self, anchors: [.leading(Layouts.horizontalPadding), .centerY(-1)])
            imageView.resize(anchors: [.height(Layouts.attachmentIconSize), .width(Layouts.attachmentIconSize)])
            titleLabel.leadingAnchor.pin(to: imageView.trailingAnchor, constant: Layouts.horizontalPadding)
            titleLabel.topAnchor.pin(to: imageView.topAnchor, constant: 2)
            titleLabel.trailingAnchor.pin(lessThanOrEqualTo: trailingAnchor, constant: -Layouts.horizontalPadding)
            sizeLabel.leadingAnchor.pin(to: titleLabel.leadingAnchor)
            sizeLabel.topAnchor.pin(to: titleLabel.bottomAnchor, constant: 4)

            progressView.pin(to: imageView)
            pauseButton.pin(to: progressView)
            playButton.pin(to: imageView, anchors: [.centerX(), .centerY()])
            playButton.resize(anchors: [.height(24.0), .width(24.0)])
        }

        private var isVideoFile: Bool {
            URL(fileURLWithPath: data.attachment.name ?? "").isVideo
        }
        
        open override func update(status: ChatMessage.Attachment.TransferStatus) {
            super.update(status: status)
            if data.transferStatus == .done {
                if data.thumbnail != nil && isVideoFile {
                    playButton.isHidden = false
                }
            }
        }

        open override var data: MessageLayoutModel.AttachmentLayout! {
            didSet {
                playButton.isHidden = true
                if data.transferStatus == .done {
                    imageView.image = data.thumbnail ?? appearance.attachmentIconProvider.provideVisual(for: data.attachment)
                    if data.thumbnail != nil && isVideoFile {
                        playButton.isHidden = false
                    }
                } else {
                    imageView.image = appearance.attachmentIconProvider.provideVisual(for: data.attachment)
                }
                titleLabel.text = data.name
                sizeLabel.text = data.fileSize(using: appearance.attachmentFileSizeFormatter)

                // The file-preview thumbnail is loaded asynchronously (and re-loaded after a
                // download completes), so at bind time — and right after a first download —
                // data.thumbnail may still be the default icon. Without this hook the sharp
                // preview lands on the layout but never reaches the cell until the screen
                // is reopened.
                data.onLoadThumbnail = { [weak self, weak data] thumbnail in
                    guard let self, let data, self.data === data else { return }
                    guard data.transferStatus == .done else { return }
                    self.imageView.image = thumbnail ?? self.appearance.attachmentIconProvider.provideVisual(for: data.attachment)
                    self.playButton.isHidden = !(thumbnail != nil && self.isVideoFile)
                }
            }
        }

        open override func setProgress(_ progress: AttachmentTransfer.AttachmentProgress) {
            super.setProgress(progress)
            playButton.isHidden = true

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
