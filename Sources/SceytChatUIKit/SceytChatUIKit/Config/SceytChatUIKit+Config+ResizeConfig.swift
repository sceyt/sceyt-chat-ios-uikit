//
//  SceytChatUIKit+Config+QueryLimits.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

extension SceytChatUIKit.Config {
    public struct ResizeConfig {
        public var dimensionThreshold: CGFloat
        public var compressionQuality: Double
        
        static let low: ResizeConfig = ResizeConfig(dimensionThreshold: 720, compressionQuality: 0.8)
        static let medium: ResizeConfig = ResizeConfig(dimensionThreshold: 1080, compressionQuality: 0.8)
        static let high: ResizeConfig = ResizeConfig(dimensionThreshold: 1600, compressionQuality: 0.9)
    }
}
