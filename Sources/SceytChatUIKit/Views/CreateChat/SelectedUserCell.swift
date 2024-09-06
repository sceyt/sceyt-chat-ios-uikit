//
//  SelectedUserCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class SelectedUserCell: CollectionViewCell {
    open lazy var avatarView = CircleImageView()
        .withoutAutoresizingMask
    
    open lazy var closeButton: UIButton = {
        $0.setImage(.closeCircle, for: .normal)
        return $0
    }(UIButton().withoutAutoresizingMask)
    
    open lazy var presenceView = UIImageView(image: .online)
        .withoutAutoresizingMask
    
    open lazy var label: UILabel = {
        $0.backgroundColor = .clear
        $0.textAlignment = .center
        $0.lineBreakMode = .byTruncatingMiddle
        return $0
    }(UILabel().withoutAutoresizingMask)
    
    open var onDelete: ((SelectedUserCell) -> Void)?
    
    override open func setup() {
        super.setup()
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        contentView.addSubview(avatarView)
        contentView.addSubview(closeButton)
        contentView.addSubview(label)
        contentView.addSubview(presenceView)
        
        avatarView.pin(to: contentView, anchors: [.leading(0, .greaterThanOrEqual), .centerX, .top])
        avatarView.resize(anchors: [.height(Layouts.avatarSize), .width(Layouts.avatarSize)])
        label.pin(to: contentView, anchors: [.leading(0, .greaterThanOrEqual), .centerX, .bottom])
        label.topAnchor.pin(to: avatarView.bottomAnchor, constant: 4)
        label.widthAnchor.pin(constant: 72)
        
        presenceView.pin(to: avatarView, anchors: [.trailing, .bottom(-2)])
        closeButton.pin(to: avatarView, anchors: [.leading(-2), .top(-2)])
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        label.font = appearance.font
        label.textColor = appearance.textColor
    }
    
    open var imageTask: Cancellable?
    
    open var userData: ChatUser! {
        didSet {
            label.text = SceytChatUIKit.shared.formatters.userNameFormatter.short(userData)
            presenceView.isHidden = userData.presence.state != .online
            avatarView.imageView.image = .deletedUser
            imageTask = Components.avatarBuilder.loadAvatar(into: avatarView, for: userData)
        }
    }
    
    open var channelData: ChatChannel! {
        didSet {
            if let peer = channelData.peer {
                label.text = SceytChatUIKit.shared.formatters.userNameFormatter.short(peer)
            } else {
                label.text = channelData.subject
            }
            presenceView.isHidden = channelData.peer?.presence.state != .online
            imageTask = Components.avatarBuilder.loadAvatar(into: avatarView, for: channelData)
        }
    }
    
    override open func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        onDelete = nil
        
        closeButton.publisher(for: .touchUpInside).sink { [unowned self] _ in
            onDelete?(self)
        }.store(in: &subscriptions)
    }
}

public extension SelectedUserCell {
    enum Layouts {
        public static var avatarSize: CGFloat = 56
    }
}
