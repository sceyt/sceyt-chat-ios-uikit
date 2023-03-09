//
//  ChannelProfileEditURICell.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelProfileEditURICell: TableViewCell {

    open lazy var textField = UITextField()
        .withoutAutoresizingMask
    
   
    
    public lazy var appearance = ChannelProfileEditVC.appearance {
        didSet {
            setupAppearance()
        }
    }

    open override func setupAppearance() {
        super.setupAppearance()
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.returnKeyType = .next
        textField.textColor = appearance.textFieldColor
        textField.font = appearance.textFieldFont
    }

    open override func setupLayout() {
        super.setupLayout()
        addSubview(textField)
        textField.pin(to: self)
        contentView.heightAnchor.pin(greaterThanOrEqualToConstant: 52)
    }
}
