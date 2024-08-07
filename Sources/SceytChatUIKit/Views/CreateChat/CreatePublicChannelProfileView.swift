//
//  CreatePublicChannelProfileView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class CreatePublicChannelProfileView: CreatePrivateChannelProfileView, UITextFieldDelegate {
    open lazy var uriField: MarkableTextField = {
        $0.markerLabel.text = SceytChatUIKit.shared.config.channelURIPrefix
        $0.textField.keyboardType = .URL
        $0.textField.autocorrectionType = .no
        $0.textField.placeholder = L10n.Channel.Create.Uri.placeholder
        $0.textField.delegate = self
        return $0.withoutAutoresizingMask
    }(MarkableTextField())
    
    open lazy var errorLabel: ContentInsetLabel = {
        $0.edgeInsets.bottom = .zero
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(ContentInsetLabel())
    
    open lazy var bottomLine3 = UIView()
        .withoutAutoresizingMask
    
    override open func setup() {
        commentLabel.text = L10n.Channel.Create.comment(SceytChatUIKit.shared.config.channelURIMinLength,
                                                        SceytChatUIKit.shared.config.channelURIMaxLength)
        super.setup()
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        subjectField.attributedPlaceholder = NSAttributedString(
            string: L10n.Channel.Subject.Channel.placeholder,
            attributes: [.font: appearance.fieldFont ?? Fonts.regular.withSize(16),
                         .foregroundColor: appearance.fieldPlaceHolderTextColor ?? UIColor.secondaryText]
        )
        
        uriField.markerLabel.font = appearance.fieldFont
        uriField.markerLabel.textColor = appearance.fieldTextColor
        uriField.textField.font = appearance.fieldFont
        uriField.textField.textColor = appearance.fieldPlaceHolderTextColor
        
        errorLabel.font = appearance.errorFont
        errorLabel.textColor = appearance.errorTextColor
        
        commentLabel.font = appearance.commentFont
        commentLabel.textColor = appearance.commentTextColor
        
        bottomLine3.backgroundColor = appearance.separatorColor
    }
    
    open override func setupLayout() {
        super.setupLayout()
        
        mainStackView.addArrangedSubview(uriField)
        mainStackView.addArrangedSubview(bottomLine3)
        mainStackView.addArrangedSubview(errorLabel)
        mainStackView.addArrangedSubview(commentLabel)
        mainStackView.setCustomSpacing(12, after: bottomLine3)
        uriField.heightAnchor.pin(greaterThanOrEqualToConstant: 48)
        uriField.widthAnchor.pin(to: mainStackView.widthAnchor)
        bottomLine3.widthAnchor.pin(to: mainStackView.widthAnchor)
        bottomLine3.heightAnchor.pin(constant: 1)
    }
    
    override open func resignFirstResponder() -> Bool {
        uriField.textField.resignFirstResponder()
        return super.resignFirstResponder()
    }
    
    override open var canResignFirstResponder: Bool {
        super.canResignFirstResponder ||
            uriField.textField.canResignFirstResponder
    }
    
    open func showError(_ error: String) {
        errorLabel.edgeInsets.bottom = 8
        errorLabel.text = error
        errorLabel.textColor = Colors.textRed
    }
    
    open func showSuccess(_ success: String) {
        errorLabel.edgeInsets.bottom = 8
        errorLabel.text = success
        errorLabel.textColor = UIColor.stateSuccess
    }
    
    open func hideError() {
        errorLabel.edgeInsets.bottom = 0
        errorLabel.text = nil
        errorLabel.textColor = Colors.textRed
    }
    
    open func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if string.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            let withoutWhiteSpace = string.replacingOccurrences(of: " ", with: "")
            if let text = textField.text {
                if range.upperBound < text.count {
                    textField.text = (text as NSString).replacingCharacters(in: range, with: withoutWhiteSpace)
                } else {
                    textField.text = text + withoutWhiteSpace
                    DispatchQueue.main.async {
                        let newPosition = textField.endOfDocument
                        textField.selectedTextRange = textField.textRange(from: newPosition, to: newPosition)
                    }
                }
                return false
            }
        }
        return true
    }
}
