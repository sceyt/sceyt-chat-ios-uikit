//
//  CircularProgressView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension CircularProgressView: AppearanceProviding {
    public static var appearance = Appearance(
        progressColor: .onPrimary,
        progressLabelAppearance: LabelAppearance(
            foregroundColor: .onPrimary,
            font: Fonts.regular.withSize(12)
        ),
        trackColor: .clear,
        backgroundColor: nil,
        cancelIcon: nil,
        uploadIcon: nil,
        downloadIcon: nil
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor?>
        public var progressColor: UIColor?
        
        @Trackable<Appearance, LabelAppearance>
        public var progressLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, UIColor?>
        public var trackColor: UIColor?
        
        @Trackable<Appearance, UIColor?>
        public var backgroundColor: UIColor?
        
        @Trackable<Appearance, UIImage?>
        public var cancelIcon: UIImage?
        
        @Trackable<Appearance, UIImage?>
        public var uploadIcon: UIImage?
        
        @Trackable<Appearance, UIImage?>
        public var downloadIcon: UIImage?
        
        // Initializer with all parameters
        public init(
            progressColor: UIColor?,
            progressLabelAppearance: LabelAppearance,
            trackColor: UIColor?,
            backgroundColor: UIColor?,
            cancelIcon: UIImage?,
            uploadIcon: UIImage?,
            downloadIcon: UIImage?
        ) {
            self._progressColor = Trackable(value: progressColor)
            self._progressLabelAppearance = Trackable(value: progressLabelAppearance)
            self._trackColor = Trackable(value: trackColor)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._cancelIcon = Trackable(value: cancelIcon)
            self._uploadIcon = Trackable(value: uploadIcon)
            self._downloadIcon = Trackable(value: downloadIcon)
        }
        
        // Convenience initializer
        public init(
            reference: CircularProgressView.Appearance,
            progressColor: UIColor? = nil,
            progressLabelAppearance: LabelAppearance? = nil,
            trackColor: UIColor? = nil,
            backgroundColor: UIColor? = nil,
            cancelIcon: UIImage? = nil,
            uploadIcon: UIImage? = nil,
            downloadIcon: UIImage? = nil
        ) { 
            self._progressColor = Trackable(reference: reference, referencePath: \.progressColor)
            self._progressLabelAppearance = Trackable(reference: reference, referencePath: \.progressLabelAppearance)
            self._trackColor = Trackable(reference: reference, referencePath: \.trackColor)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._cancelIcon = Trackable(reference: reference, referencePath: \.cancelIcon)
            self._uploadIcon = Trackable(reference: reference, referencePath: \.uploadIcon)
            self._downloadIcon = Trackable(reference: reference, referencePath: \.downloadIcon)
            
            if let progressColor { self.progressColor = progressColor}
            if let progressLabelAppearance { self.progressLabelAppearance = progressLabelAppearance}
            if let trackColor { self.trackColor = trackColor}
            if let backgroundColor { self.backgroundColor = backgroundColor}
            if let cancelIcon { self.cancelIcon = cancelIcon}
            if let uploadIcon { self.uploadIcon = uploadIcon}
            if let downloadIcon { self.downloadIcon = downloadIcon}
        }
    }
}
