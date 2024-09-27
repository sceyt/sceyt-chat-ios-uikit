//
//  VisualProviderProtocolTypeErasures.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

/// A type-erased wrapper for any `UserAvatarProviding` implementation.
/// This allows instances conforming to `UserAvatarProviding` to be used
/// without exposing their concrete types.
public class AnyUserAvatarProviding: UserAvatarProviding {
    private let _provideVisual: (ChatUser) -> AvatarRepresentation
    
    /// Initializes the type-erased wrapper with a specific `UserAvatarProviding` instance.
    ///
    /// - Parameter provider: The concrete provider to be wrapped.
    public init<P: UserAvatarProviding>(_ provider: P) {
        self._provideVisual = provider.provideVisual(for:)
    }
    
    /// Provides an avatar representation for the specified user.
    ///
    /// - Parameter user: The user for whom to provide the avatar.
    /// - Returns: An `AvatarRepresentation` representing the user's avatar.
    public func provideVisual(for user: ChatUser) -> AvatarRepresentation {
        return _provideVisual(user)
    }
}

/// A type-erased wrapper for any `ChannelAvatarProviding` implementation.
/// This allows instances conforming to `ChannelAvatarProviding` to be used
/// without exposing their concrete types.
public class AnyChannelAvatarProviding: ChannelAvatarProviding {
    private let _provideVisual: (ChatChannel) -> AvatarRepresentation
    
    /// Initializes the type-erased wrapper with a specific `ChannelAvatarProviding` instance.
    ///
    /// - Parameter provider: The concrete provider to be wrapped.
    public init<P: ChannelAvatarProviding>(_ provider: P) {
        self._provideVisual = provider.provideVisual(for:)
    }
    
    /// Provides an avatar representation for the specified channel.
    ///
    /// - Parameter channel: The channel for which to provide the avatar.
    /// - Returns: An `AvatarRepresentation` representing the channel's avatar.
    public func provideVisual(for channel: ChatChannel) -> AvatarRepresentation {
        return _provideVisual(channel)
    }
}

/// A type-erased wrapper for any `ChannelURIValidationMessageProviding` implementation.
/// This allows instances conforming to `ChannelURIValidationMessageProviding` to be used
/// without exposing their concrete types.
public class AnyChannelURIValidationMessageProviding: ChannelURIValidationMessageProviding {
    private let _provideVisual: (URIValidationType) -> String
    
    /// Initializes the type-erased wrapper with a specific `ChannelURIValidationMessageProviding` instance.
    ///
    /// - Parameter provider: The concrete provider to be wrapped.
    public init<P: ChannelURIValidationMessageProviding>(_ provider: P) {
        self._provideVisual = provider.provideVisual(for:)
    }
    
    /// Provides a validation message for the specified URI validation type.
    ///
    /// - Parameter type: The type of URI validation result.
    /// - Returns: A `String` containing the validation message.
    public func provideVisual(for type: URIValidationType) -> String {
        return _provideVisual(type)
    }
}

/// A type-erased wrapper for any `AttachmentIconProviding` implementation.
/// This allows instances conforming to `AttachmentIconProviding` to be used
/// without exposing their concrete types.
public class AnyAttachmentIconProviding: AttachmentIconProviding {
    private let _provideVisual: (ChatMessage.Attachment) -> UIImage?
    
    /// Initializes the type-erased wrapper with a specific `AttachmentIconProviding` instance.
    ///
    /// - Parameter provider: The concrete provider to be wrapped.
    public init<P: AttachmentIconProviding>(_ provider: P) {
        self._provideVisual = provider.provideVisual(for:)
    }
    
    /// Provides an icon image for the specified attachment.
    ///
    /// - Parameter attachment: The attachment for which to provide the icon.
    /// - Returns: An optional `UIImage` representing the attachment icon.
    public func provideVisual(for attachment: ChatMessage.Attachment) -> UIImage? {
        return _provideVisual(attachment)
    }
}

/// A type-erased wrapper for any `ConnectionStateProviding` implementation.
/// This allows instances conforming to `ConnectionStateProviding` to be used
/// without exposing their concrete types.
public class AnyConnectionStateProviding: ConnectionStateProviding {
    private let _provideVisual: (ConnectionState) -> String
    
    /// Initializes the type-erased wrapper with a specific `ConnectionStateProviding` instance.
    ///
    /// - Parameter provider: The concrete provider to be wrapped.
    public init<P: ConnectionStateProviding>(_ provider: P) {
        self._provideVisual = provider.provideVisual(for:)
    }
    
    /// Provides a text for the specified connection state.
    ///
    /// - Parameter state: The connection state for which to provide the text.
    /// - Returns: A `String` representing the connection text.
    public func provideVisual(for state: ConnectionState) -> String {
        return _provideVisual(state)
    }
}
