//
//  ChannelMemberListViewController+MemberCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelMemberListViewController {
    open class MemberCell: TableViewCell {
        
        open lazy var avatarView = Components.circleImageView
            .init()
            .contentMode(.scaleAspectFill)
            .withoutAutoresizingMask
        
        private lazy var textStackView = UIStackView(
            column: [titleLabel, statusLabel],
            spacing: 3,
            alignment: .leading
        )
            .withoutAutoresizingMask
        
        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.defaultLow)
        
        open lazy var statusLabel = UILabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.defaultLow)
        
        open lazy var roleLabel = ContentInsetLabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.defaultLow)
        
        open lazy var separatorView = UIView()
            .withoutAutoresizingMask
        
        override open func setup() {
            super.setup()
            roleLabel.clipsToBounds = true
            roleLabel.edgeInsets = .init(top: 2, left: 8, bottom: 2, right: 8)
            roleLabel.layer.cornerRadius = 9
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.backgroundColor
            contentView.backgroundColor = .clear
            separatorView.backgroundColor = appearance.separatorColor
            
            titleLabel.textColor = appearance.titleLabelTextColor
            titleLabel.font = appearance.titleLabelFont
            
            statusLabel.textColor = appearance.statusLabelTextColor
            statusLabel.font = appearance.statusLabelFont
            
            roleLabel.textColor = appearance.roleLabelTextColor
            roleLabel.font = appearance.roleLabelFont
            roleLabel.backgroundColor = appearance.roleLabelBackgroundColor
        }
        
        override open func setupLayout() {
            super.setupLayout()
            contentView.addSubview(avatarView)
            contentView.addSubview(textStackView)
            contentView.addSubview(roleLabel)
            contentView.addSubview(separatorView)
            
            avatarView.leadingAnchor.pin(to: contentView.leadingAnchor, constant: 16)
            avatarView.pin(to: contentView, anchors: [.top(8, .greaterThanOrEqual), .centerY()])
            avatarView.resize(anchors: [.height(40), .width(40)])
            
            textStackView.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 12)
            textStackView.pin(to: contentView, anchors: [.top(8, .greaterThanOrEqual), .centerY])
            separatorView.topAnchor.pin(greaterThanOrEqualTo: textStackView.bottomAnchor, constant: 8)
            textStackView.trailingAnchor.pin(lessThanOrEqualTo: roleLabel.leadingAnchor)
            
            roleLabel.pin(to: contentView, anchors: [.centerY, .trailing(-16)])
            separatorView.pin(to: contentView, anchors: [.bottom, .trailing(-16)])
            separatorView.leadingAnchor.pin(to: titleLabel.leadingAnchor)
            separatorView.heightAnchor.pin(constant: 1)
            contentView.heightAnchor.pin(greaterThanOrEqualToConstant: 56)
        }
        
        var imageTask: Cancellable?
        
        open var data: ChatChannelMember! {
            didSet {
                guard let data
                else { return }
                
                if me == data.id {
                    titleLabel.text = L10n.User.current
                    selectionStyle = .none
                } else {
                    titleLabel.text = SceytChatUIKit.shared.formatters.userNameFormatter.format(data)
                    selectionStyle = .default
                }
                
                roleLabel.text = data.roleName == SceytChatUIKit.shared.config.groupRoleParticipant ? nil : data.roleName?.localizedCapitalized
                statusLabel.text = SceytChatUIKit.shared.formatters.userPresenceDateFormatter.format(data.presence)
                
                imageTask = AvatarBuilder
                    .loadAvatar(into: avatarView,
                                for: data)
            }
        }
        
        override open func prepareForReuse() {
            super.prepareForReuse()
            avatarView.imageView.image = nil
            imageTask?.cancel()
        }
    }
}
