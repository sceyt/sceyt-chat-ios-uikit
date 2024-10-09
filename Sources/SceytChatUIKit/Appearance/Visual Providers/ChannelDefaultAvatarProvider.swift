//
//  ChannelDefaultAvatarProvider.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public struct ChannelDefaultAvatarProvider: ChannelAvatarProviding {
    public func provideVisual(for channel: ChatChannel) -> AvatarRepresentation {
        switch channel.channelType {
        case .direct: .image(channel.peer?.defaultAvatar)
        case .group: .initialsAppearance(InitialsBuilderAppearance())
        case .broadcast: .initialsAppearance(InitialsBuilderAppearance())
        }
    }
}
