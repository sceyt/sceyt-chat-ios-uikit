//
//  NavigationController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 04.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension NavigationController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var barAppearance: NavigationBarAppearance
        public init(barAppearance: NavigationBarAppearance = NavigationBarAppearance()) {
            self.barAppearance = barAppearance
        }
    }
}
