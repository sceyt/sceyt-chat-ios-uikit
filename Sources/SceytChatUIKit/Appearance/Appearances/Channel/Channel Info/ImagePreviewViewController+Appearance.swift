//
//  ImagePreviewViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ImagePreviewViewController: AppearanceProviding {
    public static var appearance = Appearance(
        navigationBarAppearance: {
            $0.shadowColor = .border
            return $0
        }(NavigationBarAppearance.appearance),
        backgroundColor: .background,
        channelNameFormatter: SceytChatUIKit.shared.formatters.channelNameFormatter
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, NavigationBarAppearance.Appearance>
        public var navigationBarAppearance: NavigationBarAppearance.Appearance
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, any ChannelFormatting>
        public var channelNameFormatter: any ChannelFormatting
        
        public init(
            navigationBarAppearance: NavigationBarAppearance.Appearance,
            backgroundColor: UIColor,
            channelNameFormatter: any ChannelFormatting
        ) {
            self._navigationBarAppearance = Trackable(value: navigationBarAppearance)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._channelNameFormatter = Trackable(value: channelNameFormatter)
        }
        
        public init(
            reference: ImagePreviewViewController.Appearance,
            navigationBarAppearance: NavigationBarAppearance.Appearance? = nil,
            backgroundColor: UIColor? = nil,
            channelNameFormatter: (any ChannelFormatting)? = nil
        ) {
            self._navigationBarAppearance = Trackable(reference: reference, referencePath: \.navigationBarAppearance)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._channelNameFormatter = Trackable(reference: reference, referencePath: \.channelNameFormatter)
            
            if let navigationBarAppearance { self.navigationBarAppearance = navigationBarAppearance }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let channelNameFormatter { self.channelNameFormatter = channelNameFormatter }
        }
    }
}
