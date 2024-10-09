//
//  MessageCell+LinkPreviewView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import LinkPresentation

extension MessageCell {

    open class LinkPreviewView: View, Measurable {
        
        public lazy var appearance = Components.messageCell.appearance {
            didSet {
                setupAppearance()
            }
        }

        open lazy var imageView = ImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFill)

        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityV(.required)

        open lazy var descriptionLabel = UILabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityV(.required)

        open private(set) var link: URL!
        
        private var imageViewSizeConstraints: [NSLayoutConstraint]?
        
        open override func setup() {
            super.setup()
            imageView.cornerRadius = 8
            imageView.clipsToBounds = true
            titleLabel.numberOfLines = 2
            descriptionLabel.numberOfLines = 3
            
        }

        open override func setupAppearance() {
            super.setupAppearance()
            titleLabel.font = appearance.linkPreviewAppearance.titleLabelAppearance.font
            titleLabel.textColor = appearance.linkPreviewAppearance.titleLabelAppearance.foregroundColor
            descriptionLabel.font = appearance.linkPreviewAppearance.descriptionLabelAppearance.font
            descriptionLabel.textColor = appearance.linkPreviewAppearance.descriptionLabelAppearance.foregroundColor
        }

        open override func setupLayout() {
            super.setupLayout()
            addSubview(imageView)
            addSubview(titleLabel)
            addSubview(descriptionLabel)
            imageView.pin(to: self, anchors: [.top(6), .leading(6), .trailing(-6)])
            titleLabel.pin(to: self, anchors: [.leading(6), .trailing(-6)])
            descriptionLabel.pin(to: self, anchors: [.leading(6), .trailing(-6)])
            titleLabel.topAnchor.pin(to: imageView.bottomAnchor, constant: 6)
            descriptionLabel.topAnchor.pin(to: titleLabel.bottomAnchor, constant: 2)
            descriptionLabel.bottomAnchor.pin(to: self.bottomAnchor, constant: -6)
            imageViewSizeConstraints = imageView.resize(anchors: [.width, .height])
        }
        
        open override func layoutSubviews() {
            super.layoutSubviews()
            layer.cornerRadius = 8
        }
        
        open var data: MessageLayoutModel.LinkPreview! {
            didSet {
                imageView.image = data.image
                titleLabel.attributedText = data.title
                descriptionLabel.attributedText = data.description
                link = data.url
                if let imageViewSizeConstraints, imageViewSizeConstraints.count == 2 {
                    let size = Self.imageSize(model: data)
                    imageViewSizeConstraints[0].constant = size.width
                    imageViewSizeConstraints[1].constant = size.height
                }
            }
        }
        
        private static func imageSize(model: MessageLayoutModel.LinkPreview) -> CGSize {
            var size = CGSize()
            if let image = model.image {
                if let imageOriginalSize = model.imageOriginalSize,
                    max(imageOriginalSize.width, imageOriginalSize.height) <=
                    max(MessageLayoutModel.defaults.imageAttachmentSize.width, MessageLayoutModel.defaults.imageAttachmentSize.height) {
                    size = imageOriginalSize
                } else {
                    size.width = min(max(model.imageOriginalSize?.width ?? 0, image.size.width), MessageLayoutModel.defaults.imageAttachmentSize.width)
                    size.height = min(max(model.imageOriginalSize?.height ?? 0, image.size.height), MessageLayoutModel.defaults.imageAttachmentSize.height)
                }
            }
            return size
        }

        open class func measure(model: MessageLayoutModel.LinkPreview, appearance: Appearance) -> CGSize {
            var size = CGSize()
            if let image = model.image {
                size = imageSize(model: model)
            } else {
                size.width = max(model.titleSize.width, model.descriptionSize.width)
            }
            size.height += model.titleSize.height //size name
            size.height += model.descriptionSize.height // desc
            if size.height > 0 {
                size.height += 20 // padding
            }
            return size
        }
    }
}

