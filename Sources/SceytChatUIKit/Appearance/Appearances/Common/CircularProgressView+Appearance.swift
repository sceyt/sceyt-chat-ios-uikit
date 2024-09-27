//
//  CircularProgressView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension CircularProgressView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var progressColor: UIColor? = .onPrimary
        public lazy var trackColor: UIColor? = .clear
        public lazy var backgroundColor: UIColor? = nil
        public lazy var cancelIcon: UIImage? = nil
        public lazy var uploadIcon: UIImage? = nil
        public lazy var downloadIcon: UIImage? = nil
        
        // Initializer with default values
        public init(
            progressColor: UIColor? = .onPrimary,
            trackColor: UIColor? = .clear,
            backgroundColor: UIColor? = nil,
            cancelIcon: UIImage? = nil,
            uploadIcon: UIImage? = nil,
            downloadIcon: UIImage? = nil
        ) {
            self.progressColor = progressColor
            self.trackColor = trackColor
            self.backgroundColor = backgroundColor
            self.cancelIcon = cancelIcon
            self.uploadIcon = uploadIcon
            self.downloadIcon = downloadIcon
        }
    }
}
