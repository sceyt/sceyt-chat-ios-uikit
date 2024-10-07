//
//  ChannelViewController+ScrollDownView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 27.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelViewController.ScrollDownView: AppearanceProviding {
    public static var appearance = Appearance(
        unreadCountLabelAppearance: LabelAppearance(
            foregroundColor: .onPrimary,
            font: Fonts.regular.withSize(12),
            backgroundColor: .accent
        ),
        icon: .channelUnreadBubble
    )
    
    public struct Appearance {
        @Trackable<Appearance, LabelAppearance>
        public var unreadCountLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, UIImage>
        public var icon: UIImage
        
        // Initializer with default values
        public init(
            unreadCountLabelAppearance: LabelAppearance,
            icon: UIImage
        ) {
            self._unreadCountLabelAppearance = Trackable(value: unreadCountLabelAppearance)
            self._icon = Trackable(value: icon)
        }
        
        public init(
            reference: ChannelViewController.ScrollDownView.Appearance,
            unreadCountLabelAppearance: LabelAppearance? = nil,
            icon: UIImage? = nil
        ) {
            self._unreadCountLabelAppearance = Trackable(reference: reference, referencePath: \.unreadCountLabelAppearance)
            self._icon = Trackable(reference: reference, referencePath: \.icon)
            
            if let unreadCountLabelAppearance { self.unreadCountLabelAppearance = unreadCountLabelAppearance }
            if let icon { self.icon = icon }
        }
    }
}
