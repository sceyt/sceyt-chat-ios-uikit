//
//  ChannelProfileNotificationCell.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelProfileNotificationCell: TableViewCell, Bindable {

    open lazy var iconView = UIImageView()
        .withoutAutoresizingMask

    open lazy var titleLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var switchMute = UISwitch()
        .withoutAutoresizingMask

    open lazy var topUnderLine = UIView()
        .withoutAutoresizingMask

    open lazy var bottomUnderLine = UIView()
        .withoutAutoresizingMask

    var onChangeSwitchValue: ((Bool) -> Void)?

    open override func setup() {
        super.setup()
        switchMute.addTarget(self, action: #selector(switchAction(_:)), for: .valueChanged)
    }

    open override func setupAppearance() {
        super.setupAppearance()
        contentView.backgroundColor = Colors.background
        switchMute.onTintColor = Colors.kitBlue
        iconView.image = Appearance.Images.channelNotification
        titleLabel.backgroundColor = Colors.textBlack
        titleLabel.textAlignment = .left
        titleLabel.text = L10n.Channel.Profile.Mute.title
        titleLabel.textColor = Colors.textBlack
        titleLabel.font = Fonts.regular.withSize(16)
        titleLabel.backgroundColor = .clear
        topUnderLine.backgroundColor = Colors.background4
        bottomUnderLine.backgroundColor = Colors.background4
    }

    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(topUnderLine)
        contentView.addSubview(bottomUnderLine)
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(switchMute)
        topUnderLine.pin(to: contentView, anchors: [.leading(16), .trailing(-16), .top()])
        topUnderLine.resize(anchors: [.height(1)])
        bottomUnderLine.pin(to: contentView, anchor: .bottom())
        bottomUnderLine.pin(to: topUnderLine, anchors: [.leading(), .trailing()])
        bottomUnderLine.resize(anchors: [.height(1)])
        iconView.pin(to: contentView, anchor: .centerY())
        iconView.pin(to: topUnderLine, anchor: .leading())
        iconView.topAnchor.pin(greaterThanOrEqualTo: topUnderLine.bottomAnchor, constant: 12)
        iconView.bottomAnchor.pin(lessThanOrEqualTo: bottomUnderLine.topAnchor, constant: 12)
        titleLabel.centerYAnchor.pin(to: contentView.centerYAnchor)
        titleLabel.leadingAnchor.pin(to: iconView.trailingAnchor, constant: 12)
        titleLabel.topAnchor.pin(greaterThanOrEqualTo: topUnderLine.bottomAnchor, constant: 12)
        titleLabel.bottomAnchor.pin(lessThanOrEqualTo: bottomUnderLine.topAnchor, constant: 12)
        switchMute.pin(to: contentView, anchor: .centerY())
        switchMute.pin(to: topUnderLine, anchor: .trailing())
        bottomUnderLine.topAnchor.pin(greaterThanOrEqualTo: topUnderLine.bottomAnchor, constant: 50)
    }

    @objc
    open func switchAction(_ sender: UISwitch) {
        onChangeSwitchValue?(sender.isOn)
    }

    open func bind(_ data: Bool) {
        switchMute.isOn = data
    }
}
