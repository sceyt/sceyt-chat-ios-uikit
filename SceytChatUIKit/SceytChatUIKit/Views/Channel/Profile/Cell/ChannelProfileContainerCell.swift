//
//  ChannelProfileBottomContainerCell.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelProfileContainerCell: TableViewCell {

    open var containerView: UIView?
    
    private lazy var heightAnchorView = UIView()
        .withoutAutoresizingMask
    
    public var heightAnchorConstant: CGFloat? {
        didSet {
            let constraint = heightAnchorView.constraints.first(where: {$0.firstAttribute == .height})
            if let heightAnchorConstant {
                if let constraint {
                    constraint.constant = heightAnchorConstant
                } else {
                    heightAnchorView.heightAnchor.pin(constant: heightAnchorConstant)
                }
                
            } else if let constraint {
                heightAnchorView.removeConstraint(constraint)
            }
        }
    }
    
    public lazy var appearance = ChannelProfileVC.appearance {
        didSet {
            setupAppearance()
        }
    }
    
    open override func setup() {
        super.setup()
        heightAnchorView.alpha = 0
    }
    
    open override func setupLayout() {
        super.setupLayout()
        guard let containerView
        else { return }
        contentView.addSubview(containerView)
        contentView.addSubview(heightAnchorView)
        containerView.pin(to: contentView)
        heightAnchorView.pin(to: contentView, anchors: [.leading(-100), .top, .bottom])
        heightAnchorView.widthAnchor.pin(constant: 1)
        if let heightAnchorConstant {
            heightAnchorView.heightAnchor.pin(constant: heightAnchorConstant)
        }
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        backgroundColor = appearance.itemsBackgroundColor
        contentView.backgroundColor = appearance.itemsBackgroundColor
    }
}
