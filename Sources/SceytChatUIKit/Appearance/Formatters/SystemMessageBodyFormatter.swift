//
//  SystemMessageBodyFormatter.swift
//  SceytChatUIKit
//
//  Created by Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

/// A protocol for formatting system message bodies.
public protocol SystemMessageBodyFormatting: MessageFormatting {
    /// Formats a system message into a string.
    ///
    /// - Parameter message: The `ChatMessage` instance to format.
    /// - Returns: A `String` representing the formatted system message.
    func format(_ message: ChatMessage) -> String

    /// The span of the actor's name inside `format(_:)`'s output, for a row that names one
    /// and styles it apart from the rest of the sentence — "Adam" in "Adam pinned: …".
    ///
    /// - Parameter message: The system message being rendered.
    /// - Returns: The name's range, or `nil` for a row drawn as one uniform run.
    func emphasizedNameRange(in message: ChatMessage) -> NSRange?
}

public extension SystemMessageBodyFormatting {
    /// A row is one uniform run unless the formatter says otherwise, so a custom formatter
    /// written against the earlier protocol keeps compiling and renders as it did.
    func emphasizedNameRange(in message: ChatMessage) -> NSRange? { nil }
}

/// Default implementation for formatting system messages.
open class SystemMessageBodyFormatter: SystemMessageBodyFormatting {

    /// Initialize a new system message formatter
    public init() {}

    /// Formats a system message based on its body content.
    ///
    /// - Parameter message: The system message to format
    /// - Returns: A formatted string describing the system message
    open func format(_ message: ChatMessage) -> String {
        // System messages use the message body to identify the type
        // The message metadata may contain additional information (e.g., member IDs)
        let body = message.body

        // Get the owner's display name
        var owner: String {
            self.owner(of: message)
        }

        // Extract member IDs from metadata if available
        var members: String {
            if let metadata = message.metadata,
               let data = metadata.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let memberIds = json["m"] as? [UserId] {
                return memberIds.compactMap { displayName(userId: $0) ?? "+\($0)" }.joined(separator: ", ")
            }
            return ""
        }


        // Extract disappearing message time from metadata if available
        var disappearingTime: String {
            guard let metadata = message.metadata,
                  let disappearingMetadata = SystemMessageMetadata.DisappearingMessage.from(jsonString: metadata),
                  let timeInterval = disappearingMetadata.toTimeInterval() else {
                return ""
            }

            if timeInterval == 0 {
                return L10n.System.Message.disableDisappearingMessages(owner)
            } else {
                let formattedTime = SceytChatUIKit.shared.formatters.timeIntervalFormatter.format(timeInterval)
                return L10n.System.Message.setDisappearingMessageTime(owner, formattedTime)
            }
        }

        // Format the system message based on its type
        switch body {
        case "CG": // createGroup
            let name = displayName(userId: message.user.id) ?? message.user.displayName
            return L10n.System.Message.createGroup(name)
        case "CC": // createChannel
            let name = displayName(userId: message.user.id) ?? message.user.displayName
            return L10n.System.Message.createChannel(name)
        case "AM": // addGroupMember
            return L10n.System.Message.addGroupMember(owner, members)
        case "RM": // removeGroupMember
            return L10n.System.Message.removeGroupMember(owner, members)
        case "LG": // leaveGroup
            return L10n.System.Message.leaveGroup(owner)
        case "JL": // joinByInviteLink
            return L10n.System.Message.joinByInviteLink(owner)
        case ChatMessage.SystemMessageType.pinnedMessage: // "PM"
            return pinnedMessage(message, owner: owner)
        case "ADM": // setDisappearingMessageTime
            return disappearingTime
        default:
            // For unknown system message types, return the body as-is
            return body
        }
    }

    /// The display name of a user id, "You" for this user.
    open func displayName(userId: UserId) -> String? {
        if userId == SceytChatUIKit.shared.currentUserId {
            return L10n.User.current
        }
        return SceytChatUIKit.shared.formatters.userNameFormatter.format(.init(id: userId))
    }

    /// The name of whoever the row is about — the one who pinned, added, left.
    open func owner(of message: ChatMessage) -> String {
        // An outgoing message is this user's by definition, and that is checked before
        // the id: a system message this device has just created and not yet had echoed
        // back carries no user at all, which would otherwise render the row with the
        // name missing — " pinned: …".
        if !message.incoming || message.user.id == SceytChatUIKit.shared.currentUserId {
            return L10n.User.current
        }
        return displayName(userId: message.user.id) ?? message.user.displayName
    }

    /// The pinned-message row names its actor and draws that name in its own font, so the
    /// cell needs the name's range in the formatted sentence. Every other type is drawn as
    /// one run and returns `nil` through the protocol's default.
    ///
    /// Searched rather than assumed to be a prefix — the templates are localized, and the
    /// name is not first in every language. The first match is the one taken: where the
    /// name does lead the sentence that is the name itself, even when the quoted body
    /// happens to repeat it.
    open func emphasizedNameRange(in message: ChatMessage) -> NSRange? {
        guard message.body == ChatMessage.SystemMessageType.pinnedMessage else { return nil }
        let name = owner(of: message)
        guard !name.isEmpty else { return nil }
        let text = format(message)
        guard let range = text.range(of: name) else { return nil }
        return NSRange(range, in: text)
    }

    /// "Adam pinned: \"See you at 6\"" for a message with a body, "Adam pinned a photo" and
    /// friends for one without.
    ///
    /// Rendered from the pinned message itself — the system message links it through
    /// `parentMessageId`, and `ChannelPinnedMessageProvider.sendPinSystemMessage` makes sure
    /// the link is there on the sender's own copy too, not only after the server echo.
    open func pinnedMessage(_ message: ChatMessage, owner: String) -> String {
        guard let parent = message.parent else {
            // The pinned message is not in the store — never fetched on this device, or
            // swept by a clear-history. Still says who did what.
            return L10n.System.Message.pinnedMessage(owner)
        }

        // A poll's body is its question, so it has to be checked before the body or it
        // renders as a bare sentence with no hint that it is a poll. Matched on the type as
        // well as the payload for the same reason `PinnedMessageBodyFormatter.body` does:
        // a parent stub carries no `PollDetails`.
        if parent.poll != nil || parent.type == ChatMessage.MessageType.poll {
            return L10n.System.Message.pinnedPoll(owner)
        }

        let body = previewBody(parent.body)
        if !body.isEmpty {
            return L10n.System.Message.pinnedBody(owner, body)
        }

        // The same type literals `AttachmentNameFormatter` switches on. Each gets its own
        // string rather than being interpolated into one "%@ pinned a %@" template — the
        // article and the noun form do not survive that in other languages.
        switch parent.attachments?.first?.type {
        case "image": return L10n.System.Message.pinnedPhoto(owner)
        case "video": return L10n.System.Message.pinnedVideo(owner)
        case "voice": return L10n.System.Message.pinnedVoice(owner)
        case "file": return L10n.System.Message.pinnedFile(owner)
        default: return L10n.System.Message.pinnedMessage(owner)
        }
    }

    /// Collapses the pinned body onto one line and caps its length.
    ///
    /// `SystemMessageCell` is `numberOfLines = 0` and measures against whatever string it is
    /// handed, so an uncapped body would grow the system row without limit.
    open func previewBody(_ body: String, limit: Int = 100) -> String {
        let singleLine = body
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard singleLine.count > limit else { return singleLine }
        return singleLine.prefix(limit).trimmingCharacters(in: .whitespaces) + "\u{2026}"
    }
}
