//
//  InitialsBuilder.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class InitialsBuilder {
    
    open class func build(
        appearance: InitialsBuilderAppearance = .init(),
        display: String) -> UIImage {
        
        let display = display.trimmingCharacters(in: .whitespacesAndNewlines)

        return Components.imageBuilder.build(
            size: appearance.size,
            backgroundColor: .initial(title: display)) {
                $0.text = SceytChatUIKit.shared.formatters.avatarInitialsFormatter.format(display)
                $0.textColor = appearance.color
                $0.font = appearance.font
                $0.adjustsFontSizeToFitWidth = appearance.adjustsFontSizeToFitWidth
            } ?? UIImage()
    }
    
    open class func backgroundColor(display: String) -> UIColor {
        .initial(title: display)
    }
}
