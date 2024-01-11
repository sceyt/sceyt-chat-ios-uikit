//
//  MessageCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

open class MessageCell: CollectionViewCell,
                        UITextViewDelegate,
                        MessageCellMeasurable,
                        ContextMenuSnapshotProviding {
    
    open var onAction: ((Action) -> Void)?
    
    open lazy var checkBoxView = {
        $0.isUserInteractionEnabled = false
        return $0
    }(CheckBoxView())
        .withoutAutoresizingMask
    
    open lazy var containerView = UIView()
        .withoutAutoresizingMask
    
    open lazy var unreadView = UnreadView
        .init()
        .withoutAutoresizingMask
    
    open lazy var bubbleView = UIView()
        .withoutAutoresizingMask
    
    open lazy var textLabel = Components.textLabel
        .init()
        .withoutAutoresizingMask
    
    open lazy var infoView = InfoView
        .init()
        .withoutAutoresizingMask

    open lazy var dateTickBackgroundView = InfoViewBackgroundView()
        .withoutAutoresizingMask
    
    open lazy var nameLabel = UILabel()
        .withoutAutoresizingMask
    
    open lazy var avatarView = UIImageView()
        .withoutAutoresizingMask
        .contentMode(.scaleAspectFill)
    
    open lazy var attachmentView = AttachmentStackView
        .init()
        .withoutAutoresizingMask
    
    open lazy var attachmentOverlayView = {
        $0.alpha = 0
        $0.layer.cornerRadius = 16
        $0.isUserInteractionEnabled = false
        return $0
    }(UIView().withoutAutoresizingMask)
    
    open lazy var linkView = LinkStackView
        .init()
        .withoutAutoresizingMask
    
    open lazy var reactionView = ReactionsView
        .init()
        .withoutAutoresizingMask
    
    open lazy var reactionTotalView = ReactionTotalView
        .init()
        .withoutAutoresizingMask
    
    open lazy var replyView = ReplyView
        .init()
        .withoutAutoresizingMask
    
    open lazy var forwardView = ForwardView
        .init()
        .withoutAutoresizingMask
    
    open lazy var replyCountView = ReplyCountView
        .init()
        .withoutAutoresizingMask
    
    open lazy var replyArrowView = ReplyArrowView
        .init()
        .withoutAutoresizingMask
    
    open lazy var replyIcon = UIImageView(image: .channelReply)
        .withoutAutoresizingMask
    
    open var isHighlightedBubbleView = false
        
    public private(set) var contentConstraints: [NSLayoutConstraint]?
    
    private var longPressItem: LongPressItem?
    
    open override func setup() {
        super.setup()
        
        unreadView.isHidden = true
        replyCountView.addTarget(
            self,
            action: #selector(replyCountAction(_:)),
            for: .touchUpInside
        )
        
        attachmentView.onAction = { [unowned self] action in
            switch action {
            case .userSelect(let index):
                onAction?(.selectAttachment(index))
            case .pauseTransfer(let message, let attachment):
                onAction?(.pauseTransfer(message, attachment))
            case .resumeTransfer(let message, let attachment):
                onAction?(.resumeTransfer(message, attachment))
            case .play(let url):
                onAction?(.playAtUrl(url))
            }
        }
        
        reactionView.onAction = { [unowned self] action in
            switch action {
            case .new:
                onAction?(.addReaction)
            case .delete(let key):
                onAction?(.deleteReaction(key))
            case .score(let key, let score, let byMe):
                onAction?(.updateReactionScore(key, score, !byMe))
            }
        }
        
        reactionTotalView.addTarget(
            self,
            action: #selector(reactionTotalViewAction(_:)),
            for: .touchUpInside)
        
        linkView.onDidTapContentView = { [unowned self] view in
            onAction?(.openUrl(view.link))
        }
        
        replyView.addTarget(
            self,
            action: #selector(replyViewAction(_:)),
            for: .touchUpInside
        )
        
        attachmentView.previewer = { [weak self] in
            self?.previewer?()
        }
                
        NotificationCenter.default.addObserver(self, selector: #selector(didUpdateDeliveryStatus(_:)), name: .didUpdateDeliveryStatus, object: nil)
        
        replyIcon.isHidden = true
    }
    
    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(containerView)
        containerView.addSubview(replyArrowView)
        containerView.addSubview(bubbleView)
        bubbleView.addSubview(forwardView)
        bubbleView.addSubview(replyView)
        bubbleView.addSubview(textLabel)
        bubbleView.addSubview(attachmentView)
        bubbleView.addSubview(linkView)
        bubbleView.addSubview(dateTickBackgroundView)
        bubbleView.addSubview(infoView)
        bubbleView.addSubview(nameLabel)
        containerView.addSubview(avatarView)
        containerView.addSubview(reactionView)
        containerView.addSubview(reactionTotalView)
        containerView.addSubview(replyCountView)
        contentView.addSubview(unreadView)
        contentView.addSubview(replyIcon)
        contentView.addSubview(checkBoxView)
        if data != nil {
            bind()
            makeConstraints()
        }
        
        bubbleView.addSubview(attachmentOverlayView)
        attachmentOverlayView.pin(to: attachmentView)
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        replyView.appearance = appearance
        replyArrowView.appearance = appearance
        replyCountView.appearance = appearance
        reactionView.appearance = appearance
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        containerView.backgroundColor = .clear
        
        textLabel.backgroundColor = .clear
        
        bubbleView.layer.cornerRadius = 16
        bubbleView.isUserInteractionEnabled = true
        
        dateTickBackgroundView.clipsToBounds = true
        dateTickBackgroundView.backgroundColor = appearance.dateTickBackgroundViewColor
        dateTickBackgroundView.layer.cornerRadius = 12
        dateTickBackgroundView.isHidden = true
        
        nameLabel.font = appearance.titleFont
        
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 18
        
        checkBoxView.contentInsets = .init(top: Layouts.checkBoxPadding,
                                           left: Layouts.checkBoxPadding,
                                           bottom: Layouts.checkBoxPadding,
                                           right: Layouts.checkBoxPadding)
    }
    
    public var showSenderInfo: Bool = true
    
    open var previewer: (() -> AttachmentPreviewDataSource?)?
    
    open var isEditing: Bool = false {
        didSet {
            contentView.isUserInteractionEnabled = !isEditing
        }
    }

    open var data: MessageLayoutModel! {
        didSet {
            if superview != nil {
                bind()
                makeConstraints()
            }
        }
    }
    
    open func bind() {
        guard let data = data else { return }
        let message = data.message
        showSenderInfo = data.showUserInfo
        unreadView.isHidden = !data.isLastDisplayedMessage
        textLabel.attributedText = data.attributedView.content
        infoView.data = data
        nameLabel.text = Formatters.userDisplayName.format(message.user)
        nameLabel.textColor = appearance.titleColor ?? .initial(title: message.user.id)
        attachmentView.data = data
        linkView.data = data
        switch data.reactionType {
        case .interactive:
            reactionView.data = data
            reactionView.isHidden = (data.reactions?.isEmpty ?? true)
            reactionTotalView.isHidden = true
        case .withTotalScore:
            reactionTotalView.data = data
            reactionView.isHidden = true
            reactionTotalView.isHidden = (data.reactions?.isEmpty ?? true)
        }
        replyView.data = message.repliedInThread ? nil : data.replyLayout
        replyCountView.count = data.replyCount
        deliveryStatus = message.deliveryStatus
        if showSenderInfo {
            nameLabel.isHidden = false
            avatarView.isHidden = false
            let scale = Config.displayScale
            imageTask = Components.avatarBuilder
                .loadAvatar(
                    into: avatarView,
                    for: message.user,
                    size: CGSize(width: 36 * scale,
                                 height: 36 * scale))
        } else {
            nameLabel.isHidden = true
            avatarView.isHidden = true
        }
        forwardView.isHidden = !data.isForwarded
        data.updateOptions = []
    }
    
    private func makeConstraints() {
        UIView.performWithoutAnimation {
            NSLayoutConstraint.deactivate(contentConstraints ?? [])
            contentConstraints = containerView.pin(to: contentView,
                                                   anchors: [
                                                    .trailing(-data.contentInsets.right),
                                                    .top(data.contentInsets.top)
                                                   ])
            contentConstraints! += [containerView.bottomAnchor.pin(to: unreadView.topAnchor)]
            contentConstraints! += unreadView.pin(to: contentView, anchors: [.leading(data.contentInsets.left), .trailing(-data.contentInsets.right)])
            contentConstraints! += unreadView.pin(to: contentView, anchors: [.bottom(-data.contentInsets.bottom)])
            contentConstraints! += layoutConstraints(layout: data)
            contentConstraints! += [replyIcon.trailingAnchor.pin(to: contentView.trailingAnchor, constant: 44)]
            contentConstraints! += [replyIcon.bottomAnchor.pin(to: bubbleView.bottomAnchor)]
            contentConstraints! += replyIcon.resize(anchors: [.height(32), .width(32)])
            contentConstraints! += [checkBoxView.centerYAnchor.pin(to: contentView.centerYAnchor)]
            contentConstraints! += [checkBoxView.leadingAnchor.pin(to: contentView.leadingAnchor)]
            if isEditing {
                let checkBoxSize = Layouts.checkBoxSize + 2 * Layouts.checkBoxPadding
                contentConstraints! += [checkBoxView.trailingAnchor.pin(to: containerView.leadingAnchor)]
                contentConstraints! += checkBoxView.resize(anchors: [.height(checkBoxSize), .width(checkBoxSize)])
            } else {
                contentConstraints! += [containerView.leadingAnchor.pin(to: contentView.leadingAnchor, constant: data.contentInsets.left)]
                contentConstraints! += checkBoxView.resize(anchors: [.height(0), .width(0)])
            }
        }
    }
    
    open override func prepareForReuse() {
        super.prepareForReuse()
        isHighlightedBubbleView = false
        longPressItem = nil
        deliveryStatus = .pending
        NSLayoutConstraint.deactivate(contentView.constraints + containerView.constraints + (contentConstraints ?? []))
        imageTask?.cancel()
        contextMenu?.disconnect(from: bubbleView, identifier: .init(value: data))
        constraintsAffectingLayout(for: .horizontal)
        replyIcon.isHidden = true
    }
    
    open func layoutConstraints(layout: MessageLayoutModel) -> [NSLayoutConstraint] {
        return []
    }
    
    open class func measure(
        model: MessageLayoutModel,
        appearance: MessageCell.Appearance
    ) -> CGSize {
        return .zero
    }
    
    open var imageTask: Cancellable?
    
    open var hasBackground: Bool {
        !data.attachments.isEmpty
        && !data.hasFileAttachments
        && !data.hasVoiceAttachments
    }
    
    open var deliveryStatus: ChatMessage.DeliveryStatus = ChatMessage.DeliveryStatus.pending {
        didSet {
            guard let data = data,
                  !data.message.incoming,
                  data.message.state != .deleted
            else {
                infoView.tickView.image = nil
                return
            }
            infoView.tickView.image = deliveryStatusImage(deliveryStatus)
                .withRenderingMode(.alwaysTemplate)
            infoView.tickView.tintColor = deliveryStatusColor(deliveryStatus)
        }
    }
    
    open var contextMenu: ContextMenu? {
        didSet {
            let alignment: ContextMenu.HorizontalAlignment = data.message.incoming ? .leading : .trailing
            contextMenu?.connect(
                to: bubbleView,
                identifier: .init(value: data),
                alignment: effectiveUserInterfaceLayoutDirection == .rightToLeft ? alignment.reversed : alignment
            )
        }
    }

    private var _backingTextLabel: UILabel?
    
    open func deliveryStatusImage(_ status: ChatMessage.DeliveryStatus) -> UIImage {
        switch status {
        case .sent:
            return .sentMessage
        case .pending:
            return .pendingMessage
        case .received:
            return .deliveredMessage
        case .displayed:
            return .readMessage
        case .failed:
            return .failedMessage
        }
    }
    
    open func deliveryStatusColor(_ status: ChatMessage.DeliveryStatus) -> UIColor? {
        if hasBackground, ![.failed, .displayed].contains(status) {
            return appearance.infoViewRevertColorOnBackgroundView
        }
        switch status {
        case .pending:
            return appearance.ticksViewDisabledTintColor
        case .sent:
            return appearance.ticksViewDisabledTintColor
        case .received:
            return appearance.ticksViewDisabledTintColor
        case .displayed:
            return appearance.ticksViewTintColor
        case .failed:
            return appearance.ticksViewErrorTintColor
        }
    }
    
    @objc
    func didUpdateDeliveryStatus(_ notification: Notification) {
        deliveryStatus = data.messageDeliveryStatus
    }
    
    open override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
    }
    
    // MARK: Actions
    @objc
    open func replyCountAction(_ sender: UIButton) {
        onAction?(.showThread)
    }
    
    @objc
    open func replyViewAction(_ sender: ReplyView) {
        onAction?(.showReply)
    }
    
    @objc
    open func reactionTotalViewAction(_ sender: ReactionTotalView) {
        onAction?(.tapReaction)
    }
    
    //MARK: ContextMenuSnapshotProviding
    open func onPrepareSnapshot() {
        textLabel.isHidden = true
        let backingTextLabel = UILabel().withoutAutoresizingMask
        backingTextLabel.numberOfLines = 0
        backingTextLabel.preferredMaxLayoutWidth = textLabel.frame.width
        backingTextLabel.attributedText = textLabel.attributedText
        bubbleView.addSubview(backingTextLabel)
        backingTextLabel.pin(to: textLabel, anchors: [.leading, .trailing, .bottom, .top])
        layoutIfNeeded()
        self._backingTextLabel = backingTextLabel
    }

    open func onFinishSnapshot() {
        textLabel.isHidden = false
        _backingTextLabel?.removeFromSuperview()
    }
    
    //MARK: handle Gesture recognizers
    @discardableResult
    open func handleTap(sender: UITapGestureRecognizer) -> Bool {
        if textLabel.contains(gestureRecognizer: sender),
           let index = textLabel.indexForGesture(sender: sender),
           let item = data.attributedView.items.first(where: { $0.range.contains(index) }) {
            switch item {
            case .link(_, let link):
                if let link {
                    onAction?(.didTapLink(link))
                    return true
                }
            case .mention(_, let id):
                onAction?(.didTapMentionUser(id))
                return true
            }
            if let url = URL(string: data.attributedView.content.attributedSubstring(from: item.range).string) {
                onAction?(.didTapLink(url))
                return true
            }
        } else if avatarView.contains(gestureRecognizer: sender),
                    !avatarView.isHidden {
            onAction?(.didTapAvatar)
            return true
        }
        return false
    }
    
    @discardableResult
    open func handleLongPress(sender: UILongPressGestureRecognizer) -> LongPressItem? {
        switch sender.state {
        case .began:
            if textLabel.contains(gestureRecognizer: sender),
               let index = textLabel.indexForGesture(sender: sender),
               let item = data.attributedView.items.first(where: { $0.range.contains(index)}) {
                if case .link = item {
                    longPressItem = .init(view: textLabel, item: item, cell: self)
                    selectLink(range: item.range)
                    if let url = item.url {
                        onAction?(.didLongPressLink(url))
                    } else if let url = URL(string: data.attributedView.content.attributedSubstring(from: item.range).string) {
                        onAction?(.didLongPressLink(url))
                    }
                } else {
                    contextMenu?.handleLogPress(sender: sender, on: bubbleView, identifier: .init(value: data))
                }
            } else if bubbleView.contains(gestureRecognizer: sender) {
                longPressItem = .init(view: bubbleView, cell: self)
                contextMenu?.handleLogPress(sender: sender, on: bubbleView, identifier: .init(value: data))
            }
        case .changed:
            if let longPressItem {
                if longPressItem.item == nil {
                    contextMenu?.handleLogPress(sender: sender, on: longPressItem.view, identifier: .init(value: data))
                } else if !longPressItem.view.contains(gestureRecognizer: sender) {
                    deSelectLink(range: longPressItem.item!.range)
                    self.longPressItem = nil
                }
            }
        case .ended, .failed, .cancelled, .possible:
            if let longPressItem {
                if longPressItem.item == nil {
                    contextMenu?.handleLogPress(sender: sender, on: longPressItem.view, identifier: .init(value: data))
                } else if let item = longPressItem.item {
                    deSelectLink(range: item.range)
                }
            }
            self.longPressItem = nil
        default:
            break
        }
        return longPressItem
    }
    
    private func selectLink(range: NSRange) {
        guard let text = textLabel.attributedText?.mutableCopy() as? NSMutableAttributedString,
                let color = appearance.highlightedLinkBackgroundColor
        else { return }
        text.addAttributes([.backgroundColor: color], range: range)
        textLabel.attributedText = text
    }
    
    private func deSelectLink(range: NSRange) {
        guard let text = textLabel.attributedText?.mutableCopy() as? NSMutableAttributedString
        else { return }
        text.removeAttribute(.backgroundColor, range: range)
        textLabel.attributedText = text
    }
    
    private var isSwipeActivated = false
    @objc
    open func handlePan(_ sender: UIPanGestureRecognizer?) {
        replyIcon.isHidden = false
        func reset() {
            UIView.animate(withDuration: 0.25) { [weak self] in
                guard let self else { return }
                self.containerView.transform = .identity
                self.replyIcon.transform = .identity
            } completion: { [weak self] _ in
                guard let self else { return }
                self.replyIcon.isHidden = true
            }
        }
        guard let sender else {
            return reset()
        }
        switch sender.state {
        case .began:
            isSwipeActivated = false
        case .changed:
            let translation = sender.translation(in: self)
            var newX = translation.x
            if newX <= 0 {
                let range: CGFloat = 60
                let padding: CGFloat = 12
                let scale = min(1, abs(newX + padding)/(range-padding))
                if newX < -range {
                    newX = -range + (newX + range) / 5
                    if !isSwipeActivated {
                        isSwipeActivated = true
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                } else {
                    isSwipeActivated = false
                }
                containerView.transform = .init(translationX: newX, y: 0)
                replyIcon.transform = .init(translationX: newX, y: 0).scaledBy(x: scale, y: scale)
            }
        default:
            if isSwipeActivated {
                onAction?(.didSwipe)
            }
            reset()
        }
    }
}

