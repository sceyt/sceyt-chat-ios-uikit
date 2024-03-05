//
//  ChannelVC.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import Photos
import SceytChat
import UIKit

open class ChannelVC: ViewController,
                      UIGestureRecognizerDelegate,
                      UICollectionViewDelegateFlowLayout,
                      UICollectionViewDataSource,
                      UINavigationControllerDelegate,
                      ContextMenuDataSource,
                      ContextMenuDelegate,
                      ContextMenuSnapshotDelegate,
                      AttachmentPreviewDataSourceDelegate
{    
    open var channelViewModel: ChannelVM!
    
    open lazy var router = Components.channelRouter
        .init(rootVC: self)
    
    open lazy var collectionView = Components.channelCollectionView
        .init()
        .withoutAutoresizingMask
    
    public var layout: ChannelCollectionViewLayout {
        collectionView.layout
    }
    
    open lazy var coverView = BarCoverView()
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
    
    open var bottomView = Components.channelBottomView
        .init()
        .withoutAutoresizingMask
    
    open var searchControlsView = Components.channelSearchControlsView
        .init()
        .withoutAutoresizingMask
    
    open lazy var joinGlobalChannelButton = UIButton()
        .withoutAutoresizingMask
    
    open lazy var selectingView = Components.channelSelectingView
        .init()
        .withoutAutoresizingMask
    
    open lazy var noDataView = Components.noDataView
        .init()
        .withoutAutoresizingMask
    
    open lazy var createdView = Components.channelCreatedView
        .init()
        .withoutAutoresizingMask
    
    open lazy var tapAction: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(viewTapped(gesture:))
        )
        tap.delegate = self
        tap.cancelsTouchesInView = true
        return tap
    }()
    
    open lazy var searchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = L10n.Channel.Search.search
        searchBar.showsCancelButton = true
        searchBar.delegate = self
        searchBar.searchTextField.returnKeyType = .default
        searchBar.barTintColor = appearance.searchBarBackgroundColor
        searchBar.searchTextField.backgroundColor = appearance.searchBarBackgroundColor
        return searchBar
    }()
    
    open lazy var searchBarActivityIndicator = {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.backgroundColor = appearance.searchBarBackgroundColor
        activityIndicator.color = appearance.searchBarActivityIndicatorColor
        activityIndicator.hidesWhenStopped = true
        return activityIndicator
    }()
    
    @objc public lazy var tapGestureRecognizer = UITapGestureRecognizer()
    @objc public lazy var longPressGestureRecognizer = UILongPressGestureRecognizer()
    @objc public lazy var panGestureRecognizer = UIPanGestureRecognizer()
    
    open lazy var displayedTimer = DisplayedTimer()
    
    private lazy var keyboardBgView = UIView()
        .withoutAutoresizingMask
    
    public var avatarTask: Cancellable?
    
    public var messageComposerViewBottomConstraint: NSLayoutConstraint!
    public var searchControlsViewBottomConstraint: NSLayoutConstraint!
    public var messageComposerViewHeightConstraint: NSLayoutConstraint!
    
    override open var disablesAutomaticKeyboardDismissal: Bool {
        return true
    }
    
    public var highlightedDurationForReplyMessage = TimeInterval(1)
    private let highlightedDurationForSearchMessage = TimeInterval(0.5)
    
    public private(set) var keyboardObserver: KeyboardObserver?
    private var needToMarkMessageAsDisplayed = false
    private var needToScrollBottom = true
    private var requestMassagesPage = -1
    private var lastScrollDirection = ScrollDirection.none
    private var scrollDirection = ScrollDirection.none {
        willSet {
            if newValue != .none {
                lastScrollDirection = newValue
            }
        }
    }
    private var longPressItem: MessageCell.LongPressItem?
    public var unreadMessageIndexPath: IndexPath?
    
    open var userSelectOnRepliedMessage: ChatMessage?
    
    private var isCollectionViewUpdating = false
    private var isStartedDragging = false {
        didSet {
            unreadMessageIndexPath = nil
            channelViewModel.canUpdateUnreadPosition = false
        }
    }

    private var isScrollingBottom = false
    private var checkOnlyFirstTimeReceivedMessagesFromArchive = true
    private var isViewDidAppear = false
    private var contextMenu: ContextMenu!
    private var scrollTimer: Timer?
    private var isAppActive: Bool = true
    private var shouldAnimateEditing: Bool = false
    private var lastAnimatedIndexPath: IndexPath? = nil
    private var selectMessageId: MessageId = 0
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.delegate = self
        showBottomViewIfNeeded()
        updateTitle()
        updateUnreadViewVisibility()
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

        displayedTimer.start { [weak self] _ in
            guard let self,
                    !self.isCollectionViewUpdating,
                    self.isAppActive
            else { return}
            self.markMessageAsDisplayed()
        }
        
        if navigationController?.navigationBar.isUserInteractionEnabled == false { // system bug
            navigationController?.navigationBar.isUserInteractionEnabled = true
        }
    }
    
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isViewDidAppear = false
        keyboardObserver = nil
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        guard isViewLoaded
        else { return }
        
        Components.messageLayoutModel.defaults.messageWidth = floor(Components.messageLayoutModel.defaults.messageWidthRatio * size.width)
        channelViewModel.invalidateLayout()
        collectionView.reloadData()
        
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            self.titleView.setNeedsLayout()
            self.titleView.layoutIfNeeded()
        })
    }
    
    override open func setup() {
        super.setup()
        
        contextMenu = ContextMenu(parent: self)
        contextMenu.dataSource = self
        contextMenu.delegate = self
        contextMenu.snapshotDelegate = self
                
        composerVC.mentionUserListVC = { [unowned self] in
            let vc = Components.mentioningUserListVC.init()
            vc.viewModel = Components.mentioningUserListVM
                .init(channelId: channelViewModel.channel.id)
            return vc
        }
        
        selectingView.onAction = { [weak self] in
            guard let self else { return }
            switch $0 {
            case .delete:
                self.router.showDeleteOptions(clear: false)
            case .share:
                self.showShareSelectedMessages()
            case .forward:
                self.showForwardSelectedMessages()
            }
        }
        searchControlsView.isHidden = true
        searchControlsView.onAction = { [weak self] in
            guard let self else { return }
            switch $0 {
            case .previousResult:
                channelViewModel.findPreviousSearchedMessage()
            case .nextResult:
                channelViewModel.findNextSearchedMessage()
            }
        }
        NotificationCenter.default.publisher(
            for: UITextField.textDidChangeNotification,
            object: searchBar.searchTextField
        )
        .compactMap { ($0.object as? UITextField)?.text }
        .debounce(for: .milliseconds(600), scheduler: DispatchQueue.main)
        .sink { [weak self] query in
            self?.channelViewModel.search(with: query)
        }
        .store(in: &subscriptions)
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.prefetchDataSource = self
        collectionView.isPrefetchingEnabled = true
        
        noDataView.icon = Images.noMessages
        noDataView.title = L10n.Channel.NoMessages.title
        noDataView.message = L10n.Channel.NoMessages.message
        noDataView.isHidden = true
        createdView.isHidden = true
        updateUnreadViewVisibility()
        updateTitle()
        unreadCountView.addTarget(self, action: #selector(unreadButtonAction(_:)), for: .touchUpInside)
        joinGlobalChannelButton.addTarget(self, action: #selector(joinButtonAction(_:)), for: .touchUpInside)
        titleView.profileImageView.isUserInteractionEnabled = false
        titleView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showChannelProfileAction)))
        
        tapGestureRecognizer.addTarget(self, action: #selector(handleTapGestureRecognizer(_:)))
        collectionView.addGestureRecognizer(tapGestureRecognizer)
        longPressGestureRecognizer.minimumPressDuration = 0.2
        longPressGestureRecognizer.addTarget(self, action: #selector(handleLongPressGestureRecognizer(_:)))
        collectionView.addGestureRecognizer(longPressGestureRecognizer)
        tapGestureRecognizer.require(toFail: longPressGestureRecognizer)
        tapGestureRecognizer.delegate = self
        collectionView.addGestureRecognizer(panGestureRecognizer)
        panGestureRecognizer.addTarget(self, action: #selector(handlePanGestureRecognizer))
        panGestureRecognizer.delegate = self
        updateNavigationItems()
        
        bottomView.icon = Images.warning
        bottomView.message = L10n.Channel.BlockedUser.message
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        view.addSubview(collectionView)
        view.addSubview(noDataView)
        view.addSubview(createdView)
        view.addSubview(coverView)
        view.addSubview(searchControlsView)
        addChild(composerVC)
        coverView.addSubview(composerVC.view)
        coverView.addSubview(unreadCountView)
        view.addSubview(joinGlobalChannelButton)
        view.addGestureRecognizer(tapAction)
        
        messageComposerViewBottomConstraint = composerVC.view.bottomAnchor.pin(to: coverView.safeAreaLayoutGuide.bottomAnchor)
        messageComposerViewHeightConstraint = composerVC.view.resize(anchors: [.height(52)]).first!
        
        searchControlsViewBottomConstraint = searchControlsView.bottomAnchor.pin(to: view.safeAreaLayoutGuide.bottomAnchor)
        searchControlsView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .trailing])
        
        updateCollectionViewInsets()
        //        collectionView.scrollToTop(animated: false)
        coverView.pin(to: view.safeAreaLayoutGuide)
        collectionView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .trailing, .top])
        collectionView.bottomAnchor.pin(to: coverView.safeAreaLayoutGuide.bottomAnchor)
        noDataView.pin(to: view, anchors: [.leading, .trailing])
        noDataView.topAnchor.pin(to: view.safeAreaLayoutGuide.topAnchor)
        noDataView.bottomAnchor.pin(to: composerVC.view.topAnchor)
        createdView.pin(to: view, anchors: [.leading, .trailing])
        createdView.bottomAnchor.pin(to: composerVC.view.topAnchor)
        composerVC.view.pin(to: coverView.safeAreaLayoutGuide, anchors: [.leading, .trailing])
        unreadCountView.trailingAnchor.pin(to: composerVC.view.trailingAnchor, constant: -10)
        unreadCountView.bottomAnchor.pin(to: composerVC.view.topAnchor, constant: -10)
        unreadCountView.resize(anchors: [.width(44), .height(48)])
        joinGlobalChannelButton.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .trailing, .bottom])
        joinGlobalChannelButton.resize(anchors: [.height(52)])
        
        view.addSubview(keyboardBgView)
        keyboardBgView.pin(to: view, anchors: [.leading, .trailing, .bottom])
        keyboardBgView.topAnchor.pin(to: composerVC.view.bottomAnchor)
        
        view.addSubview(selectingView)
        selectingView.pin(to: view, anchors: [.leading, .trailing])
        selectingView.bottomAnchor.pin(to: composerVC.view.bottomAnchor)
        
        
        if let view = searchBar.searchTextField.leftView {
            view.addSubview(searchBarActivityIndicator)
            searchBarActivityIndicator.pin(to: view)
        }
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        view.backgroundColor = appearance.backgroundColor
        coverView.backgroundColor = appearance.coverViewBackgroundColor
        collectionView.backgroundColor = appearance.backgroundColor
        
        joinGlobalChannelButton.setAttributedTitle(.init(
            string: L10n.Channel.join,
            attributes: [
                .font: appearance.joinFont as Any,
                .foregroundColor: appearance.joinColor as Any
            ]), for: .normal)
        joinGlobalChannelButton.backgroundColor = appearance.joinBackgroundColor
        keyboardBgView.backgroundColor = view.backgroundColor
    }
    
    override open func setupDone() {
        super.setupDone()
        updateJoinButtonVisibility()
        
        inputTextView
            .typingEvent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isTyping in
                self?.channelViewModel.isTyping = isTyping
            }.store(in: &subscriptions)
        
        composerVC.onContentHeightUpdate = { [weak self] height, completion in
            guard let self else { return }
            if height != self.messageComposerViewHeightConstraint.constant {
                UIView.animate(withDuration: 0.25) { [weak self] in
                    guard let self else { return }
                    let bottom = self.collectionView.contentInset.bottom
                    var contentOffsetY = self.collectionView.contentOffset.y
                    let diff = self.messageComposerViewHeightConstraint.constant - height
                    self.messageComposerViewHeightConstraint.constant = height
                    self.updateCollectionViewInsets()
                    let newBottom = self.collectionView.contentInset.bottom
                    if newBottom != bottom {
                        contentOffsetY += newBottom - bottom
                    }
                    contentOffsetY = min(contentOffsetY, collectionView.contentSize.height)
                    let needsToScroll = (self.collectionView.lastVisibleAttributes?.frame.maxY ?? 0) > self.composerVC.view.frameRelativeTo(view: self.collectionView).minY + diff
                    self.coverView.layoutIfNeeded()
                    guard needsToScroll else { return }
                    self.collectionView.layoutIfNeeded()
                    self.collectionView.setContentOffset(
                        .init(
                            x: 0,
                            y: contentOffsetY
                        ),
                        animated: false
                    )
                } completion: { _ in completion?() }
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
                        UIView.animate(withDuration: 0.25) { [weak self] in
                            self?.view.layoutIfNeeded()
                        }
                    }
                case .didActivateState(let state):
                    switch state {
                    case .edit(let model):
                        channelViewModel.select(message: model.message, for: .edit)
                    case .reply(let model):
                        channelViewModel.select(message: model.message, for: .reply)
                    default:
                        if channelViewModel.selectedMessageForAction?.1 != .forward {
                            channelViewModel.removeSelectedMessage()
                        }
                    }
                case .didStartRecording:
                    didStartVoiceRecording()
                case .didStopRecording:
                    didStopVoiceRecording()
                }
            }.store(in: &subscriptions)
        
        channelViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        
        channelViewModel.$selectedMessages
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateNavigationItems()
                self.collectionView.reloadData()
            }.store(in: &subscriptions)
        
        channelViewModel.$isEditing
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEditing in
                guard let self else { return }
                self.updateNavigationItems()
                if isEditing {
                    self.shouldAnimateEditing = true
                    self.collectionView.reloadData()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                        self?.shouldAnimateEditing = false
                    }
                    self.bottomView.removeFromSuperview()
                } else {
                    UIView.animate(withDuration: 0.3) { [weak self] in
                        guard let self else { return }
                        self.collectionView.visibleCells.forEach {
                            guard let cell = $0 as? MessageCell, cell.isEditing else { return }
                            let checkBoxSize = MessageCell.Layouts.checkBoxSize + 2 * MessageCell.Layouts.checkBoxPadding
                            cell.contentView.alpha = 1
                            cell.checkBoxView.transform = .init(translationX: -checkBoxSize, y: 0)
                            if cell.data.message.incoming {
                                cell.containerView.transform = .init(translationX: -checkBoxSize, y: 0)
                            }
                        }
                    } completion: { [weak self] _ in
                        self?.collectionView.reloadData()
                    }
                    self.showBottomViewIfNeeded()
                }
        }.store(in: &subscriptions)
        
        channelViewModel
            .$newMessageCount
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] value in
                self?.unreadCountView.unreadCount.value = Formatters.channelUnreadMessageCount.format(value)
            }.store(in: &subscriptions)
        
        channelViewModel
            .$isSearching
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSearching in
                self?.updateNavigationItems()
                self?.composerVC.view.isHidden = isSearching
                self?.searchControlsView.isHidden = !isSearching
            }
            .store(in: &subscriptions)
        
        channelViewModel
            .$searchResult
            .receive(on: DispatchQueue.main)
            .compactMap { $0?.state == .loaded ? $0 : nil }
            .sink { [weak self] searchResult in
                guard let self else { return }
                self.searchControlsView.update(
                    with: searchResult,
                    query: self.searchBar.searchTextField.text ?? ""
                )
                if searchResult.cacheCount == 0 {
                    NotificationCenter.default.post(name: .selectMessage, object: 0)
                }
            }
            .store(in: &subscriptions)
        
        channelViewModel
            .$isSearchResultsLoading
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.searchBarActivityIndicator.startAnimating()
                } else {
                    self?.searchBarActivityIndicator.stopAnimating()
                }
            }
            .store(in: &subscriptions)
        
        inputTextView.attributedText = channelViewModel.draftMessage
        
        ApplicationStateObserver()
            .didBecomeActive { [weak self] _ in
                self?.isAppActive = true
                self?.channelViewModel.canUpdateUnreadPosition = false
                self?.updateUnreadViewVisibility()
            }
            .didEnterBackground { [weak self] _ in
                self?.isAppActive = false
                self?.channelViewModel.canUpdateUnreadPosition = true
            }
    }
    
    private func updateCollectionViewInsets() {
        let bottomConstraint = searchControlsView.isHidden
        ? messageComposerViewBottomConstraint.constant
        : searchControlsViewBottomConstraint.constant
        let controlHeight = searchControlsView.isHidden
        ? messageComposerViewHeightConstraint.constant
        : searchControlsView.frame.height
        
        collectionView.contentInset.bottom =
        10 +
        abs(bottomConstraint) +
        abs(controlHeight)
        collectionView.scrollIndicatorInsets = .init(
            top: collectionView.contentInset.top,
            left: 0,
            bottom: collectionView.contentInset.bottom,
            right: 0)
    }
    
    private func removePrevUnreadSeparatorView(
        escape messageId: UInt64
    ) {
        DispatchQueue.main.async { [weak self] in
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
    
    func goTo(indexPath: IndexPath, completion: @escaping (MessageCell) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.collectionView.scrollToItem(at: indexPath, pos: .centeredVertically, animated: true)
            UIView.animate(withDuration: 0.3, delay: 0, options: .allowUserInteraction) { [weak self] in
            } completion: { [weak self] _ in
                guard let self else { return }
                if let cell = self.collectionView.cellForItem(at: indexPath) as? MessageCell {
                    completion(cell)
                } else {
                    print("[STOP] cell not exist")
                }
                self.updateUnreadViewVisibility()
            }
        }
    }
    
    open func keyboardWillShow(notification: Notification) {
        setSectionHeadersPinToVisibleBounds(false)
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
        searchControlsViewBottomConstraint.constant = shift
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
        setSectionHeadersPinToVisibleBounds(false)
        let bottom = collectionView.contentInset.bottom
        var contentOffsetY = collectionView.contentOffset.y
        messageComposerViewBottomConstraint.constant = 0
        searchControlsViewBottomConstraint.constant = 0
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
    
    open func updateNavigationItems() {
        if channelViewModel.isEditing {
            composerVC.actionViewCancelAction()
            view.endEditing(true)
            navigationItem.setHidesBackButton(false, animated: false)
            navigationItem.leftItemsSupplementBackButton = false
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: L10n.Channel.Selecting.ClearChat.clear,
                                                               style: .done,
                                                               target: router,
                                                               action: #selector(ChannelRouter.clearChat))
            navigationItem.titleView = nil
            navigationItem.title = L10n.Channel.Selecting.selected(channelViewModel.selectedMessages.count)
            navigationItem.rightBarButtonItems = [UIBarButtonItem(title: L10n.Alert.Button.cancel,
                                                                  style: .done,
                                                                  target: self,
                                                                  action: #selector(cancelSelecting))]
//            navigationItem./*searchController = nil*/
        } else if channelViewModel.isSearching {
            showSearchBar()
        } else {
            navigationItem.setHidesBackButton(false, animated: false)
            navigationItem.leftItemsSupplementBackButton = true
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: titleView)
            navigationItem.title = nil
            navigationItem.titleView = nil
            navigationItem.rightBarButtonItems = []
        }
        selectingView.isHidden = !channelViewModel.isEditing
        coverView.isHidden = channelViewModel.isEditing
    }
    
    open func showSearchBar() {
        definesPresentationContext = true
        navigationItem.setHidesBackButton(true, animated: false)
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItems = nil
        navigationItem.titleView = searchBar
        
        DispatchQueue.main.async {
            self.searchBar.searchTextField.becomeFirstResponder()
        }
        let appearance = UINavigationBarAppearance()
        appearance.backgroundColor = self.appearance.backgroundColor
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }
    
    // MARK: Title
    
    open func updateTitle() {
        showTitle(
            title: channelViewModel.title,
            subTitle: channelViewModel.subTitle
        )
        var appearance = channelViewModel.channel.appearance
        appearance?.size = .init(width: 36, height: 36)
        avatarTask = Components.avatarBuilder.loadAvatar(
            into: titleView.profileImageView,
            for: channelViewModel.channel,
            appearance: appearance
        )
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
           titleView.mode == .typing {
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
        hud.isLoading = true
        channelViewModel.join { [weak self] error in
            hud.isLoading = false
            guard let self = self else { return }
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
        if let userSelectOnRepliedMessage {
            showRepliedMessage(userSelectOnRepliedMessage)
            self.userSelectOnRepliedMessage = nil
        } else {
            scrollToBottom()
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
    
    //MARK: Gesture actions
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
    
    @objc
    public func handleTapGestureRecognizer(_ sender: UITapGestureRecognizer) {
        guard sender.state == .recognized
        else { return }
        if let cell = collectionView.findCell(forGesture: sender) as? MessageCell {
            if !cell.handleTap(sender: sender) {
                viewTapped(gesture: sender)
            }
        } else {
            viewTapped(gesture: sender)
        }
    }
    
    @objc
    public func handleLongPressGestureRecognizer(_ sender: UILongPressGestureRecognizer) {
        guard !channelViewModel.isEditing, !composerVC.isRecording
        else { return }
        
        func reset() {
            sender.isEnabled = false
            sender.isEnabled = true
        }
        
        switch sender.state {
        case .began:
            guard let cell = collectionView.findCell(forGesture: sender) as? MessageCell
            else {
                reset()
                return
            }
            longPressItem = cell.handleLongPress(sender: sender)
        case .changed:
            longPressItem?.cell?.handleLongPress(sender: sender)
        case .ended, .failed, .cancelled, .possible:
            longPressItem?.cell?.handleLongPress(sender: sender)
            reset()
            longPressItem = nil
        default:
            break
        }
    }
    
    private var panningCell: MessageCell?
    @objc
    open func handlePanGestureRecognizer(_ sender: UIPanGestureRecognizer) {
        if channelViewModel.isReadOnlyChannel {
            return
        }
        if let panningCell {
            if channelViewModel.canReply(model: panningCell.data) {
                panningCell.handlePan(sender)
            }
            if [.cancelled, .recognized].contains(sender.state) {
                self.panningCell = nil
            }
        } else if let cell = collectionView.findCell(forGesture: sender) as? MessageCell {
            panningCell = cell
            if channelViewModel.canReply(model: cell.data) {
                cell.handlePan(sender)
            }
        }
    }
    
    open func select(layoutModel: MessageLayoutModel) {
        channelViewModel.isEditing = true
        channelViewModel.selectedMessages = [layoutModel]
//        if let indexPath = channelViewModel.indexPaths(for: [model.message]).first?.value {
//            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
//        }
    }
    
    @objc
    open func cancelSelecting() {
        channelViewModel.isEditing = false
    }
    
    open func showShareSelectedMessages() {
        channelViewModel.isEditing = false
        var items = [Any]()
        channelViewModel.selectedMessages.sorted().forEach {
            let message = $0.message
            guard let user = message.user
            else { return }
            let body = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty {
                items.append("\(Formatters.userDisplayName.format(user)) [\(Formatters.attachmentTimestamp.format(message.createdAt))]\n\(body)")
            }
            items += message.attachments?.compactMap { 
                if $0.type == "link" {
                    return nil
                }
                return $0.fileUrl ?? $0.originUrl
            } ?? []
        }
        if !items.isEmpty {
            router.share(items, from: self)
        }
    }
    
    open func showForwardSelectedMessages() {
        channelViewModel.isEditing = false
        let messages = channelViewModel.selectedMessages.sorted().map { $0.message }
        forward(messages: messages)
    }
    
    open func forward(messages: [ChatMessage]) {
        guard !composerVC.isRecording else {
            return showRecordDiscardAlertIfNeeded()
        }
        router.showForward { [weak self] channels in
            guard let self else { return }
            hud.show()
            self.channelViewModel.share(messages: messages, to: channels.map { $0.id }) { [weak self] in
                guard let self else { return }
                if channels.contains(self.channelViewModel.channel) {
                    self.collectionView.scrollToBottom(animated: false) { _ in }
                } else if channels.count == 1 {
                    ChannelListRouter.showChannel(channels[0])
                }
                self.router.dismiss()
                hud.hide()
            }
        }
    }
    
    // MARK: UIGestureRecognizer delegate
    
    open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panGestureRecognizer {
            let translation = panGestureRecognizer.translation(in: collectionView)
            if abs(translation.y) > 0 {
                // ignore vertical panning
                return false
            }
            if channelViewModel.isEditing {
                return false
            }
        }
        return true
    }
    
    open func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        if gestureRecognizer === navigationController?.interactivePopGestureRecognizer ||
            !(gestureRecognizer is UITapGestureRecognizer)
        {
            return true
        }
        guard !(touch.view is ChannelUnreadCountView)
        else { return false }
        guard !(touch.view?.tag == 999)
        else { return false }
        guard !(touch.view is MessageCell.LinkView)
        else { return false }
        guard !(touch.view is MessageCell.ReplyView)
        else { return false }
        guard !(touch.view is MessageCell.ReactionTotalView)
        else { return false }
        guard !(touch.view is MessageCell.ReactionView)
        else { return false }
        if channelViewModel.isEditing {
            return false
        }
        return composerVC.presentedMentionUserListVC?.parent == nil
    }
    
    @discardableResult
    open func addMoreMessage(scrollDirection: ScrollDirection, force: Bool = false) -> IndexPath? {
        guard !isCollectionViewUpdating,
              isStartedDragging
        else { return nil }
        switch scrollDirection {
        case .up:
            let indexPath = collectionView.indexPathsForVisibleItems.min()
            if let indexPath, force || collectionView.contentOffset.y < 500 {
                loadPrevMessages(beforeMessageAt: indexPath)
            }
            return indexPath
        case .down:
            let indexPathsForVisibleItems = collectionView.indexPathsForVisibleItems
            guard !indexPathsForVisibleItems.isEmpty
            else { return nil }
            if let indexPath = indexPathsForVisibleItems.max() {
                loadNextMessages(afterMessageAt: indexPath)
                return indexPath
            }
        default:
            break
        }
        return nil
    }
    
    open func syncVisibleMessageAfterConnect() {
        if let indexPath = collectionView.indexPathsForVisibleItems.min() {
            channelViewModel.loadNextMessages(afterMessageAt: indexPath)
        }
    }
    
    open func loadPrevMessages(beforeMessageAt indexPath: IndexPath) {
        channelViewModel.loadPrevMessages(beforeMessageAt: indexPath)
    }
    
    open func loadNextMessages(afterMessageAt indexPath: IndexPath) {
        channelViewModel.loadNextMessages(afterMessageAt: indexPath)
    }
    
    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isStartedDragging = true
    }
    
    open func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        self.scrollDirection = self.scrollDirectionForVelocity(scrollView.panGestureRecognizer.velocity(in: scrollView))
        self.addMoreMessage(scrollDirection: self.scrollDirection, force: true)
    }
    
    open func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        scrollDirection = scrollDirectionForVelocity(scrollView.panGestureRecognizer.velocity(in: scrollView))
    }
    
    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if let userSelectOnRepliedMessage,
            !collectionView.visibleCells.contains(where: { ($0 as? MessageCell)?.data.message.id == userSelectOnRepliedMessage.id }) {
            self.userSelectOnRepliedMessage = nil
        }
        
        if lastScrollDirection == .down,
           let indexPath = addMoreMessage(scrollDirection: lastScrollDirection, force: true) {
            RunLoop.current.perform { [weak self] in
                self?.loadNextMessages(afterMessageAt: indexPath)
            }
        }
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if let lastAnimatedIndexPath, !isCollectionViewUpdating {
            if !self.isCollectionViewUpdating {
//                self.channelViewModel.loadNearMessages(arMessageAt: lastAnimatedIndexPath)
            }
        }
    }
    
    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if let userSelectOnRepliedMessage,
            !collectionView.visibleCells.contains(where: { ($0 as? MessageCell)?.data.message.id == userSelectOnRepliedMessage.id }) {
            self.userSelectOnRepliedMessage = nil
        }
    }
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateUnreadViewVisibility()
        updateLastNavigatedIndexPath()
        updatePinnedHeaderVisibility()
    }
    
    open func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        isStartedDragging = true
        addMoreMessage(scrollDirection: .up, force: true)
    }
    
    open func scrollDirectionForVelocity(_ velocity: CGPoint) -> ScrollDirection {
        if velocity.y < 0 {
            return .down
        } else if velocity.y > 0 {
            return .up
        }
        return .none
    }
    
    open func scrollToBottom(animated: Bool = true, duration: CGFloat = 0.22) {
        guard isAppActive else { return }
        isStartedDragging = true
        isScrollingBottom = true
        collectionView.scrollToBottom(animated: animated) { [weak self] _ in
            self?.isScrollingBottom = false
        }
    }
    
    open func updateUnreadViewVisibility() {
        if isScrollingBottom {
            unreadCountView.isHidden = true
            return
        }
        guard !collectionView.indexPathsForVisibleItems.isEmpty,
              let lastAttributesFrame = collectionView.lastVisibleAttributes?.frame
        else {
            unreadCountView.isHidden = true
            return
        }
        if round(lastAttributesFrame.maxY) >= round(collectionView.safeContentSize.height - collectionView.contentInset.top - layout.sectionInset.top) {
            unreadCountView.isHidden = true
        } else {
            unreadCountView.isHidden = composerVC.isRecording
        }
    }
    
    open func updateLastNavigatedIndexPath() {
        let currentOffset = round(collectionView.contentOffset.y + collectionView.frame.height)
        let bottomOffset = round(collectionView.contentSize.height + collectionView.contentInset.bottom)
        if currentOffset == bottomOffset {
            channelViewModel.clearLastNavigatedIndexPath()
        }
    }
    
    open func updatePinnedHeaderVisibility() {
        guard collectionView.isDragging || collectionView.isDecelerating
        else { return }
        if let scrollTimer, scrollTimer.isValid {
            scrollTimer.invalidate()
        }
        setSectionHeadersPinToVisibleBounds(true)
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false, block: { [weak self] _ in
            guard let self else { return }
            self.setSectionHeadersPinToVisibleBounds(false)
        })
    }
    
    open func setSectionHeadersPinToVisibleBounds(_ show: Bool) {
        if layout.sectionHeadersPinToVisibleBounds != show {
            let context = UICollectionViewFlowLayoutInvalidationContext()
            layout.sectionHeadersPinToVisibleBounds = show
            layout.invalidateLayout(with: context)
        }
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
//        guard isViewDidAppear
//        else { return }
//        guard let cell = cell as? MessageCell,
//              let model = cell.data
//        else { return }
//
//        if isStartedDragging {
////            channelViewModel.markMessageAsDisplayed([model.message])
//        }
        
        guard shouldAnimateEditing, let cell = cell as? MessageCell
        else { return }
        if cell.isEditing, cell.checkBoxView.transform != .identity {
            cell.contentView.alpha = 1
            UIView.animate(withDuration: 0.3) { [weak self] in
                guard let self else { return }
                cell.checkBoxView.transform = .identity
                cell.containerView.transform = .identity
                cell.contentView.alpha = self.channelViewModel.canSelectMessage(at: indexPath) ? 1 : 0.5
            }
        }
    }
    
    // MARK: UICollectionViewDataSource
    
    open func numberOfSections(in collectionView: UICollectionView) -> Int {
        let s = channelViewModel.numberOfSections
        return s
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        let ns = channelViewModel.numberOfMessages(in: section)
        return ns
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        
        guard let model = channelViewModel.layoutModel(at: indexPath) ?? channelViewModel.createLayoutModels(at: [indexPath]).first
        else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Components.incomingMessageCell.reuseId, for: indexPath)
            return cell
        }
        return cellForItemAt(indexPath: indexPath, collectionView: collectionView, model: model)
    }
    
    open func cellForItemAt(
        indexPath: IndexPath,
        collectionView: UICollectionView,
        model: MessageLayoutModel
    ) -> UICollectionViewCell {
        print("Section: \(indexPath.section), row: \(indexPath.row)")
        let message = model.message
        let type: MessageCell.Type =
        model.message.incoming ?
        Components.incomingMessageCell :
        Components.outgoingMessageCell
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: type)
        cell.isEditing = channelViewModel.isEditing
        if cell.isEditing {
            cell.contentView.alpha = channelViewModel.canSelectMessage(at: indexPath) ? 1 : 0.5
        } else {
            cell.contentView.alpha = 1
        }
        if cell.isEditing, shouldAnimateEditing {
            let checkBoxSize = MessageCell.Layouts.checkBoxSize + 2 * MessageCell.Layouts.checkBoxPadding
            cell.checkBoxView.transform = .init(translationX: -checkBoxSize, y: 0)
            if message.incoming {
                cell.containerView.transform = .init(translationX: -checkBoxSize, y: 0)
            } else {
                cell.containerView.transform = .identity
            }
        } else {
            cell.checkBoxView.transform = .identity
            cell.containerView.transform = .identity
        }
        cell.checkBoxView.isSelected = channelViewModel.selectedMessages.contains(model)
        cell.data = model
        if message.id == selectMessageId {
            cell.hightlightMode = .search
        } else if cell.hightlightMode == .search {
            cell.hightlightMode = .none
        }
        cell.previewer = { [weak self] in
            guard let self
            else { return nil }
            if self.channelViewModel.previewer.delegate == nil {
                self.channelViewModel.previewer.delegate = self
            }
            return self.channelViewModel.previewer
        }
        cell.onAction = { [weak self] action in
            guard let self else { return }
            
            self.isStartedDragging = true
            
            switch action {
            case .editMessage:
                self.edit(layoutModel: model)
            case .deleteMessage:
                self.delete(layoutModel: model)
            case .showThread:
                self.reply(layoutModel: model, in: true)
            case .showReply:
                self.showReply(layoutModel: model)
            case .tapReaction:
                self.tapReaction(layoutModel: model)
            case .addReaction:
                self.addReaction(layoutModel: model)
            case .deleteReaction(let key):
                self.deleteReaction(layoutModel: model, reaction: key)
            case .updateReactionScore(let key, let score, let add):
                self.updateReaction(layoutModel: model, reaction: key, score: UInt16(score), add: add)
            case .selectMentionedUser:
                break
            case .selectAttachment(let index):
                if let attachments = message.attachments,
                   index < attachments.count,
                   attachments[index].type == "file" {
                    self.showAttachment(attachments[index])
                }
            case .pauseTransfer(let message, let attachment):
                self.channelViewModel.stopFileTransfer(message: message, attachment: attachment)
            case .resumeTransfer(let message, let attachment):
                self.channelViewModel.resumeFileTransfer(message: message, attachment: attachment)
            case .openUrl(let url):
                self.showLink(url)
            case .playAtUrl(let url):
                self.router.playFrom(url: url)
            case .didTapLink(let link):
                self.showLink(link)
            case .didLongPressLink(let link):
                self.router
                    .showLinkAlert(
                        link,
                        actions: [(L10n.Link.openIn, .default), (L10n.Link.copy, .default)])
                { [weak self] actionTitle in
                    if actionTitle == L10n.Link.openIn {
                        self?.showLink(link)
                    } else if actionTitle == L10n.Link.copy {
                        UIPasteboard.general.string = link.absoluteString
                    }
                }
            case .didTapAvatar:
                self.didSelectAvatar(layoutModel: model)
            case .didTapMentionUser(let userId):
                self.didSelectMentionUser(userId: userId, layoutModel: model)
            case .didSwipe:
                self.reply(layoutModel: model, in: false)
            }
            
        }
        cell.contextMenu = contextMenu
        channelViewModel.downloadMessageAttachmentsIfNeeded(layoutModel: model)
        return cell
    }
    
    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard channelViewModel.canSelectMessage(at: indexPath)
        else { return }
        channelViewModel.didChangeSelection(for: indexPath)
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let cell = collectionView.dequeueReusableSupplementaryView(
            for: indexPath,
            cellType: Components.messageSectionSeparatorView.self,
            kind: .header
        )
        cell.date = channelViewModel.separatorDateForMessage(at: indexPath)
        return cell
    }
    
    // MARK: ChannelCollectionViewLayoutDelegate
    
    open func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = collectionView.bounds.width
        if let lm = channelViewModel.layoutModel(at: indexPath) {
            return CGSize(width: width, height: lm.measureSize.height)
        }
        return CGSize(width: width, height: 33)
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
//        if collectionView.numberOfSections - 1 == section {
//            return .init(top: 8, left: 0, bottom: 0, right: 0)
//        }
//        return .init(top: 8, left: 0, bottom: 8, right: 0)
        .zero
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        0
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int
    ) -> CGFloat {
        0
    }

    open func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        let width = collectionView.bounds.width
        return CGSize(width: width, height: 40)
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForFooterInSection section: Int
    ) -> CGSize {
        .zero
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
            attachments: mediaView.items,
            linkMetadata: composerVC.lastDetectedLinkMetadata
        )
        if let ma = channelViewModel.selectedMessageForAction {
            switch ma {
            case (let message, .reply):
                m.action = .reply(message)
            case (let message, .edit):
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
        if channelViewModel.selectedMessageForAction == nil ||
            channelViewModel.selectedMessageForAction?.1 == .reply {
            UIView.animate(withDuration: 0.25) { [weak self] in
                self?.view.layoutIfNeeded()
            }
            isScrollingBottom = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.scrollToBottom(animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    self?.unreadCountView.isHidden = true
                }
            }
        }
        composerVC.removeActionView()
        channelViewModel.removeSelectedMessage()
    }
    
    open func info(layoutModel: MessageLayoutModel) {
        router.showMessageInfo(layoutModel: layoutModel)
    }
    
    open func report(layoutModel: MessageLayoutModel) {
        channelViewModel.report(layoutModel: layoutModel)
    }
    
    open func edit(layoutModel: MessageLayoutModel) {
        composerVC.addEdit(layoutModel: layoutModel)
        inputTextView.attributedText = layoutModel.attributedView.content
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.inputTextView.becomeFirstResponder()
            self?.view.layoutIfNeeded()
        }
    }
    
    open func reply(
        layoutModel: MessageLayoutModel,
        in thread: Bool
    ) {
        if !thread {
            UIView.animate(withDuration: 0.25) { [weak self] in
                guard let self else { return }
                self.inputTextView.becomeFirstResponder()
                self.view.layoutIfNeeded()
            } completion: { [weak self] _ in
                guard let self else { return }
                self.composerVC.addReply(layoutModel: layoutModel)
            }
        } else {
            showThreadForMessage(layoutModel.message)
        }
    }
    
    open func delete(
        layoutModel: MessageLayoutModel,
        forMeOnly: Bool = false
    ) {
        channelViewModel.deleteMessage(
            layoutModel: layoutModel,
            forMeOnly: forMeOnly
        )
    }
    
    open func tapReaction(layoutModel: MessageLayoutModel) {
        router.showReactions(
            message: layoutModel.message
        ).onEvent = { [weak self] event in
            switch event {
            case .removeReaction(let reaction):
                if self?.channelViewModel.canDeleteReaction(message: layoutModel.message, key: reaction.key) == true {
                    self?.presentedViewController?.dismiss(animated: true) { [weak self] in
                        self?.deleteReaction(layoutModel: layoutModel, reaction: reaction.key)
                    }
                }
            }
        }
    }
    
    open func addReaction(layoutModel: MessageLayoutModel) {
        router.showEmojis()
            .onEvent = { [weak self] emoji in
                self?.channelViewModel.addReaction(
                    layoutModel: layoutModel,
                    key: emoji.key
                )
            }
    }
    
    open func deleteReaction(
        layoutModel: MessageLayoutModel,
        reaction key: String
    ) {
        channelViewModel.deleteReaction(
            layoutModel: layoutModel,
            key: key
        )
    }
    
    open func updateReaction(
        layoutModel: MessageLayoutModel,
        reaction key: String,
        score: UInt16,
        add: Bool
    ) {
        if add {
            channelViewModel.addReaction(
                layoutModel: layoutModel,
                key: key,
                score: score
            )
        } else {
            channelViewModel.deleteReaction(
                layoutModel: layoutModel,
                key: key
            )
        }
    }
    
    open func showLink(_ link: URL) {
        router.showLink(link)
    }
    
    open func didSelectAvatar(layoutModel: MessageLayoutModel) {
        showProfile(user: layoutModel.message.user)
    }
    
    open func didSelectMentionUser(userId: UserId, layoutModel: MessageLayoutModel) {
        if let user = layoutModel.message.mentionedUsers?.first(where: { $0.id == userId}) {
            showProfile(user: user)
        } else {
            channelViewModel.user(id: userId) {[weak self] user in
                self?.showProfile(user: user)
            }
        }
        
    }
    
    open func showProfile(user: ChatUser) {
        logger.debug("showProfile for \(user.id)")
        channelViewModel.directChannel(user: user) { [weak self] channel, error in
            guard let self else { return }
            if let channel {
                self.router.showChannelProfileVC(channel: channel)
            } else if let error {
                self.showAlert(error: error)
            }
        }
    }
    
    open func copy(layoutModel: MessageLayoutModel) {
        do {
            try UIPasteboard.general.set(layoutModel.attributedView.content)
        } catch {
            UIPasteboard.general.string = layoutModel.message.body
        }
    }
    
    open func showReply(layoutModel: MessageLayoutModel) {
        guard let parent = layoutModel.message.parent
        else { return }
        userSelectOnRepliedMessage = layoutModel.message
        channelViewModel.findReplayedMessage(id: parent.id)
    }
    
    open func showRepliedMessage(_ message: ChatMessage) {
        let paths = channelViewModel.indexPaths(for: [message])
        guard let indexPath = paths.values.first else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            UIView.animate(withDuration: 0.3, delay: 0, options: .allowUserInteraction) { [weak self] in
                guard let self else { return }
                self.collectionView.scrollToItem(at: indexPath, pos: .centeredVertically, animated: false)
            } completion: { [weak self] _ in
                guard let self else { return }
                if let cell = self.collectionView.cellForItem(at: indexPath) as? MessageCell {
                    self.highlightCell(cell)
                }
            }
        }
    }
    
    open func highlightCell(_ cell: MessageCell) {
        UIView.animate(withDuration: highlightedDurationForReplyMessage) { [weak cell] in
            cell?.hightlightMode = .reply
            cell?.hightlightMode = .none
        }
    }
    
    open func showThreadForMessage(_ message: ChatMessage) {
        router.showThreadForMessage(message)
    }
    
    open func showAttachment(_ attachment: ChatMessage.Attachment) {
        router.showAttachment(attachment)
    }
    
    open func markMessageAsDisplayed() {
        guard isViewDidAppear
        else { return }
        channelViewModel.markMessageAsDisplayed(indexPaths: collectionView.indexPathsForVisibleItems)
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
            let continuesOptions = paths.continuesOptions
            var needsToScrollBottom = false
            if !noDataView.isHidden {
                showEmptyViewIfNeeded()
            }
            if let unreadMessageIndexPath, checkOnlyFirstTimeReceivedMessagesFromArchive {
                checkOnlyFirstTimeReceivedMessagesFromArchive = false
                if inserts.count == 1,
                   collectionView.lastIndexPath == collectionView.lastVisibleIndexPath {
                    isStartedDragging = true
                } else {
                    collectionView.reloadDataAndScrollTo(indexPath: unreadMessageIndexPath)
                    return
                }
            }
            
            if checkOnlyFirstTimeReceivedMessagesFromArchive, !isViewDidAppear {
                checkOnlyFirstTimeReceivedMessagesFromArchive = false
                layout.isInsertingItemsToTop = false
                collectionView.reloadDataAndScrollToBottom()
                return
            }
            
            if continuesOptions.isEmpty || continuesOptions.contains(.top) || continuesOptions.contains(.middle) {
                layout.isInsertingItemsToTop = true
            } else {
                layout.isInsertingItemsToTop = false
            }
//            var animatedScroll = inserts.count == 1
//            if isScrollingBottom {
//                needsToScrollBottom = true
//                animatedScroll = true
//            } else if paths.numberOfIndexPaths == 1 &&
//                        (!paths.reloads.isEmpty || !paths.inserts.isEmpty),
//                      let lastIndexPath = collectionView.lastIndexPath,
//                      collectionView.lastVisibleIndexPath == lastIndexPath {
//                isStartedDragging = true
//                var isReloadLastIndexPath: Bool {
//                    guard let last = paths.reloads.last else { return false }
//                    return last >= lastIndexPath
//                }
//                var isInsertLastIndexPath: Bool {
//                    guard let last = paths.inserts.last else { return false }
//                    return last >= lastIndexPath
//                }
//                if isReloadLastIndexPath || isInsertLastIndexPath {
//                    needsToScrollBottom = true
//                    animatedScroll = true
//                } else {
//                    needsToScrollBottom = false
//                }
//            }
            
            var isInsertLastIndexPath: Bool {
                guard let last = paths.inserts.last, 
                        let lastIndexPath = collectionView.lastIndexPath
                else { return false }
                return last >= lastIndexPath
            }
            var animatedScroll = inserts.count == 1
            if isScrollingBottom {
                needsToScrollBottom = true
                animatedScroll = true
            } else if unreadCountView.isHidden {
                isStartedDragging = true
                needsToScrollBottom = isInsertLastIndexPath
                animatedScroll = isInsertLastIndexPath
            } else {
                needsToScrollBottom = false
            }
                        
            if userSelectOnRepliedMessage != nil || unreadMessageIndexPath != nil {
                needsToScrollBottom = false
            }
            
            UIView.performWithoutAnimation {
                isCollectionViewUpdating = true
                collectionView.performBatchUpdates {
                    if !sectionInserts.isEmpty {
                        collectionView.insertSections(sectionInserts)
                    }
                    if !sectionDeletes.isEmpty {
                        collectionView.deleteSections(sectionDeletes)
                    }
                    collectionView.insertItems(at: inserts)
                    collectionView.reloadItems(at: reloads)
                    collectionView.deleteItems(at: deletes)
                    moves.forEach { from, to in
                        collectionView.moveItem(at: from, to: to)
                    }
                    logger.debug("[isCollectionViewUpdating] \(isCollectionViewUpdating) start")
                } completion: { [weak self] _ in
                    var scrollBottom = false
                    defer {
                        logger.debug("[isCollectionViewUpdating] \(self?.isCollectionViewUpdating) end")
                        if let self = self {
                            self.isCollectionViewUpdating = false
                            if scrollBottom {
                                self.scrollToBottom(animated: animatedScroll)
                            }
                        }
                    }
                    guard let self = self else { return }
                    UIView.performWithoutAnimation {
                        let reloads = paths.reloads + moves.map(\.to)
                        if !reloads.isEmpty {
                            self.collectionView.performBatchUpdates {
                                self.collectionView.reloadItems(at: reloads)
                            }
                        }
                    }
                    
                    if needsToScrollBottom, !(self.collectionView.isDragging || self.collectionView.isDecelerating) {
                        scrollBottom = true
                    } else {
                        self.updateUnreadViewVisibility()
                    }
                }
            }
            
        case .updateDeliveryStatus(let model, let indexPath):
            if let cell = collectionView.cell(for: indexPath, cellType: MessageCell.self),
               cell.data?.message.id == model.message.id {
                cell.deliveryStatus = model.messageDeliveryStatus
            } else {
                NotificationCenter.default.post(name: .didUpdateDeliveryStatus, object: model)
            }
        case .reloadData:
            collectionView.reloadData()
        case .reload(let indexPath):
            UIView.performWithoutAnimation {
                collectionView.performBatchUpdates {
                    collectionView.reloadItems(at: [indexPath])
                }
            }
            needToMarkMessageAsDisplayed = true
            collectionView.reloadData()
        case .reloadDataAndScrollToBottom:
            needToMarkMessageAsDisplayed = true
            collectionView.reloadDataAndScrollToBottom()
        case .reloadDataAndScroll(let indexPath):
            needToMarkMessageAsDisplayed = true
            collectionView.reloadDataAndScrollTo(indexPath: indexPath)
        case .didSetUnreadIndexPath(let indexPath):
            unreadMessageIndexPath = indexPath
        case .typing(let isTyping, let user):
            if channelViewModel.channel.isGroup {
                if showTyping(member: Formatters.userDisplayName.format(user),
                              isTyping: isTyping) == 0 {
                    updateTitle()
                }
            } else {
                if isTyping {
                    _ = showTyping(
                        member: channelViewModel.channel.channelType == .direct ? "" : Formatters.userDisplayName.format(user),
                        isTyping: isTyping
                    )
                } else {
                    updateTitle()
                }
            }
        case .changePresence(let presence):
            RunLoop.main.perform { [weak self] in
                guard let self
                else { return }
                let mode = self.titleView.mode
                let change = Formatters.userPresenceFormatter.format(presence)
                self.showTitle(title: self.channelViewModel.title, subTitle: change)
                if mode == .typing {
                    self.titleView.mode = mode
                }
            }
            
        case .updateChannel:
            updateTitle()
            updateJoinButtonVisibility()
            showBottomViewIfNeeded()
        case .showNoMessage:
            showEmptyViewIfNeeded()
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
                syncVisibleMessageAfterConnect()
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
        case let .scrollAndSelect(indexPath, messageId):
            selectMessageId = messageId
            self.lastAnimatedIndexPath = indexPath
            logger.debug("[isCollectionViewUpdating] \(isCollectionViewUpdating) scroll")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                logger.debug("[isCollectionViewUpdating] \(self.isCollectionViewUpdating) scroll2")
            }
            self.collectionView.scrollToItem(at: indexPath, pos: .centeredVertically, animated: true)
            NotificationCenter.default.post(name: .selectMessage, object: messageId)
        case .resetSearchResultHighlight(let indexPath):
            break
