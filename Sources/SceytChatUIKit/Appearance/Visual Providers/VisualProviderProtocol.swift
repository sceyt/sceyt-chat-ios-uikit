//
//  VisualProviderProtocol.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 23.09.24.
//

import UIKit
import SceytChat

/// A protocol that defines a method for providing a visual representation for a given input.
public protocol VisualProviding {
    /// The type of input for which the visual will be provided.
    associatedtype Input
    /// The type of visual representation that will be provided.
    associatedtype Visual
    /// Provides a visual representation for the given input.
    ///
    /// - Parameter input: The input for which to provide the visual.
    /// - Returns: The visual representation of the input.
    func provideVisual(for input: Input) -> Visual
}

/// A protocol for providing avatar visuals for users.
public protocol UserAvatarProviding: VisualProviding {
    /// Provides an avatar representation for the specified user.
    ///
    /// - Parameter user: The user for whom to provide the avatar.
    /// - Returns: An `AvatarRepresentation` representing the user's avatar.
    func provideVisual(for user: ChatUser) -> AvatarRepresentation
}

/// A protocol for providing avatar visuals for channels.
public protocol ChannelAvatarProviding: VisualProviding {
    /// Provides an avatar representation for the specified channel.
    ///
    /// - Parameter channel: The channel for which to provide the avatar.
    /// - Returns: An `AvatarRepresentation` representing the channel's avatar.
    func provideVisual(for channel: ChatChannel) -> AvatarRepresentation
}

/// A protocol for providing validation messages for channel URIs.
public protocol ChannelURIValidationMessageProviding: VisualProviding {
    /// Provides a validation message for the specified URI validation type.
    ///
    /// - Parameter type: The type of URI validation result.
    /// - Returns: A `String` containing the validation message.
    func provideVisual(for type: URIValidationType) -> String
}

/// A protocol for providing icons for message attachments.
public protocol AttachmentIconProviding: VisualProviding {
    /// Provides an icon image for the specified attachment.
    ///
    /// - Parameter attachment: The attachment for which to provide the icon.
    /// - Returns: An optional `UIImage` representing the attachment icon.
    func provideVisual(for attachment: ChatMessage.Attachment) -> UIImage?
}

/// A protocol for providing text for connection state.
public protocol ConnectionStateProviding: VisualProviding {
    /// Provides a text for the specified connection state.
    ///
    /// - Parameter state: The connection state for which to provide the text.
    /// - Returns: A `String` representing the connection text.
    func provideVisual(for state: ConnectionState) -> String
}

/// A protocol for providing image for presence state.
public protocol PresenceStateIconProviding: VisualProviding {
    /// Provides an image for the specified presence state.
    ///
    /// - Parameter state: The presence state for which to provide the image.
    /// - Returns: A `UIImage` representing the icon.
    func provideVisual(for state: ChatUser.Presence.State) -> UIImage?
}

/// A protocol for providing color for given user.
public protocol UserColorProviding: VisualProviding {
    /// Provides a color for the specified user.
    ///
    /// - Parameter user: The user for whom to provide the color.
    /// - Returns: A `UIColor` representing the icon.
    func provideVisual(for user: ChatUser) -> UIColor
}

/// A protocol for providing name for given default marker.
public protocol DefaultMarkerTitleProviding: VisualProviding {
    /// Provides a name for the specified marker.
    ///
    /// - Parameter marker: The marker for whom to provide the color.
    /// - Returns: A `String` representing the icon.
    func provideVisual(for marker: DefaultMarker) -> String
}



// MARK: - Enums

/// An enumeration representing different types of avatar representations.
public enum AvatarRepresentation {
    /// An avatar represented by an image.
    ///
    /// - Parameter image: An optional `UIImage` for the avatar.
    case image(UIImage?)
    /// An avatar represented by initials appearance.
    ///
    /// - Parameter initialsAppearance: An optional `InitialsBuilderAppearance` for building initials.
    case initialsAppearance(InitialsBuilderAppearance?)
}

/// An enumeration representing the result types of URI validation.
public enum URIValidationType {
    /// The URI is free to use.
    case freeToUse
    /// The URI is already taken.
    case alreadyTaken
    /// The URI is too long.
    case tooLong
    /// The URI is too short.
    case tooShort
    /// The URI contains invalid characters.
    case invalidCharacters
}
