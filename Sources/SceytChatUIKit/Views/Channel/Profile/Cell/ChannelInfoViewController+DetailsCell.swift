//
//  ChannelInfoViewController+DetailsCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController {
    open class DetailsCell: TableViewCell {
        
        open lazy var avatarButton = ImageButton()
            .withoutAutoresizingMask
        
        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
        
        open lazy var subtitleLabel = UILabel()
            .withoutAutoresizingMask
        
        open lazy var row = UIStackView(row: [avatarButton, column], spacing: 12, alignment: .center)
            .withoutAutoresizingMask
        
        open lazy var column = UIStackView(column: [titleLabel, subtitleLabel])
            .withoutAutoresizingMask
        
        override open func setup() {
            super.setup()
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.backgroundColor
            titleLabel.textColor = appearance.titleLabelAppearance.foregroundColor
            titleLabel.font = appearance.titleLabelAppearance.font
            subtitleLabel.textColor = appearance.subtitleLabelAppearance.foregroundColor
            subtitleLabel.font = appearance.subtitleLabelAppearance.font
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            contentView.addSubview(row)
            row.pin(to: contentView, anchors: [.leading(16), .trailing(-16), .top(16), .bottom(-16)])
            avatarButton.resize(anchors: [.width(72), .height(72)])
            
            column.setCustomSpacing(2, after: titleLabel)
        }
        
        open override var safeAreaInsets: UIEdgeInsets {
            .init(top: 0, left: Components.channelInfoViewController.Layouts.cellHorizontalPadding, bottom: 0, right: Components.channelInfoViewController.Layouts.cellHorizontalPadding)
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
            imageTask = appearance.channelAvatarRenderer.render(
                data,
                with: appearance.avatarAppearance,
                into: avatarButton)
        }
        
        open func updateTitle() {
            titleLabel.text = appearance.channelNameFormatter.format(data)
        }
        
        open func updateSubtitle() {
            subtitleLabel.text = appearance.channelSubtitleFormatter.format(data)
        }
        
        override open func prepareForReuse() {
            super.prepareForReuse()
            imageTask?.cancel()
        }
        
    }
}
