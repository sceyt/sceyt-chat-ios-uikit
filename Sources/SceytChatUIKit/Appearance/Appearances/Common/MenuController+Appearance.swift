//
//  MenuController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension MenuController: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .surface1
    )
    
    public class Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        // Primary Initializer with all parameters
        public init(
            backgroundColor: UIColor
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
        }
        
        // Secondary Initializer with optional parameters
        public init(
            reference: MenuController.Appearance,
            backgroundColor: UIColor? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
        }
    }
}
