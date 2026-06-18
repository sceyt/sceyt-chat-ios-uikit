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
        display: String
    ) -> UIImage {
        
        let display = display.trimmingCharacters(in: .whitespacesAndNewlines)

        return Components.imageBuilder.build(
            size: appearance.size,
            backgroundColor: appearance.backgroundColor ?? backgroundColor(display: display),
            text: SceytChatUIKit.shared.formatters.avatarInitialsFormatter.format(display),
            textColor: appearance.color,
            font: appearance.font
        )
    }
    
    open class func backgroundColor(display: String) -> UIColor {
        DefaultColors.initial(title: display)
    }
}
