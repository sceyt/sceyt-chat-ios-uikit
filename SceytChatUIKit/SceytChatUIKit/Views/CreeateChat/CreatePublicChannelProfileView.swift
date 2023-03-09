//
//  CreatePublicChannelProfileView.swift
//  SceytChatUIKit
//

import UIKit

open class CreatePublicChannelProfileView: CreatePrivateChannelProfileView, UITextFieldDelegate {
 
    open lazy var uriField: MarkableTextField = {
        $0.markerLabel.text = Config.channelURIPrefix
        $0.markerLabel.font = Fonts.regular.withSize(16)
        $0.markerLabel.textColor = Colors.textBlack
        $0.textField.font = Fonts.regular.withSize(16)
        $0.textField.textColor = Colors.textGray
        $0.textField.keyboardType = .URL
        $0.textField.autocorrectionType = .no
        $0.textField.placeholder = L10n.Channel.Create.Uri.placeholder
        $0.textField.delegate = self
        return $0.withoutAutoresizingMask
    }(MarkableTextField())
    
    open lazy var errorLabel: ContentInsetLabel = {
        $0.font = Fonts.regular.withSize(13)
        $0.textColor = Colors.textRed
        $0.edgeInsets.bottom = .zero
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(ContentInsetLabel())
    
    open lazy var bottomLine3: UIView = {
        $0.backgroundColor = Colors.separatorBorder
        return $0.withoutAutoresizingMask
    }(UIView())
    
    override open func setup() {
        commentLabel.text = L10n.Channel.Create.comment(Config.channelURIMinLength,
                                                        Config.channelURIMaxLength)
        super.setup()
    }
    
    override open func setNeedsLayout() {
        mainStackView.addArrangedSubview(uriField)
        mainStackView.addArrangedSubview(bottomLine3)
        mainStackView.addArrangedSubview(errorLabel)
        mainStackView.addArrangedSubview(commentLabel)
        mainStackView.setCustomSpacing(12, after: bottomLine3)
        super.setNeedsLayout()
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
        errorLabel.textColor = Colors.success
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
