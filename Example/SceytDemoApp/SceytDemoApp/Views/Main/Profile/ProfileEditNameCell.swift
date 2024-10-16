//
//  ProfileEditNameCell.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 16.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChatUIKit

class ProfileEditNameCell: TableViewCell {
    
    var onTextFieldChange: ((UITextField) -> Void)?
    
    lazy var firstNameField: UITextField = {
        $0.font = .systemFont(ofSize: .init(16), weight: .regular)
        $0.textColor = .primaryText
        $0.textContentType = .givenName
        return $0.withoutAutoresizingMask
    }(UITextField())
    
    lazy var lastNameField: UITextField = {
        $0.font = .systemFont(ofSize: .init(16), weight: .regular)
        $0.textColor = .primaryText
        $0.textContentType = .familyName
        return $0.withoutAutoresizingMask
    }(UITextField())
    
    lazy var separatorView: UIView = {
        $0.backgroundColor = .border
        return $0.withoutAutoresizingMask
    }(UIView())
    
    lazy var stackView: UIStackView = {
        $0.axis = .vertical
        $0.alignment = .leading
        $0.distribution = .fillProportionally
        return $0.withoutAutoresizingMask
    }(UIStackView(arrangedSubviews: [firstNameField, separatorView, lastNameField]))
    
    override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(stackView)
        contentView.backgroundColor = .backgroundSections
        stackView.pin(to: contentView, anchors: [.leading(16), .trailing(-16), .top(14), .bottom(-14)])
        firstNameField.pin(to: stackView, anchors: [.leading(), .trailing()])
        lastNameField.pin(to: stackView, anchors: [.leading(), .trailing()])
        firstNameField.heightAnchor.pin(greaterThanOrEqualToConstant: 48)
        lastNameField.heightAnchor.pin(greaterThanOrEqualToConstant: 48)
        separatorView.heightAnchor.pin(constant: 1)
        separatorView.widthAnchor.pin(to: stackView.widthAnchor)
    }
    
    override func setupDone() {
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChangeNotification(sender:)), name: UITextField.textDidChangeNotification, object: firstNameField)
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChangeNotification(sender:)), name: UITextField.textDidChangeNotification, object: lastNameField)
    }
    
    @objc
    func textDidChangeNotification(sender: UITextField) {
        onTextFieldChange?(sender)
    }
}
