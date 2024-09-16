//
//  ChannelInfoVC+AttachmentCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 10.07.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoVC {
    open class AttachmentCell: CollectionViewCell {
        
        open lazy var imageView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFill)
        
        override open func setup() {
            super.setup()
            imageView.isUserInteractionEnabled = true
            imageView.clipsToBounds = true
        }
        
        override open func setupLayout() {
            super.setupLayout()
            contentView.addSubview(imageView)
            imageView.pin(to: contentView)
        }
        
        open var data: MessageLayoutModel.AttachmentLayout!
        
        open var previewer: (() -> AttachmentPreviewDataSource?)?
    }
}
