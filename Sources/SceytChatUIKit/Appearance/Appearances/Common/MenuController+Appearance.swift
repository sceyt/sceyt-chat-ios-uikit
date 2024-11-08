//
//  MenuController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension MenuController: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .surface1,
        cellAppearance: Components.menuCell.appearance
    )
    
    public class Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, MenuCell.Appearance>
        public var cellAppearance: MenuCell.Appearance
        
        // Primary Initializer with all parameters
        public init(
            backgroundColor: UIColor,
            cellAppearance: MenuCell.Appearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._cellAppearance = Trackable(value: cellAppearance)
        }
        
        // Secondary Initializer with optional parameters
        public init(
            reference: MenuController.Appearance,
            backgroundColor: UIColor? = nil,
            cellAppearance: MenuCell.Appearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._cellAppearance = Trackable(reference: reference, referencePath: \.cellAppearance)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let cellAppearance { self.cellAppearance = cellAppearance }
        }
    }
}
