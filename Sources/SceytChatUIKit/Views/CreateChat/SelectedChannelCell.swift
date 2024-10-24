//
//  SelectedChannelCell.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

open class SelectedChannelCell: SelectedBaseCell {
    open var channelData: ChatChannel! {
        didSet {
            label.text = appearance.titleFormatter.format(channelData)
            presenceView.isHidden = channelData.peer?.presence.state != .online
            imageTask = switch appearance.visualProvider.provideVisual(for: channelData) {
            case .image(let image):
                Components.avatarBuilder.loadAvatar(into: avatarView,
                                                    for: channelData,
                                                    defaultImage: image)
            case .initialsAppearance(let initialsAppearance):
                Components.avatarBuilder.loadAvatar(into: avatarView,
                                                    for: channelData,
                                                    appearance: initialsAppearance)
            }
        }
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        backgroundColor = appearance.backgroundColor
        label.font = appearance.labelAppearance.font
        label.textColor = appearance.labelAppearance.foregroundColor
        closeButton.setImage(appearance.removeIcon, for: .normal)
    }
}
