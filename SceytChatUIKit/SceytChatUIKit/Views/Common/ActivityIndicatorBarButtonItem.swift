//
//  ActivityIndicatorBarButtonItem.swift
//  SceytChatUIKit
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
