//
//  ChannelProfileImageAttachmentCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelProfileImageAttachmentCell: ChannelProfileAttachmentCell {
   
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
