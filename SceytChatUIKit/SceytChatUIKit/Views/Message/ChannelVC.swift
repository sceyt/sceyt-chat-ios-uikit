//
//  ChannelVC.swift
//  SceytChatUIKit
//  Copyright © 2020 Varmtech LLC. All rights reserved.
//

import Photos
import SceytChat
import UIKit

private let messageBottomSpace = CGFloat(5)

open class ChannelVC: ViewController,
                      UIGestureRecognizerDelegate,
                      UICollectionViewDelegate,
                      UICollectionViewDataSource,
                      UICollectionViewDataSourcePrefetching,
                      UINavigationControllerDelegate,
                      ChannelCollectionViewLayoutDelegate,
                      ContextMenuDataSource,
                      ContextMenuDelegate,
                      ContextMenuSnapshotDelegate {
    
    public let clientDelegateIdentifier = NSUUID().uuidString
        
    open var channelViewModel: ChannelVM!
    open lazy var router = Components.channelRouter
        .init(rootVC: self)
    
    open lazy var collectionView = Components.channelCollectionView
        .init()
        .withoutAutoresizingMask
    
    public var layout: ChannelCollectionViewLayout {
        collectionView.channelCollectionViewLayout
    }
    
    private lazy var coverView = BarCoverView()
        .withoutAutoresizingMask
    
    open lazy var composerVC = Components.composerVC
        .init()
    
    open var inputTextView: ComposerVC.InputTextView {
        composerVC.inputTextView
    }
    
    open var mediaView: ComposerVC.MediaView {
        composerVC.mediaView
    }
    
    open var titleView = Components.channelTitleView
        .init()
        .withoutAutoresizingMask
    
    open var unreadCountView = Components.channelUnreadCountView
        .init()
        .withoutAutoresizingMask
    
    open var blockView = Components.channelBlockView
        .init()
        .withoutAutoresizingMask
    
    open lazy var joinGlobalChannelButton = UIButton()
        .withoutAutoresizingMask
    
    open lazy var indicatorView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .large)
            .withoutAutoresizingMask
        view.hidesWhenStopped = true
        return view
    }()
    
    open lazy var tapAction: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(viewTapped(gesture:))
        )
        tap.delegate = self
        tap.cancelsTouchesInView = true
        return tap
    }()
    
    private lazy var keyboardBgView = UIView()
        .withoutAutoresizingMask
    
    public var avatarTask: Cancellable?
    
    public var messageComposerViewBottomConstraint: NSLayoutConstraint!
    public var messageComposerViewHeightConstraint: NSLayoutConstraint!
    
    override open var disablesAutomaticKeyboardDismissal: Bool {
        return true
    }
    
    open var highlightReplyMessageAfterDelay = TimeInterval(0.25)
    open var highlightedDurationForReplyMessage = TimeInterval(0.5)
    
    public private(set) var keyboardObserver: KeyboardObserver?
    private var needToMarkMessageAsDisplayed = false
    private var needToScrollBottom = true
    private var requestMassagesPage = -1
    private var isScrollingTop = false
    private var contentSizeObserver: NSKeyValueObservation?
    private var shouldScrollUnreadPosition: Bool {
        switch layout.scrollToPositionAfterInvalidationContext {
        case .indexPath:
            return true
        default:
            return false
        }
    }
    
    private var collectionViewScrolledAtIndexPath: IndexPath? {
        didSet {
            if collectionViewScrolledAtIndexPath == nil {
                highlightedMessageId = nil
            }
        }
    }
    
    private var collectionViewVisibleFrame: CGRect {
        var rect = collectionView.frame
        rect.origin.y = 0
        rect.size.height -= collectionView.contentInset.bottom - 10
        return rect
    }
    
    private var highlightedMessageId: MessageId?
    private var selectedAttributes: ChannelCollectionViewLayoutAttributes?
    private var checkOnlyFirstTimeReceivedMessagesFromArchive = true
    private var isViewDidAppear = false
    private var contextMenu: ContextMenu!
    //    private var interactivePopGestureRecognizerDelegate: UIGestureRecognizerDelegate?
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.delegate = self
        updateTitle()
        updateUnreadViewVisibility()
        
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        updateUnreadViewVisibility()
        isViewDidAppear = true
        keyboardObserver = KeyboardObserver()
            .willShow { [weak self] in
                self?.keyboardWillShow(notification: $0)
            }.willHide { [weak self] in
                self?.keyboardWillHide(notification: $0)
            }
            .didShow { [weak self] in
                self?.keyboardWillShow(notification: $0)
            }
        markMessageAsDisplayed(at: collectionView.indexPathsForVisibleItems)
    }
    
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateUnreadViewVisibility()
        
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        //        navigationController?.interactivePopGestureRecognizer?.delegate = interactivePopGestureRecognizerDelegate
        //        interactivePopGestureRecognizerDelegate = nil
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isViewDidAppear = false
        keyboardObserver = nil
        //        if navigationController?.delegate === self {
        //            navigationController?.delegate = nil
        //        }
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        guard isViewLoaded
        else { return }
        let posY = collectionView.contentOffset.y
        let isScrolling = collectionView.isDragging || collectionView.isDecelerating
        let indexPath = collectionView.lastVisibleAttributes?.indexPath
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.setNeedsLayout()
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.performBatchUpdates(nil)
        }, completion: { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    override open func setup() {
        super.setup()
        contextMenu = ContextMenu(parent: self)
        contextMenu.dataSource = self
        contextMenu.delegate = self
        contextMenu.snapshotDelegate = self
        navigationItem.leftItemsSupplementBackButton = true
        navigationItem.leftBarButtonItems = [UIBarButtonItem(customView: titleView)]
        composerVC.mentionUserListVC = { [unowned self] in
            let vc = Components.mentioningUserListVC.init()
            vc.viewModel = Components.mentioningUserListVM
                .init(channelId: channelViewModel.channel.id)
            return vc
        }
        
        collectionView.delegate = self
        collectionView.dataSource = self
        layout.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.isPrefetchingEnabled = true
        unreadCountView.isHidden = true
        unreadCountView.isEnabled = true
        blockView.isHidden = true
        updateTitle()
        unreadCountView.addTarget(self, action: #selector(unreadButtonAction(_:)), for: .touchUpInside)
        joinGlobalChannelButton.addTarget(self, action: #selector(joinButtonAction(_:)), for: .touchUpInside)
        titleView.profileImageView.isUserInteractionEnabled = false
        titleView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showChannelProfileAction)))
        avatarTask = Components.avatarBuilder.loadAvatar(into: titleView.profileImageView, for: channelViewModel.channel)
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        view.addSubview(collectionView)
        view.addSubview(coverView)
        addChild(composerVC)
        coverView.addSubview(composerVC.view)
        coverView.addSubview(unreadCountView)
        coverView.addSubview(blockView)
        view.addSubview(joinGlobalChannelButton)
        view.addSubview(indicatorView)
        view.addGestureRecognizer(tapAction)
        
        messageComposerViewBottomConstraint = composerVC.view.bottomAnchor.pin(to: coverView.safeAreaLayoutGuide.bottomAnchor)
        messageComposerViewHeightConstraint = composerVC.view.resize(anchors: [.height(52)]).first!
        updateCollectionViewInsets()
        //        collectionView.scrollToTop(animated: false)
        coverView.pin(to: view.safeAreaLayoutGuide)
        collectionView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .trailing, .top])
        collectionView.bottomAnchor.pin(to: coverView.safeAreaLayoutGuide.bottomAnchor)
        composerVC.view.pin(to: coverView.safeAreaLayoutGuide, anchors: [.leading, .trailing])
        unreadCountView.trailingAnchor.pin(to: composerVC.view.trailingAnchor, constant: -10)
        unreadCountView.bottomAnchor.pin(to: composerVC.view.topAnchor, constant: -10)
        unreadCountView.resize(anchors: [.width(44), .height(48)])
        joinGlobalChannelButton.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .trailing, .bottom])
        joinGlobalChannelButton.resize(anchors: [.height(52)])
        indicatorView.pin(to: view, anchors: [.centerX, .centerY])
        blockView.pin(to: composerVC.view)
        
        view.addSubview(keyboardBgView)
        keyboardBgView.pin(to: view, anchors: [.leading, .trailing, .bottom])
        keyboardBgView.topAnchor.pin(to: composerVC.view.bottomAnchor)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        view.backgroundColor = appearance.backgroundColor
        coverView.backgroundColor = appearance.coverViewBackgroundColor
        collectionView.backgroundColor = appearance.backgroundColor
        
        joinGlobalChannelButton.setTitle(L10n.Channel.join, for: .normal)
        joinGlobalChannelButton.titleLabel?.font = Fonts.bold.withSize(14)
        joinGlobalChannelButton.backgroundColor = Colors.kitBlue
        keyboardBgView.backgroundColor = view.backgroundColor
    }
    
    override open func setupDone() {
        super.setupDone()
        
        inputTextView.onTyping = { [weak self] isTyping in
            self?.channelViewModel.isTyping = isTyping
        }
        composerVC.onContentHeightUpdate = { [unowned self] height in
            if height != messageComposerViewHeightConstraint.constant {
                let bottom = collectionView.contentInset.bottom
                var contentOffsetY = collectionView.contentOffset.y
                let diff = messageComposerViewHeightConstraint.constant - height
                messageComposerViewHeightConstraint.constant = height
                updateCollectionViewInsets()
                let newBottom = collectionView.contentInset.bottom
                if newBottom != bottom {
                    if collectionView.contentSize.height >= collectionView.bounds.height {
                        contentOffsetY += newBottom - bottom
                    } else {
                        let diff2 = collectionView.contentSize.height - (collectionView.bounds.height - newBottom)
                        if diff2 > 0 {
                            contentOffsetY += diff2
                        } else {
                            contentOffsetY -= diff
                        }
                    }
                }
                contentOffsetY = min(contentOffsetY, collectionView.contentSize.height)
                let needsToScroll = collectionView.contentSize.height > collectionView.frame.height
                UIView.animate(withDuration: 0.2) {
                    self.coverView.layoutIfNeeded()
                    guard needsToScroll else { return }
                    self.collectionView.setContentOffset(
                        .init(
                            x: 0,
                            y: contentOffsetY
                        ),
                        animated: false
                    )
                }
            }
        }
        composerVC.$action
            .compactMap { $0 }
            .sink { [unowned self] in
                switch $0 {
                case .send(let shouldClearText):
                    sendMessage(
                        createMessage(shouldClearText: shouldClearText),
                        shouldClearText: shouldClearText
                    )
                case .cancel:
                    channelViewModel.removeSelectedMessage()
                case .deleteMedia:
                    if composerVC.mediaView.items.count == 0 {
                        UIView.animate(withDuration: 0.2, animations: {
                            self.view.layoutIfNeeded()
                        })
                    }
                }
            }.store(in: &subscriptions)
       
        channelViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        channelViewModel.startDatabaseObserver()
        channelViewModel.loadLastMessages()
        inputTextView.attributedText = channelViewModel.draftMessage
    }
    
    private func updateCollectionViewInsets() {
        collectionView.contentInset.bottom =
        10 +
        abs(messageComposerViewBottomConstraint.constant) +
        abs(messageComposerViewHeightConstraint.constant)
    }
    
    private func removePrevUnreadSeparatorView(escape messageId: UInt64) {
        DispatchQueue.main.async {[weak self] in
            self?.collectionView.visibleCells.forEach {
                if let self, let cell = ($0 as? MessageCell),
                   cell.data.message.id != messageId,
                   !cell.unreadView.isHidden {
                    if let indexPath = self.collectionView.indexPath(for: cell) {
                        self.collectionView.reloadItems(at: [indexPath])
                    } else {
                        cell.unreadView.isHidden = true
                    }
                }
            }
        }
    }
    
    open func keyboardWillShow(notification: Notification) {
        guard let keyboardFrameEndValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
        else { return }
        let bottom = collectionView.contentInset.bottom
        var contentOffsetY = collectionView.contentOffset.y
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        let keyboardScreenEndFrame = keyboardFrameEndValue.cgRectValue
        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)
        let shift = min(
            0,
            -min(
                view.bounds.height,
                view.bounds.height - max(
                    0,
                    keyboardViewEndFrame.origin.y + view.safeAreaInsets.bottom
                )
            )
        )
        messageComposerViewBottomConstraint.constant = shift
        updateCollectionViewInsets()
        let newBottom = collectionView.contentInset.bottom
        if newBottom != bottom {
            if collectionView.contentSize.height >= collectionView.bounds.height {
                contentOffsetY += newBottom - bottom
            } else {
                let diff = collectionView.contentSize.height - (collectionView.bounds.height - newBottom)
                if diff > 0 {
                    contentOffsetY += diff
                }
            }
        }
        contentOffsetY = min(contentOffsetY, collectionView.contentSize.height)
        let animation = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        UIView.animate(
            withDuration: duration ?? 0,
            delay: 0,
            options: .init(rawValue: animation ?? 0)
        ) {
            self.view.layoutIfNeeded()
            self.collectionView.setContentOffset(.init(x: 0, y: contentOffsetY), animated: false)
        }
    }
    
    open func keyboardWillHide(notification: Notification) {
        let bottom = collectionView.contentInset.bottom
        var contentOffsetY = collectionView.contentOffset.y
        messageComposerViewBottomConstraint.constant = 0
        updateCollectionViewInsets()
        let newBottom = collectionView.contentInset.bottom
        contentOffsetY += newBottom - bottom
        contentOffsetY = max(contentOffsetY, 0)
        
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        let animation = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        UIView.animate(
            withDuration: duration ?? 0,
            delay: 0,
            options: .init(rawValue: animation ?? 0)
        ) {
            self.composerVC.view.layoutIfNeeded()
            if self.channelViewModel.selectedMessageForAction == nil {
                self.collectionView.setContentOffset(.init(x: 0, y: contentOffsetY), animated: false)
            }
        }
    }
    
    // MARK: Title
    
    open func updateTitle() {
        showTitle(
            title: channelViewModel.title,
            subTitle: channelViewModel.subTitle
        )
        avatarTask = Components.avatarBuilder.loadAvatar(into: titleView.profileImageView, for: channelViewModel.channel)
    }
    
    open func showTitle(
        title: String,
        subTitle: String?
    ) {
        titleView.mode = .default
        var attrs = [NSAttributedString.Key: Any]()
        
        if let font = titleView.appearance.titleFont {
            attrs[.font] = font
        }
        if let color = titleView.appearance.titleColor {
            attrs[.foregroundColor] = color
        }
        
        let head = NSMutableAttributedString(
            string: title,
            attributes: attrs
        )
        titleView.headLabel.attributedText = head
        
        attrs.removeAll(keepingCapacity: true)
        
        if let font = titleView.appearance.subtitleFont {
            attrs[.font] = font
        }
        if let color = titleView.appearance.subtitleColor {
            attrs[.foregroundColor] = color
        }
        
        guard let subTitle else { return }
        let sub = NSAttributedString(
            string: subTitle,
            attributes: attrs
        )
        titleView.subLabel.attributedText = sub
    }
    
    open func reloadTitle() {
        updateTitle()
    }
    
    open func updateJoinButtonVisibility() {
        joinGlobalChannelButton.isHidden = !channelViewModel.isUnsubscribedChannel
    }
    
    open func showConnectionState(
        text: String,
        color: UIColor
    ) {
        titleView.mode = .default
        var attrs = [NSAttributedString.Key: Any]()
        
        if let font = titleView.appearance.titleFont {
            attrs[.font] = font
        }
        if let color = titleView.appearance.titleColor {
            attrs[.foregroundColor] = color
        }
        
        let head = NSMutableAttributedString(
            string: Formatters.channelDisplayName.format(channelViewModel.channel),
            attributes: attrs
        )
        titleView.headLabel.attributedText = head
        
        attrs.removeAll(keepingCapacity: true)
        
        if let font = titleView.appearance.subtitleFont {
            attrs[.font] = font
        }
        if let color = titleView.appearance.subtitleColor {
            attrs[.foregroundColor] = color
        }
        
        let sub = NSAttributedString(
            string: text,
            attributes: attrs
        )
        titleView.subLabel.attributedText = sub
    }
    
    open func showTyping(
        member: String,
        isTyping: Bool
    ) -> Int {
        if let titleView = navigationItem.titleView as? TitleView,
           titleView.mode == .typing
        {
            titleView.typingView.update(typer: member, typing: isTyping)
            navigationController?.navigationBar.setNeedsLayout()
            return titleView.typingView.typers.count
        }
        titleView.mode = .typing
        
        var attrs = [NSAttributedString.Key: Any]()
        
        if let font = titleView.appearance.titleFont {
            attrs[.font] = font
        }
        if let color = titleView.appearance.titleColor {
            attrs[.foregroundColor] = color
        }
        
        let head = NSMutableAttributedString(
            string: Formatters.channelDisplayName.format(channelViewModel.channel),
            attributes: attrs
        )
        
        titleView.headLabel.attributedText = head
        titleView.typingView.label.font = titleView.appearance.subtitleFont
        titleView.typingView.update(
            typer: member,
            typing: isTyping
        )
        return titleView.typingView.typers.count
    }
    
    // MARK: Actions
    
    @objc
    open func joinButtonAction(_ sender: UIButton) {
        channelViewModel.join { [weak self] error in
            guard let self = self else { return }
            self.indicatorView.stopAnimating()
            if let error = error {
                self.showAlert(error: error)
            } else {
                self.joinGlobalChannelButton.isHidden = true
            }
            self.updateTitle()
        }
    }
    
    @objc
    open func unreadButtonAction(_ sender: ChannelUnreadCountView) {
        layout.scrollToPositionAfterInvalidationContext = .end
        if let collectionViewScrolledAtIndexPath {
            showRepliedMessage(at: collectionViewScrolledAtIndexPath)
            self.collectionViewScrolledAtIndexPath = nil
        } else {
            collectionView.scrollToBottom()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.channelViewModel.markChannelAsDisplayed()
                self?.channelViewModel.loadPrevMessages(before: 0)
                self?.unreadCountView.isHidden = true
            }
        }
    }
    
    @objc
    open func showChannelProfileAction() {
        router.showChannelProfile()
    }
    
    @objc
    open func viewTapped(gesture: UITapGestureRecognizer) {
        let child = children.first { vc in
            vc.view.bounds.contains(gesture.location(in: vc.view))
        }
        guard
            !composerVC.isRecording,
            !composerVC.view.bounds.contains(gesture.location(in: composerVC.view)),
            !unreadCountView.bounds.contains(gesture.location(in: unreadCountView)),
            child == nil
        else { return }
        needToScrollBottom = true
        inputTextView.resignFirstResponder()
    }
    
    // MARK: UIGestureRecognizer delegate
    
    open func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        if gestureRecognizer === navigationController?.interactivePopGestureRecognizer ||
            !(gestureRecognizer is UITapGestureRecognizer) {
            return true
        }
        guard !(touch.view is ChannelUnreadCountView)
        else { return false }
        guard inputTextView.isFirstResponder
        else { return false }
        guard !(touch.view?.tag == 999)
        else { return false }
        guard !(touch.view is MessageCell.LinkView)
        else { return false }
        guard !(touch.view is MessageCell.ReplyView)
        else { return false }
        return composerVC.presentedMentionUserListVC?.parent == nil
    }
    
    // MARK: UICollectionViewDelegate
    
