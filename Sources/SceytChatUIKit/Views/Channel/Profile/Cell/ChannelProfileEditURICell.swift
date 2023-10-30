//
//  ChannelProfileEditURICell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelProfileEditURICell: TableViewCell {
    open lazy var prefixLabel = UILabel()
    
    open lazy var textField = UITextField()
        .withoutAutoresizingMask
    
    open var onTextChanged: ((String?) -> Void)? {
        didSet {
            textField
                .publisher(for: .editingChanged)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.onTextChanged?(self?.textField.text)
                }.store(in: &subscriptions)
        }
    }

    public lazy var appearance = ChannelProfileEditVC.appearance {
        didSet {
            setupAppearance()
        }
    }
    
    open override func setup() {
        super.setup()
        
        selectionStyle = .none
        prefixLabel.text = Config.channelURIPrefix
        textField.leftViewMode = .always
        textField.leftView = prefixLabel
    }

    override open func setupAppearance() {
        super.setupAppearance()
        
        prefixLabel.textColor = appearance.textFieldColor
        prefixLabel.font = appearance.textFieldFont
        
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.returnKeyType = .next
        textField.textColor = appearance.textFieldColor
        textField.font = appearance.textFieldFont
        backgroundColor = appearance.textFieldBackgroundColor
    }

    override open func setupLayout() {
        super.setupLayout()
        
        contentView.addSubview(textField)
        textField.pin(to: contentView, anchors: [.leading(16), .trailing(-16), .top(17), .bottom(-17)])
        contentView.heightAnchor.pin(greaterThanOrEqualToConstant: 56)
    }
    
    open override func prepareForReuse() {
        super.prepareForReuse()
    }
}
