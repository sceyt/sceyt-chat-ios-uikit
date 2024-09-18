//
//  ReactionsInfoViewController+ReactionScoreCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension ReactionsInfoViewController {
    open class ReactionScoreCell: CollectionViewCell {
        
        public static var textInsets: UIEdgeInsets? = .init(top: 6, left: 12, bottom: 6, right: 12)
        public static var containerInsets: UIEdgeInsets? = .init(top: 8, left: 4, bottom: 8, right: 4)
        
        open lazy var label = UILabel()
            .withoutAutoresizingMask
        open lazy var container = UIView()
            .withoutAutoresizingMask
        
        open var data: String! {
            didSet {
                guard let data = data else { return }
                label.text = data
            }
        }
        
        open override var isSelected: Bool {
            didSet {
                label.textColor = isSelected ? appearance.selectedTextColor : appearance.textColor
                container.backgroundColor = isSelected ? appearance.selectedBackgroundColor : appearance.backgroundColor
                _setCGColors()
            }
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            label.font = appearance.textFont
            label.textColor = appearance.textColor
            container.backgroundColor = appearance.backgroundColor
            container.layer.borderWidth = 1
            container.layer.cornerRadius = 15
            _setCGColors()
        }
        
        open override func setupLayout() {
            super.setupLayout()
            contentView.addSubview(container)
            let cInsets = Self.containerInsets ?? .zero
            container.pin(
                to: contentView,
                anchors: [.leading(cInsets.left), .top(cInsets.top), .trailing(-cInsets.right), .bottom(-cInsets.bottom)]
            )
            let tInsets = Self.textInsets ?? .zero
            container.addSubview(label)
            label.pin(
                to: container,
                anchors: [.leading(tInsets.left), .top(tInsets.top), .trailing(-tInsets.right), .bottom(-tInsets.bottom)]
            )
        }
        
        open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            _setCGColors()
        }
        
        open func _setCGColors() {
            container.layer.borderColor = isSelected ? appearance.selectedBorderColor?.cgColor : appearance.borderColor?.cgColor
        }
        
    }
}
