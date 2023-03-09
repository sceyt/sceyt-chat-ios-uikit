//
//  ChannelProfileEditAvatarCell.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelProfileEditAvatarCell: TableViewCell {

    open lazy var avatarButton = CircleButton()
        .withoutAutoresizingMask
    
    open lazy var editButton = CircleButton()
        .withoutAutoresizingMask

    open override func setup() {
        super.setup()
        editButton.setImage(.channelProfileEditAvatar, for: .normal)
        editButton.isUserInteractionEnabled = false
    }

    override open func setupLayout() {
        super.setupLayout()
        contentView.addSubview(avatarButton)
        contentView.addSubview(editButton)
        avatarButton.pin(to: contentView, anchors: [.top, .centerX])
        avatarButton.bottomAnchor.pin(to: contentView.bottomAnchor, constant: -6)
        avatarButton.resize(anchors: [.width(90), .height(90)])
        editButton.leadingAnchor.pin(to: avatarButton.leadingAnchor)
        editButton.trailingAnchor.pin(to: avatarButton.trailingAnchor)
        editButton.topAnchor.pin(to: avatarButton.topAnchor)
        editButton.bottomAnchor.pin(to: avatarButton.bottomAnchor)
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }
    
    public var imageTask: Cancellable?
    
    open var data: ChatChannel! {
        didSet {
            guard data != nil else { return }
            updateAvatar()
        }
    }
    
    open func updateAvatar() {
        imageTask = AvatarBuilder
            .loadAvatar(into: avatarButton,
                        for: data)
    }
    
    override open func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
    }
}


