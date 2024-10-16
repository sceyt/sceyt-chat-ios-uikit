//
//  UIView+Extensiosn.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 16.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension UIView {
    var width: CGFloat {
        get { frame.width }
        set { frame.size.width = newValue }
    }
    
    var height: CGFloat {
        get { frame.height }
        set { frame.size.height = newValue }
    }
}
