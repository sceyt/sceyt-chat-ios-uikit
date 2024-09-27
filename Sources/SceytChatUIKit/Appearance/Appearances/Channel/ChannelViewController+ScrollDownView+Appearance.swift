//
//  ChannelViewController+ScrollDownView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 27.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelViewController.ScrollDownView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var unreadCountLabelAppearance: LabelAppearance = .init(foregroundColor: .onPrimary,
                                                                            font: Fonts.regular.withSize(12),
                                                                            backgroundColor: .accent)
        public lazy var icon: UIImage = .channelUnreadBubble
        
        // Initializer with default values
        public init(
            unreadCountLabelAppearance: LabelAppearance = .init(foregroundColor: .onPrimary,
                                                                font: Fonts.regular.withSize(12),
                                                                backgroundColor: .accent),
            icon: UIImage = .channelUnreadBubble
        ) {
            self.unreadCountLabelAppearance = unreadCountLabelAppearance
            self.icon = icon
        }
    }
}
