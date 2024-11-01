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
        backgroundColor: .clear,
        unreadCountLabelAppearance: LabelAppearance(
            foregroundColor: .onPrimary,
            font: Fonts.regular.withSize(12),
            backgroundColor: .accent
        ),
        icon: .channelUnreadBubble,
        unreadCountFormatter: SceytChatUIKit.shared.formatters.unreadCountFormatter
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var unreadCountLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, UIImage>
        public var icon: UIImage
        
        @Trackable<Appearance, any UIntFormatting>
        public var unreadCountFormatter: any UIntFormatting
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor,
            unreadCountLabelAppearance: LabelAppearance,
            icon: UIImage,
            unreadCountFormatter: any UIntFormatting
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._unreadCountLabelAppearance = Trackable(value: unreadCountLabelAppearance)
            self._icon = Trackable(value: icon)
            self._unreadCountFormatter = Trackable(value: unreadCountFormatter)
        }
        
        public init(
            reference: ChannelViewController.ScrollDownView.Appearance,
            backgroundColor: UIColor? = nil,
            unreadCountLabelAppearance: LabelAppearance? = nil,
            icon: UIImage? = nil,
            unreadCountFormatter: (any UIntFormatting)? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._unreadCountLabelAppearance = Trackable(reference: reference, referencePath: \.unreadCountLabelAppearance)
            self._icon = Trackable(reference: reference, referencePath: \.icon)
            self._unreadCountFormatter = Trackable(reference: reference, referencePath: \.unreadCountFormatter)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let unreadCountLabelAppearance { self.unreadCountLabelAppearance = unreadCountLabelAppearance }
            if let icon { self.icon = icon }
            if let unreadCountFormatter { self.unreadCountFormatter = unreadCountFormatter }
        }
    }
}
