//
//  ChannelInfoViewController+ImageAttachmentCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController {
    open class ImageAttachmentCell: ChannelInfoViewController.AttachmentCell {
        
        open override var data: MessageLayoutModel.AttachmentLayout! {
            didSet {
                guard let data
                else { return }
                imageView.image = data.thumbnail
                imageView.setup(
                    previewer: { self.previewer?() },
                    item: PreviewItem.attachment(data.attachment)
                )
            }
        }
    }
}
