//
//  MarkableTextField.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class MarkableTextField: View {

    open lazy var markerLabel = ContentInsetLabel()
        .withoutAutoresizingMask
        .contentHuggingPriorityH(.required)
    
    open lazy var textField = UITextField()
        .withoutAutoresizingMask
        
    public var text: String? {
        textField.text
    }
    
    public var attributedText: NSAttributedString? {
        textField.attributedText
    }
    
    override open func setup() {
        super.setup()
        markerLabel.textAlignment = .right
        textField.textAlignment = .left
        textField.layer.sublayerTransform = CATransform3DMakeTranslation(0, 0, 0);
        markerLabel.edgeInsets = .zero
    }
    
    override open func setupLayout() {
        super.setupLayout()
        addSubview(markerLabel)
        addSubview(textField)
        markerLabel.pin(to: self, anchors: [.leading(), .top(), .bottom()])
        textField.pin(to: self, anchors: [.trailing(0), .top(), .bottom()])
        textField.leadingAnchor.pin(to: markerLabel.trailingAnchor)
    }
}
