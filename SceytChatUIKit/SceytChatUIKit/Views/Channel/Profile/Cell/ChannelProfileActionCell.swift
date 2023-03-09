//
//  ChannelProfileActionCell.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelProfileActionCell: TableViewCell {

    open lazy var actionButton = UIButton()
        .withoutAutoresizingMask

    open var title: String? {
        set { actionButton.setTitle(newValue, for: .normal) }
        get { actionButton.title(for: .normal)}
    }

    open var onButtonAction: (() -> Void)?

    open override func setup() {
        super.setup()
        actionButton.addTarget(self, action: #selector(buttonAction(_:)), for: .touchUpInside)
    }

    open override func setupAppearance() {
        super.setupAppearance()
        contentView.backgroundColor = Appearance.Colors.background
        actionButton.titleLabel?.font = Fonts.regular.withSize(16)
        actionButton.setTitleColor(Appearance.Colors.textRed, for: .normal)
    }

    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(actionButton)
        actionButton.pin(to: contentView, anchors: [.leading(16), .top(), .bottom()])
        actionButton.resize(anchors: [.height(50, .greaterThanOrEqual)])
    }

    @objc
    open func buttonAction(_ sender: UIButton) {
        onButtonAction?()
    }

}
