//
//  ChannelPinnedMessageListViewController+MessageCell.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelPinnedMessageListViewController {

    /// One pinned message in the standalone pinned-messages list, rendered by the very
    /// cell the conversation uses — same bubble, same attachments, reactions, reply
    /// preview and poll, on the same side of the screen, with the same gestures.
    ///
    /// The conversation's cell is a *collection* view cell, so it rides inside this row as
    /// a plain subview, laid out to the height its `MessageLayoutModel` measured — exactly
    /// what the message list gives it. `MessageInfoViewController.MessageCell` hosts the
    /// same cell the same way.
    ///
    /// Incoming and outgoing bubbles are different classes and a table cell cannot change
    /// its class on reuse, so the direction is a subclass: `IncomingMessageCell` and
    /// `OutgoingMessageCell`. The base defaults to incoming.
    open class MessageCell: TableViewCell {

        open lazy var appearance = Components.channelPinnedMessageListViewController.appearance {
            didSet {
                setupAppearance()
            }
        }

        /// The conversation's cell, showing this row's message.
        open lazy var messageView = makeMessageView()
            .withoutAutoresizingMask

        /// The one control that leaves this screen: it jumps the conversation to this
        /// message. Tapping the bubble itself does what it does in the conversation —
        /// opens an attachment, votes in a poll, follows a link — so the jump needs a
        /// button of its own.
        ///
        /// The disc behind the arrow is the button's own rounded background rather than
        /// part of the artwork, so the disc and the glyph stay separately themeable.
        open lazy var navigateButton = UIButton()
            .withoutAutoresizingMask

        open var onNavigate: (() -> Void)?

        /// A chat cell has no intrinsic height — it is laid out to the height its layout
        /// model measured, which is also the row height the screen reports.
        public private(set) var messageViewHeight: NSLayoutConstraint?

        /// The bubble this row hosts. Incoming and outgoing are separate classes, so a
        /// subclass answers with the one it renders; the base renders incoming.
        open func makeMessageView() -> ChatMessageCell {
            Components.channelIncomingMessageCell.init()
        }

        /// Pins the navigate button beside the bubble on the side the bubble leaves free —
        /// the trailing side of an incoming message. Anchored to the bubble rather than to
        /// the row, so the button follows the bubble's width instead of floating in a
        /// column of its own.
        open func pinNavigateButtonToBubble() {
            navigateButton.leadingAnchor.pin(
                to: messageView.bubbleView.trailingAnchor,
                constant: Layouts.navigateButtonSpacing
            )
        }

        open override func setup() {
            super.setup()

            // The row itself is never "selected": the bubble handles its own gestures and
            // the navigate button carries the jump.
            selectionStyle = .none
            navigateButton.addTarget(self, action: #selector(navigateAction(_:)), for: .touchUpInside)
        }

        open override func setupLayout() {
            super.setupLayout()

            contentView.addSubview(messageView)
            contentView.addSubview(navigateButton)

            messageView.pin(to: contentView, anchors: [.leading, .trailing, .top])
            // Deliberately no bottom pin: the row's height comes from the screen's
            // `heightForRowAt`, and a bottom pin would fight the height constraint through
            // the initial layout pass, before the table applies that height.
            messageViewHeight = messageView.heightAnchor.pin(constant: data?.measureSize.height ?? 0)

            navigateButton.resize(anchors: [
                .width(Layouts.navigateButtonSize),
                .height(Layouts.navigateButtonSize)
            ])
            navigateButton.layer.cornerRadius = Layouts.navigateButtonSize / 2
            navigateButton.clipsToBounds = true
            navigateButton.bottomAnchor.pin(to: messageView.bubbleView.bottomAnchor)
            pinNavigateButtonToBubble()
        }

        open override func setupAppearance() {
            super.setupAppearance()

            backgroundColor = appearance.backgroundColor
            contentView.backgroundColor = appearance.backgroundColor
            navigateButton.setImage(appearance.navigateIcon, for: .normal)
            navigateButton.tintColor = appearance.navigateIconTintColor
            navigateButton.backgroundColor = appearance.navigateIconBackgroundColor
            messageView.parentAppearance = appearance.messageCellAppearance
        }

        open var data: MessageLayoutModel? {
            didSet {
                guard let data else { return }

                // The appearance is already in the bubble — `setupAppearance` put it there,
                // and pushing it again would make the bubble rebuild itself twice per row.
                messageView.data = data
                messageViewHeight?.constant = data.measureSize.height
            }
        }

        @objc
        open func navigateAction(_ sender: Any) {
            onNavigate?()
        }

        public enum Layouts {
            public static var navigateButtonSize: CGFloat = 36
            public static var navigateButtonSpacing: CGFloat = 8
        }
    }

    /// A pinned message received from someone else.
    open class IncomingMessageCell: MessageCell {}

    /// A pinned message the current user sent.
    open class OutgoingMessageCell: MessageCell {

        open override func makeMessageView() -> ChatMessageCell {
            Components.channelOutgoingMessageCell.init()
        }

        open override func pinNavigateButtonToBubble() {
            navigateButton.trailingAnchor.pin(
                to: messageView.bubbleView.leadingAnchor,
                constant: -Layouts.navigateButtonSpacing
            )
        }
    }
}
