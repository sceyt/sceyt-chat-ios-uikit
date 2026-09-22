//
//  MessageInputViewController+ThumbnailView+FileView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInputViewController.ThumbnailView {
    open class FileView: View {
        public lazy var appearance = Components.messageInputSelectedMediaView.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open lazy var imageView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFit)
        
        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
        
        open lazy var subtitleLabel = UILabel()
            .withoutAutoresizingMask
        
        override open func setup() {
            super.setup()
            clipsToBounds = true
            layer.cornerRadius = 8
            titleLabel.lineBreakMode = .byTruncatingMiddle
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            backgroundColor = appearance.fileAttachmentBackgroundColor
            titleLabel.textColor = appearance.fileAttachmentNameLabelAppearance.foregroundColor
            titleLabel.font = appearance.fileAttachmentNameLabelAppearance.font
            subtitleLabel.textColor = appearance.fileAttachmentSizeLabelAppearance.foregroundColor
            subtitleLabel.font = appearance.fileAttachmentSizeLabelAppearance.font
        }
        
        override open func setupLayout() {
            super.setupLayout()
            addSubview(imageView)
            addSubview(titleLabel)
            addSubview(subtitleLabel)
            imageView.pin(to: self, anchors: [.top(12, .greaterThanOrEqual), .bottom(-12, .lessThanOrEqual), .leading(12)])
            imageView.heightAnchor.pin(to: imageView.widthAnchor)
            imageView.heightAnchor.pin(constant: 46)
            titleLabel.leadingAnchor.pin(to: imageView.trailingAnchor, constant: 12)
            titleLabel.pin(to: self, anchors: [.top(12, .greaterThanOrEqual), .trailing(-21, .lessThanOrEqual)])
            titleLabel.bottomAnchor.pin(to: imageView.centerYAnchor)
            titleLabel.widthAnchor.pin(lessThanOrEqualToConstant: 120)
            subtitleLabel.leadingAnchor.pin(to: imageView.trailingAnchor, constant: 12)
            subtitleLabel.pin(to: self, anchors: [.bottom(-12, .lessThanOrEqual), .trailing(-21, .lessThanOrEqual)])
            subtitleLabel.topAnchor.pin(to: imageView.centerYAnchor, constant: 4)
        }

        /// The generic file-type icon, for a document that carries no preview (pdf/zip/…).
        /// Drawn at its own aspect ratio inside the slot, unclipped.
        open func showIcon(_ icon: UIImage?) {
            imageView.image = icon
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = false
            imageView.layer.cornerRadius = 0
        }

        /// A real preview for an image or a video picked as a document — filled and rounded
        /// like the thumbnail its file bubble will show once sent, rather than letterboxed
        /// the way the icon is.
        open func showPreview(_ preview: UIImage) {
            imageView.image = preview
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = Layouts.previewCornerRadius
        }
    }
}

public extension MessageInputViewController.ThumbnailView.FileView {
    enum Layouts {
        public static var previewCornerRadius: CGFloat = 8
    }
}
