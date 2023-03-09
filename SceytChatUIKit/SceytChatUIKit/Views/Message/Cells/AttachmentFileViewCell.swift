//
//  AttachmentFileViewCell.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
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
            layer.cornerRadius = 16

            imageView.clipsToBounds = true
            imageView.image = .file

            titleLabel.font = Fonts.medium.withSize(16)
            titleLabel.textColor = .textBlack
            titleLabel.lineBreakMode = .byTruncatingMiddle

            sizeLabel.font = Fonts.regular.withSize(10)
            sizeLabel.textColor = .textBlack

            progressView.backgroundColor = .kitBlue
            progressView.contentInsets = .init(top: 4, left: 4, bottom: 4, right: 4)
            progressView.trackColor = .white.withAlphaComponent(0.3)
            progressView.progressColor = .white
        }

        open override func setupLayout() {
            super.setupLayout()

            addSubview(imageView)
            addSubview(titleLabel)
            addSubview(sizeLabel)
            addSubview(progressView)
            addSubview(pauseButton)

            imageView.pin(to: self, anchors: [.leading(10), .centerY(-1)])
            imageView.resize(anchors: [.height(40), .width(40)])
            titleLabel.leadingAnchor.pin(to: imageView.trailingAnchor, constant: 12)
            titleLabel.topAnchor.pin(to: imageView.topAnchor)
            titleLabel.trailingAnchor.pin(lessThanOrEqualTo: trailingAnchor, constant: -8)
            sizeLabel.leadingAnchor.pin(to: titleLabel.leadingAnchor)
            sizeLabel.topAnchor.pin(to: titleLabel.bottomAnchor, constant: 4)

            progressView.resize(anchors: [.width(40), .height(40)])
            progressView.pin(to: imageView, anchors: [.centerX, .centerY])
            pauseButton.pin(to: progressView)
        }

        open override var data: ChatMessage.Attachment! {
            didSet {
                titleLabel.text = fileName
                sizeLabel.text = fileSize
            }
        }
        
        open var fileName: String {
            data.name ?? ((data.url ?? data.filePath) as NSString?)?.lastPathComponent ?? ""
        }
        
        open var fileSize: String {
            let fileSize: UInt
            if data.uploadedFileSize > 0 {
                fileSize = data.uploadedFileSize
            } else if let filePath = data.filePath {
                fileSize = Storage.sizeOfItem(at: filePath)
            } else {
                fileSize = 0
            }
            return Formatters.fileSize.format(fileSize)
        }
    }
}
