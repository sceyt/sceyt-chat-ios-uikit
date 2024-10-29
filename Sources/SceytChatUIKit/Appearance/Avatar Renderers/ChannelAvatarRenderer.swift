//
//  ChannelAvatarRenderer.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 29.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

public class ChannelAvatarRenderer: ChannelAvatarRendering {
    
    var size = Components.avatarBuilder.avatarDefaultSize
    
    public init() {}
    
    public func render(
        _ channel: ChatChannel,
        with appearance: AvatarAppearance,
        into imagePresentable: ImagePresentable
    ) -> Cancellable? {
        let avatarRepresentation = SceytChatUIKit.shared.visualProviders.channelDefaultAvatarProvider.provideVisual(for: channel)
        
        if let view = imagePresentable as? UIView {
            view.backgroundColor = appearance.backgroundColor
            view.clipsToBounds = true
            view.contentMode = .scaleAspectFill
            
            imagePresentable.shape = appearance.shape
        }
        
        return switch avatarRepresentation {
        case .image(let image):
            Components.avatarBuilder.loadAvatar(
                into: imagePresentable,
                for: channel,
                defaultImage: image,
                size: size
            )
        case .initialsAppearance(let initialsAppearance):
            Components.avatarBuilder.loadAvatar(
                into: imagePresentable,
                for: channel,
                appearance: initialsAppearance,
                size: size
            )
        }
    }
    
    public func render(
        _ channel: ChatChannel,
        with appearance: AvatarAppearance,
        into imagePresentable: ImagePresentable,
        size: CGSize
    ) -> Cancellable? {
        self.size = size
        return render(channel, with: appearance, into: imagePresentable)
    }
    
    public func render(
        _ channel: ChatChannel,
        completion: @escaping (UIImage?) -> Void
    ) -> Cancellable? {
        let avatarRepresentation = SceytChatUIKit.shared.visualProviders.channelDefaultAvatarProvider.provideVisual(for: channel)
                
        return switch avatarRepresentation {
        case .image(let image):
            Components.avatarBuilder.loadAvatar(
                for: channel,
                defaultImage: image,
                size: size,
                avatar: completion
            )
        case .initialsAppearance(let initialsAppearance):
            Components.avatarBuilder.loadAvatar(
                for: channel,
                appearance: initialsAppearance,
                size: size,
                avatar: completion
            )
        }
    }
}
