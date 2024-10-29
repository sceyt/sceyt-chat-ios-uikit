//
//  ImagePresentable.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public protocol ImagePresentable: AnyObject {
    
    var image: UIImage? { get set }
    var shape: Shape { get set }
}

private var shapeKey: UInt8 = 0

extension ImagePresentable {
    
    public var shape: Shape {
        get {
            // Retrieve the associated value or default to `.circle` if nil.
            return objc_getAssociatedObject(self, &shapeKey) as? Shape ?? .roundedRectangle(cornerRadius: 0)
        }
        set {
            // Set the new value using Objective-C associated objects.
            objc_setAssociatedObject(self, &shapeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

extension ImageView: ImagePresentable { }

extension ImageButton: ImagePresentable { }

extension CircleImageView: ImagePresentable { }

extension View {
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        if self is ImagePresentable {
            switch (self as! ImagePresentable).shape {
            case .circle:
                layer.cornerRadius = height / 2
            case .roundedRectangle(let cornerRadius):
                layer.cornerRadius = min(height / 2, cornerRadius)
            }
        }
    }
}

extension ImageView {
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        if self is ImagePresentable {
            switch (self as! ImagePresentable).shape {
            case .circle:
                layer.cornerRadius = height / 2
            case .roundedRectangle(let cornerRadius):
                layer.cornerRadius = min(height / 2, cornerRadius)
            }
        }
    }
}

extension ImageButton {
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        if self is ImagePresentable {
            switch (self as! ImagePresentable).shape {
            case .circle:
                layer.cornerRadius = height / 2
            case .roundedRectangle(let cornerRadius):
                layer.cornerRadius = min(height / 2, cornerRadius)
            }
        }
    }
}
