//
//  GlobalSearchMessageCell.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

open class GlobalSearchMessageCell: TableViewCell {

    open lazy var avatarView = ImageView()
        .contentMode(.scaleAspectFill)
        .withoutAutoresizingMask

    open lazy var titleLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var statusLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var timeLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var separatorView = UIView()
        .withoutAutoresizingMask

    open lazy var textVStack = UIStackView(column: [titleLabel, statusLabel], spacing: Layouts.textSpacing)
        .withoutAutoresizingMask

    open var imageTask: Cancellable?

    open var searchQuery: String?

    open var messageData: (channel: ChatChannel, message: ChatMessage)? {
        didSet {
            guard let (channel, message) = messageData else { return }
            imageTask = appearance.avatarRenderer.render(
                channel,
                with: appearance.avatarAppearance,
                into: avatarView
            )
            titleLabel.text = appearance.titleFormatter.format(channel)
            statusLabel.attributedText = attributedStatus(channel: channel, message: message)
            timeLabel.text = appearance.channelDateFormatter.format(message.updatedAt ?? message.createdAt)
        }
    }

    private func senderPrefix(channel: ChatChannel, message: ChatMessage) -> String {
        guard let user = message.user else { return "" }
        if message.state == .deleted || channel.isSelfChannel {
            return ""
        } else if (user.id == SceytChatUIKit.shared.currentUserId) || (user.id.isEmpty && !message.incoming) {
            return "\(L10n.User.current): "
        } else if !channel.isDirect {
            return "\(SceytChatUIKit.shared.formatters.userShortNameFormatter.format(user)): "
        }
        return ""
    }

    private func attributedStatus(channel: ChatChannel, message: ChatMessage) -> NSAttributedString {
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

        let snippet = makeSnippet(body: message.body, query: searchQuery)
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

    /// Returns a snippet of `body` that includes the first search match.
    /// If the match is on a later line or far from the start by characters, the body is
    /// trimmed and prefixed with "…" so the matched text appears near the beginning of the snippet.
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

        // Find the start of the line that contains the match.
        // This handles multiline bodies where the match may be on a later line
        // but still within `contextBefore` characters from the body start.
        let lineStart: String.Index
        if let lastNewline = body[..<matchStart].lastIndex(of: "\n") {
            lineStart = body.index(after: lastNewline)
        } else {
            lineStart = body.startIndex
        }

        // Measure how far the match is from the start of its own line.
        let matchOffsetInLine = body.distance(from: lineStart, to: matchStart)

        // If the match is on the first line and close to the start, return the full body.
        if lineStart == body.startIndex && matchOffsetInLine <= contextBefore {
            return body
        }

        // If the match is near the start of its line, trim at the line boundary.
        if matchOffsetInLine <= contextBefore {
            return "…" + String(body[lineStart...])
        }

        // Match is far into its line — apply character-based trimming within the line.
        let cutIndex = body.index(lineStart, offsetBy: matchOffsetInLine - contextBefore)
        // Advance to the nearest word boundary so we don't cut mid-word.
        var snippetStart = cutIndex
        if let spaceIdx = body[cutIndex...].firstIndex(of: " ") {
            let afterSpace = body.index(after: spaceIdx)
            if afterSpace < matchStart {
                snippetStart = afterSpace
            }
        }

        return "…" + String(body[snippetStart...])
    }

    override open func setupLayout() {
        super.setupLayout()
        contentView.addSubview(avatarView)
        contentView.addSubview(timeLabel)
        contentView.addSubview(textVStack)
        contentView.addSubview(separatorView)

        avatarView.pin(to: contentView, anchors: [.leading(Layouts.horizontalPadding), .top(Layouts.verticalPadding)])
        avatarView.resize(anchors: [.height(Layouts.iconSize), .width(Layouts.iconSize)])

        timeLabel.pin(to: contentView, anchors: [.trailing(-Layouts.horizontalPadding), .top(Layouts.verticalPadding)])
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        textVStack.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: Layouts.horizontalPadding)
        textVStack.topAnchor.pin(to: contentView.topAnchor, constant: Layouts.verticalPadding)
        textVStack.trailingAnchor.pin(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -Layouts.timeLabelSpacing)

        separatorView.topAnchor.pin(greaterThanOrEqualTo: textVStack.bottomAnchor, constant: Layouts.verticalPadding)
        separatorView.topAnchor.pin(greaterThanOrEqualTo: avatarView.bottomAnchor, constant: Layouts.verticalPadding)
        separatorView.pin(to: contentView, anchors: [.bottom, .trailing(-Layouts.horizontalPadding)])
        separatorView.leadingAnchor.pin(to: titleLabel.leadingAnchor)
        separatorView.heightAnchor.pin(constant: 1)
    }

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
        imageTask?.cancel()
        searchQuery = nil
        messageData = nil
    }
}

public extension GlobalSearchMessageCell {
    enum Layouts {
        public static var iconSize: CGFloat = 56
        public static var verticalPadding: CGFloat = 8
        public static var horizontalPadding: CGFloat = 16
        public static var textSpacing: CGFloat = 3
        public static var timeLabelSpacing: CGFloat = 8
    }
}
