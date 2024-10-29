//
//  AvatarRendering.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 28.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

public protocol AvatarRendering {
    
    associatedtype Input
    
    func render(
        _ input: Input,
        with appearance: AvatarAppearance,
        into view: ImagePresentable
    ) -> Cancellable?
}

public protocol UserAvatarRendering: AvatarRendering {
    func render(
        _ input: ChatUser,
        with appearance: AvatarAppearance,
        into view: ImagePresentable
    ) -> Cancellable?
}

public protocol ChannelAvatarRendering: AvatarRendering {
    func render(
        _ input: ChatChannel,
        with appearance: AvatarAppearance,
        into view: ImagePresentable
    ) -> Cancellable?
    
    func render(
        _ input: ChatChannel,
        with appearance: AvatarAppearance,
        into view: ImagePresentable,
        size: CGSize
    ) -> Cancellable?
    
    func render(
        _ input: ChatChannel,
        completion: @escaping (UIImage?) -> Void
    ) -> Cancellable?
}
