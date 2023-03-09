//
//  InitialsBuilder.swift
//  SceytChatUIKit
//

import UIKit

open class InitialsBuilder {
    
    open class func build(
        appearance: InitialsBuilderAppearance = .init(),
        display: String) -> UIImage {
            
        return Components.imageBuilder.build(
            size: appearance.size,
            backgroundColor: .initial(title: display)) {
                $0.text = Formatters.initials.format(display)
                $0.textColor = appearance.color
                $0.font = appearance.font
                $0.adjustsFontSizeToFitWidth = appearance.adjustsFontSizeToFitWidth
            } ?? UIImage()
    }
    
    open class func backgroundColor(display: String) -> UIColor {
        .initial(title: display)
    }
}
