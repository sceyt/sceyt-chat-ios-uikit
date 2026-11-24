//
//  PinnedMessageBodyFormatter.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import UIKit

/// Renders the one-line preview of a pinned message, for the pinned banner and the pinned
/// messages list.
///
/// The resolution order is deliberate — a poll is checked before the body, because a poll
/// message's body *is* its question and would otherwise render as a bare sentence with no
/// hint that it is a poll:
///
/// | message | preview |
/// | --- | --- |
/// | deleted | "Message was deleted" |
/// | unsupported | delegated to `unsupportedMessageShortFormatter` |
/// | poll | `Poll: <question>` |
/// | attachment, no caption | `Photo` / `Video` / `File` |
/// | voice, no caption | `Voice: 00:56` |
/// | anything else | the body, mentions resolved, newlines collapsed |
///
/// A subclass can put an inline icon in front of that preview by overriding `icon(for:)`;
/// `iconPrefix(_:attributes:)` owns the sizing, tinting and baseline alignment so an
/// integrator does not have to re-derive the `NSTextAttachment` geometry. The base class
/// returns no icon, so the preview is text-only unless a subclass asks for one.
open class PinnedMessageBodyFormatter: PinnedMessageBodyFormatting {

    public init() {}

    open func format(_ attributes: PinnedMessageBodyFormatterAttributes) -> NSAttributedString {
        let message = attributes.message

        if message.state == .deleted {
            return NSAttributedString(
                string: attributes.deletedStateText,
                attributes: [
                    .font: attributes.deletedLabelAppearance.font,
                    .foregroundColor: attributes.deletedLabelAppearance.foregroundColor
                ]
            )
        }

        if MessageLayoutModel.isMessageUnsupported(message) {
            return SceytChatUIKit.shared.formatters.unsupportedMessageShortFormatter.format(message)
        }

        let preview = body(attributes).replacingLineBreaksWithSpacesForPreview()

        // The icon is deliberately outside `body(_:)`: a subclass that overrides the body still
        // gets the icon, and a deleted or unsupported message returns above without one.
        guard let icon = icon(for: attributes) else { return preview }
        let result = NSMutableAttributedString(attributedString: iconPrefix(icon, attributes: attributes))
        result.append(preview)
        return result
    }

    /// The icon shown in front of the preview, or `nil` for a text-only preview — which is
    /// every message here, since the pinned banner already carries a thumbnail for media.
    /// Override it to name a message kind the banner cannot show any other way.
    ///
    /// A template image is tinted with the body colour; anything else is drawn as-is.
    open func icon(for attributes: PinnedMessageBodyFormatterAttributes) -> UIImage? {
        nil
    }

    /// The icon plus the space that separates it from the text, sized from the body font and
    /// centred on its cap height, the same geometry the channel-list preview uses.
    open func iconPrefix(
        _ icon: UIImage,
        attributes: PinnedMessageBodyFormatterAttributes
    ) -> NSAttributedString {
        let font = attributes.bodyLabelAppearance.font
        let baseFont = attributes.bodyLabelAppearance.baseFont
        // Grows with Dynamic Type: the appearance's font is the scaled one, its base font the
        // unscaled original, so their ratio is the scale the label is being rendered at.
        let scale = baseFont.pointSize > 0 ? font.pointSize / baseFont.pointSize : 1
        let side = (Self.iconSide * scale).rounded(.up)
        let size = CGSize(width: side, height: side)

        let tinted = icon.renderingMode == .alwaysTemplate
            ? icon.withTintColor(attributes.bodyLabelAppearance.foregroundColor, renderingMode: .alwaysOriginal)
            : icon
        let sized = UIGraphicsImageRenderer(size: size).image { _ in
            tinted.draw(in: CGRect(origin: .zero, size: size))
        }

        let attachment = NSTextAttachment()
        attachment.image = sized
        attachment.bounds = CGRect(
            x: 0,
            y: ((font.capHeight - size.height) / 2).rounded(),
            width: size.width,
            height: size.height
        )
        let result = NSMutableAttributedString(attachment: attachment)
        result.append(NSAttributedString(string: " ", attributes: [.font: font]))
        return result
    }

