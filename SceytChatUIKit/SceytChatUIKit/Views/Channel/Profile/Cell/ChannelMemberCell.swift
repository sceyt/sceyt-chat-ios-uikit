//
//  ChannelMemberCell.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelMemberCell: TableViewCell {
    
    open lazy var avatarView = Components.circleImageView
        .init()
        .contentMode(.scaleAspectFill)
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
        contentView.backgroundColor = appearance.backgroundColor
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
        contentView.addSubview(titleLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(roleLabel)
        contentView.addSubview(separatorView)
      
        avatarView.leadingAnchor.pin(to: contentView.leadingAnchor, constant: 16)
        avatarView.pin(to: contentView, anchors: [.top(6, .greaterThanOrEqual), .bottom(6, .greaterThanOrEqual), .centerY()])
        avatarView.resize(anchors: [.height(40), .width(40)])
        titleLabel.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 12)
        titleLabel.pin(to: contentView, anchors: [.top(7), .trailing(-16, .greaterThanOrEqual)])
        statusLabel.leadingAnchor.pin(to: titleLabel.leadingAnchor)
        statusLabel.pin(to: contentView, anchors: [.bottom(-7), .trailing(-16, .greaterThanOrEqual)])
        statusLabel.topAnchor.pin(to: titleLabel.bottomAnchor)
        titleLabel.heightAnchor.pin(greaterThanOrEqualToConstant: 22)
        statusLabel.heightAnchor.pin(greaterThanOrEqualToConstant: 16)
        roleLabel.pin(to: contentView, anchors: [.centerY, .trailing(-16)])
        separatorView.pin(to: contentView, anchors: [.bottom(), .trailing()])
        separatorView.leadingAnchor.pin(to: titleLabel.leadingAnchor)
        separatorView.heightAnchor.pin(constant: 1)
        contentView.heightAnchor.pin(greaterThanOrEqualToConstant: 52)
    }
    
    var imageTask: Cancellable?
 
    open var data: ChatChannelMember! {
        didSet {
            guard let data
            else { return }
            
            if me == data.id {
                titleLabel.text = L10n.User.current
            } else {
                titleLabel.text = Formatters.userDisplayName.format(data)
            }
            
            roleLabel.text = data.roleName?.localizedCapitalized
            statusLabel.text = Formatters.userPresenceFormatter.format(data.presence)
            
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
