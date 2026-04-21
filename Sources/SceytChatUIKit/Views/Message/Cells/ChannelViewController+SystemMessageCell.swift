//
//  ChannelViewController+SystemMessageCell.swift
//  SceytChatUIKit
//
//  Created by Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelViewController {

    open class SystemMessageCell: CollectionViewCell, MessageCellMeasurable {

        public static var titleContentInsets: UIEdgeInsets = .init(top: 2, left: 8, bottom: 2, right: 8)

        open var highlightMode: MessageCell.HighlightMode = .none {
            didSet {
                switch highlightMode {
                case .reply, .mention, .search:
                    titleContentView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
                case .none:
                    titleContentView.backgroundColor = .clear
                }
            }
        }

        open lazy var unreadView: MessageCell.UnreadMessagesSeparatorView = {
            return $0.withoutAutoresizingMask
        }(MessageCell.UnreadMessagesSeparatorView())

        open lazy var blurView: CustomBlurEffectView = {
            let blur = CustomBlurEffectView(radius: 11, color: UIColor(hex: "0x000000").withAlphaComponent(0.5), colorAlpha: 0.5)
            blur.layer.cornerRadius = 11
            blur.clipsToBounds = true
            return blur.withoutAutoresizingMask
        }()

        open lazy var titleContentView: UIView = {
            $0.layer.cornerRadius = 11
            $0.clipsToBounds = true
            return $0.withoutAutoresizingMask
        }(UIView())

        open lazy var titleLabel: UILabel = {
            $0.font = MessageCell.appearance.systemMessageFont
            $0.textColor = MessageCell.appearance.systemMessageTextColor
            $0.textAlignment = .center
            $0.numberOfLines = 0
            $0.clipsToBounds = true
            return $0.withoutAutoresizingMask
        }(UILabel())

        private var layoutConstraint: [NSLayoutConstraint]?

        private var contentInsets: UIEdgeInsets = .init(top: 0, left: 48, bottom: 0, right: 48) {
            didSet {
                guard let layoutConstraint
                else { return }
                UIView.performWithoutAnimation {
                    layoutConstraint[0].constant = contentInsets.left
                    layoutConstraint[1].constant = -contentInsets.right
                    layoutConstraint[2].constant = contentInsets.top
                    layoutConstraint[4].constant = -contentInsets.bottom
                }
            }
        }

        open override func setup() {
            super.setup()
            unreadView.isHidden = true
        }

        open override func setupLayout() {
            super.setupLayout()
            contentView.addSubview(titleContentView)
            contentView.addSubview(unreadView)
            titleContentView.addSubview(blurView)
            titleContentView.addSubview(titleLabel)
            unreadView.pin(to: contentView, anchors: [.leading, .trailing, .bottom])
            blurView.pin(to: titleContentView, anchors: [.top, .bottom, .leading, .trailing])
            let insets = Self.titleContentInsets
            titleLabel.pin(to: titleContentView, anchors: [.top(insets.top), .bottom(-insets.bottom), .leading(insets.left), .trailing(-insets.right)])
            layoutConstraint = titleContentView.pin(to: contentView, anchors: [
                .leading(contentInsets.left, .greaterThanOrEqual),
                .trailing(-contentInsets.right, .lessThanOrEqual),
                .top(contentInsets.top),
                .centerX()
            ])
            layoutConstraint! += [
                titleLabel.bottomAnchor.pin(to: unreadView.topAnchor, constant: -contentInsets.bottom)
            ]
            titleLabel.heightAnchor.pin(greaterThanOrEqualToConstant: 22)
        }

        open override func setupAppearance() {
            super.setupAppearance()
            titleContentView.backgroundColor = .clear
        }

        open var data: MessageLayoutModel! {
            didSet {
                guard let data else { return }
                // Format system message using the system message body formatter
                let formattedText = SceytChatUIKit.shared.formatters.systemMessageBodyFormatter.format(data.message)
                titleLabel.attributedText = NSAttributedString(
                    string: formattedText,
                    attributes: [
                        .font: MessageCell.appearance.systemMessageFont,
                        .foregroundColor: MessageCell.appearance.systemMessageTextColor
                    ]
                )
                var cn = contentInsets
                cn.top = data.contentInsets.top
                cn.bottom = data.contentInsets.bottom
                if cn != contentInsets {
                    contentInsets = cn
                }
            }
        }

        open class func measure(
            model: MessageLayoutModel,
            appearance: MessageCell.Appearance
        ) -> CGSize {
            let text = SceytChatUIKit.shared.formatters.systemMessageBodyFormatter.format(model.message)
            let attributedText = NSAttributedString(
                string: text,
                attributes: [
                    .font: appearance.systemMessageFont,
                    .foregroundColor: appearance.systemMessageTextColor
                ]
            )
            let insets = titleContentInsets
            var size: CGSize = TextSizeMeasure
                .calculateSize(
                    of: attributedText,
                    config: .init(
                        restrictingWidth: UIScreen.main.bounds.width - 48 - 48 - insets.left - insets.right,
                        font: appearance.systemMessageFont,
                        lastFragmentUsedRect: false
                    )).textSize
            if size.height < 22 {
                size.height = 22
            } else {
                size.height += insets.bottom + insets.top
            }

            if model.isLastDisplayedMessage {
                size.height += MessageCell.UnreadMessagesSeparatorView.measure(model: model, appearance: appearance).height
            }

            return size
        }
    }
}
