//
//  ActionPresentationController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension ActionPresentationController: AppearanceProviding {
    public static var appearance = Appearance(dimColor: .overlayBackground1)
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var dimColor: UIColor
        
        // Initializer with all parameters
        public init(dimColor: UIColor) {
            self._dimColor = Trackable(value: dimColor)
        }
        
        // Convenience initializer with optional parameters
        public init(
            reference: ActionPresentationController.Appearance,
            dimColor: UIColor? = nil
        ) {            
            self._dimColor = Trackable(reference: reference, referencePath: \.dimColor)
            
            if let dimColor { self.dimColor = dimColor }
        }
    }
}
