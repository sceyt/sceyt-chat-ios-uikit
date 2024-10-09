//
//  MessageInputViewController+SelectedMessagesActionsView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24.
//

import UIKit

extension MessageInputViewController.SelectedMessagesActionsView: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        separatorColor: .border,
        deleteIcon: .chatDelete,
        shareIcon: .chatShare,
        forwardIcon: .chatForward
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        @Trackable<Appearance, UIImage>
        public var deleteIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var shareIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var forwardIcon: UIImage
        
        public init(
            backgroundColor: UIColor,
            separatorColor: UIColor,
            deleteIcon: UIImage,
            shareIcon: UIImage,
            forwardIcon: UIImage
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            self._deleteIcon = Trackable(value: deleteIcon)
            self._shareIcon = Trackable(value: shareIcon)
            self._forwardIcon = Trackable(value: forwardIcon)
        }
        
        public init(
            reference: MessageInputViewController.SelectedMessagesActionsView.Appearance,
            backgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            deleteIcon: UIImage? = nil,
            shareIcon: UIImage? = nil,
            forwardIcon: UIImage? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._deleteIcon = Trackable(reference: reference, referencePath: \.deleteIcon)
            self._shareIcon = Trackable(reference: reference, referencePath: \.shareIcon)
            self._forwardIcon = Trackable(reference: reference, referencePath: \.forwardIcon)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
            if let deleteIcon { self.deleteIcon = deleteIcon }
            if let shareIcon { self.shareIcon = shareIcon }
            if let forwardIcon { self.forwardIcon = forwardIcon }
        }
    }
}
