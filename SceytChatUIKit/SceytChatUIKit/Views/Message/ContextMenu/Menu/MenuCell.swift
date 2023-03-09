//
//  MenuCell.swift
//  Emoji-Custom-Transition
//
//

import UIKit

open class MenuCell: CollectionViewCell {

    open lazy var titleLabel = UILabel()
        .withoutAutoresizingMask
    open lazy var iconView = UIImageView()
        .withoutAutoresizingMask
    open lazy var separatorView = UIView()
        .withoutAutoresizingMask
    
    override open var isHighlighted: Bool {
        didSet {
            contentView.backgroundColor = isHighlighted ? appearance.selectedBackgroundColor : appearance.backgroundColor
        }
    }
    
    open override func setup() {
        super.setup()
        iconView.contentMode = .scaleAspectFit
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(separatorView)
        
        titleLabel.leadingAnchor.pin(to: contentView.leadingAnchor, constant: Layout.insets.left)
        titleLabel.topAnchor.pin(to: contentView.topAnchor, constant: Layout.insets.top)
        contentView.bottomAnchor.pin(to: titleLabel.bottomAnchor, constant: Layout.insets.bottom)
        iconView.heightAnchor.pin(constant: Layout.imageSize.height)
        iconView.widthAnchor.pin(constant: Layout.imageSize.width)
        contentView.trailingAnchor.pin(to: iconView.trailingAnchor, constant: Layout.insets.right)
        iconView.centerYAnchor.pin(to: titleLabel.centerYAnchor)
        iconView.leadingAnchor.pin(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: Layout.insets.right)
        separatorView.leadingAnchor.pin(to: contentView.leadingAnchor)
        contentView.trailingAnchor.pin(to: separatorView.trailingAnchor)
        contentView.bottomAnchor.pin(to: separatorView.bottomAnchor)
        separatorView.heightAnchor.pin(constant: 1)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        contentView.backgroundColor = appearance.backgroundColor
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
}

private enum Layout {
    static let insets = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
    static let imageSize: CGSize = .init(width: 20, height: 20)
    static let separatorX: CGFloat = 24
}
