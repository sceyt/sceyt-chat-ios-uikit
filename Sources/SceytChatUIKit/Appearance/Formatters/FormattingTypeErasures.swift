//
//  FormattingTypeErasures.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

/// A type-erased wrapper for any `UserFormatting` implementation.
/// This allows instances conforming to `UserFormatting` to be used
/// without exposing their concrete types.
public class AnyUserFormatting: UserFormatting {
    private let _format: (ChatUser) -> String
    
    /// Initializes the type-erased wrapper with a specific `UserFormatting` instance.
    ///
    /// - Parameter formatter: The concrete formatter to be wrapped.
    public init<F: UserFormatting>(_ formatter: F) {
        self._format = formatter.format
    }
    
    /// Formats the given user into a string.
    ///
    /// - Parameter user: The user to format.
    /// - Returns: A formatted string representing the user.
    public func format(_ user: ChatUser) -> String {
        return _format(user)
    }
}

/// A type-erased wrapper for any `DateFormatting` implementation.
/// This allows instances conforming to `DateFormatting` to be used
/// without exposing their concrete types.
public class AnyDateFormatting: DateFormatting {
    private let _format: (Date) -> String
    
    /// Initializes the type-erased wrapper with a specific `DateFormatting` instance.
    ///
    /// - Parameter formatter: The concrete formatter to be wrapped.
    public init<F: DateFormatting>(_ formatter: F) {
        self._format = formatter.format
    }
    
    /// Formats the given date into a string.
    ///
    /// - Parameter date: The date to format.
    /// - Returns: A formatted string representing the date.
    public func format(_ date: Date) -> String {
        return _format(date)
    }
}

/// A type-erased wrapper for any `ChannelFormatting` implementation.
/// This allows instances conforming to `ChannelFormatting` to be used
/// without exposing their concrete types.
public class AnyChannelFormatting: ChannelFormatting {
    private let _format: (ChatChannel) -> String
    
    /// Initializes the type-erased wrapper with a specific `ChannelFormatting` instance.
    ///
    /// - Parameter formatter: The concrete formatter to be wrapped.
    public init<F: ChannelFormatting>(_ formatter: F) {
        self._format = formatter.format
    }
    
    /// Formats the given channel into a string.
    ///
    /// - Parameter channel: The channel to format.
    /// - Returns: A formatted string representing the channel.
    public func format(_ channel: ChatChannel) -> String {
        return _format(channel)
    }
}

/// A type-erased wrapper for any `UIntFormatting` implementation.
/// This allows instances conforming to `UIntFormatting` to be used
/// without exposing their concrete types.
public class AnyUIntFormatting: UIntFormatting {
    private let _format: (UInt64) -> String
    
    /// Initializes the type-erased wrapper with a specific `UIntFormatting` instance.
    ///
    /// - Parameter formatter: The concrete formatter to be wrapped.
    public init<F: UIntFormatting>(_ formatter: F) {
        self._format = formatter.format
    }
    
    /// Formats the given unsigned integer into a string.
    ///
    /// - Parameter count: The unsigned integer to format.
    /// - Returns: A formatted string representing the count.
    public func format(_ count: UInt64) -> String {
        return _format(count)
    }
}

/// A type-erased wrapper for any `StringFormatting` implementation.
/// This allows instances conforming to `StringFormatting` to be used
/// without exposing their concrete types.
public class AnyStringFormatting: StringFormatting {
    private let _format: (String) -> String
    
    /// Initializes the type-erased wrapper with a specific `StringFormatting` instance.
    ///
    /// - Parameter formatter: The concrete formatter to be wrapped.
    public init<F: StringFormatting>(_ formatter: F) {
        self._format = formatter.format
    }
    
    /// Formats the given string (initials) into a new string.
    ///
    /// - Parameter initials: The initials string to format.
    /// - Returns: A formatted string.
    public func format(_ initials: String) -> String {
        return _format(initials)
    }
}

/// A type-erased wrapper for any `TimeIntervalFormatting` implementation.
/// This allows instances conforming to `TimeIntervalFormatting` to be used
/// without exposing their concrete types.
public class AnyTimeIntervalFormatting: TimeIntervalFormatting {
    private let _format: (TimeInterval) -> String
    
    /// Initializes the type-erased wrapper with a specific `TimeIntervalFormatting` instance.
    ///
    /// - Parameter formatter: The concrete formatter to be wrapped.
    public init<F: TimeIntervalFormatting>(_ formatter: F) {
        self._format = formatter.format
    }
    
    /// Formats the given time interval into a string.
    ///
    /// - Parameter timeInterval: The time interval to format.
    /// - Returns: A formatted string representing the time interval.
    public func format(_ timeInterval: TimeInterval) -> String {
        return _format(timeInterval)
    }
}

/// A type-erased wrapper for any `AttachmentFormatting` implementation.
/// This allows instances conforming to `AttachmentFormatting` to be used
/// without exposing their concrete types.
public class AnyAttachmentFormatting: AttachmentFormatting {
    private let _format: (ChatMessage.Attachment) -> String
    
    /// Initializes the type-erased wrapper with a specific `AttachmentFormatting` instance.
    ///
    /// - Parameter formatter: The concrete formatter to be wrapped.
    public init<F: AttachmentFormatting>(_ formatter: F) {
        self._format = formatter.format
    }
    
    /// Formats the given chat message attachment into a string.
    ///
    /// - Parameter attachment: The `ChatMessage.Attachment` instance to format.
    /// - Returns: A formatted string representing the attachment.
    public func format(_ attachment: ChatMessage.Attachment) -> String {
        return _format(attachment)
    }
}
