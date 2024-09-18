//
//  MediaPickerViewController+FooterView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Photos
import PhotosUI
import UIKit

extension MediaPickerViewController {
    open class FooterView: View {
        public lazy var appearance = Components.mediaPickerViewController.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open lazy var attachButton = Components.mediaPickerAttachButton.init()
            .withoutAutoresizingMask
        
        private var heightConstraint: NSLayoutConstraint?
        
        public var selectedCount: Int {
            get { Int(attachButton.selectedCountLabel.value ?? "0") ?? 0 }
            set {
                attachButton.selectedCountLabel.value = String(newValue)
                if newValue == 0 {
                    heightConstraint?.constant = 0
                } else {
                    heightConstraint?.constant = 80
                }
            }
        }
        
        override open func setup() {
            super.setup()
            attachButton.layer.cornerRadius = 8
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            backgroundColor = appearance.toolbarBackgroundColor
        }
        
        override open func setupLayout() {
            super.setupLayout()
            addSubview(attachButton)
            attachButton.pin(to: self,
                             anchors: [
                                .leading(16),
                                .trailing(-16),
                                .centerY(),
                                .top(0, .greaterThanOrEqual),
                                .bottom(0, .lessThanOrEqual),
                             ])
            attachButton.heightAnchor.pin(constant: 48)
            heightConstraint = resize(anchors: [.height(selectedCount == 0 ? 0 : 80)])[0]
        }
    }
}
