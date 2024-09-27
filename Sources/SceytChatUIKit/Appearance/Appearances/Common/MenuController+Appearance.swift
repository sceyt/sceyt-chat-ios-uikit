//
//  MenuController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension MenuController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var backgroundColor: UIColor? = UIColor.surface1
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor? = UIColor.surface1
        ) {
            self.backgroundColor = backgroundColor
        }
    }
}
