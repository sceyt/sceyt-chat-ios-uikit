//
//  CreateChatActionsView.swift
//  SceytChatUIKit
//

import UIKit


class CreateChatActionsView: View {
    
    lazy var groupView: Control = {
        return $0.withoutAutoresizingMask
    }(Control())
    
    lazy var channelView: Control = {
        return $0.withoutAutoresizingMask
    }(Control())
    
    lazy var groupIconView: UIImageView = {
        $0.image = Images.channelCreatePrivate
        $0.contentMode = .center
        return $0.withoutAutoresizingMask
    }(UIImageView())
    
    lazy var groupTitleLabel: UILabel = {
        $0.text = L10n.Channel.New.createPrivate
        $0.font = Fonts.regular.withSize(16)
        $0.textColor = Colors.textBlack
        $0.textAlignment = .left
        return $0.withoutAutoresizingMask
    }(UILabel())
    
    lazy var groupBottomLine: UIView = {
        $0.backgroundColor = Colors.separatorBorder
        return $0.withoutAutoresizingMask
    }(UIView())

    lazy var channelIconView: UIImageView = {
        $0.image = Images.channelCreatePrivate
        $0.contentMode = .center
        return $0.withoutAutoresizingMask
    }(UIImageView())
    
    lazy var channelTitleLabel: UILabel = {
        $0.text = L10n.Channel.New.createPublic
        $0.font = Fonts.regular.withSize(16)
        $0.textColor = Colors.textBlack
        $0.textAlignment = .left
        return $0.withoutAutoresizingMask
    }(UILabel())
    
    lazy var channelBottomLine: UIView = {
        $0.backgroundColor = Colors.separatorBorder
        return $0.withoutAutoresizingMask
    }(UIView())
    
    override func setupLayout() {
        super.setupLayout()
        
        addSubview(groupView)
        addSubview(channelView)
        
        groupView.resize(anchors: [.height(48)])
        channelView.resize(anchors: [.height(48)])
        
        groupView.pin(to: self, anchors: [.leading(), .top(), .trailing()])
        channelView.pin(to: self, anchors: [.leading(), .bottom(), .trailing()])
        channelView.topAnchor.pin(to: groupView.bottomAnchor)

        groupView.addSubview(groupIconView)
        groupView.addSubview(groupTitleLabel)
        groupView.addSubview(groupBottomLine)
        
        
        channelView.addSubview(channelIconView)
        channelView.addSubview(channelTitleLabel)
        channelView.addSubview(channelBottomLine)
        
        groupIconView.pin(to: groupView, anchor: .leading(16))
        groupIconView.resize(anchors: [.width(28), .height(28)])
        groupIconView.centerYAnchor.pin(to: groupView.centerYAnchor)
        
        groupTitleLabel.leadingAnchor.pin(to: groupIconView.trailingAnchor, constant: 16)
        groupTitleLabel.trailingAnchor.pin(to: groupView.trailingAnchor, constant: -16)
        groupTitleLabel.centerYAnchor.pin(to: groupView.centerYAnchor)
        
        groupBottomLine.pin(to: groupTitleLabel, anchors: [.trailing(), .leading()])
        groupBottomLine.bottomAnchor.pin(to: groupView.bottomAnchor)
        groupBottomLine.heightAnchor.pin(constant: 1)
        
        channelIconView.pin(to: channelView, anchor: .leading(16))
        channelIconView.resize(anchors: [.width(28), .height(28)])
        channelIconView.centerYAnchor.pin(to: channelView.centerYAnchor)
        
        channelTitleLabel.leadingAnchor.pin(to: channelIconView.trailingAnchor, constant: 16)
        channelTitleLabel.trailingAnchor.pin(to: channelView.trailingAnchor, constant: -16)
        channelTitleLabel.centerYAnchor.pin(to: channelView.centerYAnchor)
        
        channelBottomLine.pin(to: channelTitleLabel, anchors: [.trailing(), .leading()])
        channelBottomLine.bottomAnchor.pin(to: channelView.bottomAnchor)
        channelBottomLine.heightAnchor.pin(constant: 1)
    }
}