public extension MessageCell {
    
    enum Action {
        case editMessage
        case deleteMessage
        case showThread
        case showReply
        case tapReaction
        case addReaction
        case deleteReaction(String)
        case updateReactionScore(String, UInt, Bool)
        case selectMentionedUser(String)
        case selectAttachment(Int)
        case pauseTransfer(ChatMessage, ChatMessage.Attachment)
        case resumeTransfer(ChatMessage, ChatMessage.Attachment)
        case openUrl(URL)
        case playAtUrl(URL)
        case didTapLink(URL)
        case didLongPressLink(URL)
        case didTapAvatar
        case didTapMentionUser(String)
        case didSwipe
    }
    
    enum Measure {
        
    }
    
    class LongPressItem {
        public let view: UIView
        public let item: MessageLayoutModel.ContentItem?
        public private(set) weak var cell: MessageCell?
        
        public init(
            view: UIView,
            item: MessageLayoutModel.ContentItem? = nil,
            cell: MessageCell? = nil) {
            self.view = view
            self.item = item
            self.cell = cell
        }
    }

}

extension MessageCell {
    
    open class ImageView: UIImageView {
        open override func layoutSubviews() {
            super.layoutSubviews()
            layer.cornerRadius = 16
        }
    }
}

public extension MessageCell {
    enum Layouts {
        public static var checkBoxSize: CGFloat = 24
        public static var checkBoxPadding: CGFloat = 12
        public static var horizontalPadding: CGFloat = 12
        public static var attachmentIconSize: CGFloat = 40
    }
}
