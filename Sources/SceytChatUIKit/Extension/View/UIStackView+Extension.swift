//
//  UIStackView+Extension.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension UIStackView {
    func removeArrangedSubviews() {
        arrangedSubviews.forEach { v in
            removeArrangedSubview(v)
            v.removeFromSuperview()
            (v as? UIStackView)?.removeArrangedSubviews()
        }
    }
    
    func removeArrangedSubviews(_ arrangedSubviews: [UIView]) {
        arrangedSubviews.forEach { v in
            removeArrangedSubview(v)
            v.removeFromSuperview()
            (v as? UIStackView)?.removeArrangedSubviews()
        }
    }
}
