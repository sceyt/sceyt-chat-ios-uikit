//
//  EmptyStateView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension EmptyStateView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var icon: UIImage? = nil
        public lazy var title: String? = nil
        public lazy var message: String? = nil
        public lazy var titleLabelAppearance: LabelAppearance? = .init(foregroundColor: .primaryText,
                                                                       font: Fonts.semiBold.withSize(20))
        public lazy var messageLabelAppearance: LabelAppearance? = .init(foregroundColor: .secondaryText,
                                                                         font: Fonts.regular.withSize(15))
        
        // Initializer with default values
        public init(
            icon: UIImage? = nil,
            title: String? = nil,
            message: String? = nil,
            titleLabelAppearance: LabelAppearance? = .init(foregroundColor: .primaryText, font: Fonts.semiBold.withSize(20)),
            messageLabelAppearance: LabelAppearance? = .init(foregroundColor: .secondaryText, font: Fonts.regular.withSize(15))
        ) {
            self.icon = icon
            self.title = title
            self.message = message
            self.titleLabelAppearance = titleLabelAppearance
            self.messageLabelAppearance = messageLabelAppearance
        }
    }
}
