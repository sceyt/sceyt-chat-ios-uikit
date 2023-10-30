//
//  ChannelProfileBottomContainerCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelProfileContainerCell: TableViewCell {
    open override func setup() {
        super.setup()
        selectionStyle = .none
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        backgroundColor = .clear
    }
}
