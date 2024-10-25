//
//  CreateChannelViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension CreateChannelViewController: AppearanceProviding {
    public static var appearance = Appearance(
        navigationBarAppearance: NavigationBarAppearance.appearance,
        backgroundColor: .background,
        detailsViewAppearance: .init(
            reference: CreateGroupViewController.DetailsView.appearance,
            nameTextFieldAppearance: .init(
                reference: CreateGroupViewController.DetailsView.appearance.nameTextFieldAppearance,
                placeholder: L10n.Channel.Subject.Channel.placeholder
            )
        )
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, NavigationBarAppearance.Appearance>
        public var navigationBarAppearance: NavigationBarAppearance.Appearance
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, CreateGroupViewController.DetailsView.Appearance>
        public var detailsViewAppearance: CreateGroupViewController.DetailsView.Appearance
        
        public init(
            navigationBarAppearance: NavigationBarAppearance.Appearance,
            backgroundColor: UIColor,
            detailsViewAppearance: CreateGroupViewController.DetailsView.Appearance
        ){
            self._navigationBarAppearance = Trackable(value: navigationBarAppearance)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._detailsViewAppearance = Trackable(value: detailsViewAppearance)
        }
        
        public init(
            reference: CreateChannelViewController.Appearance,
            navigationBarAppearance: NavigationBarAppearance.Appearance? = nil,
            backgroundColor: UIColor? = nil,
            detailsViewAppearance: CreateGroupViewController.DetailsView.Appearance? = nil
        ) {
            self._navigationBarAppearance = Trackable(reference: reference, referencePath: \.navigationBarAppearance)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._detailsViewAppearance = Trackable(reference: reference, referencePath: \.detailsViewAppearance)
            
            if let navigationBarAppearance { self.navigationBarAppearance = navigationBarAppearance }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let detailsViewAppearance { self.detailsViewAppearance = detailsViewAppearance }
        }
    }
}
