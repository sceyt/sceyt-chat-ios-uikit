//
//  MessageCell+UnreadMessagesSeparatorView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 27.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageCell.UnreadMessagesSeparatorView {
    
    public struct Appearance {
        public var unreadText: String = L10n.Message.List.unread
        public var backgroundColor: UIColor = SceytChatUIKit.Components.messageCell.Appearance.bubbleIncoming
        public var labelAppearance: LabelAppearance = .init(
            foregroundColor: .secondaryText,
            font: Fonts.semiBold.withSize(14)
        )
        
        public init(
            backgroundColor: UIColor = SceytChatUIKit.Components.messageCell.Appearance.bubbleIncoming,
            labelAppearance: LabelAppearance = .init(
                foregroundColor: .secondaryText,
                font: Fonts.semiBold.withSize(14)
            )
        ) {
            self.backgroundColor = backgroundColor
            self.labelAppearance = labelAppearance
        }
    }
}
