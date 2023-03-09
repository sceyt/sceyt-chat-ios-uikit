//
//  ProfileTableView.swift
//  SceytChatUIKit
//

import UIKit

open class ProfileTableView: UITableView, UIGestureRecognizerDelegate {
 
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
       true
    }
}

