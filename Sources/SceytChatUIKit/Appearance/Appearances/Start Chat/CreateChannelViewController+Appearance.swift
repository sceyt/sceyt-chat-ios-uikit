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
        ),
        imageCropperAppearance: Components.imageCropperViewController.appearance
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, NavigationBarAppearance>
        public var navigationBarAppearance: NavigationBarAppearance
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, CreateGroupViewController.DetailsView.Appearance>
        public var detailsViewAppearance: CreateGroupViewController.DetailsView.Appearance
        
        @Trackable<Appearance, ImageCropperViewController.Appearance>
        public var imageCropperAppearance: ImageCropperViewController.Appearance
        
        public init(
            navigationBarAppearance: NavigationBarAppearance,
            backgroundColor: UIColor,
            detailsViewAppearance: CreateGroupViewController.DetailsView.Appearance,
            imageCropperAppearance: ImageCropperViewController.Appearance
        ){
            self._navigationBarAppearance = Trackable(value: navigationBarAppearance)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._detailsViewAppearance = Trackable(value: detailsViewAppearance)
            self._imageCropperAppearance = Trackable(value: imageCropperAppearance)
        }
        
        public init(
            reference: CreateChannelViewController.Appearance,
            navigationBarAppearance: NavigationBarAppearance? = nil,
            backgroundColor: UIColor? = nil,
            detailsViewAppearance: CreateGroupViewController.DetailsView.Appearance? = nil,
            imageCropperAppearance: ImageCropperViewController.Appearance? = nil
        ) {
            self._navigationBarAppearance = Trackable(reference: reference, referencePath: \.navigationBarAppearance)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._detailsViewAppearance = Trackable(reference: reference, referencePath: \.detailsViewAppearance)
            self._imageCropperAppearance = Trackable(reference: reference, referencePath: \.imageCropperAppearance)
            
            if let navigationBarAppearance { self.navigationBarAppearance = navigationBarAppearance }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let detailsViewAppearance { self.detailsViewAppearance = detailsViewAppearance }
            if let imageCropperAppearance { self.imageCropperAppearance = imageCropperAppearance }
        }
    }
}
