//
//  MessageCell+UnreadMessagesSeparatorView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageCell {

    open class UnreadMessagesSeparatorView: View, MessageCellMeasurable {
        enum Layouts {
            static public var textHeight: CGFloat = 24
            static public var verticalPadding: CGFloat = 8
        }

        lazy var backgroundView = UIView()
            .withoutAutoresizingMask

        lazy var titleLabel = UILabel()
            .withoutAutoresizingMask

        private lazy var heightConstraint: NSLayoutConstraint = {
            titleLabel.heightAnchor.constraint(equalToConstant: Layouts.textHeight)
        }()

        open private(set) var contentConstraints: [NSLayoutConstraint]?
        
        public lazy var appearance = MessageCell.appearance {
            didSet {
                setupAppearance()
            }
        }

        open override func setup() {
            super.setup()
            
            titleLabel.text = L10n.Message.List.unread
            titleLabel.textAlignment = .center
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = .clear
            backgroundView.backgroundColor = appearance.unreadMessagesSeparatorAppearance.backgroundColor
            titleLabel.font = appearance.unreadMessagesSeparatorAppearance.labelAppearance.font
            titleLabel.textColor = appearance.unreadMessagesSeparatorAppearance.labelAppearance.foregroundColor
        }

        open override func setupLayout() {
            super.setupLayout()
            
            addSubview(backgroundView)
            backgroundView.addSubview(titleLabel)
            updateContentConstraints()
        }

        open override var isHidden: Bool {
            didSet {
                if superview != nil {
                    updateContentConstraints()
                }
            }
        }
        
        open var contentInsets: UIEdgeInsets = .zero {
            didSet {
                if superview != nil {
                    updateContentConstraints()
                }
            }
        }

        private func updateContentConstraints() {
            NSLayoutConstraint.deactivate(contentConstraints ?? [])
            contentConstraints = []
            if isHidden {
                contentConstraints = [heightAnchor.pin(constant: 0)]
            } else {
                contentConstraints = backgroundView.pin(
                    to: self,
                    anchors: [
                        .top(Layouts.verticalPadding),
                        .leading,
                        .trailing,
                        .bottom(-Layouts.verticalPadding)]
                )
                contentConstraints! += titleLabel.pin(to: backgroundView)
                + [titleLabel.heightAnchor.pin(constant: Layouts.textHeight)]
            }
        }
        
        open class func measure(model: MessageLayoutModel, appearance: MessageCell.Appearance) -> CGSize {
            CGSize(width: 1, height: Layouts.textHeight + Layouts.verticalPadding * 2)
        }
    }
}
