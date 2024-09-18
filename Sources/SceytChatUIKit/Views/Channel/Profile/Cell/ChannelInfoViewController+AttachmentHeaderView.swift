//
//  ChannelInfoViewController+AttachmentHeaderView.swift
//  SceytChatUIKit
//
//  Created by Duc on 29/09/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController {
    open class AttachmentHeaderView: CollectionReusableView {
        open lazy var headerLabel = UILabel()
            .withoutAutoresizingMask
        
        override open func setupLayout() {
            super.setupLayout()
            
            addSubview(headerLabel)
            headerLabel.pin(to: self, anchors: [.top(Layouts.verticalPadding/2), .bottom(-Layouts.verticalPadding/2),
                                                .left(Layouts.horizontalPadding), .right(-Layouts.horizontalPadding)])
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            headerLabel.font = appearance.headerFont
            headerLabel.textColor = appearance.headerTextColor
            backgroundColor = appearance.headerBackgroundColor
        }
        
        open var date: Date? {
            didSet {
                headerLabel.text = SceytChatUIKit.shared.formatters.channelInfoMediaDateFormatter.format(date ?? Date())
            }
        }
    }
}

public extension ChannelInfoViewController.AttachmentHeaderView {
    enum Layouts {
        public static var horizontalPadding: CGFloat = 16
        public static var verticalPadding: CGFloat = 8
        public static var headerHeight: CGFloat = 32
    }
}
