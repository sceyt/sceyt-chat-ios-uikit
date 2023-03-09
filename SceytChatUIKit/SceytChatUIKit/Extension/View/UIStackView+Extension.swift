//
//  UIStackView+Extension.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
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
}
