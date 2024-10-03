//
//  EmptyStateView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension EmptyStateView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var icon: UIImage? = nil
        public var title: String? = nil
        public var message: String? = nil
        public var titleLabelAppearance: LabelAppearance? = .init(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(20)
        )
        public var messageLabelAppearance: LabelAppearance? = .init(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(15)
        )
        
        // Initializer with default values
        public init(
            icon: UIImage? = nil,
            title: String? = nil,
            message: String? = nil,
            titleLabelAppearance: LabelAppearance? = .init(
                foregroundColor: .primaryText,
                font: Fonts.semiBold.withSize(20)
            ),
            messageLabelAppearance: LabelAppearance? = .init(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(15)
            )
        ) {
            self.icon = icon
            self.title = title
            self.message = message
            self.titleLabelAppearance = titleLabelAppearance
            self.messageLabelAppearance = messageLabelAppearance
        }
    }
}
