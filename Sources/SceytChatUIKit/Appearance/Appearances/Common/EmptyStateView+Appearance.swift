//
//  EmptyStateView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension EmptyStateView: AppearanceProviding {
    public static var appearance = Appearance(
        icon: nil,
        title: nil,
        message: nil,
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(20)
        ),
        messageLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(15)
        )
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIImage?>
        public var icon: UIImage?
        
        @Trackable<Appearance, String?>
        public var title: String?
        
        @Trackable<Appearance, String?>
        public var message: String?
        
        @Trackable<Appearance, LabelAppearance?>
        public var titleLabelAppearance: LabelAppearance?
        
        @Trackable<Appearance, LabelAppearance?>
        public var messageLabelAppearance: LabelAppearance?
        
        // Initializer with all parameters
        public init(
            icon: UIImage?,
            title: String?,
            message: String?,
            titleLabelAppearance: LabelAppearance,
            messageLabelAppearance: LabelAppearance
        ) {
            self._icon = Trackable(value: icon)
            self._title = Trackable(value: title)
            self._message = Trackable(value: message)
            self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
            self._messageLabelAppearance = Trackable(value: messageLabelAppearance)
        }
        
        // Convenience initializer with default values
        public init(
            reference: EmptyStateView.Appearance,
            icon: UIImage? = nil,
            title: String? = nil,
            message: String? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            messageLabelAppearance: LabelAppearance? = nil
        ) {
            self._icon = Trackable(reference: reference, referencePath: \.icon)
            self._title = Trackable(reference: reference, referencePath: \.title)
            self._message = Trackable(reference: reference, referencePath: \.message)
            self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
            self._messageLabelAppearance = Trackable(reference: reference, referencePath: \.messageLabelAppearance)
            
            if let icon { self.icon = icon }
            if let title { self.title = title }
            if let message { self.message = message }
            if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
            if let messageLabelAppearance { self.messageLabelAppearance = messageLabelAppearance }
        }
    }
}
