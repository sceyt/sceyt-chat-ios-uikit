//
//  MessageInputViewController+SelectedMessagesActionsView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24.
//

import UIKit

extension MessageInputViewController.SelectedMessagesActionsView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor = UIColor.background
        public var separatorColor: UIColor = .border
        public var deleteIcon: UIImage = .chatDelete
        public var shareIcon: UIImage = .chatShare
        public var forwardIcon: UIImage = .chatForward
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor = UIColor.background,
            separatorColor: UIColor = .border,
            deleteIcon: UIImage = .chatDelete,
            shareIcon: UIImage = .chatShare,
            forwardIcon: UIImage = .chatForward
        ) {
            self.backgroundColor = backgroundColor
            self.separatorColor = separatorColor
            self.deleteIcon = deleteIcon
            self.shareIcon = shareIcon
            self.forwardIcon = forwardIcon
        }
    }
}
