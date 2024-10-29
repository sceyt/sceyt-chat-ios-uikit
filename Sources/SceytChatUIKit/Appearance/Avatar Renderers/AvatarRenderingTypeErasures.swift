//
//  AnyUserAvatarRendering.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 29.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

// MARK: - UserAvatarRendering

/// A type-erased wrapper for any `UserAvatarRendering` implementation.
///
/// `AnyUserAvatarRendering` allows you to store and use different types that conform
/// to `UserAvatarRendering` without exposing their concrete types. This abstraction
/// ensures flexibility when handling various rendering strategies for user avatars.
public struct AnyUserAvatarRendering: UserAvatarRendering {
    
    /// A closure that holds the rendering logic for the wrapped `UserAvatarRendering` instance.
    private let _render: (ChatUser, AvatarAppearance, ImagePresentable) -> Cancellable?
    
    /// Creates a type-erased wrapper around a given `UserAvatarRendering` instance.
    ///
    /// - Parameter renderer: A concrete instance conforming to `UserAvatarRendering`.
    public init<Renderer: UserAvatarRendering>(
        _ renderer: Renderer
    ) {
        self._render = renderer.render
    }
    
    /// Renders a user avatar with the given input, appearance, and target view.
    ///
    /// - Parameters:
    ///   - input: The `ChatUser` instance containing user-related data for rendering.
    ///   - appearance: The `AvatarAppearance` instance used to customize the avatar.
    ///   - view: A view conforming to `ImagePresentable` where the avatar will be rendered.
    /// - Returns: A `Cancellable?` that can be used to cancel the rendering task, if needed.
    public func render(
        _ input: ChatUser,
        with appearance: AvatarAppearance,
        into view: ImagePresentable
    ) -> Cancellable? {
        return _render(input, appearance, view)
    }
}

// MARK: - ChannelAvatarRendering

/// A type-erased wrapper for any `ChannelAvatarRendering` implementation.
///
/// `AnyChannelAvatarRendering` allows you to store and work with different types
/// conforming to `ChannelAvatarRendering` without exposing their concrete types.
/// This abstraction simplifies handling multiple rendering strategies for channel avatars.
public struct AnyChannelAvatarRendering: ChannelAvatarRendering {
    
    /// A closure that holds the rendering logic for the primary render method.
    private let _render: (ChatChannel, AvatarAppearance, ImagePresentable) -> Cancellable?
    
    /// A closure that holds the rendering logic for the size-specific render method.
    private let _renderWithSize: (ChatChannel, AvatarAppearance, ImagePresentable, CGSize) -> Cancellable?
    
    /// A closure that holds the rendering logic for the completion-based render method.
    private let _renderWithCompletion: (ChatChannel, @escaping (UIImage?) -> Void) -> Cancellable?
    
    /// Creates a type-erased wrapper around a given `ChannelAvatarRendering` instance.
    ///
    /// - Parameter renderer: A concrete instance conforming to `ChannelAvatarRendering`.
    public init<Renderer: ChannelAvatarRendering>(
        _ renderer: Renderer
    ) {
        self._render = renderer.render
        self._renderWithSize = renderer.render
        self._renderWithCompletion = renderer.render
    }
    
    /// Renders a channel avatar with the given input, appearance, and target view.
    ///
    /// - Parameters:
    ///   - input: The `ChatChannel` instance containing channel-related data for rendering.
    ///   - appearance: The `AvatarAppearance` instance used to customize the avatar.
    ///   - view: A view conforming to `ImagePresentable` where the avatar will be rendered.
    /// - Returns: A `Cancellable?` that can be used to cancel the rendering task, if needed.
    public func render(
        _ input: ChatChannel,
        with appearance: AvatarAppearance,
        into view: ImagePresentable
    ) -> Cancellable? {
        return _render(input, appearance, view)
    }
    
    /// Renders a channel avatar with the given input, appearance, target view, and size.
    ///
    /// - Parameters:
    ///   - input: The `ChatChannel` instance containing channel-related data for rendering.
    ///   - appearance: The `AvatarAppearance` instance used to customize the avatar.
    ///   - view: A view conforming to `ImagePresentable` where the avatar will be rendered.
    ///   - size: The desired size for the avatar rendering.
    /// - Returns: A `Cancellable?` that can be used to cancel the rendering task, if needed.
    public func render(
        _ input: ChatChannel,
        with appearance: AvatarAppearance,
        into view: ImagePresentable,
        size: CGSize
    ) -> Cancellable? {
        return _renderWithSize(input, appearance, view, size)
    }
    
    /// Renders a channel avatar asynchronously and returns the result via a completion handler.
    ///
    /// - Parameters:
    ///   - input: The `ChatChannel` instance containing channel-related data for rendering.
    ///   - completion: A closure called with the rendered `UIImage?` result.
    /// - Returns: A `Cancellable?` that can be used to cancel the rendering task, if needed.
    public func render(
        _ input: ChatChannel,
        completion: @escaping (UIImage?) -> Void
    ) -> Cancellable? {
        return _renderWithCompletion(input, completion)
    }
}
