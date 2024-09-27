//
//  AudioWaveformView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension AudioWaveformView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var progressColor: UIColor = .accent
        public lazy var trackColor: UIColor = .iconSecondary
        
        // Initializer with default values
        public init(progressColor: UIColor = .accent, trackColor: UIColor = .iconSecondary) {
            self.progressColor = progressColor
            self.trackColor = trackColor
        }
    }
}
