//
//  MessageSectionSeparatorView.swift
//  SceytChatUIKit
//

import UIKit

open class MessageSectionSeparatorView: CollectionReusableView {
    
    open lazy var titleLabel = ContentInsetLabel
        .init()
        .withoutAutoresizingMask
    
    public lazy var appearance = MessageCell.appearance {
        didSet {
            setupAppearance()
        }
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        titleLabel.isHidden = true
        backgroundColor = appearance.separatorViewBackgroundColor
        titleLabel.backgroundColor = appearance.separatorViewTextBackgroundColor
        titleLabel.font = appearance.separatorViewFont
        titleLabel.textAlignment = .center
        titleLabel.textColor = appearance.separatorViewTextColor
        titleLabel.clipsToBounds = true
        titleLabel.layer.borderWidth = 1
        titleLabel.layer.borderColor = appearance.separatorViewTextBorderColor?.cgColor
        titleLabel.layer.cornerRadius = 10
    }
    
    open override func setupLayout() {
        super.setupLayout()
        addSubview(titleLabel)
        titleLabel.pin(to: self, anchors: [
            .top(6),
                .bottom(-6),
                .centerX(),
                .centerY()]
        )
    }
    
    open var date: Date? {
        didSet {
            if let date = date {
                titleLabel.edgeInsets = .init(top: 4, left: 6, bottom: 4, right: 6)
                titleLabel.text = Formatters.messageListSeparator.format(date)
                titleLabel.isHidden = false
            } else {
                titleLabel.edgeInsets = .zero
                titleLabel.text = nil
                titleLabel.isHidden = true
            }
        }
    }
    
    open override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let preferredAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
//        guard preferredAttributes.frame != layoutAttributes.frame else { return preferredAttributes }
        let targetSize = CGSize(width: layoutAttributes.frame.width, height: UIView.layoutFittingCompressedSize.height)
        preferredAttributes.frame.size = self.systemLayoutSizeFitting(targetSize,
                                                                      withHorizontalFittingPriority: .required,
                                                                      verticalFittingPriority: .fittingSizeLevel)
        return preferredAttributes
    }
    
    open override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
    }
    
}
