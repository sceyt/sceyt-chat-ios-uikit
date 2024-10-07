//
//  ReactionPickerViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 27.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ReactionPickerViewController: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .backgroundSections,
        moreIcon: .messageActionMoreReactions,
        selectedBackgroundColor: .surface2
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIImage>
        public var moreIcon: UIImage
        
        @Trackable<Appearance, UIColor>
        public var selectedBackgroundColor: UIColor
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor,
            moreIcon: UIImage,
            selectedBackgroundColor: UIColor
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._moreIcon = Trackable(value: moreIcon)
            self._selectedBackgroundColor = Trackable(value: selectedBackgroundColor)
        }
        
        public init(
            reference: ReactionPickerViewController.Appearance,
            backgroundColor: UIColor? = nil,
            moreIcon: UIImage? = nil,
            selectedBackgroundColor: UIColor? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._moreIcon = Trackable(reference: reference, referencePath: \.moreIcon)
            self._selectedBackgroundColor = Trackable(reference: reference, referencePath: \.selectedBackgroundColor)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let moreIcon { self.moreIcon = moreIcon }
            if let selectedBackgroundColor { self.selectedBackgroundColor = selectedBackgroundColor }
        }
    }
}
