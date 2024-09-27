//
//  MessageInputViewController+SelectedMessagesActionsView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24.
//

import UIKit

extension MessageInputViewController.SelectedMessagesActionsView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var backgroundColor: UIColor = UIColor.background
        public lazy var separatorColor: UIColor = .border
        public lazy var deleteIcon: UIImage = .chatDelete
        public lazy var shareIcon: UIImage = .chatShare
        public lazy var forwardIcon: UIImage = .chatForward
        
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
