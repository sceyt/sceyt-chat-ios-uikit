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
    /// Formats the given input into a `String`.
    ///
    /// - Parameter input: The input to format.
    /// - Returns: A formatted `String`.
    func format(_ input: U) -> String
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