    /// The icon's side at 100% Dynamic Type, matching the channel-list preview's icons.
    open class var iconSide: CGFloat { 16 }

    /// The preview text before mention substitution.
    open func body(_ attributes: PinnedMessageBodyFormatterAttributes) -> NSAttributedString {
        let message = attributes.message
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: attributes.bodyLabelAppearance.font,
            .foregroundColor: attributes.bodyLabelAppearance.foregroundColor
        ]

        // A poll's body is its question — see the send path, `.type("poll").body(question)`.
        //
        // Matched on the type as well as the payload: the pinned banner renders from
        // `PinnedMessage.previewMessage`, a snapshot that carries no `PollDetails`, so a
        // `poll != nil` check alone would silently fall through to the bare question.
        if message.poll != nil || message.type == ChatMessage.MessageType.poll {
            return NSAttributedString(
                string: L10n.Message.Pinned.poll(message.body),
                attributes: bodyAttributes
            )
        }

        if message.body.isEmpty {
            if let attachment = message.attachments?.first {
                // "Photo" / "Video" / "File", and for a voice note its length alongside
                // the name — "Voice: 00:56" — since the length is the only thing that
                // tells one voice pin from another.
                let name = attributes.attachmentNameFormatter.format(attachment)
                let text: String
                if let duration = voiceDuration(of: attachment) {
                    text = L10n.Message.Pinned.voice(
                        name,
                        attributes.attachmentDurationFormatter.format(duration)
                    )
                } else {
                    text = name
                }
                return NSAttributedString(string: text, attributes: bodyAttributes)
            }
            return NSAttributedString(string: "", attributes: bodyAttributes)
        }

        return applyMentions(to: NSAttributedString(string: message.body, attributes: bodyAttributes),
                             attributes: attributes)
    }

    /// The length of a voice attachment, when it is one and its metadata carries a
    /// duration. `nil` for every other attachment type, which is what keeps the
    /// "Voice: 00:56" join out of a photo's or file's preview.
    open func voiceDuration(of attachment: ChatMessage.Attachment) -> TimeInterval? {
        guard MessageLayoutModel.AttachmentLayout.AttachmentType(rawValue: attachment.type) == .voice,
              let duration = attachment.voiceDecodedMetadata?.duration,
              duration > 0
        else { return nil }
        return TimeInterval(duration)
    }

    /// Replaces each mention span with the mentioned user's display name, styled with the
    /// mention appearance. Highest offset first, so earlier ranges stay valid as the string
    /// changes length.
    open func applyMentions(
        to body: NSAttributedString,
        attributes: PinnedMessageBodyFormatterAttributes
    ) -> NSAttributedString {
        let message = attributes.message
        guard let mentions = message.bodyAttributes?.filter({ $0.type == .mention }),
              !mentions.isEmpty
        else { return body }

        let result = body.mutableCopy() as! NSMutableAttributedString
        for bodyAttribute in mentions.sorted(by: { $0.offset > $1.offset }) {
            let range = NSRange(location: bodyAttribute.offset, length: bodyAttribute.length)
            guard let userId = bodyAttribute.metadata,
                  let user = message.mentionedUsers?.first(where: { $0.id == userId })
            else { continue }
            let mention = NSAttributedString(
                string: SceytChatUIKit.shared.config.mentionTriggerPrefix
                    + attributes.mentionUserNameFormatter.format(user),
                attributes: [
                    .font: attributes.mentionLabelAppearance.font,
                    .foregroundColor: attributes.mentionLabelAppearance.foregroundColor,
                    .mention: userId
                ]
            )
            result.safeReplaceCharacters(in: range, with: mention)
        }
        return result
    }
}
