//
//  NavigationController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 04.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension NavigationController: AppearanceProviding {
    public static var appearance = NavigationBarAppearance.appearance
    
    public struct Appearance {
        @Trackable<Appearance, NavigationBarAppearance>
        public var barAppearance: NavigationBarAppearance
        
        public init(barAppearance: NavigationBarAppearance) {
            self._barAppearance = Trackable(value: barAppearance)
        }

        public init(
            reference: NavigationController.Appearance,
            barAppearance: NavigationBarAppearance? = nil
        ) {
            self._barAppearance = Trackable(reference: reference, referencePath: \.barAppearance)
            if let barAppearance { self.barAppearance = barAppearance }
        }
    }
}
