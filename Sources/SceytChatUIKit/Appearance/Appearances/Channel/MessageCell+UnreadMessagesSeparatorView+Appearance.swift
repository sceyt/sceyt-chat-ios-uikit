//
//  MessageCell+UnreadMessagesSeparatorView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 27.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

//extension MessageCell.UnreadMessagesSeparatorView: AppearanceProviding {
//    public static var appearance = Appearance(
//        unreadText: L10n.Message.List.unread,
//        backgroundColor: SceytChatUIKit.Components.messageCell.Appearance.bubbleIncoming,
//        labelAppearance: LabelAppearance(
//            foregroundColor: .secondaryText,
//            font: Fonts.semiBold.withSize(14)
//        )
//    )
//    
//    public struct Appearance {
//        @Trackable<Appearance, String>
//        public var unreadText: String
//        
//        @Trackable<Appearance, UIColor>
//        public var backgroundColor: UIColor
//        
//        @Trackable<Appearance, LabelAppearance>
//        public var labelAppearance: LabelAppearance
//        
//        public init(
//            unreadText: String = L10n.Message.List.unread,
//            backgroundColor: UIColor = SceytChatUIKit.Components.messageCell.Appearance.bubbleIncoming,
//            labelAppearance: LabelAppearance = .init(
//                foregroundColor: .secondaryText,
//                font: Fonts.semiBold.withSize(14)
//            )
//        ) {
//            self._unreadText = Trackable(value: unreadText)
//            self._backgroundColor = Trackable(value: backgroundColor)
//            self._labelAppearance = Trackable(value: labelAppearance)
//        }
//        
//        public init(
//            unreadText: String? = nil,
//            backgroundColor: UIColor? = nil,
//            labelAppearance: LabelAppearance? = nil
//        ) {
//            let reference = MessageCell.UnreadMessagesSeparatorView.appearance
//            self._unreadText = Trackable(reference: reference, referencePath: \.unreadText)
//            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
//            self._labelAppearance = Trackable(reference: reference, referencePath: \.labelAppearance)
//            
//            if let unreadText { self.unreadText = unreadText }
//            if let backgroundColor { self.backgroundColor = backgroundColor }
//            if let labelAppearance { self.labelAppearance = labelAppearance }
//        }
//    }
//}


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
        public var backgroundColor: UIColor = DefaultColors.bubbleIncoming
        public var labelAppearance: LabelAppearance = .init(
            foregroundColor: .secondaryText,
            font: Fonts.semiBold.withSize(14)
        )
        
        public init(
            backgroundColor: UIColor = DefaultColors.bubbleIncoming,
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