//            if let cell = collectionView.cellForItem(at: indexPath) as? MessageCell {
//                UIView.animate(withDuration: highlightedDurationForSearchMessage) {
//                    cell.hightlightMode = .none
//                }
//            }
        }
    }
    
    open func showEmptyViewIfNeeded() {
        noDataView.isHidden = (channelViewModel.channel.channelType == .broadcast && channelViewModel.channel.userRole == Config.chatRoleOwner) || channelViewModel.numberOfSections > 0
        createdView.isHidden = channelViewModel.channel.channelType != .broadcast || channelViewModel.numberOfSections > 0 || channelViewModel.channel.userRole != Config.chatRoleOwner
    }
    
    open func showBottomViewIfNeeded() {
        var icon: UIImage?
        var message: String?
        if channelViewModel.isDeletedUser {
            icon = .warning
            message = L10n.Channel.DeletedUser.message
        } else if channelViewModel.isReadOnlyChannel,
           !channelViewModel.isUnsubscribedChannel {
            icon = .eye
            message = L10n.Channel.ReadOnly.message
        } else if channelViewModel.isBlocked {
            icon = .warning
            message = L10n.Channel.BlockedUser.message
        }
        if let icon, let message {
            view.endEditing(true)
            coverView.addSubview(bottomView)
            bottomView.pin(to: composerVC.view, anchors: [.leading, .top, .trailing, .bottom])
            bottomView.icon = icon
            bottomView.message = message
            composerVC.shouldHideRecordButton = true
            composerVC.addMediaButton.isHidden = true
            composerVC.sendButton.isHidden = true
            composerVC.recordButton.isHidden = true
            composerVC.mediaView.isHidden = true
            composerVC.actionView.isHidden = true
        } else {
            bottomView.removeFromSuperview()
            composerVC.shouldHideRecordButton = false
            composerVC.addMediaButton.isHidden = false
            composerVC.updateState()
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
    
    private var isShowingRecordDiscardAlert = false
    open func showRecordDiscardAlertIfNeeded() {
        guard composerVC.isRecording,
              !isShowingRecordDiscardAlert
        else { return }
        
        isShowingRecordDiscardAlert = true
        router.showAlert(
            message: L10n.Channel.StopRecording.message,
            actions: [
                .init(title: L10n.Alert.Button.cancel, style: .cancel) { [weak self] in
                    self?.isShowingRecordDiscardAlert = false
                },
                .init(title: L10n.Alert.Button.discard, style: .default) { [weak self] in
                    self?.composerVC.recorderView.stopAndPreview()
                    self?.isShowingRecordDiscardAlert = false
                }
            ],
            preferredActionIndex: 1
        )
    }
    
    // MARK: ContextMenuDataSource
    
    open func canShow(contextMenu: ContextMenu, identifier: Identifier) -> Bool {
        guard let model = identifier.value as? MessageLayoutModel,
              model.message.state != .deleted
        else { return false }
        return true
    }
    
    open func canShowEmojis(contextMenu: ContextMenu, identifier: Identifier) -> Bool {
        guard let model = identifier.value as? MessageLayoutModel
        else { return false }
        return ![.pending, .failed].contains(model.message.deliveryStatus)
    }
    
    open func emojis(contextMenu: ContextMenu, identifier: Identifier) -> [String] {
        return channelViewModel.emojis(identifier: identifier)
    }
    
    open func showPlusAfterEmojis(contextMenu: ContextMenu, identifier: Identifier) -> Bool {
        return channelViewModel.showPlusAfterEmojis(identifier: identifier)
    }
    
    open func selectedEmojis(contextMenu: ContextMenu, identifier: Identifier) -> [String] {
        return channelViewModel.selectedEmojis(identifier: identifier)
    }
    
    open func items(contextMenu: ContextMenu, identifier: Identifier) -> [MenuItem] {
        guard let model = identifier.value as? MessageLayoutModel,
              model.message.state != .deleted
        else { return [] }
        
        var items: [MenuItem] = []
        if channelViewModel.canShowInfo(model: model) {
            items += [
                .init(
                    title: L10n.Message.Action.Title.info,
                    image: .messageActionInfo,
                    imageRenderingMode: .alwaysTemplate,
                    action: { [weak self] _ in
                        self?.info(layoutModel: model)
                    }
                )
            ]
        }
        if channelViewModel.canEdit(model: model) {
            items += [
                .init(
                    title: L10n.Message.Action.Title.edit,
                    image: .messageActionEdit,
                    imageRenderingMode: .alwaysTemplate,
                    action: { [weak self] _ in
                        self?.edit(layoutModel: model)
                    }
                )
            ]
        }
        if !channelViewModel.isReadOnlyChannel {
            items += [
                .init(
                    title: L10n.Message.Action.Title.reply,
                    image: .messageActionReply,
                    imageRenderingMode: .alwaysTemplate,
                    action: { [weak self] _ in
                        self?.reply(layoutModel: model, in: false)
                    }
                ),
//                .init(
//                    title: L10n.Message.Action.Title.replyInThread,
//                    image: .messageActionReplyInThread,
//                    imageRenderingMode: .alwaysTemplate,
//                    action: { [weak self] _ in
//                        self?.reply(layoutModel: model, in: true)
//                    }
//                )
            ]
        }
        
        items += [
            .init(
                title: L10n.Message.Action.Title.forward,
                image: .messageActionForward,
                imageRenderingMode: .alwaysTemplate,
                action: { [weak self] _ in
                    self?.forward(messages: [model.message])
                }
            ),
            .init(
                title: L10n.Message.Action.Title.copy,
                image: .messageActionCopy,
                imageRenderingMode: .alwaysTemplate,
                action: { [weak self] _ in
                    self?.copy(layoutModel: model)
                }
            )]
//        if channelViewModel.canReport(model: model) {
//            items += [
//                .init(
//                    title: L10n.Message.Action.Title.report,
//                    image: .messageActionReport,
//                    imageRenderingMode: .alwaysTemplate,
//                    action: { [weak self] _ in
//                        self?.report(layoutModel: model)
//                    }
//                )
//            ]
//        }
        if !channelViewModel.isReadOnlyChannel {
            items += [
                .init(
                    title: L10n.Message.Action.Title.select,
                    image: .messageActionSelect,
                    imageRenderingMode: .alwaysTemplate,
                    action: { [weak self] _ in
                        self?.select(layoutModel: model)
                    }
                )
            ]
        }
        if channelViewModel.canDelete(model: model) {
            items.append(
                .init(
                    title: L10n.Message.Action.Title.delete,
                    image: .messageActionDelete,
                    destructive: true,
                    dismissOnAction: false,
                    action: { [weak self] _ in
                        contextMenu.actionController?.emojiController.view.isHidden = true
                        contextMenu.reload(items: [
                            .init(
                                title: L10n.Message.Action.Subtitle.deleteAll,
                                image: .messageActionDelete,
                                destructive: true,
                                action: { [weak self] _ in
//                                    self?.router.showConfirmationAlertForDeleteMessage {
//                                        if $0 {
                                            self?.delete(layoutModel: model, forMeOnly: false)
//                                        }
//                                    }
                                }
                            ),
                            
                                .init(
                                    title: L10n.Message.Action.Subtitle.deleteMe,
                                    image: .messageActionDelete,
                                    destructive: true,
                                    action: { [weak self] _ in
//                                        self?.router.showConfirmationAlertForDeleteMessage {
//                                            if $0 {
                                                self?.delete(layoutModel: model, forMeOnly: true)
//                                            }
//                                        }
                                    }
                                )
                        ])
                    }
                )
            )
        }
        
        return items
    }
    
    // MARK: ContextMenuDelegate
    
    open func didSelect(emoji: String, forViewWith identifier: Identifier) {
        if let model = identifier.value as? MessageLayoutModel {
            channelViewModel.addReaction(layoutModel: model, key: emoji)
        }
    }
    
    open func didDeselect(emoji: String, forViewWith identifier: Identifier) {
        if let model = identifier.value as? MessageLayoutModel {
            channelViewModel.deleteReaction(layoutModel: model, key: emoji)
        }
    }
    
    open func didSelectMoreAction(forViewWith identifier: Identifier) {
        if let model = identifier.value as? MessageLayoutModel {
            addReaction(layoutModel: model)
        }
    }
    
    // MARK: ContextMenuSnapshotDelegate
    
    open func willMakeSnapshot(forViewWith identifier: Identifier) {
        if #unavailable(iOS 16) {
            if let model = identifier.value as? MessageLayoutModel,
               let snapshotProving = collectionView.visibleCells.first(where: { ($0 as? MessageCell)?.data.message == model.message }) as? ContextMenuSnapshotProviding
            {
                snapshotProving.onPrepareSnapshot()
            }
        }
    }
    
    open func didMakeSnapshot(forViewWith identifier: Identifier) {
        if #unavailable(iOS 16) {
            if let model = identifier.value as? MessageLayoutModel,
               let snapshotProving = collectionView.visibleCells.first(where: { ($0 as? MessageCell)?.data.message == model.message }) as? ContextMenuSnapshotProviding
            {
                snapshotProving.onFinishSnapshot()
            }
        }
    }
    
    deinit {
        SimpleSinglePlayer.stop()
        avatarTask?.cancel()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
    
    open func didStartVoiceRecording() {
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        updateUnreadViewVisibility()
    }
    
    open func didStopVoiceRecording() {
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        updateUnreadViewVisibility()
    }
    
    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if composerVC.isRecording {
            if view.window?.windowScene?.interfaceOrientation.isLandscape == true {
                return [.landscapeLeft, .landscapeRight]
            } else {
                return .portrait
            }
        }
        return .allButUpsideDown
    }
    
    @objc
    open func canShowPreviewer() -> Bool {
        if composerVC.isRecording {
            showRecordDiscardAlertIfNeeded()
            return false
        } else {
            return true
        }
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
    
    public enum ScrollDirection {
        case none
        case up
        case down
        
        var reversed: ScrollDirection {
            switch self {
            case .down:
                return .up
            case .up:
                return .down
            case .none:
                return .none
            }
        }
    }
}

// MARK: UISearchBarDelegate

extension ChannelVC: UISearchBarDelegate {
    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        channelViewModel.toggleSearch(isSearching: false)
    }
    
    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension ChannelVC: UICollectionViewDataSourcePrefetching {
    
    public func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        print()
    }
}
