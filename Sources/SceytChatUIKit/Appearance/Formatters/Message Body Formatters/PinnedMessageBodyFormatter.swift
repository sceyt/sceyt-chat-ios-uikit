//
//  PinnedMessageBodyFormatter.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation

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

        return body(attributes).replacingLineBreaksWithSpacesForPreview()
    }

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
