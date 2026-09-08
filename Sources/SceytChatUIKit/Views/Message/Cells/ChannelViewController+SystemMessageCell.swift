//
//  ChannelViewController+SystemMessageCell.swift
//  SceytChatUIKit
//
//  Created by Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

extension ChannelViewController {

    open class SystemMessageCell: CollectionViewCell, MessageCellMeasurable {

        public static var titleContentInsets: UIEdgeInsets = .init(top: 2, left: 8, bottom: 2, right: 8)

        public enum Action {
            /// The row points at another message — a pin system message at the message that
            /// was pinned — and the user tapped it.
            case didTapTargetMessage(MessageId)
        }

        open var onAction: ((Action) -> Void)?

        /// The message this row jumps to, `nil` when it has none. Drives whether
        /// `tapGesture` is live, so only the rows that go somewhere react to a tap.
        public private(set) var targetMessageId: MessageId?

        open lazy var tapGesture: UITapGestureRecognizer = {
            $0.isEnabled = false
            return $0
        }(UITapGestureRecognizer(target: self, action: #selector(didTapTitleContent)))

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
            $0.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.SystemCell.title
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
            titleContentView.isUserInteractionEnabled = true
            titleContentView.addGestureRecognizer(tapGesture)
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
                accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.SystemCell
                    .identifier(for: data.message.id)
                targetMessageId = data.message.systemMessageTargetId
                tapGesture.isEnabled = targetMessageId != nil
                // Format system message using the system message body formatter
                titleLabel.attributedText = Self.attributedText(
                    for: data.message,
                    appearance: MessageCell.appearance
                )
                var cn = contentInsets
                cn.top = data.contentInsets.top
                cn.bottom = data.contentInsets.bottom
                if cn != contentInsets {
                    contentInsets = cn
                }
            }
        }

        @objc
        open func didTapTitleContent() {
            guard let targetMessageId else { return }
            onAction?(.didTapTargetMessage(targetMessageId))
        }

        open override func prepareForReuse() {
            super.prepareForReuse()
            // One cell class serves every system message type, so a reused row must not
            // keep the previous row's target or its handler.
            onAction = nil
            targetMessageId = nil
            tapGesture.isEnabled = false
        }

        /// The row's styled text: one run for most system messages, two for a row that
        /// emphasizes the actor's name — "Adam" in `systemMessageFont`, "pinned: …" in the
        /// lighter `systemMessageBodyFont`.
        ///
        /// Shared by `data` and `measure` so the height is calculated from the very string
        /// the label draws. The two fonts are what make that matter: a regular run is
        /// narrower than a semibold one and wraps in a different place.
        open class func attributedText(
            for message: ChatMessage,
            appearance: MessageCell.Appearance
        ) -> NSAttributedString {
            let formatter = SceytChatUIKit.shared.formatters.systemMessageBodyFormatter
            let text = NSMutableAttributedString(
                string: formatter.format(message),
                attributes: [
                    .font: appearance.systemMessageFont,
                    .foregroundColor: appearance.systemMessageTextColor
                ]
            )
            // The range is measured against the same `format(_:)` output, but a custom
            // formatter can return one that does not fit this string — a mismatched range
            // would trap in `addAttribute`.
            if let nameRange = formatter.emphasizedNameRange(in: message),
               nameRange.location >= 0,
               NSMaxRange(nameRange) <= text.length {
                let whole = NSRange(location: 0, length: text.length)
                text.addAttribute(.font, value: appearance.systemMessageBodyFont, range: whole)
                text.addAttribute(.font, value: appearance.systemMessageFont, range: nameRange)
            }
            return text
        }

        open class func measure(
            model: MessageLayoutModel,
            appearance: MessageCell.Appearance
        ) -> CGSize {
            let attributedText = attributedText(for: model.message, appearance: appearance)
            let insets = titleContentInsets
            // No `font` in the config: it would overwrite the string's own fonts, flattening
            // an emphasized-name row onto one of the two and measuring a width the label
            // never draws.
            var size: CGSize = TextSizeMeasure
                .calculateSize(
                    of: attributedText,
                    config: .init(
                        restrictingWidth: UIScreen.main.bounds.width - 48 - 48 - insets.left - insets.right,
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
