//
//  MessageInputViewController+MessageSearchControlsView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInputViewController.MessageSearchControlsView: AppearanceProviding {
    public static var appearance = Appearance(
        separatorColor: .border,
        backgroundColor: .background,
        previousIcon: .chevronDown,
        nextIcon: .chevronUp,
        resultLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        )
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor?>
        public var separatorColor: UIColor?
        
        @Trackable<Appearance, UIColor?>
        public var backgroundColor: UIColor?
        
        @Trackable<Appearance, UIImage>
        public var previousIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var nextIcon: UIImage
        
        @Trackable<Appearance, LabelAppearance>
        public var resultLabelAppearance: LabelAppearance
        
        public init(
            separatorColor: UIColor?,
            backgroundColor: UIColor?,
            previousIcon: UIImage,
            nextIcon: UIImage,
            resultLabelAppearance: LabelAppearance
        ) {
            self._separatorColor = Trackable(value: separatorColor)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._previousIcon = Trackable(value: previousIcon)
            self._nextIcon = Trackable(value: nextIcon)
            self._resultLabelAppearance = Trackable(value: resultLabelAppearance)
        }
        
        public init(
            reference: MessageInputViewController.MessageSearchControlsView.Appearance,
            separatorColor: UIColor? = nil,
            backgroundColor: UIColor? = nil,
            previousIcon: UIImage? = nil,
            nextIcon: UIImage? = nil,
            resultLabelAppearance: LabelAppearance? = nil
        ) {
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._previousIcon = Trackable(reference: reference, referencePath: \.previousIcon)
            self._nextIcon = Trackable(reference: reference, referencePath: \.nextIcon)
            self._resultLabelAppearance = Trackable(reference: reference, referencePath: \.resultLabelAppearance)
            
            if let separatorColor { self.separatorColor = separatorColor }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let previousIcon { self.previousIcon = previousIcon }
            if let nextIcon { self.nextIcon = nextIcon }
            if let resultLabelAppearance { self.resultLabelAppearance = resultLabelAppearance }
        }
    }
}
