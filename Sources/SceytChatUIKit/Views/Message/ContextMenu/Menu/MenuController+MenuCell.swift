//
//  MenuController+MenuCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 16.02.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension MenuController {
    open class MenuCell: CollectionViewCell {
        
        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
        open lazy var iconView = UIImageView()
            .withoutAutoresizingMask
        open lazy var separatorView = UIView()
            .withoutAutoresizingMask
        
        open override func setup() {
            super.setup()
            iconView.contentMode = .scaleAspectFit
            selectedBackgroundView = UIView()
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            contentView.addSubview(iconView)
            contentView.addSubview(titleLabel)
            contentView.addSubview(separatorView)
            
            titleLabel.leadingAnchor.pin(to: contentView.safeAreaLayoutGuide.leadingAnchor, constant: Layout.insets.left)
            titleLabel.topAnchor.pin(to: contentView.safeAreaLayoutGuide.topAnchor, constant: Layout.insets.top)
            contentView.safeAreaLayoutGuide.bottomAnchor.pin(to: titleLabel.bottomAnchor, constant: Layout.insets.bottom)
            iconView.heightAnchor.pin(constant: Layout.imageSize.height)
            iconView.widthAnchor.pin(constant: Layout.imageSize.width)
            contentView.safeAreaLayoutGuide.trailingAnchor.pin(to: iconView.trailingAnchor, constant: Layout.insets.right)
            iconView.centerYAnchor.pin(to: titleLabel.centerYAnchor)
            iconView.leadingAnchor.pin(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: Layout.insets.right)
            separatorView.leadingAnchor.pin(to: contentView.safeAreaLayoutGuide.leadingAnchor)
            contentView.safeAreaLayoutGuide.trailingAnchor.pin(to: separatorView.trailingAnchor)
            contentView.safeAreaLayoutGuide.bottomAnchor.pin(to: separatorView.bottomAnchor)
            separatorView.heightAnchor.pin(constant: 1)
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            selectedBackgroundView?.backgroundColor = appearance.selectedBackgroundColor
            backgroundColor = appearance.backgroundColor
            separatorView.backgroundColor = appearance.separatorColor
            titleLabel.textColor = appearance.textColor
            titleLabel.font = appearance.textFont
            iconView.tintColor = appearance.imageTintColor
        }
        
        open var item: MenuItem? {
            didSet {
                if let item {
                    if item.attributedTitle != nil {
                        titleLabel.attributedText = item.attributedTitle
                    } else {
                        titleLabel.text = item.title
                        if item.destructive {
                            titleLabel.textColor = appearance.destructiveTextColor
                        } else {
                            titleLabel.textColor = appearance.textColor
                        }
                    }
                    iconView.image = item.image?.withRenderingMode(item.imageRenderingMode)
                    if item.destructive {
                        iconView.tintColor = appearance.destructiveImageTintColor
                    } else {
                        iconView.tintColor = appearance.imageTintColor
                    }
                } else {
                    titleLabel.text = nil
                    iconView.image = nil
                }
            }
        }
        
        open var contentInsets: UIEdgeInsets = .zero {
            didSet {
                setNeedsLayout()
                layoutIfNeeded()
            }
        }
        
        open override var safeAreaInsets: UIEdgeInsets {
            var safeAreaInsets = super.safeAreaInsets
            safeAreaInsets.left += contentInsets.left
            safeAreaInsets.right += contentInsets.right
            safeAreaInsets.top += contentInsets.top
            safeAreaInsets.bottom += contentInsets.bottom
            return safeAreaInsets
        }
    }
}

extension MenuController.MenuCell {
    public enum Layout {
        static let insets = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
        static let imageSize: CGSize = .init(width: 24, height: 24)
    }
}
