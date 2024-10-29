//
//  ImageButton.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ImageButton: Button {
    open var image: UIImage? {
        set {
            setImage(newValue, for: .normal)
            imageView?.contentMode = contentMode
        }
        get { imageView?.image }
    }
}
