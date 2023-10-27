//
//  ActivityIndicatorBarButtonItem.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ActivityIndicatorBarButtonItem: UIBarButtonItem {

    public convenience init(style: UIActivityIndicatorView.Style, color: UIColor?) {
        let view = UIActivityIndicatorView(style: style)
        if let color = color {
            view.color = color
        }
        view.startAnimating()
        self.init(customView: view)
    }
}
