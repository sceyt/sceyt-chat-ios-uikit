//
//  MessageCell+UnreadView.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import UIKit

extension MessageCell {

    open class UnreadView: View {

        lazy var backgroundView = UIView()
            .withoutAutoresizingMask

        lazy var titleLabel = UILabel()
            .withoutAutoresizingMask

        open var preferredHeight: CGFloat = 20

        private lazy var heightConstraint: NSLayoutConstraint = {
            titleLabel.heightAnchor.constraint(equalToConstant: preferredHeight)
        }()

        open private(set) var contentConstraints: [NSLayoutConstraint]?
        
        public lazy var appearance = MessageCell.appearance {
            didSet {
                setupAppearance()
            }
        }

        open override func setupAppearance() {
            super.setupAppearance()
            backgroundColor = .clear
            backgroundView.backgroundColor = appearance.newMessagesSeparatorViewBackgroundColor
            titleLabel.font = appearance.newMessagesSeparatorViewFont
            titleLabel.text = L10n.Message.List.unread
            titleLabel.textAlignment = .center
            titleLabel.textColor = appearance.newMessagesSeparatorViewTextColor
        }

        open override func setupLayout() {
            super.setupLayout()
            addSubview(backgroundView)
            backgroundView.addSubview(titleLabel)
            updateContentConstraints()
        }

        open override var isHidden: Bool {
            didSet {
                updateContentConstraints()
            }
        }
        
        open var contentInsets: UIEdgeInsets = .zero {
            didSet {
                updateContentConstraints()
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
                        .top(isHidden ? 0 : contentInsets.top),
                        .leading(isHidden ? 0 : contentInsets.left),
                        .trailing(isHidden ? 0 : -contentInsets.right),
                        .bottom(isHidden ? 0 : -contentInsets.bottom)]
                )
                contentConstraints! += titleLabel.pin(to: backgroundView)
                + [titleLabel.heightAnchor.pin(constant: preferredHeight)]
            }
        }
    }
}
