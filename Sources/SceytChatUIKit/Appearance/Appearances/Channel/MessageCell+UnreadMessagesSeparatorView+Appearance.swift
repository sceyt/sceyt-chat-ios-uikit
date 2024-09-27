//
//  MessageCell+UnreadMessagesSeparatorView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 27.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageCell.UnreadMessagesSeparatorView {
    
    public class Appearance {
        public lazy var backgroundColor: UIColor = SceytChatUIKit.Components.messageCell.Appearance.bubbleIncoming
        public lazy var labelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                 font: Fonts.semiBold.withSize(14))
        
        public init(backgroundColor: UIColor = SceytChatUIKit.Components.messageCell.Appearance.bubbleIncoming,
                    labelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                             font: Fonts.semiBold.withSize(14))) {
            self.backgroundColor = backgroundColor
            self.labelAppearance = labelAppearance
        }
    }
}
