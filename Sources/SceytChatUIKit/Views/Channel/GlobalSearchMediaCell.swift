//
//  GlobalSearchMediaCell.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

open class GlobalSearchMediaCell: TableViewCell {

    open lazy var avatarView = ImageView()
        .contentMode(.scaleAspectFill)
        .withoutAutoresizingMask

    open lazy var titleLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var statusLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var timeLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var thumbnailView = ImageView()
        .contentMode(.scaleAspectFill)
        .withoutAutoresizingMask

    open lazy var separatorView = UIView()
        .withoutAutoresizingMask

    open lazy var textVStack = UIStackView(column: [titleLabel, statusLabel], spacing: GlobalSearchMessageCell.Layouts.textSpacing)
        .withoutAutoresizingMask

    /// Right column: date on top, thumbnail below.
    open lazy var rightStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.alignment = .trailing
        sv.spacing = Layouts.rightStackSpacing
        sv.addArrangedSubview(timeLabel)
        sv.addArrangedSubview(thumbnailView)
        return sv
    }().withoutAutoresizingMask

    open var imageTask: Cancellable?
    open var searchQuery: String?

    open var data: (channel: ChatChannel?, message: ChatMessage, layout: MessageLayoutModel.AttachmentLayout)? {
        didSet { configure() }
    }

    private func configure() {
        guard let (channel, message, layout) = data else { return }

        if let channel {
            imageTask = appearance.avatarRenderer.render(
                channel,
                with: appearance.avatarAppearance,
                into: avatarView
            )
            titleLabel.text = appearance.titleFormatter.format(channel)
        } else {
            avatarView.image = nil
            titleLabel.text = nil
        }

        statusLabel.attributedText = attributedStatus(channel: channel, message: message, layout: layout)
        timeLabel.text = appearance.channelDateFormatter.format(message.updatedAt ?? message.createdAt)

        thumbnailView.image = layout.thumbnail
        thumbnailView.backgroundColor = appearance.thumbnailPlaceholderColor
        thumbnailView.layer.cornerRadius = Layouts.thumbnailCornerRadius
        thumbnailView.clipsToBounds = true
    }

    // MARK: - Status / Snippet

    private func senderPrefix(channel: ChatChannel?, message: ChatMessage) -> String {
        guard let user = message.user else { return "" }
        if message.state == .deleted || channel?.isSelfChannel == true {
            return ""
        } else if (user.id == SceytChatUIKit.shared.currentUserId) || (user.id.isEmpty && !message.incoming) {
            return "\(L10n.User.current): "
        } else if channel?.isDirect == false {
            return "\(SceytChatUIKit.shared.formatters.userShortNameFormatter.format(user)): "
        }
        return ""
    }

    private func attributedStatus(
        channel: ChatChannel?,
        message: ChatMessage,
        layout: MessageLayoutModel.AttachmentLayout
    ) -> NSAttributedString {
        let prefix = senderPrefix(channel: channel, message: message)
        let bodyFont = appearance.subtitleLabelAppearance?.font ?? Fonts.regular.withSize(15)
        let bodyColor = appearance.subtitleLabelAppearance?.foregroundColor ?? UIColor.secondaryText

        let result = NSMutableAttributedString()
        if !prefix.isEmpty {
            result.append(NSAttributedString(
                string: prefix,
                attributes: [
                    .font: appearance.senderNameLabelAppearance.font,
                    .foregroundColor: appearance.senderNameLabelAppearance.foregroundColor
                ]
            ))
        }

        let bodyText = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if bodyText.isEmpty {
            result.append(attachmentOnlyFallback(message: message, layout: layout, font: bodyFont, color: bodyColor))
            return result
        }

        let snippet = makeSnippet(body: bodyText, query: searchQuery)
        let bodyStart = result.length
        result.append(NSAttributedString(
            string: snippet,
            attributes: [.font: bodyFont, .foregroundColor: bodyColor]
        ))

        if let query = searchQuery, !query.isEmpty {
            let tokens = query
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            let fullRange = NSRange(location: 0, length: (snippet as NSString).length)
            for token in tokens {
                let escaped = NSRegularExpression.escapedPattern(for: token)
                guard let regex = try? NSRegularExpression(pattern: "(?i)\\b\(escaped)") else { continue }
                for match in regex.matches(in: snippet, range: fullRange) {
                    let range = NSRange(location: bodyStart + match.range.location, length: match.range.length)
                    result.addAttributes([
                        .foregroundColor: appearance.highlightedBodyLabelAppearance.foregroundColor,
                        .font: appearance.highlightedBodyLabelAppearance.font
                    ], range: range)
                }
            }
        }

        return result
    }

    private func attachmentOnlyFallback(
        message: ChatMessage,
        layout: MessageLayoutModel.AttachmentLayout,
        font: UIFont,
        color: UIColor
    ) -> NSAttributedString {
        let type = layout.attachment.type
        let attachmentName: String
        switch type {
        case "image":
            attachmentName = L10n.Attachment.image
        case "video":
            attachmentName = L10n.Attachment.video
        case "file":
            attachmentName = L10n.Attachment.file
        case "voice":
            attachmentName = L10n.Attachment.voice
        default:
            attachmentName = L10n.Attachment.file
        }

        let messageTypeIconProvider = SceytChatUIKit.shared.visualProviders.messageTypeIconProvider
        let result = NSMutableAttributedString()
        if let icon = messageTypeIconProvider.provideVisual(for: message) {
            let finalIcon: UIImage
            if icon.renderingMode == .alwaysTemplate {
                finalIcon = icon.withTintColor(color, renderingMode: .alwaysOriginal)
            } else {
                finalIcon = icon
            }
            let attachment = NSTextAttachment()
            attachment.bounds = CGRect(
                x: 0,
                y: (font.capHeight - finalIcon.size.height).rounded() / 2,
                width: finalIcon.size.width,
                height: finalIcon.size.height
            )
            attachment.image = finalIcon
            result.append(NSAttributedString(attachment: attachment))
            result.append(NSAttributedString(string: " ", attributes: [.font: font]))
        }
        result.append(NSAttributedString(
            string: attachmentName,
            attributes: [.font: font, .foregroundColor: color]
        ))
        return result
    }

    private func makeSnippet(body: String, query: String?) -> String {
        let contextBefore = 30
        guard let query = query, !query.isEmpty else { return body }

        let tokens = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var firstMatchStart: String.Index?

        for token in tokens {
            let escaped = NSRegularExpression.escapedPattern(for: token)
            guard let regex = try? NSRegularExpression(pattern: "(?i)\\b\(escaped)") else { continue }
            let fullRange = NSRange(body.startIndex..., in: body)
            if let match = regex.firstMatch(in: body, range: fullRange),
               let matchRange = Range(match.range, in: body) {
                if firstMatchStart == nil || matchRange.lowerBound < firstMatchStart! {
                    firstMatchStart = matchRange.lowerBound
                }
            }
        }

        guard let matchStart = firstMatchStart else { return body }

        let lineStart: String.Index
        if let lastNewline = body[..<matchStart].lastIndex(of: "\n") {
            lineStart = body.index(after: lastNewline)
        } else {
            lineStart = body.startIndex
        }

        let matchOffsetInLine = body.distance(from: lineStart, to: matchStart)
        if lineStart == body.startIndex && matchOffsetInLine <= contextBefore { return body }
        if matchOffsetInLine <= contextBefore { return "…" + String(body[lineStart...]) }

        let cutIndex = body.index(lineStart, offsetBy: matchOffsetInLine - contextBefore)
        var snippetStart = cutIndex
        if let spaceIdx = body[cutIndex...].firstIndex(of: " ") {
            let afterSpace = body.index(after: spaceIdx)
            if afterSpace < matchStart { snippetStart = afterSpace }
        }
        return "…" + String(body[snippetStart...])
    }

    // MARK: - Layout

    override open func setupLayout() {
        super.setupLayout()
        contentView.addSubview(avatarView)
        contentView.addSubview(rightStack)
        contentView.addSubview(textVStack)
        contentView.addSubview(separatorView)

        thumbnailView.resize(anchors: [.height(Layouts.thumbnailSize), .width(Layouts.thumbnailSize)])

        avatarView.pin(to: contentView, anchors: [.leading(Layouts.horizontalPadding), .top(Layouts.verticalPadding)])
        avatarView.resize(anchors: [.height(Layouts.iconSize), .width(Layouts.iconSize)])

        rightStack.pin(to: contentView, anchors: [.trailing(-Layouts.horizontalPadding), .top(Layouts.verticalPadding)])
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        textVStack.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: Layouts.horizontalPadding)
        textVStack.topAnchor.pin(to: contentView.topAnchor, constant: Layouts.verticalPadding)
        textVStack.trailingAnchor.pin(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -Layouts.timeLabelSpacing)

        separatorView.topAnchor.pin(greaterThanOrEqualTo: textVStack.bottomAnchor, constant: Layouts.verticalPadding)
        separatorView.topAnchor.pin(greaterThanOrEqualTo: avatarView.bottomAnchor, constant: Layouts.verticalPadding)
        separatorView.topAnchor.pin(greaterThanOrEqualTo: rightStack.bottomAnchor, constant: Layouts.verticalPadding)
        separatorView.pin(to: contentView, anchors: [.bottom, .trailing(-Layouts.horizontalPadding)])
        separatorView.leadingAnchor.pin(to: titleLabel.leadingAnchor)
        separatorView.heightAnchor.pin(constant: 1)
    }

    // MARK: - Appearance

    override open func setupAppearance() {
        super.setupAppearance()
        backgroundColor = appearance.backgroundColor
        contentView.backgroundColor = appearance.backgroundColor
        separatorView.backgroundColor = appearance.separatorColor
        titleLabel.textColor = appearance.titleLabelAppearance.foregroundColor
        titleLabel.font = appearance.titleLabelAppearance.font
        statusLabel.textColor = appearance.subtitleLabelAppearance?.foregroundColor
        statusLabel.font = appearance.subtitleLabelAppearance?.font
        statusLabel.numberOfLines = 2
        timeLabel.textColor = appearance.dateLabelAppearance.foregroundColor
        timeLabel.font = appearance.dateLabelAppearance.font
    }

    override open func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        statusLabel.attributedText = nil
        timeLabel.text = nil
        thumbnailView.image = nil
        imageTask?.cancel()
        searchQuery = nil
        data = nil
    }
}

public extension GlobalSearchMediaCell {
    enum Layouts {
        public static var iconSize: CGFloat = GlobalSearchMessageCell.Layouts.iconSize
        public static var verticalPadding: CGFloat = GlobalSearchMessageCell.Layouts.verticalPadding
        public static var horizontalPadding: CGFloat = GlobalSearchMessageCell.Layouts.horizontalPadding
        public static var timeLabelSpacing: CGFloat = GlobalSearchMessageCell.Layouts.timeLabelSpacing
        public static var thumbnailSize: CGFloat = 24
        public static var thumbnailCornerRadius: CGFloat = 2
        public static var rightStackSpacing: CGFloat = 4
    }
}
