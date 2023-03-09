//
//  SelectedUserCell.swift
//  SceytChatUIKit
//

import UIKit


class SelectedUserCell: CollectionViewCell {
    
    lazy var avatarView = AvatarView()
        .withoutAutoresizingMask
    
    lazy var label: UILabel = {
        $0.font = Fonts.regular.withSize(12)
        $0.textColor = Colors.textBlack
        $0.backgroundColor = .clear
        $0.textAlignment = .center
        $0.lineBreakMode = .byTruncatingMiddle
        return $0
    }(UILabel().withoutAutoresizingMask)
    
    lazy var presenceView = UIImageView(image: .online)
        .withoutAutoresizingMask
    
    var onDelete: ((SelectedUserCell) -> Void)?
    
    override func setup() {
        super.setup()
        
        avatarView.button.onTouchUpInside { [unowned self] in
            onDelete?(self)
        }
    }
    
    override func setupLayout() {
        super.setupLayout()
        addSubview(avatarView)
        addSubview(label)
        addSubview(presenceView)
        
        avatarView.leadingAnchor.pin(greaterThanOrEqualTo: leadingAnchor)
        avatarView.topAnchor.pin(to: topAnchor)
        avatarView.trailingAnchor.pin(greaterThanOrEqualTo: trailingAnchor)
        avatarView.centerXAnchor.pin(to: centerXAnchor)
        avatarView.heightAnchor.pin(constant: 64)
        label.leadingAnchor.pin(greaterThanOrEqualTo: leadingAnchor)
        label.trailingAnchor.pin(lessThanOrEqualTo: trailingAnchor)
        label.centerXAnchor.pin(to: centerXAnchor)
        label.bottomAnchor.pin(greaterThanOrEqualTo: bottomAnchor)
        label.topAnchor.pin(to: avatarView.bottomAnchor, constant: 6)
        label.widthAnchor.pin(constant: 64)
        
        presenceView.pin(to: avatarView, anchors: [
            .trailing(-3.5),
            .bottom(-1.5)
        ])
    }
    
    var imageTask: Cancellable?
    
    var data: ChatUser! {
        didSet {
            label.text = data.firstName ?? data.lastName
            presenceView.isHidden = data.presence.state != .online
            avatarView.imageView.image = .deletedUser
            imageTask = Components.avatarBuilder.loadAvatar(into: avatarView.imageView.imageView, for: data)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        onDelete = nil
    }
}

extension SelectedUserCell {
    class AvatarView: View {
        lazy var imageView = CircleImageView().withoutAutoresizingMask
        
        lazy var button: UIButton = {
            $0.setImage(.closeImage, for: .normal)
            return $0
        }(UIButton().withoutAutoresizingMask)
        
        override func setupLayout() {
            super.setupLayout()
            addSubview(imageView)
            addSubview(button)
            
            imageView.topAnchor.pin(to: topAnchor)
            imageView.centerXAnchor.pin(to: centerXAnchor)
            imageView.widthAnchor.pin(constant: 64)
            imageView.heightAnchor.pin(to: imageView.widthAnchor)
            button.topAnchor.pin(to: imageView.topAnchor)
            button.leadingAnchor.pin(to: imageView.leadingAnchor)
        }
    }
}
