//
//  GlobalSearchLinkCell.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

open class GlobalSearchLinkCell: TableViewCell {

    open lazy var iconView = UIImageView()
        .withoutAutoresizingMask
        .contentMode(.scaleAspectFill)

    open lazy var titleLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var linkLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var detailLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var textVStack = UIStackView(column: [titleLabel, linkLabel, detailLabel], spacing: 4)
        .withoutAutoresizingMask

    open lazy var contentHStack = UIStackView(row: [iconView, textVStack],
                                              spacing: Layouts.horizontalPadding,
                                              alignment: .top)
        .withoutAutoresizingMask

    open lazy var separatorView = UIView()
        .withoutAutoresizingMask

    open var data: MessageLayoutModel.AttachmentLayout? {
        didSet {
            guard let data else { return }
            linkLabel.text = data.attachment.url
            titleLabel.text = nil
            detailLabel.text = nil
            titleLabel.isHidden = true
            detailLabel.isHidden = true
            iconView.image = appearance.linkPreviewAppearance.placeholderIcon
        }
    }

    open var metadata: LinkMetadata? {
        didSet {
            guard let metadata else { return }
            if data?.attachment.imageDecodedMetadata?.hideLinkDetails == true {
                titleLabel.text = nil
                detailLabel.text = nil
                titleLabel.isHidden = true
                detailLabel.isHidden = true
                iconView.image = appearance.linkPreviewAppearance.placeholderIcon
            } else {
                titleLabel.text = metadata.title
                titleLabel.isHidden = (titleLabel.text ?? "").isEmpty
                detailLabel.text = metadata.summary
                detailLabel.isHidden = (detailLabel.text ?? "").isEmpty
                if let image = metadata.image {
                    iconView.image = image
                } else {
                    iconView.image = appearance.linkPreviewAppearance.placeholderIcon
                }
            }
        }
    }

    // MARK: - Setup

    override open func setup() {
        super.setup()
        iconView.clipsToBounds = true
        selectionStyle = .none
    }

    override open func setupAppearance() {
        super.setupAppearance()
        backgroundColor = appearance.backgroundColor
        contentView.backgroundColor = appearance.backgroundColor
        separatorView.backgroundColor = appearance.separatorColor

        iconView.image = appearance.linkPreviewAppearance.placeholderIcon
        iconView.layer.cornerRadius = Layouts.cornerRadius

        titleLabel.font = appearance.linkPreviewAppearance.titleLabelAppearance.font
        titleLabel.textColor = appearance.linkPreviewAppearance.titleLabelAppearance.foregroundColor

        linkLabel.font = appearance.linkLabelAppearance.font
        linkLabel.textColor = appearance.linkLabelAppearance.foregroundColor

        detailLabel.font = appearance.linkPreviewAppearance.descriptionLabelAppearance.font
        detailLabel.textColor = appearance.linkPreviewAppearance.descriptionLabelAppearance.foregroundColor
        detailLabel.numberOfLines = 2
    }

    override open func setupLayout() {
        super.setupLayout()
        contentView.addSubview(contentHStack)
        contentView.addSubview(separatorView)

        contentHStack.pin(to: contentView, anchors: [
            .leading(Layouts.horizontalPadding), .trailing(-Layouts.horizontalPadding),
            .top(Layouts.verticalPadding)
        ])

        iconView.resize(anchors: [.height(Layouts.iconSize), .width(Layouts.iconSize)])

        separatorView.topAnchor.pin(greaterThanOrEqualTo: contentHStack.bottomAnchor, constant: Layouts.verticalPadding)
        separatorView.pin(to: contentView, anchors: [.bottom, .trailing(-Layouts.horizontalPadding)])
        separatorView.leadingAnchor.pin(to: linkLabel.leadingAnchor)
        separatorView.heightAnchor.pin(constant: 1)
    }

    override open func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        linkLabel.text = nil
        detailLabel.text = nil
        iconView.image = appearance.linkPreviewAppearance.placeholderIcon
        titleLabel.isHidden = true
        detailLabel.isHidden = true
        metadata = nil
        data = nil
    }
}

public extension GlobalSearchLinkCell {
    enum Layouts {
        public static var iconSize: CGFloat = 40
        public static var horizontalPadding: CGFloat = 16
        public static var verticalPadding: CGFloat = 8
        public static var cornerRadius: CGFloat = 8
    }
}
