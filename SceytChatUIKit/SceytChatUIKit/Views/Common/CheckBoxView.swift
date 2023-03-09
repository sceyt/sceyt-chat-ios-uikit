//
//  CheckBoxView.swift
//  SceytChatUIKit
//

import UIKit

open class CheckBoxView: View {

    public var selectedImage: UIImage? = .radioSelected
    public var unselectedImage: UIImage? = .radio
    
    open var isSelected = false {
        didSet {
            if oldValue != isSelected {
                imageView.image = isSelected ? selectedImage : unselectedImage
                onChangeValue?(isSelected)
            }
        }
    }

    open lazy var imageView = UIImageView(image: unselectedImage)
        .withoutAutoresizingMask

    var onChangeValue: ((Bool) -> Void)?

    open lazy var tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapGestureAction(_:)))

    open override func setup() {
        super.setup()
        imageView.isUserInteractionEnabled = true
        addGestureRecognizer(tapGesture)
    }

    open override func setupLayout() {
        super.setupLayout()
        addSubview(imageView)
        imageView.pin(to: self, anchors: [.centerY(), .centerX()])
        imageView.resize(anchors: [.width(20), .height(20)])
    }
    open override func setupAppearance() {
        super.setupAppearance()
    }

    @objc
    open func tapGestureAction(_ tap: UITapGestureRecognizer) {
        guard tap.state == .ended else { return }
        isSelected = !isSelected
    }

    open func setTapGestureRecognizer(view: UIView) {
        tapGesture.view?.removeGestureRecognizer(tapGesture)
        view.addGestureRecognizer(tapGesture)
    }
}
