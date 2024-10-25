//
//  ImageCropperViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ImageCropperViewController: AppearanceProviding {
    public static var appearance = Appearance(
        navigationBarAppearance: NavigationBarAppearance.appearance,
        backgroundColor: .background,
        maskColor: .black.withAlphaComponent(0.5),
        bottomBarBackgroundColor: DefaultColors.backgroundDark,
        cancelButtonAppearance: .init(
            reference: ButtonAppearance.appearance,
            labelAppearance: .init(
                foregroundColor: .onPrimary,
                font: Fonts.semiBold.withSize(16)
                                  )
        ),
        confirmButtonAppearance: .init(
            reference: ButtonAppearance.appearance,
            labelAppearance: .init(
                foregroundColor: .onPrimary,
                font: Fonts.semiBold.withSize(16)
            )
        )
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, NavigationBarAppearance.Appearance>
        public var navigationBarAppearance: NavigationBarAppearance.Appearance
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor

        @Trackable<Appearance, UIColor>
        public var maskColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var bottomBarBackgroundColor: UIColor
        
        @Trackable<Appearance, ButtonAppearance>
        public var cancelButtonAppearance: ButtonAppearance
    
        @Trackable<Appearance, ButtonAppearance>
        public var confirmButtonAppearance: ButtonAppearance
        
        init(
            navigationBarAppearance: NavigationBarAppearance.Appearance,
            backgroundColor: UIColor,
            maskColor: UIColor,
            bottomBarBackgroundColor: UIColor,
            cancelButtonAppearance: ButtonAppearance,
            confirmButtonAppearance: ButtonAppearance
        ) {
            self._navigationBarAppearance = Trackable(value: navigationBarAppearance)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._maskColor = Trackable(value: maskColor)
            self._bottomBarBackgroundColor = Trackable(value: bottomBarBackgroundColor)
            self._cancelButtonAppearance = Trackable(value: cancelButtonAppearance)
            self._confirmButtonAppearance = Trackable(value: confirmButtonAppearance)
        }
        
        init(
            reference: ImageCropperViewController.Appearance,
            navigationBarAppearance: NavigationBarAppearance.Appearance? = nil,
            backgroundColor: UIColor? = nil,
            maskColor: UIColor? = nil,
            bottomBarBackgroundColor: UIColor? = nil,
            cancelButtonAppearance: ButtonAppearance? = nil,
            confirmButtonAppearance: ButtonAppearance? = nil
        ) {
            self._navigationBarAppearance = Trackable(reference: reference, referencePath: \.navigationBarAppearance)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._maskColor = Trackable(reference: reference, referencePath: \.maskColor)
            self._bottomBarBackgroundColor = Trackable(reference: reference, referencePath: \.bottomBarBackgroundColor)
            self._cancelButtonAppearance = Trackable(reference: reference, referencePath: \.cancelButtonAppearance)
            self._confirmButtonAppearance = Trackable(reference: reference, referencePath: \.confirmButtonAppearance)
            
            if let navigationBarAppearance { self.navigationBarAppearance = navigationBarAppearance }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let maskColor { self.maskColor = maskColor }
            if let bottomBarBackgroundColor { self.bottomBarBackgroundColor = bottomBarBackgroundColor }
            if let cancelButtonAppearance { self.cancelButtonAppearance = cancelButtonAppearance }
            if let confirmButtonAppearance { self.confirmButtonAppearance = confirmButtonAppearance }
        }
        
    }
}

