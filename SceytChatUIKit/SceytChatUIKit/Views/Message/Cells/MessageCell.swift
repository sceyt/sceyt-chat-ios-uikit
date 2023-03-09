//
//  MessageCell.swift
//  SceytChatUIKit
//  Copyright © 2020 Varmtech LLC. All rights reserved.
//

import UIKit
import SceytChat

open class MessageCell: CollectionViewCell,
                        UITextViewDelegate,
                        ContextMenuSnapshotProviding {
    
    open private(set) var attachmentsContainerSize = CGSize.zero
    open private(set) var linksContainerSize = CGSize.zero
    open var onAction: ((Action) -> Void)?
    
    open lazy var unreadView = UnreadView
        .init()
        .withoutAutoresizingMask
    
    open lazy var bubbleView = UIView()
        .withoutAutoresizingMask
    
    open lazy var textView = TextView
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
    
    open lazy var attachmentView = AttachmentStackView
        .init()
        .withoutAutoresizingMask
    
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
    
    open var isHighlightedBubbleView = false
    
    public private(set) var contentConstraints: [NSLayoutConstraint]?
    
    open override func setup() {
        super.setup()
        textView.isEditable = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = .link
        textView.spellCheckingType = .no
        textView.scrollsToTop = false
        textView.bounces = false
        textView.bouncesZoom = false
        textView.showsHorizontalScrollIndicator = false
        textView.showsVerticalScrollIndicator = false
        textView.isExclusiveTouch = true
        
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
            case .pauseTransfer(let index):
                onAction?(.pauseTransfer(index))
            case .resumeTransfer(let index):
                onAction?(.resumeTransfer(index))
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
        
        reactionTotalView.onAction = { [unowned self] in
            onAction?(.tapReaction)
        }
        
        linkView.onDidTapContentView = { [unowned self] view in
            onAction?(.openUrl(view.link))
        }
        
        replyView.addTarget(
            self,
            action: #selector(replyViewAction(_:)),
            for: .touchUpInside
        )
    }
    
    open override func setupLayout() {
        super.setupLayout()
        
        contentView.addSubview(replyArrowView)
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(forwardView)
        bubbleView.addSubview(replyView)
        bubbleView.addSubview(textView)
        bubbleView.addSubview(attachmentView)
        bubbleView.addSubview(linkView)
        bubbleView.addSubview(dateTickBackgroundView)
        bubbleView.addSubview(infoView)
        bubbleView.addSubview(nameLabel)
        bubbleView.addSubview(replyView)
        contentView.addSubview(avatarView)
        contentView.addSubview(reactionView)
        contentView.addSubview(reactionTotalView)
        contentView.addSubview(replyCountView)
        contentView.addSubview(unreadView)
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        replyView.appearance = appearance
        replyArrowView.appearance = appearance
        replyCountView.appearance = appearance
        reactionView.appearance = appearance
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
       
//        textView.font = appearance.messageFont
        textView.backgroundColor = .clear
        textView.linkTextAttributes = [.foregroundColor: appearance.linkColor as Any]
        
        bubbleView.layer.cornerRadius = 16
        bubbleView.isUserInteractionEnabled = true
        
        dateTickBackgroundView.clipsToBounds = true
        dateTickBackgroundView.backgroundColor = appearance.dateTickBackgroundViewColor
        dateTickBackgroundView.alpha = 0.4
        dateTickBackgroundView.layer.cornerRadius = 12
        dateTickBackgroundView.isHidden = true
        
        nameLabel.font = appearance.titleFont
        
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 18
    }
    
    public var showSenderInfo: Bool = true
    
    open var previewer: AttachmentPreviewDataSource? {
        get { attachmentView.previewer }
        set { attachmentView.previewer = newValue }
    }
    
    open var data: MessageLayoutModel! {
        didSet {
            guard let data = data else { return }
            UIView.performWithoutAnimation {
                let message = data.message
                textView.attributedText = data.attributedView
                infoView.dateLabel.text = Formatters.messageTimestamp.format(message.createdAt)
                nameLabel.text = Formatters.userDisplayName.format(message.user)
                nameLabel.textColor = appearance.titleColor ?? .initial(title: message.user.id)
                calculateAttachmentsContainerSize()
                calculateLinksContainerSize()
                attachmentView.data = data
//                linkView.data = data
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
                replyView.data = message.repliedInThread ? nil : message.parent
                replyCountView.count = data.replyCount
                deliveryStatus = message.deliveryStatus
                if showSenderInfo {
                    nameLabel.isHidden = false
                    avatarView.isHidden = false
                    imageTask = Components.avatarBuilder.loadAvatar(into: avatarView, for: message.user)
                } else {
                    nameLabel.isHidden = true
                    avatarView.isHidden = true
                }
                if message.state == .edited {
                    infoView.stateLabel.isHidden = false
                    infoView.stateLabel.text = L10n.Message.Info.edited
                    infoView.stateLabel.textColor = hasBackground ? appearance.infoViewStateWithBackgroundTextColor : appearance.infoViewStateTextColor
                } else {
                    infoView.stateLabel.isHidden = true
                    infoView.stateLabel.text = nil
                }
                forwardView.isHidden = !data.isForwarded
                NSLayoutConstraint.deactivate(contentConstraints ?? [])
                contentConstraints = unreadView.pin(to: contentView, anchors: [.leading(), .trailing()])
                contentConstraints! += [unreadView.topAnchor.pin(to: contentView.topAnchor)]
                contentConstraints! += layoutConstraints(layout: data)
            }
        }
    }
    
    open override func prepareForReuse() {
        super.prepareForReuse()
        isHighlightedBubbleView = false
        NSLayoutConstraint.deactivate(contentView.constraints)
        NSLayoutConstraint.deactivate(contentConstraints ?? [])
        imageTask?.cancel()
        constraintsAffectingLayout(for: .horizontal)
    }
    
    open func layoutConstraints(layout: MessageLayoutModel) -> [NSLayoutConstraint] {
        return []
    }
    
    open var imageTask: Cancellable?
    
    open func calculateAttachmentsContainerSize() {
        guard let data = data,
              !data.attachmentCount.isEmpty
        else { return }
        attachmentsContainerSize = CGSize(
            width: Components.messageLayoutModel.defaults.imageAttachmentSize.width,
            height: 0
        )
        if data.attachmentCount.numberOfImages > 0 {
            attachmentsContainerSize.height = CGFloat(
                Int(Components.messageLayoutModel.defaults.imageAttachmentSize.height)
                * data.attachmentCount.numberOfImages
                + 4
                * (data.attachmentCount.numberOfImages - 1)
            )
        }
        if data.attachmentCount.numberOfFiles > 0 {
            attachmentsContainerSize.height += CGFloat(
                Int(Components.messageLayoutModel.defaults.fileAttachmentSize.height)
                * data.attachmentCount.numberOfFiles
                + 4
                * (data.attachmentCount.numberOfFiles - 1))
        }
        if data.attachmentCount.numberOfVoices > 0 {
            attachmentsContainerSize.height += CGFloat(
                Int(Components.messageLayoutModel.defaults.audioAttachmentSize.height)
                * data.attachmentCount.numberOfVoices
                + 4
                * (data.attachmentCount.numberOfVoices - 1))
        }
    }
    
    open func calculateLinksContainerSize() {
        guard let data = data,
              let linkPreviews = data.linkPreviews,
              !linkPreviews.isEmpty
        else { return }
        linksContainerSize = CGSize(
            width: Components.messageLayoutModel.defaults.imageAttachmentSize.width,
            height: CGFloat(linkPreviews.count - 1) * 4
        )
        
        linksContainerSize.height += linkPreviews.reduce(CGFloat(0)) {
            $0
            + $1.descriptionSize.height
            + $1.titleSize.height
            + min(
                Components.messageLayoutModel.defaults.imageAttachmentSize.height,
                $1.image?.size.height ?? 0)
        }
    }
    
    open var hasBackground: Bool {
        !data.attachmentCount.isEmpty
        && data.attachmentCount.numberOfFiles == 0
        && data.attachmentCount.numberOfVoices == 0
    }
    
    open var deliveryStatus: ChatMessage.DeliveryStatus = .pending {
        didSet {
            guard let data = data,
                  !data.message.incoming,
                  data.message.state != .deleted
            else {
                infoView.tickView.image = nil
                return
            }
            let renderingMode: UIImage.RenderingMode =
            (hasBackground && deliveryStatus != .failed)
            ? .alwaysTemplate
            : .alwaysOriginal
            infoView.tickView.image = deliveryStatusImage(deliveryStatus)
                .withRenderingMode(renderingMode)
        }
    }

    private var _backingLabel: UILabel?
    
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
    
    open override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let preferredAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        guard preferredAttributes.frame != layoutAttributes.frame
        else { return preferredAttributes }
        let targetSize = CGSize(
            width: layoutAttributes.frame.width,
            height: UIView.layoutFittingCompressedSize.height
        )
        preferredAttributes.frame.size = self.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel)
        return preferredAttributes
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
    
    //MARK: ContextMenuSnapshotProviding
    open func onPrepareSnapshot() {
        textView.isHidden = true
        let label = UILabel().withoutAutoresizingMask
        label.numberOfLines = 0
        label.attributedText = textView.attributedText
        label.preferredMaxLayoutWidth = textView.frame.width
        bubbleView.addSubview(label)
        label.pin(to: textView, anchors: [.leading, .trailing, .bottom, .top])
        layoutIfNeeded()
        self._backingLabel = label
    }

    open func onFinishSnapshot() {
        textView.isHidden = false
        _backingLabel?.removeFromSuperview()
    }
}

extension MessageCell {
    
    open class TextView: UITextView {
        
        open override var isFocused: Bool {
            false
        }

        open override var canBecomeFirstResponder: Bool {
            false
        }

        open override var canBecomeFocused: Bool {
            false
        }

        open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
            false
        }
        
        open override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            guard let pos = closestPosition(to: point) else
            { return false }
            guard let range = tokenizer.rangeEnclosingPosition(
                pos,
                with: .character,
                inDirection: .layout(.left)
            ) else { return false }
            let index = offset(
                from: beginningOfDocument,
                to: range.start
            )
            if attributedText.attribute(.customKey, at: index, effectiveRange: nil) != nil {
                return false
            }
            return attributedText.attribute(.link, at: index, effectiveRange: nil) != nil
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
        case pauseTransfer(Int)
        case resumeTransfer(Int)
        case openUrl(URL)
        case playAtUrl(URL)
    }
}

extension MessageCell {
    
    open class ImageView: CircleImageView {
        open override func layoutSubviews() {
            super.layoutSubviews()
            layer.cornerRadius = 16
        }
    }
}
