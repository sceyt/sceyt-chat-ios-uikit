//
//  CreateChannelUserCell.swift
//  SceytChatUIKit
//

import UIKit

class CreateChannelUserCell: TableViewCell {
    
    lazy var avatarView: CircleImageView = {
        $0.contentMode = .scaleAspectFill
        $0.image = .deletedUser
        return $0.withoutAutoresizingMask
    }(CircleImageView())
    
    lazy var titleLabel: UILabel = {
        $0.font = Fonts.semiBold.withSize(16)
        $0.textColor = .textBlack
        return $0.withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.defaultLow)
    }(UILabel())
        
    lazy var statusLabel: UILabel = {
        $0.font = Fonts.regular.withSize(13)
        $0.textColor = Colors.textGray
        return $0.withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.defaultLow)
    }(UILabel())
        
    lazy var checkBoxView = CheckBoxView
        .init()
        .withoutAutoresizingMask
    
    lazy var separatorView: UIView = {
        $0.backgroundColor = Colors.separatorBorder
        return $0.withoutAutoresizingMask
    }(UIView())
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        checkBoxView.isSelected = selected
    }
    
    override func setup() {
        super.setup()
        checkBoxView.isUserInteractionEnabled = false
    }
  
    var showCheckBox = false
    override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(checkBoxView)
        contentView.addSubview(avatarView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(separatorView)
        
        checkBoxView.pin(to: contentView, anchors: [.leading(16), .centerY()])
        checkBoxView.resize(anchors: [.width(22)])
        checkBoxView.isHidden = !showCheckBox
        if showCheckBox {
            avatarView.leadingAnchor.pin(to: checkBoxView.trailingAnchor, constant: 13)
        } else {
            avatarView.leadingAnchor.pin(to: contentView.leadingAnchor, constant: 16)
        }
        
        avatarView.pin(to: contentView, anchors: [.top(6, .greaterThanOrEqual), .bottom(6, .greaterThanOrEqual), .centerY()])
        avatarView.resize(anchors: [.height(40), .width(40)])
        titleLabel.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 12)
        titleLabel.pin(to: contentView, anchors: [.top(7), .trailing(-16, .greaterThanOrEqual)])
        statusLabel.leadingAnchor.pin(to: titleLabel.leadingAnchor)
        statusLabel.pin(to: contentView, anchors: [.bottom(-7), .trailing(-16, .greaterThanOrEqual)])
        statusLabel.topAnchor.pin(to: titleLabel.bottomAnchor)
        titleLabel.heightAnchor.pin(greaterThanOrEqualToConstant: 22)
        statusLabel.heightAnchor.pin(greaterThanOrEqualToConstant: 16)
        separatorView.pin(to: contentView, anchors: [.bottom(), .trailing()])
        separatorView.leadingAnchor.pin(to: titleLabel.leadingAnchor)
        separatorView.heightAnchor.pin(constant: 1)
    }
    
    var imageTask: Cancellable?
 
    var data: ChatUser! {
        didSet {
            guard let data else { return }
            avatarView.imageView.image = .deletedUser
            titleLabel.text = data.displayName
            statusLabel.text = Formatters.userPresenceFormatter.format(data.presence)
            imageTask = Components.avatarBuilder.loadAvatar(into: avatarView.imageView, for: data)
            subscribeForPresence()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.imageView.image = .deletedUser
        imageTask?.cancel()
    }
    
    func subscribeForPresence() {
        guard let contact = data
        else { return }
        
        PresenceProvider.subscribe(userId: contact.id) { [weak self] user in
            PresenceProvider.unsubscribe(userId: contact.id)
            guard let self
            else { return }
            self.statusLabel.text = Formatters.userPresenceFormatter.format(user.presence)
        }
    }
//
//    func unsubscribeFromPresence() {
//        guard let contact = data
//        else { return }
//        PresenceProvider.unsubscribe(userId: contact.id)
//    }
}
