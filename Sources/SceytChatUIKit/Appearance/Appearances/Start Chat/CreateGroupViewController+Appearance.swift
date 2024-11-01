//
//  CreateGroupViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension CreateGroupViewController: AppearanceProviding {
    public static var appearance = Appearance(
        navigationBarAppearance: NavigationBarAppearance.appearance,
        backgroundColor: .background,
        detailsViewAppearance: Components.createGroupDetailsView.appearance,
        separatorViewAppearance: .init(
            reference: Components.separatorHeaderView.appearance,
            title: L10n.Channel.New.userSectionTitle
        ),
        userCellAppearance: Components.userCell.appearance,
        imageCropperAppearance: Components.imageCropperViewController.appearance
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, NavigationBarAppearance>
        public var navigationBarAppearance: NavigationBarAppearance
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, CreateGroupViewController.DetailsView.Appearance>
        public var detailsViewAppearance: CreateGroupViewController.DetailsView.Appearance
        
        @Trackable<Appearance, SeparatorHeaderView.Appearance>
        public var separatorViewAppearance: SeparatorHeaderView.Appearance
        
        @Trackable<Appearance, UserCell.Appearance>
        public var userCellAppearance: UserCell.Appearance
        
        @Trackable<Appearance, ImageCropperViewController.Appearance>
        public var imageCropperAppearance: ImageCropperViewController.Appearance
        
        public init(
            navigationBarAppearance: NavigationBarAppearance,
            backgroundColor: UIColor,
            detailsViewAppearance: CreateGroupViewController.DetailsView.Appearance,
            separatorViewAppearance: SeparatorHeaderView.Appearance,
            userCellAppearance: UserCell.Appearance,
            imageCropperAppearance: ImageCropperViewController.Appearance
        ){
            self._navigationBarAppearance = Trackable(value: navigationBarAppearance)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._detailsViewAppearance = Trackable(value: detailsViewAppearance)
            self._separatorViewAppearance = Trackable(value: separatorViewAppearance)
            self._userCellAppearance = Trackable(value: userCellAppearance)
            self._imageCropperAppearance = Trackable(value: imageCropperAppearance)
        }
        
        public init(
            reference: CreateGroupViewController.Appearance,
            navigationBarAppearance: NavigationBarAppearance? = nil,
            backgroundColor: UIColor? = nil,
            detailsViewAppearance: CreateGroupViewController.DetailsView.Appearance? = nil,
            separatorViewAppearance: SeparatorHeaderView.Appearance? = nil,
            userCellAppearance: UserCell.Appearance? = nil,
            imageCropperAppearance: ImageCropperViewController.Appearance? = nil
        ) {
            self._navigationBarAppearance = Trackable(reference: reference, referencePath: \.navigationBarAppearance)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._detailsViewAppearance = Trackable(reference: reference, referencePath: \.detailsViewAppearance)
            self._separatorViewAppearance = Trackable(reference: reference, referencePath: \.separatorViewAppearance)
            self._userCellAppearance = Trackable(reference: reference, referencePath: \.userCellAppearance)
            self._imageCropperAppearance = Trackable(reference: reference, referencePath: \.imageCropperAppearance)
            
            if let navigationBarAppearance { self.navigationBarAppearance = navigationBarAppearance }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let detailsViewAppearance { self.detailsViewAppearance = detailsViewAppearance }
            if let separatorViewAppearance { self.separatorViewAppearance = separatorViewAppearance }
            if let userCellAppearance { self.userCellAppearance = userCellAppearance }
            if let imageCropperAppearance { self.imageCropperAppearance = imageCropperAppearance }
        }
    }
}
