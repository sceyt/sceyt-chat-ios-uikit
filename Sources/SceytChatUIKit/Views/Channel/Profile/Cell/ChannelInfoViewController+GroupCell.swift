//
//  ChannelInfoViewController+GroupCell.swift
//  SceytChatUIKit
//
//  Created by Sceyt on 12.12.2024.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

extension ChannelInfoViewController {
    open class GroupCell: CollectionViewCell {
        
        open lazy var avatarView = ImageView()
            .contentMode(.scaleAspectFill)
            .withoutAutoresizingMask
        
        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
        
        open lazy var subtitleLabel = UILabel()
            .withoutAutoresizingMask
        
        open lazy var textVStack = UIStackView(column: [titleLabel, subtitleLabel], spacing: 4)
            .withoutAutoresizingMask
        
        open lazy var contentHStack = UIStackView(row: [avatarView, textVStack],
                                                  spacing: 12,
                                                  alignment: .center)
            .withoutAutoresizingMask

        open lazy var separatorView = UIView()
            .withoutAutoresizingMask

        override open func setup() {
            super.setup()

            selectedBackgroundView = UIView()
            avatarView.clipsToBounds = true
            titleLabel.numberOfLines = 1
            subtitleLabel.numberOfLines = 1

            typealias AID = SceytChatUIKit.AccessibilityIdentifiers.ChannelInfo.GroupCell
            accessibilityIdentifier = AID.root
            avatarView.accessibilityIdentifier = AID.avatar
            titleLabel.accessibilityIdentifier = AID.title
            subtitleLabel.accessibilityIdentifier = AID.subtitle
        }
        
        override open func setupAppearance() {
            super.setupAppearance()

            backgroundColor = appearance.backgroundColor
            selectedBackgroundView?.backgroundColor = appearance.selectedBackgroundColor

            titleLabel.font = appearance.titleLabelAppearance.font
            titleLabel.textColor = appearance.titleLabelAppearance.foregroundColor

            subtitleLabel.font = appearance.descriptionLabelAppearance.font
            subtitleLabel.textColor = appearance.descriptionLabelAppearance.foregroundColor

            avatarView.layer.cornerRadius = Layouts.avatarSize / 2

            separatorView.backgroundColor = appearance.separatorColor
        }
        
        override open func setupLayout() {
            super.setupLayout()

            contentView.addSubview(contentHStack)
            contentView.addSubview(separatorView)

            contentHStack.pin(to: contentView, anchors: [
                .leading(Layouts.horizontalPadding),
                .trailing(-Layouts.horizontalPadding),
                .top(Layouts.verticalPadding),
                .bottom(-Layouts.verticalPadding)
            ])
            
            avatarView.resize(anchors: [
                .width(Layouts.avatarSize),
                .height(Layouts.avatarSize)
            ])

            separatorView.pin(to: contentView, anchors: [
                .leading(Layouts.separatorLeadingPadding + Layouts.horizontalPadding),
                .trailing(0),
                .bottom(0)
            ])

            separatorView.resize(anchors: [
                .height(Layouts.separatorHeight)
            ])
        }
        
        open var data: ChannelLayoutModel? {
            didSet {
                guard let data = data else { return }
                bind(data)
            }
        }
        
        open func bind(_ data: ChannelLayoutModel) {
            titleLabel.text = data.formattedSubject
            
            // Set subtitle based on member count
            let memberCount = data.channel.memberCount
            if memberCount > 0 {
                let membersText = memberCount == 1 ? L10n.Channel.MembersCount.one : L10n.Channel.MembersCount.more(Int(memberCount))
                subtitleLabel.text = membersText
            } else {
                subtitleLabel.text = nil
            }
            
            // Load avatar
            data.$avatar
                .sink { [weak self] image in
                    guard let self else { return }
                    self.avatarView.image = image
                    self.avatarView.shape = self.appearance.avatarAppearance.shape
                    self.avatarView.contentMode = .scaleAspectFill
                }.store(in: &subscriptions)
        }
        
        open override func prepareForReuse() {
            super.prepareForReuse()
            titleLabel.text = nil
            subtitleLabel.text = nil
            avatarView.image = nil
        }
    }
}

public extension ChannelInfoViewController.GroupCell {
    enum Layouts {
        public static var avatarSize: CGFloat = 40
        public static var horizontalPadding: CGFloat = 16
        public static var verticalPadding: CGFloat = 12
        public static var separatorHeight: CGFloat = 1
        public static var separatorLeadingPadding: CGFloat = 56
    }
}
