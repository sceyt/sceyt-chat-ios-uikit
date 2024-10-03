//
//  MediaPickerViewController+AttachButton.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension MediaPickerViewController {
    open class AttachButton: Control {
        public lazy var appearance = Components.mediaPickerViewController.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
        
        lazy var selectedCountLabel = Components.badgeView
            .init()
            .withoutAutoresizingMask
        
        override open func setup() {
            super.setup()
            selectedCountLabel.isUserInteractionEnabled = false
            titleLabel.textAlignment = .right
            selectedCountLabel.clipsToBounds = true
            titleLabel.text = L10n.ImagePicker.Attach.Button.title
            selectedCountLabel.value = "0"
        }
        
        override open func setupLayout() {
            super.setupLayout()
            addSubview(titleLabel)
            addSubview(selectedCountLabel)
            titleLabel.pin(to: self, anchors: [.top(12), .bottom(-12), .leading(0, .greaterThanOrEqual)])
            selectedCountLabel.pin(to: self, anchors: [.top(12), .bottom(-12), .trailing(0, .lessThanOrEqual)])
            titleLabel.trailingAnchor.pin(to: centerXAnchor, constant: -4)
            selectedCountLabel.leadingAnchor.pin(to: centerXAnchor, constant: 4)
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            layer.cornerRadius = appearance.confirmButtonAppearance.cornerRadius
            layer.cornerCurve = appearance.confirmButtonAppearance.cornerCurve
            backgroundColor = appearance.confirmButtonAppearance.backgroundColor
            titleLabel.textColor = appearance.confirmButtonAppearance.labelAppearance.foregroundColor
            titleLabel.font = appearance.confirmButtonAppearance.labelAppearance.font
            titleLabel.backgroundColor = appearance.confirmButtonAppearance.labelAppearance.backgroundColor
            selectedCountLabel.textColor = appearance.countLabelAppearance.foregroundColor
            selectedCountLabel.font = appearance.countLabelAppearance.font
            selectedCountLabel.backgroundColor = appearance.countLabelAppearance.backgroundColor
            selectedCountLabel.widthAnchor.pin(greaterThanOrEqualTo: selectedCountLabel.heightAnchor)
        }
        
        override open func layoutSubviews() {
            super.layoutSubviews()
            selectedCountLabel.layer.cornerRadius = selectedCountLabel.bounds.height / 2
        }
    }
}

