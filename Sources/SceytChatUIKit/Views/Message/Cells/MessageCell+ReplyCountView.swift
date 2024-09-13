//
//  MessageCell+ReplyCountView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

extension MessageCell {

    open class ReplyCountView: Button {
        
        public lazy var appearance = MessageCell.appearance {
            didSet {
                setupAppearance()
            }
        }

        open override func setup() {
            super.setup()
            isUserInteractionEnabled = false
        }
        open override func setupAppearance() {
            super.setupAppearance()
            setTitleColor(appearance.replyCountTextColor, for: .normal)
            titleLabel?.font = appearance.replyCountTextFont
        }

        open var count: Int = 0 {
            didSet {
                setTitle(count > 0 ? L10n.Message.Reply.count(count) : nil, for: .normal)
                isUserInteractionEnabled = count > 0
            }
        }
    }
}

