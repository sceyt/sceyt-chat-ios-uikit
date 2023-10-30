//
//  ChannelProfileHeaderCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelProfileHeaderCell: TableViewCell {
   
    open lazy var avatarButton = CircleButton()
        .withoutAutoresizingMask
    
    open lazy var titleLabel = UILabel()
        .withoutAutoresizingMask
    
    open lazy var subtitleLabel = UILabel()
        .withoutAutoresizingMask
    
    open lazy var row = UIStackView(row: [avatarButton, column], spacing: 12, alignment: .center)
        .withoutAutoresizingMask
    
    open lazy var column = UIStackView(column: [titleLabel, subtitleLabel])
        .withoutAutoresizingMask
    
    public lazy var appearance = ChannelProfileVC.appearance {
        didSet {
            setupAppearance()
        }
    }
    
    override open func setup() {
        super.setup()
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        backgroundColor = appearance.cellBackgroundColor
        titleLabel.textColor = appearance.titleColor
        titleLabel.font = appearance.titleFont
        subtitleLabel.textColor = appearance.subtitleColor
        subtitleLabel.font = appearance.subtitleFont
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        contentView.addSubview(row)
        row.pin(to: contentView, anchors: [.leading(16), .trailing(-16), .top(16), .bottom(-16)])
        avatarButton.resize(anchors: [.width(72), .height(72)])
        
        column.setCustomSpacing(2, after: titleLabel)
    }
    
    open override var safeAreaInsets: UIEdgeInsets {
        .init(top: 0, left: ChannelProfileVC.Layouts.cellHorizontalPadding, bottom: 0, right: ChannelProfileVC.Layouts.cellHorizontalPadding)
    }
    
    public var imageTask: Cancellable?
    
    open var data: ChatChannel! {
        didSet {
            guard data != nil else { return }
            updateTitle()
            updateSubtitle()
            updateAvatar()
        }
    }
    
    open func updateAvatar() {
        imageTask = AvatarBuilder
            .loadAvatar(into: avatarButton,
                        for: data)
    }
    
    open func updateTitle() {
        titleLabel.text = data.displayName
    }
    
    open func updateSubtitle() {
        guard data.userRole != nil
        else {
            subtitleLabel.text = nil
            return
        }
        switch data.channelType {
        case .broadcast:
            switch data.memberCount {
            case 1:
                subtitleLabel.text = L10n.Channel.SubscriberCount.one
            case 2...:
                subtitleLabel.text = L10n.Channel.SubscriberCount.more(Int(data.memberCount))
            default:
                subtitleLabel.text = ""
            }
        case .private:
            switch data.memberCount {
            case 1:
                subtitleLabel.text = L10n.Channel.MembersCount.one
            case 2...:
                subtitleLabel.text = L10n.Channel.MembersCount.more(Int(data.memberCount))
            default:
                subtitleLabel.text = ""
            }
        case .direct:
            if let presence = data.peer?.presence {
                subtitleLabel.text = Formatters.userPresenceFormatter.format(presence)
            } else {
                subtitleLabel.text = data.peer?.presence.status
            }
        }
    }
    
    override open func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
    }
    
}
