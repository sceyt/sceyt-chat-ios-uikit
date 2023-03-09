//
//  ChannelProfileHeaderCell.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelProfileHeaderCell: TableViewCell {
   
    open lazy var avatarButton = CircleButton()
        .withoutAutoresizingMask
    
    open lazy var titleLabel = UILabel()
        .withoutAutoresizingMask
    
    open lazy var subtitleLabel = UILabel()
        .withoutAutoresizingMask
    
    open lazy var stackView = UIStackView(arrangedSubviews: [avatarButton, titleLabel, subtitleLabel])
        .withoutAutoresizingMask
    
    public lazy var appearance = ChannelProfileVC.appearance {
        didSet {
            setupAppearance()
        }
    }
    
    override open func setup() {
        super.setup()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.setCustomSpacing(12, after: avatarButton)
        stackView.setCustomSpacing(2, after: titleLabel)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        backgroundColor = appearance.headerBackgroundColor
        contentView.backgroundColor = appearance.headerBackgroundColor
        titleLabel.textColor = appearance.titleColor
        titleLabel.font = appearance.titleFont
        subtitleLabel.textColor = appearance.subtitleColor
        subtitleLabel.font = appearance.subtitleFont
    }
    
    override open func setupLayout() {
        super.setupLayout()
        contentView.addSubview(stackView)
        stackView.pin(to: contentView)
        avatarButton.resize(anchors: [.width(90), .height(90)])
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
        guard data.roleName != nil
        else {
            subtitleLabel.text = nil
            return
        }
        switch data.type {
        case .public:
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
            if let peer = data.peer {
                subtitleLabel.text = Formatters.userPresenceFormatter.format(peer.presence)
            } else {
                subtitleLabel.text = ""
            }
            
        }
    }
    
    override open func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
    }
    
    open override var safeAreaInsets: UIEdgeInsets {
        .init(top: 0, left: 16, bottom: 0, right: 16)
    }
    
    
}
