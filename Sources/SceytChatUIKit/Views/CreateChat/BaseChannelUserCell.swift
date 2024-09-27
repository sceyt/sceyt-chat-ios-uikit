//
//  CreateChannelUserCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class BaseChannelUserCell: TableViewCell {
    open lazy var avatarView = Components.circleImageView.init()
        .contentMode(.scaleAspectFill)
        .withoutAutoresizingMask
    
    open lazy var titleLabel = UILabel()
        .withoutAutoresizingMask
        .contentCompressionResistancePriorityH(.defaultLow)
        
    open lazy var statusLabel = UILabel()
        .withoutAutoresizingMask
        .contentCompressionResistancePriorityH(.defaultLow)
    
    open lazy var textVStack = UIStackView(column: [titleLabel, statusLabel], spacing: Layouts.textPadding)
        .withoutAutoresizingMask
        
    open lazy var checkBoxView = Components.checkBoxView.init()
        .withoutAutoresizingMask
    
    open lazy var separatorView = UIView().withoutAutoresizingMask
    
    open var showCheckBox = false {
        didSet {
            selectionStyle = showCheckBox ? .none : .default
        }
    }
    
    override open func setup() {
        super.setup()
        
        checkBoxView.isUserInteractionEnabled = false
    }
    
    override open func setupLayout() {
        super.setupLayout()
        contentView.addSubview(checkBoxView)
        contentView.addSubview(avatarView)
        contentView.addSubview(textVStack)
        contentView.addSubview(separatorView)
        
        checkBoxView.pin(to: contentView, anchors: [.leading(6), .centerY()])
        checkBoxView.resize(anchors: [.width(44), .height(44)])
        checkBoxView.isHidden = !showCheckBox
        if showCheckBox {
            avatarView.leadingAnchor.pin(to: checkBoxView.trailingAnchor, constant: 2)
        } else {
            avatarView.leadingAnchor.pin(to: contentView.leadingAnchor, constant: Layouts.horizontalPadding)
        }
        
        avatarView.pin(to: contentView, anchors: [.top(Layouts.verticalPadding, .greaterThanOrEqual), .centerY])
        avatarView.resize(anchors: [.height(Layouts.iconSize), .width(Layouts.iconSize)])
        textVStack.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: Layouts.horizontalPadding)
        textVStack.pin(to: contentView, anchors: [.top(Layouts.verticalPadding, .greaterThanOrEqual), .trailing(-Layouts.horizontalPadding), .centerY])
        separatorView.topAnchor.pin(greaterThanOrEqualTo: textVStack.bottomAnchor, constant: Layouts.verticalPadding)
        separatorView.pin(to: contentView, anchors: [.bottom, .trailing(-Layouts.horizontalPadding)])
        separatorView.leadingAnchor.pin(to: titleLabel.leadingAnchor)
        separatorView.heightAnchor.pin(constant: 1)
    }
        
    open var imageTask: Cancellable?
 
    override open func prepareForReuse() {
        super.prepareForReuse()
        
        titleLabel.text = nil
        statusLabel.text = nil
        imageTask?.cancel()
    }
}

public extension BaseChannelUserCell {
    enum Layouts {
        public static var iconSize: CGFloat = 40
        public static var verticalPadding: CGFloat = 8
        public static var horizontalPadding: CGFloat = 16
        public static var textPadding: CGFloat = 3
    }
}
