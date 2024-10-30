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
            view.clipsToBounds = true
            view.contentMode = .scaleAspectFill
            
            imagePresentable.shape = appearance.shape
        }
        
        switch avatarRepresentation {
        case .image(let image):
            return Components.avatarBuilder.loadAvatar(
                into: imagePresentable,
                for: channel,
                defaultImage: image,
                size: size
            )
        case .initialsAppearance(var initialsAppearance):
            initialsAppearance?.backgroundColor = appearance.backgroundColor
            return Components.avatarBuilder.loadAvatar(
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
        with appearance: AvatarAppearance,
        completion: @escaping (UIImage?) -> Void
    ) -> Cancellable? {
        let avatarRepresentation = SceytChatUIKit.shared.visualProviders.channelDefaultAvatarProvider.provideVisual(for: channel)
                
        switch avatarRepresentation {
        case .image(let image):
            return Components.avatarBuilder.loadAvatar(
                for: channel,
                defaultImage: image,
                size: size,
                avatar: completion
            )
        case .initialsAppearance(var initialsAppearance):
            initialsAppearance?.backgroundColor = appearance.backgroundColor
            return Components.avatarBuilder.loadAvatar(
                for: channel,
                appearance: initialsAppearance,
                size: size,
                avatar: completion
            )
        }
    }
}
