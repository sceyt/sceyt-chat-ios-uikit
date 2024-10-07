//
//  AudioWaveformView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension AudioWaveformView: AppearanceProviding {
    public static var appearance = Appearance(
        progressColor: .accent,
        trackColor: .iconSecondary
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var progressColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var trackColor: UIColor
        
        public init(
            progressColor: UIColor,
            trackColor: UIColor
        ) {
            self._progressColor = Trackable(value: progressColor)
            self._trackColor = Trackable(value: trackColor)
        }
        
        public init(
            reference: AudioWaveformView.Appearance,
            progressColor: UIColor? = nil,
            trackColor: UIColor? = nil
        ) {
            self._progressColor = Trackable(reference: reference, referencePath: \.progressColor)
            self._trackColor = Trackable(reference: reference, referencePath: \.trackColor)
            
            if let progressColor { self.progressColor = progressColor }
            if let trackColor { self.trackColor = trackColor }
        }
    }
}
