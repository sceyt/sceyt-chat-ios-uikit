//
//  MemberRolesCell.swift
//  SceytChatUIKit
//

import UIKit
import SceytChat

open class MemberRolesCell: TableViewCell, Bindable {

    open lazy var titleLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var checkBoxView = CheckBoxView
        .init()
        .withoutAutoresizingMask

    open override var isSelected: Bool {
        didSet {
            checkBoxView.isSelected = isSelected
        }
    }

    open override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        checkBoxView.isSelected = selected
    }

    open override func setup() {
        super.setup()
        checkBoxView.isUserInteractionEnabled = false
    }

    open override func setupAppearance() {
        super.setupAppearance()
        selectionStyle = .none
        titleLabel.font = Fonts.regular.withSize(14)
        titleLabel.textColor = Appearance.Colors.textBlack
    }

    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(titleLabel)
        contentView.addSubview(checkBoxView)

        checkBoxView.pin(to: contentView, anchors: [.trailing(), .top(), .bottom()])
        checkBoxView.resize(anchors: [.width(40)])
        titleLabel.pin(to: contentView, anchors: [.leading(16), .centerY()])
        titleLabel.trailingAnchor.pin(to: checkBoxView.leadingAnchor, constant: -10)
    }

    open func bind(_ data: Role) {
        titleLabel.text = data.name
    }
}