//    open func collectionView(
//        _ collectionView: UICollectionView,
//        shouldShowMenuForItemAt indexPath: IndexPath
//    ) -> Bool {
//        !channelViewModel.isUnsubscribedChannel
//    }
    
//    @available(iOS 13.0, *)
//    open func collectionView(
//        _ collectionView: UICollectionView,
//        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
//    ) -> UITargetedPreview? {
//        preview(configuration: configuration)
//    }
    
//    @available(iOS 13.0, *)
//    open func collectionView(
//        _ collectionView: UICollectionView,
//        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
//    ) -> UITargetedPreview? {
//        let targetPreview = preview(configuration: configuration)
//        needToScrollBottom =
//        collectionView.contentSize.height -
//        collectionView.contentOffset.y -
//        collectionView.bounds.height < 20
//        return targetPreview
//    }
    
//    @available(iOS 13.0, *)
//    open func collectionView(
//        _ collectionView: UICollectionView,
//        contextMenuConfigurationForItemAt indexPath: IndexPath,
//        point: CGPoint
//    ) -> UIContextMenuConfiguration? {
//        guard canPerformMessageActions(indexPath: indexPath, point: point)
//        else { return nil }
//        if inputTextView.isFirstResponder {
//            needToScrollBottom = false
//        }
//
//        let actionProvider = makeActionProvider(
//            collectionView: collectionView as! ChannelCollectionView,
//            contextMenuConfigurationForItemAt: indexPath
//        )
//
//                let previewProvider = makePreviewProvider(
//                    collectionView: collectionView as! ChannelCollectionView,
//                    contextMenuConfigurationForItemAt: indexPath
//                )
//
//        return UIContextMenuConfiguration(
//            identifier: indexPath as NSIndexPath,
////            previewProvider: {
////                previewProvider
////            },
//            actionProvider: actionProvider
//        )
//    }
    
