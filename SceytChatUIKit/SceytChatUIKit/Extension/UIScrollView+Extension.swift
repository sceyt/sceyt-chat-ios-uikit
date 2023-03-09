//
//  UIScrollView+Extension.swift
//  SceytChatUIKit
//

import UIKit

public extension UIScrollView {
    
    func adjustInsetsToKeyboard(notification: Notification, container view: UIView) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        
        let keyboardScreenEndFrame = keyboardValue.cgRectValue
        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)
        
        if notification.name == UIResponder.keyboardWillHideNotification {
            contentInset = .zero
        } else if notification.name == UIResponder.keyboardWillShowNotification {
            contentInset = .init(top: 0, left: 0, bottom: keyboardViewEndFrame.height - view.safeAreaInsets.bottom, right: 0)
        }
        scrollIndicatorInsets = contentInset
    }
    
}


