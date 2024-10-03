//
//  MessageDeliveryStatusIcons.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public struct MessageDeliveryStatusIcons {
    public var pendingIcon: UIImage = .pendingMessage
    public var sentIcon: UIImage = .sentMessage
    public var receivedIcon: UIImage = .receivedMessage
    public var displayedIcon: UIImage = .displayedMessage
    public var failedIcon: UIImage = .failedMessage
    
    // Initializer with default values
    public init(
        pendingIcon: UIImage = .pendingMessage,
        sentIcon: UIImage = .sentMessage,
        receivedIcon: UIImage = .receivedMessage,
        displayedIcon: UIImage = .displayedMessage,
        failedIcon: UIImage = .failedMessage
    ) {
        self.pendingIcon = pendingIcon
        self.sentIcon = sentIcon
        self.receivedIcon = receivedIcon
        self.displayedIcon = displayedIcon
        self.failedIcon = failedIcon
    }
}
