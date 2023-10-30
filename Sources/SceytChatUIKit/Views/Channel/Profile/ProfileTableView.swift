//
//  ProfileTableView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ProfileTableView: UITableView, UIGestureRecognizerDelegate {
    open var shouldSimultaneous: ((UITableView) -> Bool)?
    
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
       shouldSimultaneous?(self) ?? false
    }
}

