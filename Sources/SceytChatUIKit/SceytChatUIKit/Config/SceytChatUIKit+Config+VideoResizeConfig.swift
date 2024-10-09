//
//  SceytChatUIKit+Config+QueryLimits.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

extension SceytChatUIKit.Config {
    public struct VideoResizeConfig {
        public var dimensionThreshold: CGFloat
        public var compressionQuality: Double
        public var frameRate: Int
        public var bitrate: Int
        
        static let low: VideoResizeConfig = VideoResizeConfig(dimensionThreshold: 800,
                                                              compressionQuality: 0.8,
                                                              frameRate: 30,
                                                              bitrate: 500000)
        static let medium: VideoResizeConfig = VideoResizeConfig(dimensionThreshold: 1200,
                                                                 compressionQuality: 0.8,
                                                                 frameRate: 30,
                                                                 bitrate: 1000000)
        static let high: VideoResizeConfig = VideoResizeConfig(dimensionThreshold: 1600,
                                                               compressionQuality: 0.8,
                                                               frameRate: 30,
                                                               bitrate: 2000000)
        
        public init(
            dimensionThreshold: CGFloat,
            compressionQuality: Double,
            frameRate: Int,
            bitrate: Int
        ) {
            self.dimensionThreshold = dimensionThreshold
            self.compressionQuality = compressionQuality
            self.frameRate = frameRate
            self.bitrate = bitrate
        }
    }
}
