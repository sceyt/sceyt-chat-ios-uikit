//
//  EditChannelViewController+AvatarCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension EditChannelViewController {
    open class AvatarCell: TableViewCell {
        open lazy var avatarButton = CircleButton()
            .withoutAutoresizingMask
        
        open lazy var editButton = CircleButton()
            .withoutAutoresizingMask
        
        override open func setup() {
            super.setup()
            
            editButton.setImage(.channelProfileEditAvatar, for: .normal)
            editButton.isUserInteractionEnabled = false
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            contentView.addSubview(avatarButton)
            contentView.addSubview(editButton)
            avatarButton.pin(to: contentView, anchors: [.top, .bottom, .centerX])
            avatarButton.resize(anchors: [.width(Layouts.avatarSize), .height(Layouts.avatarSize)])
            editButton.pin(to: avatarButton)
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = .clear
            contentView.backgroundColor = .clear
            avatarButton.backgroundColor = appearance.avatarBackgroundColor
        }
        
        public var imageTask: Cancellable?
        
        open var data: URL? {
            didSet {
                updateAvatar()
            }
        }
        
        open func updateAvatar() {
            guard let data else {
                return avatarButton.image = nil
            }
            imageTask = AvatarBuilder.loadAvatar(into: avatarButton, for: data)
        }
        
        override open func prepareForReuse() {
            super.prepareForReuse()
            imageTask?.cancel()
        }
    }
}

extension URL: AvatarBuildable {
    public var hashString: String {
        absoluteString
    }
    
    public var imageUrl: URL? {
        self
    }
    
    public var displayName: String {
        absoluteString
    }
    
    public var defaultAvatar: UIImage? {
        .avatar
    }
    
    public var appearance: InitialsBuilderAppearance? {
        return nil
    }
}

public extension EditChannelViewController.AvatarCell {
    enum Layouts {
        public static var avatarSize: CGFloat = 120
    }
}