//    open func makeActionProvider(
//        collectionView: ChannelCollectionView,
//        contextMenuConfigurationForItemAt indexPath: IndexPath
//    ) -> UIContextMenuActionProvider? {
//        { [weak self] _ in
//            guard let message = self?.channelViewModel.layoutModel(at: indexPath)?.message
//            else { return nil }
//
//            var items: [UIMenuElement] = [
//                UIAction(
//                    title: L10n.Message.Action.Title.react,
//                    image: Images.messageActionReact
//                ) { [weak self] _ in
//                    self?.addReaction(at: indexPath)
//                },
//                UIAction(
//                    title: L10n.Message.Action.Title.reply,
//                    image: Images.messageActionReply
//                ) { [weak self] _ in
//                    self?.reply(at: indexPath, in: false)
//                },
//                UIAction(
//                    title: L10n.Message.Action.Title.replyInThread,
//                    image: Images.messageActionReplyInThread
//                ) { [weak self] _ in
//                    self?.reply(at: indexPath, in: true)
//                },
//
//                UIAction(
//                    title: L10n.Message.Action.Title.copy,
//                    image: Images.messageActionCopy
//                ) { [weak self] _ in
//                    self?.copy(at: indexPath)
//                },
//            ]
//            if !message.incoming {
//                items.insert(UIAction(
//                    title: L10n.Message.Action.Title.edit,
//                    image: Images.messageActionEdit
//                ) { [weak self] _ in
//                    self?.editMessage(at: indexPath)
//                }, at: 0)
//                items.append(UIAction(
//                    title: L10n.Message.Action.Title.delete,
//                    image: Images.messageActionDelete,
//                    attributes: .destructive
//                ) { [weak self] _ in
//                    self?.router.showConfirmationAlertForDeleteMessage { [weak self] in
//                        if $0 {
//                            self?.deleteMessage(at: indexPath)
//                        }
//                    }
//                })
//            }
//            return UIMenu(identifier: .alignment, options: [.displayInline], children: items)
//        }
//    }
//
//    open func makePreviewProvider(
//        collectionView: ChannelCollectionView,
//        contextMenuConfigurationForItemAt indexPath: IndexPath
//    ) -> UIViewController? {
//        if let cell = collectionView.cell(for: indexPath, cellType: MessageCell.self) {
//            return MessagePreviewProviderVC(message: cell)
//        }
//        return nil
//    }
    
