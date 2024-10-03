//
//  CircularProgressView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension CircularProgressView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var progressColor: UIColor? = .onPrimary
        public var progressLabelAppearance: LabelAppearance = .init(
            foregroundColor: .onPrimary,
            font: Fonts.regular.withSize(12)
        )
        public var trackColor: UIColor? = .clear
        public var backgroundColor: UIColor? = nil
        public var cancelIcon: UIImage? = nil
        public var uploadIcon: UIImage? = nil
        public var downloadIcon: UIImage? = nil
        
        // Initializer with default values
        public init(
            progressColor: UIColor? = .onPrimary,
            progressLabelAppearance: LabelAppearance = .init(
                foregroundColor: .onPrimary,
                font: Fonts.regular.withSize(12)
            ),
            trackColor: UIColor? = .clear,
            backgroundColor: UIColor? = nil,
            cancelIcon: UIImage? = nil,
            uploadIcon: UIImage? = nil,
            downloadIcon: UIImage? = nil
        ) {
            self.progressColor = progressColor
            self.progressLabelAppearance = progressLabelAppearance
            self.trackColor = trackColor
            self.backgroundColor = backgroundColor
            self.cancelIcon = cancelIcon
            self.uploadIcon = uploadIcon
            self.downloadIcon = downloadIcon
        }
    }
}
