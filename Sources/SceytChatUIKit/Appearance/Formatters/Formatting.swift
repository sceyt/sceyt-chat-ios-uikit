//
//  Formatting.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 03.09.24.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

/// A generic protocol that defines a method for formatting a given input into a `String`.
public protocol Formatting {
    associatedtype U
    associatedtype V
    /// Formats the given input into a `String`.
    ///
    /// - Parameter input: The input to format.
    /// - Returns: A formatted output.
    func format(_ input: U) -> V
}

/// A protocol for formatting `ChatUser` objects.
public protocol UserFormatting: Formatting {
    /// Formats the given user into a `String`.
    ///
    /// - Parameter user: The user to format.
    /// - Returns: A formatted `String` representing the user.
    func format(_ user: ChatUser) -> String
    
}

/// A protocol for formatting `Date` objects.
public protocol DateFormatting: Formatting {
    /// Formats the given date into a `String`.
    ///
    /// - Parameter date: The date to format.
    /// - Returns: A formatted `String` representing the date.
    func format(_ date: Date) -> String
}

/// A protocol for formatting `ChatChannel` objects.
public protocol ChannelFormatting: Formatting {
    /// Formats the given channel into a `String`.
    ///
    /// - Parameter channel: The channel to format.
    /// - Returns: A formatted `String` representing the channel.
    func format(_ channel: ChatChannel) -> String
}

/// A protocol for formatting unsigned integers (`UInt64`).
public protocol UIntFormatting: Formatting {
    /// Formats the given unsigned integer into a `String`.
    ///
    /// - Parameter count: The unsigned integer to format.
    /// - Returns: A formatted `String` representing the count.
    func format(_ count: UInt64) -> String
}

/// A protocol for formatting strings, typically initials.
public protocol StringFormatting {
    /// Formats the given initials string into a new `String`.
    ///
    /// - Parameter initials: The initials string to format.
    /// - Returns: A formatted `String`.
    func format(_ initials: String) -> String
}

/// A protocol for formatting `TimeInterval` values.
public protocol TimeIntervalFormatting {
    /// Formats the given time interval into a `String`.
    ///
    /// - Parameter timeInterval: The time interval to format.
    /// - Returns: A formatted `String` representing the time interval.
    func format(_ timeInterval: TimeInterval) -> String
}

/// A protocol that defines formatting behavior for chat message attachments.
public protocol AttachmentFormatting: Formatting {
    /// Formats a chat message attachment into a string.
    ///
    /// - Parameter attachment: The `ChatMessage.Attachment` instance to format.
    /// - Returns: A `String` representing the formatted attachment.
    func format(_ attachment: ChatMessage.Attachment) -> String
}

/// A protocol that defines formatting behavior for chat message.
public protocol MessageFormatting: Formatting {
    /// Formats a chat message attachment into a string.
    ///
    /// - Parameter attachment: The `ChatMessage` instance to format.
    /// - Returns: A `String` representing the formatted attachment.
    func format(_ message: ChatMessage) -> String
}

/// A protocol that defines formatting behavior for reaction.
public protocol ReactionFormatting: Formatting {
    /// Formats a chat message attachment into a string.
    ///
    /// - Parameter reaction: The `ChatMessage.Reaction` instance to format.
    /// - Returns: A `String` representing the formatted reaction.
    func format(_ reaction: ChatMessage.Reaction) -> String
}

// MARK: - Message Body Formatting

/// A protocol that defines formatting behavior for message bodies with content items.
public protocol MessageBodyFormatting: Formatting {
    /// Formats a message body into an attributed string along with associated content items.
    ///
    /// - Parameter attributes: The `MessageBodyFormatterAttributes` instance containing the attributes needed for formatting.
    /// - Returns: A tuple containing an `NSAttributedString` representing the formatted message body and an array of `MessageLayoutModel.ContentItem`.
    func format(_ attributes: MessageBodyFormatterAttributes) -> (NSAttributedString, [MessageLayoutModel.ContentItem])
}

/// A protocol that defines formatting behavior for message bodies.
public protocol LastMessageBodyFormatting: Formatting {
    /// Formats a message body into an attributed string.
    ///
    /// - Parameter attributes: The `LastMessageBodyFormatterAttributes` instance containing the attributes needed for formatting.
    /// - Returns: An `NSAttributedString` representing the formatted message body.
    func format(_ attributes: LastMessageBodyFormatterAttributes) -> NSAttributedString
}

/// A protocol that defines formatting behavior for replied message bodies.
public protocol RepliedMessageBodyFormatting: Formatting {
    /// Formats a replied message body into an attributed string.
    ///
    /// - Parameter attributes: The `RepliedMessageBodyFormatterAttributes` instance containing the attributes needed for formatting.
    /// - Returns: An `NSAttributedString` representing the formatted replied message body.
    func format(_ attributes: RepliedMessageBodyFormatterAttributes) -> NSAttributedString
}

/// A protocol that defines formatting behavior for edited message bodies.
public protocol EditMessageBodyFormatting: Formatting {
    /// Formats an edited message body into an attributed string.
    ///
    /// - Parameter attributes: The `EditMessageBodyFormatterAttributes` instance containing the attributes needed for formatting.
    /// - Returns: An `NSAttributedString` representing the formatted edited message body.
    func format(_ attributes: EditMessageBodyFormatterAttributes) -> NSAttributedString
}

/// A protocol that defines formatting behavior for reply message bodies.
public protocol ReplyMessageBodyFormatting: Formatting {
    /// Formats a reply message body into an attributed string.
    ///
    /// - Parameter attributes: The `ReplyMessageBodyFormatterAttributes` instance containing the attributes needed for formatting.
    /// - Returns: An `NSAttributedString` representing the formatted reply message body.
    func format(_ attributes: ReplyMessageBodyFormatterAttributes) -> NSAttributedString
}

/// A protocol that defines formatting behavior for draft message bodies.
public protocol DraftMessageBodyFormatting: Formatting {
    /// Formats a draft message body into an attributed string.
    ///
    /// - Parameter attributes: The `DraftMessageBodyFormatterAttributes` instance containing the attributes needed for formatting.
    /// - Returns: An `NSAttributedString` representing the formatted draft message body.
    func format(_ attributes: DraftMessageBodyFormatterAttributes) -> NSAttributedString
}