//    @available(iOS 13.0, *)
//    open func preview(configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
//        guard let indexPath = configuration.identifier as? IndexPath,
//              let cell = collectionView.cell(for: indexPath, cellType: MessageCell.self)
//        else { return nil }
//        let parameters = UIPreviewParameters()
//        parameters.backgroundColor = .clear
//
//        parameters.visiblePath = UIBezierPath(roundedRect: cell.bubbleView.bounds, cornerRadius: cell.bubbleView.layer.cornerRadius)
//        return UITargetedPreview(view: cell.bubbleView, parameters: parameters)
//    }
    
    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        layout.scrollToPositionAfterInvalidationContext = .none
        let y = scrollView.panGestureRecognizer.velocity(in: scrollView).y
        guard y != 0 else { return }
        isScrollingTop = y < 0
        if !isScrollingTop {
            channelViewModel.loadPrevMessages(beforeMessageAt: .zero)
        } else if let indexPath = collectionView.lastIndexPath {
            channelViewModel.loadNextMessages(afterMessageAt: indexPath)
        }
    }
    
    open func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        let y = scrollView.panGestureRecognizer.velocity(in: scrollView).y
        guard y != 0 else { return }
        isScrollingTop = y < 0
        if !isScrollingTop {
            channelViewModel.loadPrevMessages(beforeMessageAt: .zero)
        } else if let indexPath = collectionView.lastIndexPath {
            channelViewModel.loadNextMessages(afterMessageAt: indexPath)
        }
    }
    
    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if let collectionViewScrolledAtIndexPath,
           !collectionView.indexPathsForVisibleItems.contains(collectionViewScrolledAtIndexPath)
        {
            self.collectionViewScrolledAtIndexPath = nil
        }
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if let collectionViewScrolledAtIndexPath,
           !collectionView.indexPathsForVisibleItems.contains(collectionViewScrolledAtIndexPath)
        {
            self.collectionViewScrolledAtIndexPath = nil
        }
    }
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateUnreadViewVisibility()
        if scrollView.isDragging || scrollView.isDecelerating {
            isScrollingTop = scrollView.panGestureRecognizer.velocity(in: scrollView).y <= 0
        }
    }
    
    open func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        addMoreMessages(scrollView: scrollView, force: true)
    }
    
    open func updateUnreadViewVisibility() {
        guard !collectionView.indexPathsForVisibleItems.isEmpty,
              let lastAttributesFrame = layout.currentLayoutAttributes.last?.frame
        else {
            unreadCountView.isHidden = true
            return
        }
        
        let visibleContentHeight = collectionView.contentSize.height - collectionViewVisibleFrame.height
        if collectionView.contentOffset.y + lastAttributesFrame.height > visibleContentHeight {
            unreadCountView.isHidden = true
        } else {
            unreadCountView.isHidden = false
        }
        
        
//        var shouldHideUnreadView = true
//        if let indexPath = collectionView.lastIndexPath {
//            if collectionView.cellForItem(at: indexPath) == nil {
//                shouldHideUnreadView = false
//            } else if var lastFrame = collectionView.layoutAttributesForItem(at: indexPath)?.frame {
//                lastFrame.origin.y -= collectionView.contentOffset.y
//                let rect = collectionViewVisibleFrame
//                if !rect.intersects(lastFrame) {
//                    shouldHideUnreadView = false
//                }
//            }
//        }
//        if unreadCountView.isHidden != shouldHideUnreadView {
//            unreadCountView.isHidden = shouldHideUnreadView
//        }
    }
    
    open func addMoreMessages(
        scrollView: UIScrollView,
        velocity: CGFloat = 1,
        force: Bool
    ) {
        let indexPathsForVisibleItems = collectionView.indexPathsForVisibleItems
        guard scrollView.frame.height > 0,
              indexPathsForVisibleItems.count > 0
        else { return }
        let page = Int(scrollView.contentOffset.y / scrollView.frame.height)
        guard page != requestMassagesPage || force
        else { return }
        requestMassagesPage = page
        guard let maxIndexPath = collectionView.indexPathsForVisibleItems.max(),
              let minIndexPath = collectionView.indexPathsForVisibleItems.min()
        else { return }
        if !isScrollingTop {
            channelViewModel.loadPrevMessages(beforeMessageAt: minIndexPath)
        } else {
            channelViewModel.loadNextMessages(afterMessageAt: maxIndexPath)
        }
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        if collectionView.isDragging ||
            collectionView.isDecelerating ||
            needToMarkMessageAsDisplayed {
            needToMarkMessageAsDisplayed = false
            markMessageAsDisplayed(at: collectionView.indexPathsForVisibleItems + [indexPath])
        }
        
        if let mCell = (cell as? MessageCell),
           highlightedMessageId == mCell.data?.message.id
        {
            highlightCell(mCell)
        }
    }
    
    // MARK: UICollectionViewDataSource
    
    open func numberOfSections(in collectionView: UICollectionView) -> Int {
        channelViewModel.numberOfSection
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        return channelViewModel.numberOfMessages(in: section)
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let model = channelViewModel.layoutModel(at: indexPath) ?? channelViewModel.createLayoutModels(at: [indexPath]).first!
        //        channelViewModel.updateLinkPreviewsForLayoutModelIfNeeded(model, at: indexPath)
        let type: MessageCell.Type =
        model.message.incoming ?
        Components.incomingMessageCell :
        Components.outgoingMessageCell
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: type)
        cell.showSenderInfo = channelViewModel.canShowMessageSenderInfo(messageAt: indexPath)
        let top = self.collectionView
            .indexPath(after: indexPath)?.item == .some(0) ? CGFloat(0) : 6
        cell.unreadView.contentInsets = .init(top: top, left: 0, bottom: 12, right: 0)
        let canShowUnreadSeparator = channelViewModel.canShowUnreadSeparatorForMessage(at: indexPath)
        cell.unreadView.isHidden = !canShowUnreadSeparator
        cell.data = model
        if canShowUnreadSeparator {
            removePrevUnreadSeparatorView(escape: model.message.id)
        }
        cell.previewer = channelViewModel.previewer
        cell.onAction = { [weak self] action in
            switch action {
            case .editMessage:
                self?.editMessage(at: indexPath)
            case .deleteMessage:
                self?.deleteMessage(at: indexPath)
            case .showThread:
                self?.reply(at: indexPath, in: true)
            case .showReply:
                self?.showReplyMessage(at: indexPath)
            case .tapReaction:
                self?.tapReaction(at: indexPath)
            case .addReaction:
                self?.addReaction(at: indexPath)
            case .deleteReaction(let key):
                self?.deleteReaction(at: indexPath, reaction: key)
            case .updateReactionScore(let key, let score, let add):
                self?.updateReaction(at: indexPath, reaction: key, score: UInt16(score), add: add)
            case .selectMentionedUser:
                break
            case .selectAttachment(let index):
                self?.showAttachments(at: indexPath, from: index)
            case .pauseTransfer(let index):
                self?.channelViewModel.stopFileTransfer(messageAt: indexPath, attachmentAt: index)
            case .resumeTransfer(let index):
                self?.channelViewModel.resumeFileTransfer(messageAt: indexPath, attachmentAt: index)
            case .openUrl(let url):
                self?.router.showLink(url)
            case .playAtUrl(let url):
                self?.router.playFrom(url: url)
            }
        }
        contextMenu.connect(
            to: cell.bubbleView,
            identifier: .init(value: indexPath),
            alignment: model.message.incoming ? .leading : .trailing
        )
        
        return cell
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let cell = collectionView.dequeueReusableSupplementaryView(
            for: indexPath,
            cellType: MessageSectionSeparatorView.self,
            kind: .header
        )
        cell.date = channelViewModel.separatorDateForMessage(at: indexPath)
        return cell
    }
    
    // MARK: UICollectionViewDataSourcePrefetching
    
    open func collectionView(
        _ collectionView: UICollectionView,
        prefetchItemsAt indexPaths: [IndexPath]
    ) {
        channelViewModel.createLayoutModels(at: indexPaths)
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        cancelPrefetchingForItemsAt indexPaths: [IndexPath]
    ) {}
    
    //MARK: ChannelCollectionViewLayoutDelegate
    
    open func interItemSpacing(layout: ChannelCollectionViewLayout, before indexPath: IndexPath) -> CGFloat {
        if indexPath.item == 0 {
            return 0
        }
        guard let m = channelViewModel.message(at: indexPath),
              let bm = channelViewModel.message(at: .init(item: indexPath.item - 1, section: indexPath.section))
        else {
           return layout.defaults.estimatedInterItemSpacing
        }
        
        if m.incoming == bm.incoming {
            return layout.defaults.estimatedInterItemSpacing
        }
        return layout.defaults.estimatedInterItemSpacing + 5
    }
    
    open func canPerformMessageActions(
        indexPath: IndexPath,
        point: CGPoint
    ) -> Bool {
        guard !channelViewModel.isThread,
              let item = channelViewModel.message(at: indexPath),
              item.state != .deleted
        else { return false }
        
        guard let cell = collectionView.cell(
            for: indexPath,
            cellType: MessageCell.self
        )
        else { return false }
        
        let point = collectionView.convert(point, to: cell)
        return cell.bubbleView.frame.contains(point)
    }
    
    // MARK: Send message
    
    open func createMessage(shouldClearText: Bool = true) -> UserSendMessage {
        let m = UserSendMessage(
            sendText: shouldClearText ? inputTextView.attributedText : .init(),
            attachments: mediaView.items
        )
        if let ma = channelViewModel.selectedMessageForAction {
            switch ma {
            case let (message, .reply):
                m.action = .reply(message)
            case let (message, .edit):
                m.action = .edit(message)
            default:
                break
            }
        }
        return m
    }
    
    open func sendMessage(_ message: UserSendMessage, shouldClearText: Bool = true) {
        channelViewModel.createAndSendUserMessage(message)
        if shouldClearText {
            inputTextView.text = nil
        }
        composerVC.mediaView.removeAll()
        composerVC.removeActionView()
        if channelViewModel.selectedMessageForAction == nil ||
            channelViewModel.selectedMessageForAction?.1 == .reply {
            UIView.animate(withDuration: 0.2, animations: {
                self.view.layoutIfNeeded()
            })
            
            layout.scrollToPositionAfterInvalidationContext = .end
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.collectionView.scrollToBottom(animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    self?.unreadCountView.isHidden = true
                    self?.collectionView.visibleCells.forEach {
                        if let messageCell = $0 as? MessageCell {
                            messageCell.previewer = self?.channelViewModel.previewer
                        }
                    }
                }
            }
        }
        channelViewModel.removeSelectedMessage()
    }
    
    open func editMessage(at indexPath: IndexPath) {
        channelViewModel.selectMessage(at: indexPath, for: .edit)
        if let cell = collectionView.cell(for: indexPath, cellType: MessageCell.self) {
            inputTextView.attributedText = cell.data.attributedView
            let image = (cell.attachmentView.arrangedSubviews.first as? MessageCell.AttachmentView)?.imageView.image
            composerVC.addEdit(
                message: cell.data.message,
                image: image
            )
        }
        UIView.animate(withDuration: 0.2, animations: {
            self.view.layoutIfNeeded()
        })
        inputTextView.becomeFirstResponder()
    }
    
    open func reply(
        at indexPath: IndexPath,
        in thread: Bool
    ) {
        if !thread {
            channelViewModel.selectMessage(at: indexPath, for: .reply)
            if let cell = collectionView.cell(for: indexPath, cellType: MessageCell.self) {
                let image = (cell.attachmentView.arrangedSubviews.first as? MessageCell.AttachmentView)?.imageView.image
                composerVC.addReply(
                    message: cell.data.message,
                    image: image
                )
            }
            
            UIView.animate(withDuration: 0.2, animations: {
                self.view.layoutIfNeeded()
            })
            inputTextView.becomeFirstResponder()
            
        } else {
            showThreadForMessage(at: indexPath)
        }
    }
    
    open func forward(
        at indexPath: IndexPath
    ) {
        channelViewModel.selectMessage(at: indexPath, for: .forward)
    }
    
    open func deleteMessage(
        at indexPath: IndexPath,
        forMeOnly: Bool = false
    ) {
        channelViewModel.deleteMessage(
            at: indexPath,
            forMeOnly: forMeOnly
        )
    }

    open func tapReaction(at indexPath: IndexPath) {
        if let message = channelViewModel.message(at: indexPath) {
            router.showReactions(
                reactionScores: message.reactionScores ?? [:],
                reactions: message.selfReactions ?? []
            ).onEvent = { [weak self] event in
                switch event {
                case .removeReaction(let reaction):
                    if self?.channelViewModel.canDeleteReaction(at: indexPath, key: reaction.key) == true {
                        self?.presentedViewController?.dismiss(animated: true) { [weak self] in
                            self?.deleteReaction(at: indexPath, reaction: reaction.key)
                        }
                    }
                }
            }
        }
    }
    
    open func addReaction(at indexPath: IndexPath) {
        router.showEmojis()
            .onEvent = { [weak self] emoji in
                self?.channelViewModel.addReaction(
                    at: indexPath,
                    key: emoji.key
                )
            }
    }
    
    open func deleteReaction(
        at indexPath: IndexPath,
        reaction key: String
    ) {
        channelViewModel.deleteReaction(
            at: indexPath,
            key: key
        )
    }
    
    open func updateReaction(
        at indexPath: IndexPath,
        reaction key: String,
        score: UInt16,
        add: Bool
    ) {
        if add {
            channelViewModel.addReaction(
                at: indexPath,
                key: key,
                score: score
            )
        } else {
            channelViewModel.deleteReaction(
                at: indexPath,
                key: key
            )
        }
    }
    
    open func copy(at indexPath: IndexPath) {
        guard let message = channelViewModel.message(at: indexPath)
        else { return }
        UIPasteboard.general.string = message.body
        //        UIPasteboard.general.urls = model.sortedAttachments?
        //            .compactMap { $0.filePath }
        //            .map { URL(fileURLWithPath: $0) }
    }
    
    open func showReplyMessage(
        at indexPath: IndexPath
    ) {
        guard let message = channelViewModel.message(at: indexPath),
              let parent = message.parent
        else { return }
        
        func prevIndexPath(at indexPath: IndexPath) -> IndexPath? {
            if indexPath.item > 0 {
                return IndexPath(item: indexPath.item - 1, section: indexPath.section)
            } else if indexPath.section > 0 {
                return prevIndexPath(at:
                                        IndexPath(
                                            item: collectionView.numberOfItems(inSection: indexPath.section - 1) - 1,
                                            section: indexPath.section - 1
                                        )
                )
            }
            return nil
        }
        
        var parentIndexPath = indexPath
        while let prev = prevIndexPath(at: parentIndexPath) {
            parentIndexPath = prev
            if channelViewModel.message(at: prev)?.id == parent.id {
                break
            }
        }
        
        collectionViewScrolledAtIndexPath = indexPath
        UIView.animate(withDuration: 0.2) {
            self.collectionView.scrollToItem(at: parentIndexPath, at: .centeredVertically, animated: false)
        } completion: { _ in
            //            if let lastIndexPath = self.collectionView.lastIndexPath,
            //               self.collectionView.indexPathsForVisibleItems.contains(lastIndexPath) == false {
            //                self.unreadView.isHidden = false
            //            }
        }
        highlightedMessageId = parent.id
        DispatchQueue.main.asyncAfter(deadline: .now() + highlightReplyMessageAfterDelay) { [weak self] in
            guard let self else { return }
            if let cell = self.collectionView.cellForItem(at: parentIndexPath) as? MessageCell {
                self.highlightCell(cell)
            }
        }
        //        channelViewModel.loadNearMessages(messageId: parent.id)
        //        channelViewModel.loadPrevMessages(before: parent.id)
    }
    
    open func showRepliedMessage(
        at indexPath: IndexPath
    ) {
        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + highlightReplyMessageAfterDelay) { [weak self] in
            guard let self else { return }
            if let cell = self.collectionView.cellForItem(at: indexPath) as? MessageCell {
                self.highlightCell(cell)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + self.highlightedDurationForReplyMessage) { [weak self] in
                (self?.collectionView.cellForItem(at: indexPath) as? MessageCell)?
                    .isHighlightedBubbleView = false
            }
        }
    }
    
    open func highlightCell(_ cell: MessageCell) {
        cell.isHighlightedBubbleView = true
        DispatchQueue.main.asyncAfter(deadline: .now() + highlightedDurationForReplyMessage) { [weak self, weak cell] in
            cell?.isHighlightedBubbleView = false
            self?.highlightedMessageId = nil
        }
    }
    
    open func showThreadForMessage(at indexPath: IndexPath) {
        router.showThreadForMessage(at: indexPath)
    }
    
    open func showAttachments(
        at indexPath: IndexPath,
        from index: Int
    ) {
        router.showAttachments(
            messageAt: indexPath,
            from: index
        )
    }
    
    open func markMessageAsDisplayed(at indexPaths: [IndexPath]) {
        let markableIndexPaths = layout
            .layoutAttributesInVisibleBounds(
                indexPaths: indexPaths
            ).map { $0.indexPath }
        channelViewModel.markMessageAsDisplayed(at: markableIndexPaths)
    }
    
    // MARK: ViewModel Events
    
    open func onEvent(_ event: ChannelVM.Event) {
        switch event {
        case .update(let paths):
            let inserts = paths.inserts.sorted()
            let reloads = paths.reloads.sorted()
            let deletes = paths.deletes.sorted()
            let moves = paths.moves
            let sectionInserts = paths.sectionInserts
            let sectionDeletes = paths.sectionDeletes
            var needsToScrollBottom = false
            if view.superview == nil ||
                collectionView.numberOfSections == 0 ||
                (collectionView.numberOfSections == 1 && collectionView.numberOfItems(inSection: 0) == 1) {
                layout.isInsertingItemsToTop = false
                if layout.scrollToPositionAfterInvalidationContext == .none {
                    layout.scrollToPositionAfterInvalidationContext = .end
                }
                collectionView.reloadData()
                return
            }

            if case .prev = channelViewModel.lastRequestType {
                layout.isInsertingItemsToTop = true
            } else {
                layout.isInsertingItemsToTop = false
            }
            
            if collectionView.isVisibleLastIndexPath, !shouldScrollUnreadPosition {
                needsToScrollBottom = true
                needToMarkMessageAsDisplayed = true
            } else {
                needsToScrollBottom = false
            }
            
            if checkOnlyFirstTimeReceivedMessagesFromArchive,
               collectionView.totalNumberOfItems == 1 {
                checkOnlyFirstTimeReceivedMessagesFromArchive = false
                layout.isInsertingItemsToTop = false
                collectionView.reloadData()
            }
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            collectionView.performBatchUpdates {
                if !paths.sectionInserts.isEmpty {
                    collectionView.insertSections(sectionInserts)
                }
                if !paths.sectionDeletes.isEmpty {
                    collectionView.deleteSections(sectionDeletes)
                }
                collectionView.insertItems(at: inserts)
                collectionView.reloadItems(at: reloads)
                collectionView.deleteItems(at: deletes)
                moves.forEach { from, to in
                    collectionView.moveItem(at: from, to: to)
                }
            } completion: { [weak self] _ in
                defer {
                    CATransaction.commit()
                }
                guard let self = self else { return }
                UIView.performWithoutAnimation {
                    self.collectionView.reloadItems(at: moves.map(\.to))
                }
                self.layout.isInsertingItemsToTop = false
                if needsToScrollBottom, !(self.collectionView.isDragging || self.collectionView.isDecelerating) {
                    self.channelViewModel.markMessageAsDisplayed(at: inserts)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.layout.scrollToPositionAfterInvalidationContext = .none
                        self.collectionView.scrollToBottom(animated: inserts.count == 1)
                    }
                } else {
                    self.updateUnreadViewVisibility()
                }
            }
        case let .updateDeliveryStatus(deliveryStatus, indexPath):
            collectionView.cell(for: indexPath, cellType: MessageCell.self)?.deliveryStatus = deliveryStatus
        case .reload(let indexPath):
            UIView.performWithoutAnimation {
                let pos = collectionView.contentSize.height - collectionView.contentOffset.y
                collectionView.reloadItems(at: [indexPath])
                guard collectionView.contentSize.height > collectionView.frame.height else { return }
                collectionView.setContentOffset(
                    .init(x: collectionView.contentOffset.x,
                          y: collectionView.contentSize.height - pos),
                    animated: false
                )
            }
        case .reloadData:
            needToMarkMessageAsDisplayed = true
            collectionView.reloadData()
        case .didSetUnreadIndexPath(let indexPath):
            layout.scrollToPositionAfterInvalidationContext = .indexPath(indexPath)
        case .unreadCount(let count):
            unreadCountView.unreadCount.value = Formatters.channelUnreadMessageCount.format(count)
        case .typing(let isTyping, let user):
            if channelViewModel.channel.type.isGroup {
                if showTyping(member: Formatters.userDisplayName.format(user),
                              isTyping: isTyping) == 0 {
                    updateTitle()
                }
            } else {
                if isTyping {
                    _ = showTyping(
                        member: channelViewModel.channel.type == .direct ? "" : Formatters.userDisplayName.format(user),
                        isTyping: isTyping
                    )
                } else {
                    updateTitle()
                }
            }
        case .changePresence(let presence):
            let mode = titleView.mode
            let change = Formatters.userPresenceFormatter.format(presence)
            showTitle(title: channelViewModel.title, subTitle: change)
            if mode == .typing {
                titleView.mode = mode
            }
        case .updateChannel:
            updateTitle()
            updateJoinButtonVisibility()
            blockView.isHidden = !(channelViewModel.channel.peer?.blocked == true)
        case .close:
            router.popToRoot()
        case .connection(let state):
            switch state {
            case .connecting:
                showConnectionState(
                    text: L10n.Connection.State.connecting + "...",
                    color: .lightGray
                )
            case .connected:
                updateTitle()
            case .reconnecting:
                showConnectionState(
                    text: L10n.Connection.State.reconnecting,
                    color: .lightGray
                )
            case .disconnected:
                showConnectionState(
                    text: L10n.Connection.State.disconnected + "...",
                    color: .lightGray
                )
            case .failed:
                showConnectionState(
                    text: L10n.Connection.State.failed,
                    color: Colors.kitRed
                )
            @unknown default:
                break
            }
        }
    }
    
    // MARK: UINavigationControllerDelegate
    
    public func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        if self !== viewController {
            channelViewModel.updateDraftMessage(inputTextView.attributedText)
            if inputTextView.isFirstResponder {
                inputTextView.resignFirstResponder()
            }
        }
    }
    
    //MARK: ContextMenuDataSource
    open func emojis(contextMenu: ContextMenu, identifier: Identifier) -> [String] {
        Config.defaultEmojis
    }

    open func selectedEmojis(contextMenu: ContextMenu, identifier: Identifier) -> [String] {
        if let indexPath = identifier.value as? IndexPath {
            return channelViewModel.selectedEmojis(at: indexPath)
        }
        return []
    }
    
    open func items(contextMenu: ContextMenu, identifier: Identifier) -> [MenuItem] {
        if let indexPath = identifier.value as? IndexPath {
            guard let message = channelViewModel.layoutModel(at: indexPath)?.message else { return [] }
            var items: [MenuItem] = [
                .init(
                    title: L10n.Message.Action.Title.react,
                    image: Images.messageActionReact,
                    imageRenderingMode: .alwaysOriginal,
                    action: { [weak self] _ in
                        self?.addReaction(at: indexPath)
                    }
                ),
                .init(
                    title: L10n.Message.Action.Title.reply,
                    image: Images.messageActionReply,
                    imageRenderingMode: .alwaysOriginal,
                    action: { [weak self] _ in
                        self?.reply(at: indexPath, in: false)
                    }
                ),
                .init(
                    title: L10n.Message.Action.Title.replyInThread,
                    image: Images.messageActionReplyInThread,
                    imageRenderingMode: .alwaysOriginal,
                    action: { [weak self] _ in
                        self?.reply(at: indexPath, in: true)
                    }
                ),
                .init(
                    title: L10n.Message.Action.Title.forward,
                    image: Images.messageActionForward,
                    imageRenderingMode: .alwaysOriginal,
                    action: { [weak self] _ in
                        self?.forward(at: indexPath)
                    }
                ),
                .init(
                    title: L10n.Message.Action.Title.copy,
                    image: Images.messageActionCopy,
                    imageRenderingMode: .alwaysOriginal,
                    action: { [weak self] _ in
                        self?.copy(at: indexPath)
                    }
                )
            ]
            if !message.incoming {
                items.append(
                    .init(
                        title: L10n.Message.Action.Title.edit,
                        image: Images.messageActionEdit,
                        imageRenderingMode: .alwaysOriginal,
                        action: { [weak self] _ in
                            self?.editMessage(at: indexPath)
                        }
                    )
                )
                items.append(
                    .init(
                        title: L10n.Message.Action.Title.delete,
                        image: Images.messageActionDelete,
                        destructive: true,
                        dismissOnAction: false,
                        action: { [weak self] _ in
                            contextMenu.actionController?.emojiController.view.isHidden = true
                            contextMenu.reload(items: [
                                .init(
                                    title: "Delete for everyone",
                                    image: Images.messageActionDelete,
                                    destructive: true,
                                    action: { [weak self] _ in
                                        self?.router.showConfirmationAlertForDeleteMessage {
                                            if $0 {
                                                self?.deleteMessage(at: indexPath, forMeOnly: false)
                                            }
                                        }
                                    }
                                ),
                                
                                    .init(
                                        title: "Delete for me",
                                        image: Images.messageActionDelete,
                                        destructive: true,
                                        action: { [weak self] _ in
                                            self?.router.showConfirmationAlertForDeleteMessage {
                                                if $0 {
                                                    self?.deleteMessage(at: indexPath, forMeOnly: true)
                                                }
                                            }
                                        }
                                    )
                            ])
                        }
                    )
                )
            }
            return items
        }
        return []
    }
    
    //MARK: ContextMenuDelegate
    open func didSelect(emoji: String, forViewWith identifier: Identifier) {
        if let indexPath = identifier.value as? IndexPath {
            channelViewModel.addReaction(at: indexPath, key: emoji)
        }
    }

    open func didDeselect(emoji: String, forViewWith identifier: Identifier) {
        if let indexPath = identifier.value as? IndexPath {
            channelViewModel.deleteReaction(at: indexPath, key: emoji)
        }
    }
    
    open func didSelectMoreAction(forViewWith identifier: Identifier) {
        if let indexPath = identifier.value as? IndexPath {
            addReaction(at: indexPath)
        }
    }
    
    //MARK: ContextMenuSnapshotDelegate
    open func willMakeSnapshot(forViewWith identifier: Identifier) {
        if let indexPath = identifier.value as? IndexPath,
           let snapshotProving = collectionView.cellForItem(at: indexPath) as? ContextMenuSnapshotProviding {
            snapshotProving.onPrepareSnapshot()
        }
    }

    open func didMakeSnapshot(forViewWith identifier: Identifier) {
        if let indexPath = identifier.value as? IndexPath,
           let snapshotProving = collectionView.cellForItem(at: indexPath) as? ContextMenuSnapshotProviding {
            snapshotProving.onFinishSnapshot()
        }
    }
    
    deinit {
        contentSizeObserver = nil
        avatarTask?.cancel()
    }
}

extension ChannelVC {
    open class BarCoverView: UIView {
        override open func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            subviews.first { view in
                !view.isHidden && view.alpha > 0 && view.isUserInteractionEnabled && view.point(inside: convert(point, to: view), with: event)
            } != nil
        }
    }
}
