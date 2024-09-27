//
//  ActionPresentationController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension ActionPresentationController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var dimColor: UIColor? = .overlayBackground1
        
        // Initializer with default values
        public init(
            dimColor: UIColor? = .overlayBackground1
        ) {
            self.dimColor = dimColor
        }
    }
}
