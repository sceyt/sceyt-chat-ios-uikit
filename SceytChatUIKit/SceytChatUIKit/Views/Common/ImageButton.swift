//
//  ImageButton.swift
//  SceytChatUIKit
//

import UIKit

open class ImageButton: Button, ImagePresentable {

    open var image: UIImage? {
        set { setImage(newValue, for: .normal)}
        get { imageView?.image }
    }
}
