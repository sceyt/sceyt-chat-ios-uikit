//
//  MessageInfoViewController+MarkerCell.swift
//  SceytChatUIKit
//
//  Created by Duc on 21/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInfoViewController {
    open class MarkerCell: TableViewCell {
        
        open lazy var avatarView = Components.circleImageView.init()
            .contentMode(.scaleAspectFill)
        
        open lazy var nameLabel = UILabel()
        
        open lazy var dateTimeLabel = UILabel()
            .contentCompressionResistancePriorityH(.required)
            .contentHuggingPriorityH(.required)

        open lazy var hStack = UIStackView(row: [avatarView, nameLabel, dateTimeLabel],
                                           spacing: 12, alignment: .center)
            .withoutAutoresizingMask
        
        open var imageTask: Cancellable?
        
        var data: ChatMessage.Marker! {
            didSet {
                guard let data,
                      let user = data.user else { return }
                let avatarRepresentation = appearance.avatarProvider.provideVisual(for: user)
                imageTask = switch avatarRepresentation {
                case .image(let image):
                    Components.avatarBuilder.loadAvatar(into: avatarView.imageView,
                                                        for: user,
                                                        defaultImage: image)
                case .initialsAppearance(let initialsAppearance):
                    Components.avatarBuilder.loadAvatar(into: avatarView.imageView,
                                                        for: user,
                                                        appearance: initialsAppearance)
                }
                
                nameLabel.text = appearance.titleFormatter.format(user)
                dateTimeLabel.text = appearance.subtitleFormatter.format(data.createdAt)
            }
        }
        
        open override func setup() {
            super.setup()
            
            selectionStyle = .none
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            contentView.addSubview(hStack)
            hStack.pin(to: contentView.safeAreaLayoutGuide, anchors: [.leading(16), .trailing(-16), .top(4), .bottom(-4)])
            avatarView.resize(anchors: [.width(40), .height(40)])
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.backgroundColor
            nameLabel.font = appearance.titleLabelAppearance.font
            nameLabel.textColor = appearance.titleLabelAppearance.foregroundColor
            dateTimeLabel.font = appearance.subtitleLabelAppearance?.font
            dateTimeLabel.textColor = appearance.subtitleLabelAppearance?.foregroundColor
        }
        
        override open func prepareForReuse() {
            super.prepareForReuse()
            
            imageTask?.cancel()
            textLabel?.text = nil
            dateTimeLabel.text = nil
        }
        
        open var contentInsets: UIEdgeInsets = .zero {
            didSet {
                setNeedsLayout()
                layoutIfNeeded()
            }
        }
        
        open override var safeAreaInsets: UIEdgeInsets {
            var safeAreaInsets = super.safeAreaInsets
            safeAreaInsets.left += contentInsets.left
            safeAreaInsets.right += contentInsets.right
            safeAreaInsets.top += contentInsets.top
            safeAreaInsets.bottom += contentInsets.bottom
            return safeAreaInsets
        }
    }
}
