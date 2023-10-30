//
//  ChannelProfileMenuCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelProfileMenuCell: TableViewCell {

    open lazy var stackView = UIStackView()
        .withoutAutoresizingMask
    
    public lazy var appearance = ChannelProfileVC.appearance {
        didSet {
            setupAppearance()
        }
    }
    
    open override func setup() {
        super.setup()
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 8
    }
    
    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(stackView)
        stackView.pin(to: contentView,
                      anchors: [
                        .centerX,
                            .centerY,
                            .top(0, .greaterThanOrEqual),
                            .leading(0, .greaterThanOrEqual),
                            .bottom(0, .lessThanOrEqual),
                            .trailing(0, .lessThanOrEqual)]
        )
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        backgroundColor = appearance.cellBackgroundColor
    }
    
    open var data: [HoldButton] = [] {
        didSet {
            stackView.removeArrangedSubviews()
            data.forEach {
                stackView.addArrangedSubview($0)
                $0.resize(anchors: [.width(76), .height(56)])
            }
        }
    }
    
    open override var safeAreaInsets: UIEdgeInsets {
        .init(top: 0, left: 16, bottom: 0, right: 16)
    }
}
