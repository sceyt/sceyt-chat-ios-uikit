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

    /// The active search query forwarded from the page VC. Substring matches in any of
    /// the cell's text labels (title/URL/summary) are re-coloured to `.primaryText` so
    /// the user can see *which part* of the link the search hit.
    open var searchQuery: String?

    open var data: MessageLayoutModel.AttachmentLayout? {
        didSet {
            guard let data else { return }
            applyHighlightedText(
                linkLabel,
                plain: data.attachment.url,
                baseColor: appearance.linkLabelAppearance.foregroundColor,
                baseFont: appearance.linkLabelAppearance.font,
                dimOnMatch: false
            )
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
                applyHighlightedText(
                    titleLabel,
                    plain: metadata.title,
                    baseColor: appearance.linkPreviewAppearance.titleLabelAppearance.foregroundColor,
                    baseFont: appearance.linkPreviewAppearance.titleLabelAppearance.font
                )
                titleLabel.isHidden = (metadata.title ?? "").isEmpty
                applyHighlightedText(
                    detailLabel,
                    plain: metadata.summary,
                    baseColor: appearance.linkPreviewAppearance.descriptionLabelAppearance.foregroundColor,
                    baseFont: appearance.linkPreviewAppearance.descriptionLabelAppearance.font
                )
                detailLabel.isHidden = (metadata.summary ?? "").isEmpty
                if let image = metadata.image {
                    iconView.image = image
                } else {
                    iconView.image = appearance.linkPreviewAppearance.placeholderIcon
                }
            }
        }
    }

    /// Renders `plain` into `label` with context-aware colouring:
    /// - No query → entire text in `baseColor`.
    /// - Query active, no match → entire text stays in `baseColor` (unchanged).
    /// - Query active, match found → matched ranges re-coloured to `.primaryText`;
    ///   when `dimOnMatch` is `true` non-matched chars are dimmed to `.secondaryText`,
    ///   otherwise they keep `baseColor`.
    private func applyHighlightedText(
        _ label: UILabel,
        plain: String?,
        baseColor: UIColor,
        baseFont: UIFont,
        dimOnMatch: Bool = true
    ) {
        guard let plain, !plain.isEmpty else {
            label.attributedText = nil
            label.text = nil
            return
        }
        let trimmed = searchQuery?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !trimmed.isEmpty else {
            label.attributedText = NSAttributedString(
                string: plain,
                attributes: [.font: baseFont, .foregroundColor: baseColor]
            )
            return
        }

        let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let fullRange = NSRange(location: 0, length: (plain as NSString).length)
        var matchRanges: [NSRange] = []
        for token in tokens {
            let escaped = NSRegularExpression.escapedPattern(for: token)
            guard let regex = try? NSRegularExpression(pattern: "(?i)\(escaped)") else { continue }
            matchRanges += regex.matches(in: plain, range: fullRange).map(\.range)
        }

        // No match — keep base colour, no dimming.
        guard !matchRanges.isEmpty else {
            label.attributedText = NSAttributedString(
                string: plain,
                attributes: [.font: baseFont, .foregroundColor: baseColor]
            )
            return
        }

        // Match found: optionally dim whole text to secondary, then re-highlight matched ranges.
        let result = NSMutableAttributedString(
            string: plain,
            attributes: [.font: baseFont, .foregroundColor: dimOnMatch ? UIColor.secondaryText : baseColor]
        )
        for range in matchRanges {
            result.addAttribute(.foregroundColor, value: UIColor.primaryText, range: range)
        }
        label.attributedText = result
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
        titleLabel.attributedText = nil
        linkLabel.attributedText = nil
        detailLabel.attributedText = nil
        titleLabel.text = nil
        linkLabel.text = nil
        detailLabel.text = nil
        iconView.image = appearance.linkPreviewAppearance.placeholderIcon
        titleLabel.isHidden = true
        detailLabel.isHidden = true
        searchQuery = nil
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
