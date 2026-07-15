//
//  ChannelViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit
import UniformTypeIdentifiers

open class ChannelViewController: ViewController,
                      UIGestureRecognizerDelegate,
                      UICollectionViewDelegateFlowLayout,
                      UICollectionViewDataSource,
                      UINavigationControllerDelegate,
                      UISearchBarDelegate,
                      ContextMenuDataSource,
                      ContextMenuDelegate,
                      ContextMenuSnapshotDelegate,
                      AttachmentPreviewDataSourceDelegate
{
    open var channelViewModel: ChannelViewModel!
    
    open lazy var router = Components.channelRouter
        .init(rootViewController: self)
    
    open lazy var collectionView = Components.channelMessagesCollectionView
        .init()
        .withoutAutoresizingMask
    
    open var layout: ChannelViewController.MessagesCollectionViewLayout {
        collectionView.layout
    }
    
    open lazy var coverView = BarCoverView()
        .withoutAutoresizingMask
    
    open lazy var customInputViewController = Components.messageInputViewController
        .init()
    
    open var inputTextView: MessageInputViewController.InputTextView {
        customInputViewController.inputTextView
    }
    
    open var selectedMediaView: MessageInputViewController.SelectedMediaView {
        customInputViewController.selectedMediaView
    }
    
    open var titleView = Components.channelHeaderView
        .init()
        .withoutAutoresizingMask

    open var unreadMentionCountView = Components.channelUnreadMentionCountView
        .init()
        .withoutAutoresizingMask

    open var unreadCountView = Components.channelScrollDownView
        .init()
        .withoutAutoresizingMask
    
    open var bottomView = Components.messageInputCoverView
        .init()
        .withoutAutoresizingMask
    
    open var searchControlsView = Components.messageInputMessageSearchControlsView
        .init()
        .withoutAutoresizingMask
    
    open lazy var joinGlobalChannelButton = UIButton()
        .withoutAutoresizingMask
    
    open lazy var selectingView = Components.messageInputSelectedMessagesActionsView
        .init()
        .withoutAutoresizingMask
    
    open lazy var emptyStateView = Components.emptyStateView
        .init()
        .withoutAutoresizingMask
        
    open lazy var searchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = appearance.searchBarAppearance.placeholder
        searchBar.showsCancelButton = appearance.searchBarAppearance.showsCancelButton
        searchBar.delegate = self
        searchBar.searchTextField.returnKeyType = appearance.searchBarAppearance.textFieldReturnKeyType
        searchBar.barTintColor = appearance.searchBarAppearance.backgroundColor
        searchBar.layer.cornerRadius = appearance.searchBarAppearance.cornerRadius
        searchBar.layer.cornerCurve = appearance.searchBarAppearance.cornerCurve
        searchBar.layer.borderColor = appearance.searchBarAppearance.borderColor?.cgColor
        searchBar.layer.borderWidth = appearance.searchBarAppearance.borderWidth
        searchBar.searchTextField.backgroundColor = appearance.searchBarAppearance.backgroundColor
        return searchBar
    }()
    
    open lazy var searchBarActivityIndicator = {
        let activityIndicator = UIActivityIndicatorView(style: appearance.searchBarAppearance.activityIndicatorStyle)
        activityIndicator.backgroundColor = appearance.searchBarAppearance.backgroundColor
        activityIndicator.color = appearance.searchBarAppearance.activityIndicatorColor
        activityIndicator.hidesWhenStopped = appearance.searchBarAppearance.activityIndicatorHidesWhenStopped
        return activityIndicator
    }()
    
    @objc public lazy var viewTapGestureRecognizer = UITapGestureRecognizer()
    @objc public lazy var titleViewTapGestureRecognizer = UITapGestureRecognizer()
    @objc public lazy var collectionViewTapGestureRecognizer = UITapGestureRecognizer()
    @objc public lazy var longPressGestureRecognizer = UILongPressGestureRecognizer()
    @objc public lazy var panGestureRecognizer = UIPanGestureRecognizer()
    
    public var userSelectOnRepliedMessage: ChatMessage?
    
    public var avatarTask: Cancellable?
    public var canShowUnreadCountView = true
    
    public var messageInputViewBottomConstraint: NSLayoutConstraint!
    public var searchControlsViewBottomConstraint: NSLayoutConstraint!
    public var messageInputViewHeightConstraint: NSLayoutConstraint!
    
    override open var disablesAutomaticKeyboardDismissal: Bool {
        return true
    }
    
    public var highlightedDurationForReplyMessage = TimeInterval(1)
    public var highlightedDurationForSearchMessage = TimeInterval(0.5)

    /// Distance from the visual top of the message area to the top edge of the
    /// "New messages" separator bar when opening a channel with unread messages.
    public static var unreadSeparatorScrollOffsetFromTop: CGFloat = 50

    /// Vertical spacing between the newest message and the input bar (visual
    /// bottom). Added into `contentInset.top` because the list is mirrored.
    public static var collectionViewInputSpacing: CGFloat = 10

    /// Measured height of the "New messages" bar inside the anchor cell —
    /// mirrors what `UnreadMessagesSeparatorView.measure` adds to the cell height.
    public var unreadSeparatorHeight: CGFloat {
        MessageCell.UnreadMessagesSeparatorView.Layouts.textHeight
            + 2 * MessageCell.UnreadMessagesSeparatorView.Layouts.verticalPadding
    }

    public private(set) var keyboardObserver: KeyboardObserver?
    private lazy var keyboardBgView = UIView()
        .withoutAutoresizingMask
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
    public var longPressItem: MessageCell.LongPressItem?
    private var unreadMessageIndexPath: IndexPath?
    
    private var isCollectionViewUpdating = false {
        didSet {
            // If a pump arrived mid-update, fire it now that updates are done.
            if !isCollectionViewUpdating, hasPendingPrevPagePump {
                hasPendingPrevPagePump = false
                addMoreMessage(scrollDirection: .up, force: false)
            }
            // Drain any update that arrived while a batch was in flight. Defer
            // to the next runloop so UIKit can settle from the just-completed
            // batch before we start the next one.
            if !isCollectionViewUpdating, let next = pendingUpdate {
                pendingUpdate = nil
                DispatchQueue.main.async { [weak self] in
                    self?.applyPendingUpdate(next)
                }
            }
            // Re-arm displayed-marker flush after a batch finishes — willDisplay
            // calls fired mid-update are gated out inside the work item.
            if !isCollectionViewUpdating {
                scheduleMarkDisplayed()
            }
        }
    }
    private var itemsAboveAtLastPrevFetch: Int = .max
    private var hasPendingPrevPagePump = false
    private var pendingPrevDBFetchBeforeId: MessageId?

    /// A structural update that arrived while a prior batch was animating.
    /// Drained from `isCollectionViewUpdating.didSet` when the prior batch finishes.
    private enum PendingUpdate {
        case diff(CollectionUpdateIndexPaths)
        case rebuild
    }
    private var pendingUpdate: PendingUpdate?
    private var isStartedDragging = false {
        didSet {
            unreadMessageIndexPath = nil
            channelViewModel.canUpdateUnreadPosition = false
        }
    }
    
    private var isScrollingBottom = false
    private var isUpdatingInputViewHeight = false
    private var checkOnlyFirstTimeReceivedMessagesFromArchive = true
    private var isViewDidAppear = false
    private var contextMenu: ContextMenu!
    private var scrollTimer: Timer?
    private var isAppActive: Bool = true
    private var markDisplayedWorkItem: DispatchWorkItem?
    private let markDisplayedDebounceInterval: TimeInterval = 0.2
    private var shouldAnimateEditing: Bool = false
    private var lastAnimatedIndexPath: IndexPath? = nil
    private var selectMessageId: MessageId?
    private var pinnedScrollMessageId: MessageId = 0
    private let impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    /// What UIKit has been told exists. Mutated only inside `performUpdates`
    /// (or via `rebuildAppliedSnapshotFromObserver` immediately before `reloadData`).
    /// All data-source methods (`numberOfSections`, `numberOfItemsInSection`,
    /// `cellForItemAt`, `sizeForItemAt`) read from this — never from the observer
    /// directly. This guarantees that the batch-update count math
    /// `oldCount + inserts − deletes == newCount` holds by construction,
    /// instead of being checked heuristically post-hoc.
    ///
    /// Sections carry identity (`SectionId`) so the Phase 2 diff can match
    /// sections across snapshots even when their index shifts. Items are still
    /// keyed by `ChannelViewModel.Key` (tid/id-based).
    internal var appliedSnapshot: AppliedSnapshot = .empty
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.delegate = self
        showBottomViewIfNeeded()
        updateTitle()
        updateUnreadViewVisibility()

        collectionView.collectionViewLayout.invalidateLayout()
        showEmptyViewIfNeeded()
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
        
        scheduleMarkDisplayed()

        if navigationController?.navigationBar.isUserInteractionEnabled == false { // system bug
            navigationController?.navigationBar.isUserInteractionEnabled = true
        }
        if channelViewModel.isSearching, !searchBar.searchTextField.isFirstResponder {
            searchBar.searchTextField.becomeFirstResponder()
        }
    }
    
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isViewDidAppear = false
        keyboardObserver = nil
        cancelPendingMarkDisplayed()
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        guard isViewLoaded
        else { return }

        Components.messageLayoutModel.defaults.messageWidth = floor(Components.messageLayoutModel.defaults.messageWidthRatio * size.width)
        channelViewModel.invalidateLayout()

        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            self.titleView.setNeedsLayout()
            self.titleView.layoutIfNeeded()
            self.collectionView.reloadData()
        })
    }
    
    override open func setup() {
        super.setup()

        impactFeedbackGenerator.prepare()
        contextMenu = ContextMenu(parent: self)
        contextMenu.dataSource = self
        contextMenu.delegate = self
        contextMenu.snapshotDelegate = self
        
        customInputViewController.mentionUserListViewController = { [unowned self] in
            let viewController = Components.messageInputMentionUsersListViewController.init()
            viewController.viewModel = Components.mentioningUserListViewModel
                .init(channelId: channelViewModel.channel.id)
            return viewController
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
            guard let self, !self.channelViewModel.isSearchResultsLoading else { return }
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
            self?.channelViewModel.searchMessages(with: query)
        }
        .store(in: &subscriptions)
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.collectionView
        unreadCountView.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.scrollDownButton
        unreadMentionCountView.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.unreadMentionButton
        joinGlobalChannelButton.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.joinButton
        emptyStateView.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.emptyView
        searchBar.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.searchBar
        searchControlsView.nextResultButton.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.Search.nextButton
        searchControlsView.prevResultButton.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.Search.previousButton
        searchControlsView.resultsCounterLabel.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.Search.resultLabel

        updateUnreadViewVisibility()
        updateTitle()
        unreadCountView.addTarget(self, action: #selector(unreadButtonAction(_:)), for: .touchUpInside)

        unreadMentionCountView.addTarget(self, action: #selector(unreadMentionCountButtonAction(_:)), for: .touchUpInside)

        joinGlobalChannelButton.addTarget(self, action: #selector(joinButtonAction(_:)), for: .touchUpInside)
        titleView.profileImageView.isUserInteractionEnabled = false
        titleView.tapButton.addTarget(self, action: #selector(showChannelProfileAction), for: .touchUpInside)
        viewTapGestureRecognizer.addTarget(self, action: #selector(viewTapped(gesture:)))
        viewTapGestureRecognizer.delegate = self
        viewTapGestureRecognizer.cancelsTouchesInView = true
        view.addGestureRecognizer(viewTapGestureRecognizer)
        collectionViewTapGestureRecognizer.addTarget(self, action: #selector(handleTapGestureRecognizer(_:)))
        collectionView.addGestureRecognizer(collectionViewTapGestureRecognizer)
        longPressGestureRecognizer.minimumPressDuration = 0.2
        longPressGestureRecognizer.addTarget(self, action: #selector(handleLongPressGestureRecognizer(_:)))
        collectionView.addGestureRecognizer(longPressGestureRecognizer)
        collectionViewTapGestureRecognizer.require(toFail: longPressGestureRecognizer)
        collectionViewTapGestureRecognizer.delegate = self
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
        view.addSubview(emptyStateView)
        view.addSubview(coverView)
        view.addSubview(searchControlsView)
        addChild(customInputViewController)
        coverView.addSubview(customInputViewController.view)
        coverView.addSubview(unreadMentionCountView)
        coverView.addSubview(unreadCountView)
        view.addSubview(joinGlobalChannelButton)
        
        messageInputViewBottomConstraint = customInputViewController.view.bottomAnchor.pin(to: coverView.safeAreaLayoutGuide.bottomAnchor)
        messageInputViewHeightConstraint = customInputViewController.view.resize(anchors: [.height(52)]).first!
        
        searchControlsViewBottomConstraint = searchControlsView.bottomAnchor.pin(to: view.safeAreaLayoutGuide.bottomAnchor)
        searchControlsView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .trailing])
        
        updateCollectionViewInsets()
        coverView.pin(to: view.safeAreaLayoutGuide)
        collectionView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .trailing, .top])
        collectionView.bottomAnchor.pin(to: coverView.safeAreaLayoutGuide.bottomAnchor)
        emptyStateView.pin(to: view, anchors: [.leading, .trailing])
        emptyStateView.topAnchor.pin(to: view.safeAreaLayoutGuide.topAnchor)
        emptyStateView.bottomAnchor.pin(to: customInputViewController.view.topAnchor)
        customInputViewController.view.pin(to: coverView.safeAreaLayoutGuide, anchors: [.leading, .trailing])

        unreadMentionCountView.trailingAnchor.pin(to: unreadCountView.trailingAnchor)
        unreadMentionCountView.bottomAnchor.pin(to: unreadCountView.topAnchor, constant: -8)
        unreadMentionCountView.resize(anchors: [.width(44), .height(44)])

        unreadCountView.trailingAnchor.pin(to: customInputViewController.view.trailingAnchor, constant: -10)
        unreadCountView.bottomAnchor.pin(to: customInputViewController.view.topAnchor, constant: -10)
        unreadCountView.resize(anchors: [.width(44), .height(48)])
        joinGlobalChannelButton.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .trailing, .bottom])
        joinGlobalChannelButton.resize(anchors: [.height(52)])
        
        view.addSubview(keyboardBgView)
        keyboardBgView.pin(to: view, anchors: [.leading, .trailing, .bottom])
        keyboardBgView.topAnchor.pin(to: customInputViewController.view.bottomAnchor)
        
        view.addSubview(selectingView)
        selectingView.pin(to: view, anchors: [.leading, .trailing])
        selectingView.bottomAnchor.pin(to: customInputViewController.view.bottomAnchor)
        
        
        if let view = searchBar.searchTextField.leftView {
            view.addSubview(searchBarActivityIndicator)
            searchBarActivityIndicator.pin(to: view)
        }
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        canShowUnreadCountView = appearance.enableScrollDownButton
        navigationController?.navigationBar.apply(appearance: appearance.navigationBarAppearance)
        view.backgroundColor = appearance.backgroundColor
        coverView.backgroundColor = .clear
        collectionView.backgroundColor = appearance.backgroundColor
        joinGlobalChannelButton.setAttributedTitle(.init(
            string: L10n.Channel.join,
            attributes: [
                .font: appearance.messageInputAppearance.joinButtonAppearance.labelAppearance.font,
                .foregroundColor: appearance.messageInputAppearance.joinButtonAppearance.labelAppearance.foregroundColor
            ]), for: .normal)
        joinGlobalChannelButton.backgroundColor = appearance.messageInputAppearance.joinButtonAppearance.backgroundColor
        keyboardBgView.backgroundColor = view.backgroundColor
        titleView.parentAppearance = appearance.headerAppearance
        customInputViewController.parentAppearance = appearance.messageInputAppearance
        unreadCountView.parentAppearance = appearance.scrollDownAppearance
        unreadMentionCountView.parentAppearance = appearance.unreadMentionCountAppearance
        emptyStateView.parentAppearance = appearance.emptyStateAppearance
        showEmptyViewIfNeeded()
        searchControlsView.parentAppearance = Components.messageInputViewController.appearance.messageSearchControlsAppearance
        bottomView.parentAppearance = Components.messageInputViewController.appearance.coverAppearance
        selectingView.parentAppearance = Components.messageInputViewController.appearance.selectedMessagesActionsAppearance
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
        
        customInputViewController.onContentHeightUpdate = { [weak self] height, completion in
            guard let self else { return }
            if height != self.messageInputViewHeightConstraint.constant {
                self.isUpdatingInputViewHeight = true
                UIView.animate(withDuration: 0.25) { [weak self] in
                    guard let self else { return }
                    // Mirrored list: the input bar occupies contentInset.top
                    // (visual bottom). Shifting the offset opposite to the inset
                    // growth keeps the visible content riding above the input bar;
                    // at the bottom this lands exactly on the new minimum offset.
                    let top = self.collectionView.contentInset.top
                    var contentOffsetY = self.collectionView.contentOffset.y
                    self.messageInputViewHeightConstraint.constant = height
                    self.updateCollectionViewInsets()
                    let newTop = self.collectionView.contentInset.top
                    if newTop != top {
                        contentOffsetY -= newTop - top
                    }
                    self.coverView.layoutIfNeeded()
                    self.collectionView.layoutIfNeeded()
                    contentOffsetY = min(
                        max(contentOffsetY, self.collectionView.bottomContentOffsetY),
                        self.collectionView.maxContentOffsetY
                    )
                    self.collectionView.setContentOffset(
                        .init(
                            x: 0,
                            y: contentOffsetY
                        ),
                        animated: false
                    )
                } completion: { [weak self] _ in
                    self?.isUpdatingInputViewHeight = false
                    completion?()
                }
            }
        }

        customInputViewController.onCreatePoll = { [weak self] poll in
            guard let self else { return }
            channelViewModel.sendPoll(poll)
            customInputViewController.removeActionView()
            channelViewModel.removeSelectedMessage()
        }

        customInputViewController.$action
            .compactMap { $0 }
            .sink { [unowned self] in
                switch $0 {
                case .send(let shouldClearText):
                    self.channelViewModel.isTyping = false
                    sendMessage(
                        createMessage(shouldClearText: shouldClearText),
                        shouldClearText: shouldClearText
                    )
                case .cancel:
                    channelViewModel.removeSelectedMessage()
                case .deleteMedia:
                    if customInputViewController.selectedMediaView.items.count == 0 {
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
                    logger.info("🎧 did start recording")
                    self.channelViewModel.isRecording = true
                    didStartVoiceRecording()
                case .didStopRecording:
                    logger.info("🎧 did stop recording")
                    self.channelViewModel.isRecording = false
                    didStopVoiceRecording()
                }
            }.store(in: &subscriptions)
        
        channelViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)

        // The observer's initial event can fire before this subscription exists —
        // e.g. group create opens the channel while the create screen's modal
        // dismissal delays view loading. @Published replays only the latest value
        // (typically .showNoMessage, which overwrote .reloadDataAndScrollToBottom),
        // so the event carrying the first snapshot is lost and the collection view
        // stays empty until something else forces a reload. Reconcile here: if the
        // observer already has data the collection view hasn't applied, apply it.
        if channelViewModel.numberOfSections > 0, appliedSnapshot.sections.isEmpty {
            rebuildAppliedSnapshotFromObserver()
            collectionView.reloadDataAndScrollToBottom()
            showEmptyViewIfNeeded()
        }
        
        channelViewModel.$selectedMessages
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                updateNavigationItems()
                collectionView.reloadData()
            }.store(in: &subscriptions)

        channelViewModel.$isEditing
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEditing in
                guard let self else { return }
                self.updateNavigationItems()
                if isEditing {
                    shouldAnimateEditing = true
                    collectionView.reloadData()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                        self?.shouldAnimateEditing = false
                    }
                    bottomView.removeFromSuperview()
                } else {
                    UIView.animate(withDuration: 0.3) { [weak self] in
                        guard let self else { return }
                        collectionView.visibleCells.forEach {
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
                guard let self else { return }
                unreadCountView.unreadCount.value = appearance.scrollDownAppearance.unreadCountFormatter.format(value)
            }.store(in: &subscriptions)

        channelViewModel
            .$newMentionCount
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self else { return }
                unreadMentionCountView.unreadCount.value = appearance.unreadMentionCountAppearance.unreadCountFormatter.format(value)
                unreadMentionCountView.isHidden = (value == 0)

                if value == 0 {
                    self.channelViewModel.resetUnreadMentionsIfNeeded()
                }
            }.store(in: &subscriptions)

        channelViewModel
            .$isSearching
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSearching in
                self?.updateNavigationItems()
                self?.customInputViewController.view.isHidden = isSearching
                self?.searchControlsView.isHidden = !isSearching
            }
            .store(in: &subscriptions)
        
        channelViewModel
            .$searchResult
            .receive(on: DispatchQueue.main)
            .compactMap { $0?.state == .loaded ? $0 : nil }
            .sink { [weak self] searchResult in
                guard let self, self.channelViewModel.isSearching else { return }
                self.searchControlsView.update(
                    with: searchResult,
                    query: self.searchBar.searchTextField.text ?? ""
                )
                if searchResult.cacheCount == 0 {
                    NotificationCenter.default.post(name: .selectMessage, object: nil)
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

        // Listen for poll close notification to force reload collection view
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didClosePoll(_:)),
            name: .didClosePoll,
            object: nil
        )

        ApplicationStateObserver()
            .didBecomeActive { [weak self] _ in
                self?.isAppActive = true
                self?.channelViewModel.canUpdateUnreadPosition = false
                self?.updateUnreadViewVisibility()
                self?.scheduleMarkDisplayed()
            }
            .didEnterBackground { [weak self] _ in
                self?.isAppActive = false
                self?.channelViewModel.canUpdateUnreadPosition = true
                self?.cancelPendingMarkDisplayed()
            }
    }
    
    private func updateCollectionViewInsets() {
        let bottomConstraint = searchControlsView.isHidden
        ? messageInputViewBottomConstraint.constant
        : searchControlsViewBottomConstraint.constant
        let controlHeight = searchControlsView.isHidden
        ? messageInputViewHeightConstraint.constant
        : searchControlsView.frame.height

        // Mirrored list: the input bar overlays the visual bottom, which is the
        // content-space TOP — so the input area padding goes into contentInset.top.
        // The extra spacing keeps the newest message from touching the input bar.
        collectionView.contentInset.top =
        abs(bottomConstraint) +
        abs(controlHeight) +
        Self.collectionViewInputSpacing
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
                   !cell.unreadMessagesSeparatorView.isHidden {
                    if let indexPath = self.collectionView.indexPath(for: cell) {
                        self.collectionView.reloadItems(at: [indexPath])
                    } else {
                        cell.unreadMessagesSeparatorView.isHidden = true
                    }
                }
            }
        }
    }
    
    /// Expects an index path in the collection view's mirrored (newest-first)
    /// space — convert view-model paths with `uiIndexPath(fromData:)` first.
    func goTo(indexPath: IndexPath, completion: @escaping (MessageCell) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.collectionView.scrollToItem(at: indexPath, pos: .centeredVertically, animated: true)
            UIView.animate(withDuration: 0.3, delay: 0, options: .allowUserInteraction) { [weak self] in
            } completion: { [weak self] _ in
                guard let self else { return }
                if let cell = self.collectionView.cellForItem(at: indexPath) as? MessageCell {
                    completion(cell)
                }
                self.updateUnreadViewVisibility()
            }
        }
    }
    
    open func keyboardWillShow(notification: Notification) {
        setSectionHeadersPinToVisibleBounds(false)
        guard let keyboardFrameEndValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
        else { return }
        // Mirrored list: the keyboard + input bar area lives in contentInset.top
        // (visual bottom). Shift the offset opposite to the inset growth so the
        // visible content rides above the keyboard; when the user is at the
        // bottom this lands exactly on the new minimum offset (still glued to
        // the newest message). The clamp handles short content: its max offset
        // equals the bottom offset, so it stays pinned above the input bar.
        let top = collectionView.contentInset.top
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
        messageInputViewBottomConstraint.constant = shift
        searchControlsViewBottomConstraint.constant = shift
        updateCollectionViewInsets()
        let newTop = collectionView.contentInset.top
        if newTop != top {
            contentOffsetY -= newTop - top
        }
        contentOffsetY = min(
            max(contentOffsetY, collectionView.bottomContentOffsetY),
            collectionView.maxContentOffsetY
        )
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
        let top = collectionView.contentInset.top
        var contentOffsetY = collectionView.contentOffset.y
        messageInputViewBottomConstraint.constant = 0
        searchControlsViewBottomConstraint.constant = 0
        updateCollectionViewInsets()
        let newTop = collectionView.contentInset.top
        // Mirror of keyboardWillShow: the inset shrinks, so the offset grows back
        // by the same amount, clamped into the valid range.
        contentOffsetY -= newTop - top
        contentOffsetY = min(
            max(contentOffsetY, collectionView.bottomContentOffsetY),
            collectionView.maxContentOffsetY
        )

        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        let animation = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        UIView.animate(
            withDuration: duration ?? 0,
            delay: 0,
            options: .init(rawValue: animation ?? 0)
        ) {
            self.customInputViewController.view.layoutIfNeeded()
            if self.channelViewModel.selectedMessageForAction == nil {
                self.collectionView.setContentOffset(.init(x: 0, y: contentOffsetY), animated: false)
            }
        }
    }
    
    open func updateNavigationItems() {
        if channelViewModel.isEditing {
            customInputViewController.actionViewCancelAction()
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
        } else if channelViewModel.isSearching {
            showSearchBar()
        } else {
            navigationItem.setHidesBackButton(false, animated: false)
            navigationItem.leftItemsSupplementBackButton = true
            navigationItem.title = nil
            navigationItem.titleView = titleView
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItems = []
        }
        selectingView.isHidden = !channelViewModel.isEditing
        coverView.isHidden = channelViewModel.isEditing
    }
    
    open func showSearchBar() {
        definesPresentationContext = true
        navigationItem.setHidesBackButton(true, animated: false)
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItems = []
        navigationItem.titleView = searchBar
        
        if isViewDidAppear {
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
            title: channelViewModel.getTitleForHeader(with: appearance.headerAppearance),
            subTitle: channelViewModel.getSubtitleForHeader(with: appearance.headerAppearance)
        )
        appearance.headerAppearance.avatarRenderer.render(
            channelViewModel.channel,
            with: appearance.headerAppearance.avatarAppearance,
            into: titleView.profileImageView,
            size: .init(width: 36 * UIScreen.main.traitCollection.displayScale, height: 36 * UIScreen.main.traitCollection.displayScale)
        )
    }
    
    open func showTitle(
        title: String,
        subTitle: String?
    ) {
        titleView.mode = .default
        var attrs = [NSAttributedString.Key: Any]()
        
        attrs[.font] = titleView.appearance.titleLabelAppearance.font
        attrs[.foregroundColor] = titleView.appearance.titleLabelAppearance.foregroundColor
        
        let head = NSMutableAttributedString(
            string: title,
            attributes: attrs
        )
        titleView.headLabel.attributedText = head
        
        attrs.removeAll(keepingCapacity: true)
        
        attrs[.font] = titleView.appearance.subtitleLabelAppearance.font
        attrs[.foregroundColor] = titleView.appearance.subtitleLabelAppearance.foregroundColor
        
        if let subTitle {
            let sub = NSAttributedString(
                string: subTitle,
                attributes: attrs
            )
            titleView.subLabel.attributedText = sub
        } else {
            titleView.subLabel.attributedText = NSAttributedString(string: "")
        }
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
        
        attrs[.font] = titleView.appearance.titleLabelAppearance.font
        attrs[.foregroundColor] = titleView.appearance.titleLabelAppearance.foregroundColor
        
        let head = NSMutableAttributedString(
            string: appearance.headerAppearance.titleFormatter.format(channelViewModel.channel),
            attributes: attrs
        )
        titleView.headLabel.attributedText = head
        
        attrs.removeAll(keepingCapacity: true)
        
        attrs[.font] = titleView.appearance.subtitleLabelAppearance.font
        attrs[.foregroundColor] = titleView.appearance.subtitleLabelAppearance.foregroundColor
        
        let sub = NSAttributedString(
            string: text,
            attributes: attrs
        )
        titleView.subLabel.attributedText = sub
    }
    
    open func showActivity(
        channel: ChatChannel,
        user: ChatUser,
        isActive: Bool,
        mode: HeaderView.Mode,
        indicator: Indicator.Configuration
    ) -> Int {

        if let titleView = navigationItem.titleView as? HeaderView, titleView.mode == mode {
            titleView.channelEventView.update(channel: channel, model: ChannelEventModel(user: user, event: mode == .recording ? .recording : .typing, indicatorConfiguration: indicator), isActive: isActive)
            navigationController?.navigationBar.setNeedsLayout()
            return titleView.channelEventView.models.count
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: titleView.appearance.titleLabelAppearance.font,
            .foregroundColor: titleView.appearance.titleLabelAppearance.foregroundColor
        ]

        let head = NSMutableAttributedString(
            string: appearance.headerAppearance.titleFormatter.format(channelViewModel.channel),
            attributes: attrs
        )

        titleView.headLabel.attributedText = head
        titleView.channelEventView.label.font = titleView.appearance.subtitleLabelAppearance.font
        titleView.channelEventView.label.textColor = titleView.appearance.subtitleLabelAppearance.foregroundColor
        titleView.channelEventView.update(channel: channel, model: ChannelEventModel(user: user, event: mode == .recording ? .recording : .typing, indicatorConfiguration: indicator), isActive: isActive)
        titleView.mode = mode
        return titleView.channelEventView.models.count
    }

    open func showTyping(channel: ChatChannel, user: ChatUser, isTyping: Bool) -> Int {
        return showActivity(channel: channel, user: user, isActive: isTyping, mode: .typing, indicator: .indicator(colors: [
                UIColor.secondaryText.withAlphaComponent(1),
                UIColor.secondaryText.withAlphaComponent(0.7)
            ])
        )
    }
    
    open func showRecording(channel: ChatChannel, user: ChatUser, isRecording: Bool) -> Int {
        return showActivity(channel: channel, user: user, isActive: isRecording, mode: .recording, indicator: .indicator(colors: [
            UIColor.secondaryText.withAlphaComponent(1),
            UIColor.secondaryText.withAlphaComponent(0.8),
            UIColor.secondaryText.withAlphaComponent(0.6),
            UIColor.secondaryText.withAlphaComponent(0.4)
        ])
        )
    }
   
    // MARK: Actions
    
    @objc
    open func joinButtonAction(_ sender: UIButton) {
        loader.isLoading = true
        channelViewModel.join { [weak self] error in
            loader.isLoading = false
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
    open func unreadButtonAction(_ sender: ChannelViewController.ScrollDownView) {
        // Always jump to the latest message — release any active pin and any
        // pending replied-message navigation so the .reloadDataAndScrollToBottom
        // branch (or scrollToBottom() below) can actually land at the bottom.
        pinnedScrollMessageId = 0
        userSelectOnRepliedMessage = nil
        if !channelViewModel.resetToInitialStateIfNeeded() {
            scrollToBottom()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.channelViewModel.markChannelAsDisplayed()
            self.channelViewModel.loadPrevMessages(before: 0)
            self.unreadCountView.isHidden = true
            self.isScrollingBottom = false
        }
    }

    @objc
    open func unreadMentionCountButtonAction(_ sender: ChannelViewController.UnreadMentionCountView) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        Task {
            await channelViewModel.navigateToNextUnreadMention()
        }
    }

    @objc
    open func showChannelProfileAction() {
        router.showChannelProfile()
    }

    @objc
    open func didClosePoll(_ notification: Notification) {
        // Force reload the collection view when a poll is closed in this channel
        guard let userInfo = notification.userInfo,
              let channelId = userInfo["channelId"] as? ChannelId,
              channelId == channelViewModel.channel.id else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Invalidate layout to force recalculation of all cell heights
            self.channelViewModel.invalidateLayout()
            // Invalidate the collection view layout
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.reloadData()
        }
    }

    //MARK: Gesture actions
    @objc
    open func viewTapped(gesture: UITapGestureRecognizer) {
        let child = children.first { viewController in
            viewController.view.bounds.contains(gesture.location(in: viewController.view))
        }
        guard
            !customInputViewController.isRecording,
            !customInputViewController.view.bounds.contains(gesture.location(in: customInputViewController.view)),
            !unreadCountView.bounds.contains(gesture.location(in: unreadCountView)),
            !unreadMentionCountView.bounds.contains(gesture.location(in: unreadMentionCountView)),
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
    open func handleLongPressGestureRecognizer(_ sender: UILongPressGestureRecognizer) {
        guard !channelViewModel.isEditing, !customInputViewController.isRecording
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
            guard message.user != nil else { return }
            let body = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty {
                items.append(appearance.messageShareBodyFormatter.format(message))
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
        guard !customInputViewController.isRecording else {
            return showRecordDiscardAlertIfNeeded()
        }
        router.showForward { [weak self] channels in
            guard let self else { return }
            loader.show()
            self.channelViewModel.share(messages: messages, to: channels.map { $0.id }) { [weak self] in
                guard let self else { return }
                if channels.contains(self.channelViewModel.channel) {
                    self.collectionView.scrollToBottom(animated: false) { _ in }
                } else if channels.count == 1 {
                    ChannelListRouter.showChannel(channels[0])
                }
                self.router.dismiss()
                loader.hide()
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
        guard !(touch.view is ChannelViewController.ScrollDownView ||
                touch.view is ChannelViewController.UnreadMentionCountView)
        else { return false }
        guard !(touch.view?.tag == 999)
        else { return false }
        guard !(touch.view is MessageCell.LinkPreviewView)
        else { return false }
        guard !(touch.view is MessageCell.ReplyView)
        else { return false }
        guard !(touch.view is MessageCell.ReactionTotalView)
        else { return false }
        if channelViewModel.isEditing {
            return false
        }
        return customInputViewController.presentedMentionUserListViewController?.parent == nil
    }
    
    /// The list is mirrored and presented newest-first, so the OLDEST visible
    /// message is the MAX UI index path and older pagination is approached as the
    /// offset grows toward the content end. Index paths handed to the view model
    /// are converted back to its oldest-first space; the returned index path is
    /// in the view model's (data) space too, since callers only feed it back in.
    @discardableResult
    open func addMoreMessage(scrollDirection: ScrollDirection, force: Bool = false) -> IndexPath? {
        guard !isCollectionViewUpdating,
              isStartedDragging
        else { return nil }
        switch scrollDirection {
        case .up:
            let uiIndexPath = collectionView.indexPathsForVisibleItems.max()
            if let uiIndexPath, let dataIndexPath = dataIndexPath(fromUI: uiIndexPath) {
                // Count of loaded items older than the oldest visible one — the
                // remaining runway before the user hits the loaded edge.
                var itemsAbove = collectionView.numberOfItems(inSection: uiIndexPath.section) - 1 - uiIndexPath.item
                for section in (uiIndexPath.section + 1)..<collectionView.numberOfSections {
                    itemsAbove += collectionView.numberOfItems(inSection: section)
                }
                // A successful prev fetch adds older items, so itemsAbove jumps up.
                // When that happens, reset the progress marker so the user can
                // trigger again after consuming the new chunk.
                if itemsAboveAtLastPrevFetch != .max,
                   itemsAbove > itemsAboveAtLastPrevFetch + 10 {
                    itemsAboveAtLastPrevFetch = .max
                }
                let madeProgress = itemsAbove < itemsAboveAtLastPrevFetch
                if force || (itemsAbove < 10 && madeProgress) {
                    // Pin to 0 (not itemsAbove) so subsequent frames can't keep
                    // firing as the user reveals each consecutive older cell —
                    // the gate only reopens via the reset above, which requires an
                    // actual fetch of 10+ items.
                    itemsAboveAtLastPrevFetch = 0
                    loadPrevMessages(beforeMessageAt: dataIndexPath)
                }
                return dataIndexPath
            }
            return nil
        case .down:
            let indexPathsForVisibleItems = collectionView.indexPathsForVisibleItems
            guard !indexPathsForVisibleItems.isEmpty
            else { return nil }
            if let uiIndexPath = indexPathsForVisibleItems.min(),
               let dataIndexPath = dataIndexPath(fromUI: uiIndexPath) {
                loadNextMessages(afterMessageAt: dataIndexPath)
                return dataIndexPath
            }
        default:
            break
        }
        return nil
    }

    open func reloadNearMessages() {
        if let uiIndexPath = collectionView.indexPathsForVisibleItems.max(),
           let dataIndexPath = dataIndexPath(fromUI: uiIndexPath),
           let model = channelViewModel.layoutModel(at: dataIndexPath) {
            channelViewModel.loadNearMessages(messageId: model.message.id)
        }
    }
    
    open func loadPrevMessages(beforeMessageAt indexPath: IndexPath) {
        if channelViewModel.isSearching {
            channelViewModel.resetScrollState()
        }
        channelViewModel.loadPrevMessages(beforeMessageAt: indexPath)
    }
    
    open func loadNextMessages(afterMessageAt indexPath: IndexPath) {
        if channelViewModel.isSearching {
            channelViewModel.resetScrollState()
        }
        channelViewModel.loadNextMessages(afterMessageAt: indexPath)
    }
    
    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isStartedDragging = true
        pinnedScrollMessageId = 0
        // Drag starting while pinned to the oldest loaded edge (content end in the
        // mirrored order) reopens the prev-fetch gate so a failed server page can
        // be retried once connectivity returns.
        if scrollView.contentOffset.y >= collectionView.maxContentOffsetY - 1 {
            itemsAboveAtLastPrevFetch = .max
        }
    }
    
    open func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        self.scrollDirection = self.scrollDirectionForVelocity(scrollView.panGestureRecognizer.velocity(in: scrollView))
        self.addMoreMessage(scrollDirection: self.scrollDirection, force: false)
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
           let indexPath = addMoreMessage(scrollDirection: lastScrollDirection, force: false) {
            DispatchQueue.main.async { [weak self] in
                self?.loadNextMessages(afterMessageAt: indexPath)
            }
        } else if lastScrollDirection == .up {
            // Symmetric retry: a fast upward flick can exhaust the loaded buffer
            // while pagination is throttled. Re-evaluate once deceleration ends.
            addMoreMessage(scrollDirection: .up, force: false)
        }
        drainPendingPrevDBFetch()
    }

    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if let lastAnimatedIndexPath, !isCollectionViewUpdating {
            if !self.isCollectionViewUpdating {
//                self.channelViewModel.loadNearMessages(arMessageAt: lastAnimatedIndexPath)
            }
        }
        drainPendingPrevDBFetch()
    }

    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if let userSelectOnRepliedMessage,
           !collectionView.visibleCells.contains(where: { ($0 as? MessageCell)?.data.message.id == userSelectOnRepliedMessage.id }) {
            self.userSelectOnRepliedMessage = nil
        }
        if !decelerate {
            drainPendingPrevDBFetch()
        }
    }

    private func drainPendingPrevDBFetch() {
        guard let beforeMessageId = pendingPrevDBFetchBeforeId
        else { return }
        pendingPrevDBFetchBeforeId = nil
        channelViewModel.fetchPrevMessagesFromDB(before: beforeMessageId)
    }
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateUnreadViewVisibility()
        updateLastNavigatedIndexPath()
        updatePinnedHeaderVisibility()
        if !isUpdatingInputViewHeight {
            self.addMoreMessage(scrollDirection: self.lastScrollDirection, force: false)
        }
    }
    
    open func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        // In the mirrored list the system scroll-to-top (status bar tap) lands on
        // offset ≈ 0, which is the NEWEST message — so pump the next page, not prev.
        isStartedDragging = true
        addMoreMessage(scrollDirection: .down, force: true)
    }

    open func scrollDirectionForVelocity(_ velocity: CGPoint) -> ScrollDirection {
        // The collection view is mirrored (scaleY: -1), so the pan velocity arrives
        // sign-flipped relative to the screen: dragging toward older messages
        // (revealing content at the visual top) reports a NEGATIVE y velocity.
        // `.up` keeps meaning "toward older / prev pages", `.down` "toward newer".
        if velocity.y > 0 {
            return .down
        } else if velocity.y < 0 {
            return .up
        }
        return .none
    }
    
    open func scrollToBottom(animated: Bool = true, duration: CGFloat = 0.22) {
        guard isAppActive else { return }
        // User intent is to leave the pinned message — release the anchor so
        // follow-up pagination doesn't yank the viewport back.
        pinnedScrollMessageId = 0
        isStartedDragging = true
        isScrollingBottom = true
        updateUnreadViewVisibility()
        collectionView.scrollToBottom(animated: animated) { [weak self] _ in
            self?.isScrollingBottom = false
        }
    }

    /// Locate the pinned message in whatever index-space is currently laid out.
    /// Pre-batch we have to ask `appliedSnapshot` (which mirrors UICollectionView's
    /// data source), not the observer — the observer may have already advanced
    /// to the post-update snapshot, returning an indexPath whose section the CV
    /// doesn't yet know about (`layoutAttributesForItem` would return nil).
    private func pinnedMessageIndexPathInAppliedSnapshot() -> IndexPath? {
        guard pinnedScrollMessageId != 0 else { return nil }
        let key = ChannelViewModel.Key(messageId: pinnedScrollMessageId)
        for (sectionIdx, items) in appliedSnapshot.items.enumerated() {
            if let itemIdx = items.firstIndex(of: key) {
                return IndexPath(item: itemIdx, section: sectionIdx)
            }
        }
        return nil
    }

    /// Distance from the top of the viewport (in collection-view content
    /// coordinates) to the top of the currently-pinned message. Returns nil
    /// when there's no pin or the pinned item isn't laid out right now.
    /// Capture before any layout-changing operation, then hand the value to
    /// `restorePinnedMessageToVisibleOffset` after the new layout settles so
    /// the message lands at the exact same viewport position — bottom stays
    /// bottom, center stays center.
    private func pinnedMessageVisibleOffset() -> CGFloat? {
        guard let indexPath = pinnedMessageIndexPathInAppliedSnapshot(),
              let attrs = collectionView.layoutAttributesForItem(at: indexPath)
        else { return nil }
        return attrs.frame.minY - collectionView.contentOffset.y
    }

    @discardableResult
    private func restorePinnedMessageToVisibleOffset(_ visibleOffset: CGFloat) -> Bool {
        // Post-batch: CV has been told about the new sections/items, so the
        // observer's indexPath is now valid. Use that — `appliedSnapshot`
        // points at the new snapshot too once `performUpdates` returns.
        // The observer's index path is in data (oldest-first) space; convert it
        // into the mirrored UI space before asking the layout for frames.
        guard pinnedScrollMessageId != 0,
              let dataIndexPath = channelViewModel.indexPathOf(messageId: pinnedScrollMessageId),
              let indexPath = uiIndexPath(fromData: dataIndexPath),
              let attrs = collectionView.layoutAttributesForItem(at: indexPath)
        else { return false }
        let target = attrs.frame.minY - visibleOffset
        collectionView.contentOffset.y = min(
            max(target, collectionView.bottomContentOffsetY),
            collectionView.maxContentOffsetY
        )
        return true
    }
    
    open func updateUnreadViewVisibility() {
        guard canShowUnreadCountView
        else {
            unreadCountView.isHidden = true
            return
        }
        // Mirrored list: distance from the newest message is just the offset's
        // distance from the bottom anchor.
        let distanceFromNewest = collectionView.contentOffset.y - collectionView.bottomContentOffsetY
        unreadCountView.isHidden = !(distanceFromNewest > 30)
    }

    open func updateLastNavigatedIndexPath() {
        if channelViewModel.lastNavigatedIndexPath != nil,
            let indexPath = collectionView.lastVisibleIndexPath,
            let dataIndexPath = dataIndexPath(fromUI: indexPath),
            channelViewModel.isLastMessage(at: dataIndexPath) {
            channelViewModel.updateLastNavigatedIndexPath(indexPath: nil)
        }
    }

    open func updatePinnedHeaderVisibility() {
        guard collectionView.isDragging || collectionView.isDecelerating
        else { return }
        // Don't pin while all content fits on screen — the date would float
        // detached at the visual top while the messages sit at the bottom anchor.
        guard collectionView.maxContentOffsetY > collectionView.bottomContentOffsetY
        else {
            setSectionHeadersPinToVisibleBounds(false)
            return
        }
        if let scrollTimer, scrollTimer.isValid {
            scrollTimer.invalidate()
        }
        setSectionHeadersPinToVisibleBounds(true)
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false, block: { [weak self] _ in
            guard let self else { return }
            self.setSectionHeadersPinToVisibleBounds(false)
        })
    }

    /// The mirrored list renders date separators as section FOOTERS (the section's
    /// content-space end is its visual top), so sticky behavior pins footers.
    /// The method name is kept for API compatibility.
    open func setSectionHeadersPinToVisibleBounds(_ show: Bool) {
        if layout.sectionFootersPinToVisibleBounds != show {
            let context = UICollectionViewFlowLayoutInvalidationContext()
            layout.sectionFootersPinToVisibleBounds = show
            layout.invalidateLayout(with: context)
        }
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        if let systemCell = cell as? SystemMessageCell, systemCell.data != nil {
            var repliedMessageId: MessageId {
                channelViewModel.scrollToRepliedMessageId
            }
            if repliedMessageId != 0,
               systemCell.data.message.id == repliedMessageId {
                animateHighlightCell(systemCell, mode: .reply)
            } else if systemCell.highlightMode != .none {
                systemCell.highlightMode = .none
            }
            return
        }

        guard let cell = cell as? MessageCell,
              cell.data != nil
        else { return }

        var repliedMessageId: MessageId {
            channelViewModel.scrollToRepliedMessageId
        }
        if selectMessageId != 0, cell.data.message.id == selectMessageId {
            cell.highlightMode = .search
        } else if repliedMessageId != 0,
                    cell.data.message.id == repliedMessageId {
            animateHighlightCell(cell, mode: .reply)
        } else if cell.highlightMode != .none {
            cell.highlightMode = .none
        }

        if shouldAnimateEditing, cell.isEditing, cell.checkBoxView.transform != .identity {
            cell.contentView.alpha = 1
            UIView.animate(withDuration: 0.3) { [weak self] in
                guard let self else { return }
                cell.checkBoxView.transform = .identity
                cell.containerView.transform = .identity
                let canSelect = self.dataIndexPath(fromUI: indexPath).map { self.channelViewModel.canSelectMessage(at: $0) } ?? false
                cell.contentView.alpha = canSelect ? 1 : 0.5
            }
        }

        if cell.data.message.incoming {
            scheduleMarkDisplayed()
        }
    }

    // MARK: Applied snapshot helpers

    /// Pure builder — reads the observer's current state and returns a fresh
    /// `AppliedSnapshot` without touching any view-controller state. Used by
    /// `rebuildAppliedSnapshotFromObserver()` and (post-Phase 2) by the
    /// snapshot-diff pipeline to compute the target state for each batch.
    ///
    /// The snapshot is built in MIRRORED (UI) order: the observer keeps messages
    /// oldest-first, but the collection view is flipped (scaleY: -1) and presents
    /// newest-first, so sections and the items within them are reversed here.
    /// Everything downstream of the snapshot — data source counts, cell lookups,
    /// the diff, and the batch ops it produces — therefore lives in UI space with
    /// no further index mapping.
    internal func buildSnapshotFromObserver() -> AppliedSnapshot {
        let sectionCount = channelViewModel.numberOfSections
        var sections: [ChannelViewModel.SectionId] = []
        var items: [[ChannelViewModel.Key]] = []
        var versions: [ChannelViewModel.Key: UInt] = [:]
        sections.reserveCapacity(sectionCount)
        items.reserveCapacity(sectionCount)
        for s in stride(from: sectionCount - 1, through: 0, by: -1) {
            sections.append(.init(name: channelViewModel.sectionName(at: s)))
            let n = channelViewModel.numberOfMessages(in: s)
            var section: [ChannelViewModel.Key] = []
            section.reserveCapacity(n)
            for r in stride(from: n - 1, through: 0, by: -1) {
                if let m = channelViewModel.message(at: IndexPath(item: r, section: s)) {
                    let key = ChannelViewModel.Key(message: m)
                    section.append(key)
                    versions[key] = channelViewModel.layoutModels[key]?.contentVersion ?? 0
                } else {
                    // Defensive: keep counts consistent even if a slot is briefly
                    // missing from the observer. The cell will reload once content arrives.
                    section.append(.init(messageId: 0))
                }
            }
            items.append(section)
        }
        return AppliedSnapshot(sections: sections, items: items, versions: versions)
    }

    /// Rebuild `appliedSnapshot` from the observer's current state. Call this
    /// immediately before any `collectionView.reloadData()` that follows a state
    /// change (initial load, restart, reload events) so the data source counts
    /// reflect what's about to be rendered.
    open func rebuildAppliedSnapshotFromObserver() {
        appliedSnapshot = buildSnapshotFromObserver()
    }

    /// Look up the `Key` at an index path in the applied snapshot. Returns nil
    /// if the index path is out of bounds for the snapshot.
    open func snapshotKey(at indexPath: IndexPath) -> ChannelViewModel.Key? {
        guard indexPath.section < appliedSnapshot.sectionCount,
              indexPath.item < appliedSnapshot.items[indexPath.section].count
        else { return nil }
        return appliedSnapshot.items[indexPath.section][indexPath.item]
    }

    /// Look up a layout model via the snapshot. Falls back to the observer-based
    /// lookup only when the snapshot has a placeholder key (Key.messageId == 0
    /// with tid == 0), to handle the rare warm-up case.
    open func snapshotLayoutModel(at indexPath: IndexPath) -> MessageLayoutModel? {
        guard let key = snapshotKey(at: indexPath) else { return nil }
        return channelViewModel.layoutModels[key]
    }

    // MARK: Mirrored-presentation index mapping

    /// The view model keeps messages oldest-first; the collection view is mirrored
    /// (scaleY: -1) and presents newest-first, with `appliedSnapshot` built in the
    /// mirrored order. Both mappings are the same involution computed against the
    /// applied snapshot (the collection view's source of truth):
    ///   uiSection = sectionCount − 1 − dataSection
    ///   uiItem    = itemCount(uiSection) − 1 − dataItem
    /// Returns nil when the path doesn't fit the snapshot (e.g. the observer has
    /// drifted ahead of the applied state) — callers treat that as "not present".
    open func uiIndexPath(fromData indexPath: IndexPath) -> IndexPath? {
        let sectionCount = appliedSnapshot.sectionCount
        guard indexPath.section >= 0, indexPath.section < sectionCount else { return nil }
        let uiSection = sectionCount - 1 - indexPath.section
        let itemCount = appliedSnapshot.items[uiSection].count
        guard indexPath.item >= 0, indexPath.item < itemCount else { return nil }
        return IndexPath(item: itemCount - 1 - indexPath.item, section: uiSection)
    }

    /// Inverse of `uiIndexPath(fromData:)` — converts a collection-view index path
    /// into the view model's oldest-first space.
    open func dataIndexPath(fromUI indexPath: IndexPath) -> IndexPath? {
        let sectionCount = appliedSnapshot.sectionCount
        guard indexPath.section >= 0, indexPath.section < sectionCount else { return nil }
        let itemCount = appliedSnapshot.items[indexPath.section].count
        guard indexPath.item >= 0, indexPath.item < itemCount else { return nil }
        return IndexPath(
            item: itemCount - 1 - indexPath.item,
            section: sectionCount - 1 - indexPath.section
        )
    }

    /// Translates a scroll position expressed in visual terms (top = visually
    /// above) into the mirrored content space, where the visual top is the
    /// content-space bottom and vice versa.
    open func uiScrollPosition(_ pos: UICollectionView.ScrollPosition) -> UICollectionView.ScrollPosition {
        var mapped = pos
        let hadTop = mapped.contains(.top)
        let hadBottom = mapped.contains(.bottom)
        mapped.remove([.top, .bottom])
        if hadTop { mapped.insert(.bottom) }
        if hadBottom { mapped.insert(.top) }
        return mapped
    }

    /// Mutate `appliedSnapshot` deterministically using only `paths` — never reading
    /// observer state for structure. This guarantees the post-state shape matches
    /// `oldCount + sectionInserts − sectionDeletes` (and per-section the same for
    /// items), so UIKit's batch-update validation passes by construction even if
    /// the observer has drifted past this diff.
    ///
    /// Algorithm: walk pre-state, drop deleted sections + per-section deleted/moved
    /// items, then insert new sections in post-state order, then place new items
    /// and move destinations in post-state order. UIKit's `performBatchUpdates`
    /// uses the same conceptual model.
    open func applyPathsToSnapshot(_ paths: CollectionUpdateIndexPaths) {
        let oldSnap = appliedSnapshot
        let deletedSections = Set(paths.sectionDeletes)

        // Capture keys at move-from positions in pre-state before any removals.
        var movedKeys: [IndexPath: ChannelViewModel.Key] = [:]
        for move in paths.moves {
            guard move.from.section < oldSnap.items.count,
                  move.from.item < oldSnap.items[move.from.section].count else { continue }
            movedKeys[move.to] = oldSnap.items[move.from.section][move.from.item]
        }

        // Group per-section item removals (deletes + move-froms) for fast filtering.
        var removedItemsBySection: [Int: Set<Int>] = [:]
        for ip in paths.deletes {
            removedItemsBySection[ip.section, default: []].insert(ip.item)
        }
        for move in paths.moves {
            removedItemsBySection[move.from.section, default: []].insert(move.from.item)
        }

        // Walk pre-state, keeping non-deleted sections (preserving their
        // identity) and within them non-deleted/non-moved items.
        var newSections: [ChannelViewModel.SectionId] = []
        var newItems: [[ChannelViewModel.Key]] = []
        newSections.reserveCapacity(oldSnap.sectionCount)
        newItems.reserveCapacity(oldSnap.sectionCount)
        for (preS, items) in oldSnap.items.enumerated() {
            guard !deletedSections.contains(preS) else { continue }
            let sectionId = oldSnap.sections[preS]
            let removed = removedItemsBySection[preS] ?? []
            newSections.append(sectionId)
            if removed.isEmpty {
                newItems.append(items)
            } else {
                var survivors: [ChannelViewModel.Key] = []
                survivors.reserveCapacity(items.count - removed.count)
                for (i, key) in items.enumerated() where !removed.contains(i) {
                    survivors.append(key)
                }
                newItems.append(survivors)
            }
        }

        // Insert new (post-state) sections in ascending order. Each insert shifts
        // the subsequent ones, which is correct for ascending traversal. The
        // section identity is read from the observer at the post-state index —
        // the observer has already advanced past this transition, so its
        // current `section[i]` corresponds to the post-state `section[i]`.
        for s in paths.sectionInserts.sorted() {
            let target = min(s, newSections.count)
            let sectionId = ChannelViewModel.SectionId(
                name: channelViewModel.sectionName(at: target)
            )
            newSections.insert(sectionId, at: target)
            newItems.insert([], at: target)
        }

        // Insert new items + move destinations in post-state ascending order.
        struct Insertion { let to: IndexPath; let key: ChannelViewModel.Key }
        var insertions: [Insertion] = []
        insertions.reserveCapacity(paths.inserts.count + paths.moves.count)
        for ip in paths.inserts {
            let key: ChannelViewModel.Key
            if let m = channelViewModel.message(at: ip) {
                key = .init(message: m)
            } else {
                // Defensive placeholder; cell will reload once content arrives.
                key = .init(messageId: 0)
            }
            insertions.append(.init(to: ip, key: key))
        }
        for (to, key) in movedKeys {
            insertions.append(.init(to: to, key: key))
        }
        insertions.sort { $0.to < $1.to }
        for ins in insertions {
            guard ins.to.section < newItems.count else { continue }
            let target = min(ins.to.item, newItems[ins.to.section].count)
            newItems[ins.to.section].insert(ins.key, at: target)
        }

        // Reloads don't change structure; cells re-fetch via cellForItemAt and
        // get the new content through the same key lookup.

        appliedSnapshot = AppliedSnapshot(sections: newSections, items: newItems)
    }

    /// Check whether `paths` can be applied on top of `appliedSnapshot` to reach
    /// the observer's current state. Returns `false` when intermediate diffs
    /// have been lost (e.g. Combine subscription dropped events before subscribe)
    /// — in that case the caller should rebuild from the observer instead.
    open func canReconcile(_ paths: CollectionUpdateIndexPaths) -> Bool {
        let observerSectionCounts = (0..<channelViewModel.numberOfSections).map {
            channelViewModel.numberOfMessages(in: $0)
        }
        return Self.canReconcile(
            snapshot: appliedSnapshot.items,
            observerSectionCounts: observerSectionCounts,
            paths: paths
        )
    }

    /// Pure-function implementation of `canReconcile`. Takes the snapshot and
    /// observer state explicitly so the validation logic can be unit-tested in
    /// isolation without a live `ChannelViewController` / `ChannelViewModel`.
    ///
    /// Validation passes (fail-fast, top to bottom):
    ///   1. Section count math (pre + sectionInserts − sectionDeletes == post).
    ///   2. Move-pair uniqueness (UIKit requires distinct sources, distinct destinations).
    ///   3. Pre-state index bounds (deletes, reloads, move-froms).
    ///   4. Post-state index bounds (inserts, move-tos).
    ///   5. Reload disjointness vs deletes and move-froms.
    ///   6. Delete vs move-from, insert vs move-to disjointness.
    ///   7. Per-section item count math (existing).
    ///
    /// Each pass eliminates a class of `NSInternalInconsistencyException`
    /// crash UIKit would otherwise raise from `performBatchUpdates`. See
    /// CAN_RECONCILE_HARDENING_PLAN.md and the test suite for the catalog.
    internal static func canReconcile(
        snapshot: [[ChannelViewModel.Key]],
        observerSectionCounts: [Int],
        paths: CollectionUpdateIndexPaths
    ) -> Bool {
        // 1. Section count.
        let expectedSections = snapshot.count
            + paths.sectionInserts.count
            - paths.sectionDeletes.count
        guard expectedSections == observerSectionCounts.count else {
            return false
        }

        // 2. Move-pair uniqueness.
        let moveSources = paths.moves.map(\.from)
        let moveDestinations = paths.moves.map(\.to)
        guard Set(moveSources).count == moveSources.count,
              Set(moveDestinations).count == moveDestinations.count else {
            return false
        }

        // 3. Pre-state index bounds. `deletes`, `reloads`, and `moves.from`
        // use pre-batch index paths — every index must point inside `snapshot`.
        for ip in paths.deletes {
            guard ip.section >= 0,
                  ip.section < snapshot.count,
                  ip.item >= 0,
                  ip.item < snapshot[ip.section].count
            else { return false }
        }
        for ip in paths.reloads {
            guard ip.section >= 0,
                  ip.section < snapshot.count,
                  ip.item >= 0,
                  ip.item < snapshot[ip.section].count
            else { return false }
        }
        for move in paths.moves {
            guard move.from.section >= 0,
                  move.from.section < snapshot.count,
                  move.from.item >= 0,
                  move.from.item < snapshot[move.from.section].count
            else { return false }
        }

        // 4. Post-state index bounds. `inserts` and `moves.to` use post-batch
        // index paths — every index must fit in the observer's claimed state.
        // `<=` is intentional for `item`: inserting at the end (item == count)
        // is valid; item > count is not.
        for ip in paths.inserts {
            guard ip.section >= 0,
                  ip.section < observerSectionCounts.count,
                  ip.item >= 0,
                  ip.item <= observerSectionCounts[ip.section]
            else { return false }
        }
        for move in paths.moves {
            guard move.to.section >= 0,
                  move.to.section < observerSectionCounts.count,
                  move.to.item >= 0,
                  move.to.item <= observerSectionCounts[move.to.section]
            else { return false }
        }

        // 5. Reload disjointness. UIKit raises NSException when an index path
        // appears in both `reloads` and `deletes`, or when a reload targets
        // an index that is also a move source.
        let deletedSet = Set(paths.deletes)
        let moveFromSet = Set(paths.moves.map(\.from))
        let moveToSet = Set(paths.moves.map(\.to))
        for ip in paths.reloads {
            if deletedSet.contains(ip) || moveFromSet.contains(ip) {
                return false
            }
        }

        // 6. Delete/insert vs move disjointness. An index path cannot be both
        // a delete and a move source, or both an insert and a move destination.
        for ip in paths.deletes where moveFromSet.contains(ip) { return false }
        for ip in paths.inserts where moveToSet.contains(ip) { return false }

        // 7. Per-section item count math. When no section ops, sections are
        // 1:1 pre-to-post — check each section directly. With section ops,
        // fall back to total-item comparison.
        if paths.sectionInserts.isEmpty, paths.sectionDeletes.isEmpty {
            for s in 0..<snapshot.count {
                let inS = paths.inserts.lazy.filter { $0.section == s }.count
                let outS = paths.deletes.lazy.filter { $0.section == s }.count
                let mIn = paths.moves.lazy.filter { $0.to.section == s && $0.from.section != s }.count
                let mOut = paths.moves.lazy.filter { $0.from.section == s && $0.to.section != s }.count
                let expected = snapshot[s].count + inS - outS + mIn - mOut
                if expected != observerSectionCounts[s] {
                    return false
                }
            }
        } else {
            let snapshotTotal = snapshot.reduce(0) { $0 + $1.count }
            let observerTotal = observerSectionCounts.reduce(0, +)
            if snapshotTotal + paths.inserts.count - paths.deletes.count != observerTotal {
                return false
            }
        }

        return true
    }

    // MARK: UICollectionViewDataSource

    open func numberOfSections(in collectionView: UICollectionView) -> Int {
        appliedSnapshot.sectionCount
    }

    open func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        guard section < appliedSnapshot.sectionCount else { return 0 }
        return appliedSnapshot.items[section].count
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {

        // Snapshot-first lookup: the data source counts and the cell binding
        // both come from `appliedSnapshot`, so the model we hand to the cell
        // always corresponds to the slot UIKit is asking about. The observer
        // fallbacks expect the view model's oldest-first index space.
        let dataIndexPath = dataIndexPath(fromUI: indexPath)
        let model = snapshotLayoutModel(at: indexPath)
            ?? dataIndexPath.flatMap { channelViewModel.layoutModel(at: $0) }
            ?? dataIndexPath.flatMap { channelViewModel.createLayoutModels(at: [$0]).first }

        guard let model = model else {
            logger.error("[MEESS] not found \(indexPath)")
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: Components.channelIncomingMessageCell.reuseId,
                for: indexPath
            )
            cell.transform = .mirrorY
            return cell
        }

        let cell = cellForItemAt(
            indexPath: indexPath,
            collectionView: collectionView,
            model: model
        )
        // Flip the cell back upright inside the mirrored collection view.
        cell.transform = .mirrorY
        return cell
    }
    
    open func cellForItemAt(
        indexPath: IndexPath,
        collectionView: UICollectionView,
        model: MessageLayoutModel
    ) -> UICollectionViewCell {
        let message = model.message

        // Handle system messages separately
        if model.isSystemMessage {
            let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.channelSystemMessageCell)
            cell.data = model
            return cell
        }

        let type: MessageCell.Type =
        model.message.incoming ?
        Components.channelIncomingMessageCell :
        Components.channelOutgoingMessageCell
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: type)
        cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.Cell.identifier(for: message.id)
        cell.parentAppearance = appearance.messageCellAppearance
        cell.isEditing = channelViewModel.isEditing
        if cell.isEditing {
            let canSelect = dataIndexPath(fromUI: indexPath).map { channelViewModel.canSelectMessage(at: $0) } ?? false
            cell.contentView.alpha = canSelect ? 1 : 0.5
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
            cell.highlightMode = .search
        } else if cell.highlightMode == .search {
            cell.highlightMode = .none
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
            case .playedAudio(_):
                self.channelViewModel.markMessages([model.message], as: .played)
            case .openedViewOnce(_):
                self.channelViewModel.markMessages([model.message], as: .opened)
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
            case .didTapPhoneNumber(let phoneNumber), .didLongPressPhoneNumber(let phoneNumber):
                self.didSelectPhoneNumber(phoneNumber, layoutModel: model)
            case .didSwipe:
                self.reply(layoutModel: model, in: false)
            case .didTapBottomAction:
                if model.message.poll != nil {
                    self.showPollResults(for: model)
                }
            case .didTapPollOption(let optionIndex, let pollViewModel):
                self.didTapPollOption(layoutModel: model, optionIndex: optionIndex, pollViewModel: pollViewModel)
            case .didTapReadMore:

                self.channelViewModel.invalidateLayout()
                // Invalidate the collection view layout
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.reloadData()
            }
        }
        cell.contextMenu = contextMenu
        channelViewModel.downloadMessageAttachmentsIfNeeded(layoutModel: model)
        return cell
    }

    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let dataIndexPath = dataIndexPath(fromUI: indexPath),
              channelViewModel.canSelectMessage(at: dataIndexPath)
        else { return }
        channelViewModel.didChangeSelection(for: dataIndexPath)
    }

    open func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let requestedKind: UICollectionView.SupplementaryViewKind =
            kind == UICollectionView.elementKindSectionHeader ? .header : .footer
        let cell = collectionView.dequeueReusableSupplementaryView(
            for: indexPath,
            cellType: Components.channelDateSeparatorView.self,
            kind: requestedKind
        )
        cell.parentAppearance = appearance.dateSeparatorAppearance
        if requestedKind == .footer {
            let dataSection = appliedSnapshot.sectionCount - 1 - indexPath.section
            cell.date = channelViewModel.separatorDateForMessage(
                at: IndexPath(item: 0, section: max(0, dataSection)),
                with: appearance.dateSeparatorAppearance
            )
        } else {
            cell.date = nil
        }
        cell.transform = .mirrorY
        return cell
    }
    
    // MARK: ChannelViewController.MessagesCollectionViewLayoutDelegate
    
    open func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = collectionView.bounds.width
        if let lm = snapshotLayoutModel(at: indexPath)
            ?? dataIndexPath(fromUI: indexPath).flatMap({ channelViewModel.layoutModel(at: $0) }) {
            return CGSize(width: width, height: lm.measureSize.height)
        }
        return CGSize(width: width, height: 38)
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
        .zero
    }

    open func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForFooterInSection section: Int
    ) -> CGSize {
        // Date separators render as footers in the mirrored list.
        let width = collectionView.bounds.width
        return appearance.enableDateSeparator ? CGSize(width: width, height: 40) : .zero
    }

    open func canPerformMessageActions(
        indexPath: IndexPath,
        point: CGPoint
    ) -> Bool {
        guard !channelViewModel.isThread,
              let dataIndexPath = dataIndexPath(fromUI: indexPath),
              let item = channelViewModel.message(at: dataIndexPath),
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
        let messageAction = channelViewModel.selectedMessageForAction

        // Validate link metadata - clear it if no link exists or if it's different from the current link
        var linkMetadata = customInputViewController.linkMetadata
        if let metadata = linkMetadata {
            let currentLink = customInputViewController.getLink()
            if currentLink == nil || currentLink != metadata.url {
                // Link metadata is stale - either no link exists or it's different
                linkMetadata = nil
            }
        }

        let m = UserSendMessage(
            sendText: shouldClearText ? inputTextView.attributedText : .init(),
            attachments: selectedMediaView.items,
            linkMetadata: linkMetadata,
            viewOnce: customInputViewController.isViewOnceEnabled
        )

        let isLinkPreviewVisible = customInputViewController.lastDetectedLinkMetadata != nil
                                  && !customInputViewController.didUserDismissLinkPreview
        m.didUserDismissLinkPreview = !isLinkPreviewVisible
        if let ma = messageAction {
            switch ma {
            case (let message, .reply):
                m.action = .reply(message)
            case (let message, .edit):
                m.action = .edit(message)
                m.type = message.type
                m.metadata = message.metadata
            default:
                break
            }
        }
        return m
    }
    
    open func sendMessage(_ message: UserSendMessage, shouldClearText: Bool = true) {
        userSelectOnRepliedMessage = nil
        logger.verbose("[MESSAGE SEND] sendMessage")
        let canShowUnread = canShowUnreadCountView
        canShowUnreadCountView = false
        // Already at the bottom: the mirrored anchor plus the animated batch
        // handle the insert (the bubble slides up from the input edge) — forcing
        // isScrollingBottom here would route the update through the suppressed,
        // animation-free path. Only a scrolled-up sender needs the explicit jump
        // back to the newest message.
        let wasAtBottom = collectionView.isAtBottom()
        if !wasAtBottom {
            isScrollingBottom = true
        }
        // Sending is explicit intent to land on the newest message — release the
        // scroll anchors armed by `.reloadDataAndScroll` (unread/search open).
        // A surviving pin makes the insert batch's completion restore the
        // pinned message's viewport offset, which for an at-bottom sender moves
        // the list off the bottom by the new bubble's height (hiding it under
        // the input bar) and suppresses the send animation. Edits and forwards
        // keep their anchors — they don't move the newest edge.
        if channelViewModel.selectedMessageForAction == nil ||
            channelViewModel.selectedMessageForAction?.1 == .reply {
            pinnedScrollMessageId = 0
            isStartedDragging = true
        }
        channelViewModel.createAndSendUserMessage(message)
        if shouldClearText {
            inputTextView.text = nil
            channelViewModel.updateDraftMessage(nil)
        }
        customInputViewController.selectedMediaView.removeAll()
        if channelViewModel.selectedMessageForAction == nil ||
            channelViewModel.selectedMessageForAction?.1 == .reply {
            UIView.animate(withDuration: 0.25) { [weak self] in
                self?.view.layoutIfNeeded()
            }
            if !wasAtBottom {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Prevents scrolling when the first message is sent.
                    if self.channelViewModel.numberOfSections != 0 {
                        self.scrollToBottom(animated: true)
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.canShowUnreadCountView = canShowUnread
            }
        }
        customInputViewController.removeActionView()
        channelViewModel.removeSelectedMessage()
    }
    
    open func info(layoutModel: MessageLayoutModel) {
        router.showMessageInfo(layoutModel: layoutModel, messageCellAppearance: appearance.messageCellAppearance)
    }
    
    open func report(layoutModel: MessageLayoutModel) {
        channelViewModel.report(layoutModel: layoutModel)
    }
    
    open func edit(layoutModel: MessageLayoutModel) {
        customInputViewController.addEdit(layoutModel: layoutModel)
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
            endMessagesSearchIfNeeded()
            UIView.animate(withDuration: 0.25) { [weak self] in
                guard let self else { return }
                self.inputTextView.becomeFirstResponder()
                self.view.layoutIfNeeded()
            } completion: { [weak self] _ in
                guard let self else { return }
                self.customInputViewController.addReply(layoutModel: layoutModel)
            }
        } else {
            
            showThreadForMessage(layoutModel.message)
        }
    }
    
    open func delete(
        layoutModel: MessageLayoutModel,
        type: DeleteMessageType = SceytChatUIKit.shared.config.hardDeleteMessageForAll ? .deleteHard : .deleteForEveryone
    ) {
        channelViewModel.deleteMessage(
            layoutModel: layoutModel,
            type: type
        )
    }
    
    open func tapReaction(layoutModel: MessageLayoutModel) {
        router.showReactions(
            message: layoutModel.message
        ).onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .removeReaction(let reaction):
                if self.channelViewModel.canDeleteReaction(message: layoutModel.message, key: reaction.key) {
                    self.presentedViewController?.dismiss(animated: true) { [weak self] in
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
    
    // MARK: - Poll Operations
    
    open func didTapPollOption(layoutModel: MessageLayoutModel, optionIndex: Int, pollViewModel: PollViewModel) {
        // Use the passed PollViewModel which reflects the current UI state
        // (including pending votes and optimistic updates)

        // Check if poll is closed
        guard !pollViewModel.closed else {
            // Optionally show poll results if closed
            return
        }

        // Check if there's a pending vote for this poll message
        guard !channelViewModel.hasPendingPollVote(for: layoutModel.message.id) else {
            return
        }

        // Validate option index
        guard optionIndex >= 0, optionIndex < pollViewModel.options.count else {
            return
        }

        impactFeedbackGenerator.impactOccurred()
        // Get the option from PollViewModel which reflects the current selection state
        // (including pending votes)
        let optionViewModel = pollViewModel.options[optionIndex]
        let isAlreadySelected = optionViewModel.isSelected

        if isAlreadySelected {
            channelViewModel.deletePollVote(
                layoutModel: layoutModel,
                pollViewModel: pollViewModel,
                optionId: optionViewModel.id
            )
        } else {
            channelViewModel.addPollVote(
                layoutModel: layoutModel,
                pollViewModel: pollViewModel,
                optionId: optionViewModel.id
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
    
    open func didSelectPhoneNumber(_ phoneNumber: String, layoutModel: MessageLayoutModel) {
        guard let phoneNumberLink = URL(string: "tel://\(phoneNumber)") else {
            return
        }
        self.router
            .showPhoneAlert(
                phoneNumber,
                actions: [(L10n.Message.Action.Title.call, .default), (L10n.Link.copy, .default)])
        { [weak self] actionTitle in
            if actionTitle == L10n.Message.Action.Title.call {
                self?.showLink(phoneNumberLink)
            } else if actionTitle == L10n.Link.copy {
                UIPasteboard.general.string = phoneNumber
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
    
    open func showPollResults(for layoutModel: MessageLayoutModel) {
        guard let poll = layoutModel.message.poll else { return }
        router.showPollResults(pollResults: poll, messageID: layoutModel.message.id)
    }
    
    open func showProfile(user: ChatUser) {
        channelViewModel.directChannel(user: user) { [weak self] channel, error in
            guard let self else { return }
            if let channel {
                self.router.showChannelInfoViewController(channel: channel)
            } else if let error {
                self.showAlert(error: error)
            }
        }
    }
    
    open func copy(layoutModel: MessageLayoutModel) {
        guard !layoutModel.message.body.isEmpty else {
            UIPasteboard.general.string = ""
            return
        }
        
        let attributedText = prepareAttributedTextForCopy(from: layoutModel)
        copyToPasteboard(attributedText, fallbackText: layoutModel.message.body)
    }
    
    /// Prepares attributed text for copying by normalizing colors and removing underlines from URLs
    /// - Parameter layoutModel: The message layout model containing the content
    /// - Returns: A mutable attributed string ready for copying
    private func prepareAttributedTextForCopy(from layoutModel: MessageLayoutModel) -> NSMutableAttributedString {
        let attr = layoutModel.attributedView.content.mutableCopy() as! NSMutableAttributedString

        // Process links and phone numbers
        for item in layoutModel.attributedView.items {
            let range = item.range
            guard isValidRange(item.range, in: attr.length) else { continue }
            
            switch item {
            case .link(_, let url):
                if let url = url {
                    resetLinkTextColor(from: attr, at: item.range)
                    removeUnderline(from: attr, at: item.range)
                }
                
            case .phone(_, let phoneNumber):
                if let phoneNumber = phoneNumber, !phoneNumber.isEmpty {
                    resetLinkTextColor(from: attr, at: item.range)
                    removeUnderline(from: attr, at: item.range)
                }
                break
            case .mention:
                break
            }
        }
        return attr
    }
    
    /// Validates that a range is within the bounds of the string
    /// - Parameters:
    ///   - range: The range to validate
    ///   - length: The length of the string
    /// - Returns: True if the range is valid, false otherwise
    private func isValidRange(_ range: NSRange, in length: Int) -> Bool {
        return range.location >= 0 &&
               range.length > 0 &&
               range.location + range.length <= length
    }
    
    /// Removes underline styling from the specified range in the attributed string
    /// - Parameters:
    ///   - attributedString: The attributed string to modify
    ///   - range: The range where underline should be removed
    private func removeUnderline(from attributedString: NSMutableAttributedString, at range: NSRange) {
        if attributedString.attribute(.underlineStyle, at: range.location, effectiveRange: nil) != nil {
            attributedString.removeAttribute(.underlineStyle, range: range)
            attributedString.removeAttribute(.underlineColor, range: range)
        }
    }
    
    /// Resets link styling color from the specified range in the attributed string
    /// - Parameters:
    ///   - attributedString: The attributed string to modify
    ///   - range: The range where link should be reseted
    private func resetLinkTextColor(from attributedString: NSMutableAttributedString, at range: NSRange) {
        if attributedString.attribute(.underlineStyle, at: range.location, effectiveRange: nil) != nil {
            attributedString.removeAttribute(.foregroundColor, range: range)
            attributedString.addAttribute(.foregroundColor, value: inputTextView.textColor, range: range)
        }
    }
    
    /// Copies attributed text to the pasteboard with multiple format support
    /// - Parameters:
    ///   - attributedText: The attributed text to copy
    ///   - fallbackText: Plain text fallback if archiving fails
    private func copyToPasteboard(_ attributedText: NSAttributedString, fallbackText: String) {
        let pasteboard = UIPasteboard.general
        
        guard let archivedData = try? NSKeyedArchiver.archivedData(withRootObject: attributedText, requiringSecureCoding: false) else {
            pasteboard.string = fallbackText
            return
        }
        
        if #available(iOS 14.0, *) {
            var items: [String: Any] = [
                UTType.plainText.identifier: attributedText.string,
                "com.sceyt.attributedstring": archivedData
            ]
            pasteboard.items = [items]
        } else {
            do {
                try pasteboard.set(attributedText)
            } catch {
                pasteboard.string = fallbackText
            }
        }
    }
    
    open func showReply(layoutModel: MessageLayoutModel) {
        guard let parent = layoutModel.message.parent
        else { return }
        pinnedScrollMessageId = 0
        userSelectOnRepliedMessage = layoutModel.message
        channelViewModel.findReplayedMessage(messageId: parent.id)
    }
    
    open func showRepliedMessage(_ message: ChatMessage) {
        let paths = channelViewModel.indexPaths(for: [message])
        guard let dataPath = paths.values.first,
              let indexPath = uiIndexPath(fromData: dataPath) else {
            channelViewModel.findReplayedMessage(messageId: message.id)
            return
        }
        if let userSelectOnRepliedMessage {
            NotificationCenter.default.post(name: .selectMessage,
                                            object: (userSelectOnRepliedMessage.id, MessageCell.HighlightMode.none))
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Deliberately no highlight on this jump: it returns the user from the
            // original message back to the reply. The original was already
            // highlighted when navigating from the reply — flashing the reply
            // bubble here would read as a second, confusing highlight.
            UIView.animate(withDuration: 0.3, delay: 0, options: .allowUserInteraction) { [weak self] in
                guard let self else { return }
                self.collectionView.scrollToItem(at: indexPath, pos: .centeredVertically, animated: false)
            }
        }
    }
    
    open func animateHighlightCell(_ cell: MessageCell, mode: MessageCell.HighlightMode) {
        cell.highlightMode = mode
        UIView.animate(withDuration: highlightedDurationForReplyMessage) { [weak cell] in
            cell?.highlightMode = .none
        }
    }

    open func animateHighlightCell(_ cell: SystemMessageCell, mode: MessageCell.HighlightMode) {
        cell.highlightMode = mode
        UIView.animate(withDuration: highlightedDurationForReplyMessage) { [weak cell] in
            cell?.highlightMode = .none
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
        let messages = collectionView.visibleCells.compactMap {
            ($0 as? MessageCell)?.data?.message
        }
        if messages.count == collectionView.indexPathsForVisibleItems.count {
            channelViewModel.markMessages(messages, as: .displayed)
        } else {
            // The view model expects oldest-first index paths.
            let dataPaths = collectionView.indexPathsForVisibleItems.compactMap {
                dataIndexPath(fromUI: $0)
            }
            channelViewModel.markMessage(as: .displayed, indexPaths: dataPaths)
        }
    }

    private func scheduleMarkDisplayed() {
        guard isViewDidAppear, isAppActive else { return }
        markDisplayedWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  !self.isCollectionViewUpdating,
                  self.isAppActive,
                  self.isViewDidAppear
            else { return }
            self.markMessageAsDisplayed()
        }
        markDisplayedWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + markDisplayedDebounceInterval, execute: work)
    }

    private func cancelPendingMarkDisplayed() {
        markDisplayedWorkItem?.cancel()
        markDisplayedWorkItem = nil
    }
    
    // MARK: ViewModel Events

    /// Drain a queued update after a prior batch finished. Invoked from
    /// `isCollectionViewUpdating.didSet`. Routes back into `onEvent` so the
    /// same reconciliation + queueing path is exercised — in particular, if
    /// observer state has drifted further by the time we drain, the
    /// reconciliation gate will catch it and rebuild.
    private func applyPendingUpdate(_ update: PendingUpdate) {
        switch update {
        case .diff(let paths):
            onEvent(.update(paths: paths))
        case .rebuild:
            rebuildAppliedSnapshotFromObserver()
            collectionView.reloadData()
            updateUnreadViewVisibility()
            showEmptyViewIfNeeded()
        }
    }

    open func onEvent(_ event: ChannelViewModel.Event) {
        switch event {
        case .update(let paths):
            // Single-flight queue. If a batch is animating, the just-arrived
            // diff could fire UIKit's "operations queued while a batch is in
            // flight" misbehavior. Park it and drain after the batch finishes
            // (see isCollectionViewUpdating.didSet → applyPendingUpdate →
            // onEvent(.update)). The cached `paths` is replayed only for its
            // policy hints (continuesOptions, etc.); a fresh diff is computed
            // against the latest observer state at drain time.
            if isCollectionViewUpdating {
                pendingUpdate = .diff(paths)
                return
            }

            // ── Snapshot-diff pipeline (Phase 2/3 of SNAPSHOT_DIFF_MIGRATION_PLAN.md). ──
            // Build the target snapshot from the observer NOW, then compute a
            // fresh diff against the currently-applied snapshot. The diff is a
            // pure function of the two snapshots, so the batch-update math is
            // consistent by construction — no matter how many intermediate
            // observer events were coalesced or how stale `paths` has become.
            let newSnapshot = buildSnapshotFromObserver()
            // Observer/VM reload hints arrive in DATA space (oldest-first), but
            // computeDiff sanitizes hints as pre-state positions in the MIRRORED
            // `appliedSnapshot` — convert before diffing, while `appliedSnapshot`
            // is still the pre-state. Hints that don't fit the applied bounds are
            // dropped; the contentVersion diff inside computeDiff covers those.
            let reloadHints = Set(paths.reloads.compactMap { uiIndexPath(fromData: $0) })
            let diff = Self.computeDiff(
                from: appliedSnapshot,
                to: newSnapshot,
                reloadHints: reloadHints
            )

            // No structural or content change → cheap exit. Keeps the
            // single-flight queue from spinning on no-op events.
            guard !diff.isEmpty else {
                return
            }

            // Note: we deliberately do NOT validate `diff` against the legacy
            // `canReconcile` gate. canReconcile's section-ops fallback uses a
            // total-item-count check that has false positives when sections
            // come/go, and its reload-disjointness pass collides with stale
            // observer reload hints that computeDiff filters separately. The
            // diff is correct by construction (covered by the property tests
            // in `SnapshotDiffTests`); the NSException catch in
            // `MessagesCollectionView.performUpdates` is the runtime safety net.

            // Policy hints — derive from the freshly-computed diff (structural
            // ops the user will actually see).
            let diffInserts = diff.inserts
            let diffMoves = diff.moves
            var needsToScrollBottom = false

            showEmptyViewIfNeeded()

            if let unreadMessageIndexPath, checkOnlyFirstTimeReceivedMessagesFromArchive {
                checkOnlyFirstTimeReceivedMessagesFromArchive = false
                if diffInserts.count == 1,
                   collectionView.isAtBottom() {
                    isStartedDragging = true
                } else {
                    rebuildAppliedSnapshotFromObserver()
                    // Same absolute position as the initial `.reloadDataAndScroll`
                    // unread branch, recomputed from fresh layout attributes — so
                    // when this fires on the first post-initial update (async
                    // preload, marker change) it is an idempotent re-assert, not
                    // a jump, and it corrects any drift from that insert.
                    if let uiPath = uiIndexPath(fromData: unreadMessageIndexPath) {
                        collectionView.reloadDataAndScrollToUnreadSeparator(
                            at: uiPath,
                            separatorHeight: unreadSeparatorHeight,
                            offsetFromVisualTop: Self.unreadSeparatorScrollOffsetFromTop)
                    } else {
                        collectionView.reloadData()
                    }
                    return
                }
            }

            if checkOnlyFirstTimeReceivedMessagesFromArchive, !isViewDidAppear,
               pinnedScrollMessageId == 0 {
                // Pre-viewDidAppear path: skip the structural update so the
                // navigation transition doesn't jank. We only enter this
                // branch when nothing is pinned — when a pin IS active
                // (e.g. scrollToMessageId), we MUST process the update so
                // the capture-restore below can keep the pinned message at
                // its visible offset (otherwise the prev pagination would
                // arrive while we ignore it, then leak through later
                // events with the viewport already drifted).
                checkOnlyFirstTimeReceivedMessagesFromArchive = false
                if channelViewModel.scrollToRepliedMessageId == 0 {
                    rebuildAppliedSnapshotFromObserver()
                    collectionView.reloadDataAndScrollToBottom()
                }
                updateUnreadViewVisibility()
                return
            }
            // If we reached here with the first-archive flag still set, clear
            // it — we're about to apply the update normally.
            checkOnlyFirstTimeReceivedMessagesFromArchive = false
            // Mirrored list: UI IndexPath(0,0) is the NEWEST edge (visual bottom).
            // Inserts there are new incoming/outgoing messages. Older-message
            // pagination lands at the content END in the mirrored order and needs
            // no offset handling at all — the anchor is the newest edge.
            let isInsertingNewestItems =
                diff.sectionInserts.contains(0)
                || diff.inserts.contains(IndexPath(item: 0, section: 0))

            // Offset-based bottom check: in the mirrored space the bottom is a
            // constant offset, so no indexPath comparison is needed.
            let isUserAtBottom = collectionView.isAtBottom()

            // With the mirrored anchor, a user at the bottom follows new messages
            // automatically — UIKit keeps contentOffset stable while the new item
            // materializes at the anchor. Explicit scrolling remains only for an
            // in-flight scroll-to-bottom tap.
            let animatedScroll = diffInserts.count == 1
            if isScrollingBottom {
                needsToScrollBottom = true
            } else if isUserAtBottom, isInsertingNewestItems, !channelViewModel.isSearching {
                // Parity with the pre-mirror behavior: receiving a message while
                // reading at the bottom counts as interaction (clears the unread
                // anchor state); no scroll is needed.
                isStartedDragging = true
                // The bottom anchor wins over the position pin armed by the
                // unread/search open: a user at the bottom follows new messages.
                // Keeping the pin here would make the completion's pin-restore
                // hold the pinned message still — shifting the viewport off the
                // bottom by the new bubble's height, hiding it under the input
                // bar — and would suppress the newest-insert animation.
                pinnedScrollMessageId = 0
            }

            if userSelectOnRepliedMessage != nil || unreadMessageIndexPath != nil || pinnedScrollMessageId != 0 {
                needsToScrollBottom = false
            }

            let contentHeightBeforeInsertion = collectionView.contentSize.height
            // Capture the pin's pre-batch viewport offset using the CV's
            // current data source — the observer may already point at the
            // post-update indexPath whose section the CV doesn't know about
            // yet. Restored in the completion below so the pinned message
            // stays at the same viewport position across structural updates.
            let pinnedVisibleOffsetBefore = pinnedMessageVisibleOffset()

            // New messages land at the content-space top. When the user is
            // scrolled up reading history (and no pin is active — the pin
            // restore below handles that case exactly), ask the layout for an
            // atomic contentOffset compensation so the reading position holds.
            // At the bottom: no compensation, no scroll — the anchor does it.
            let needsNewestInsertCompensation =
                isInsertingNewestItems
                && !isUserAtBottom
                && !isScrollingBottom
                && pinnedScrollMessageId == 0
                && contentHeightBeforeInsertion > 0

            // A new message arriving while the user watches the bottom is the one
            // update that SHOULD animate: the batch runs with UIKit's default
            // animation — the new bubble slides up from the input edge (see the
            // layout's initialLayoutAttributesForAppearingItem) while previous
            // messages shift up. Every other update stays animation-free.
            let animatesNewestInsert =
                isInsertingNewestItems
                && isUserAtBottom
                && !isScrollingBottom
                && pinnedScrollMessageId == 0
                && userSelectOnRepliedMessage == nil
                && unreadMessageIndexPath == nil
                && contentHeightBeforeInsertion > 0

            if isInsertingNewestItems {
                logger.debug("""
                    [MSGANIM] inserts=\(diffInserts.count) atBottom=\(isUserAtBottom) \
                    animate=\(animatesNewestInsert) compensate=\(needsNewestInsertCompensation) \
                    scrollingBottom=\(isScrollingBottom) pinned=\(pinnedScrollMessageId) \
                    offset=\(collectionView.contentOffset.y) bottom=\(collectionView.bottomContentOffsetY) \
                    needScroll=\(needsToScrollBottom) unread=\(unreadMessageIndexPath != nil)
                    """)
            }

            isCollectionViewUpdating = true
            if !animatesNewestInsert {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
            }

            // The atomic adjustment runs via targetContentOffset(forProposedContentOffset:)
            // in the same layout pass as the batch, preventing the one-frame jump
            // that even CATransaction's disabled actions can't suppress
            // (UICollectionView's batch animations are driven by UIView.animate,
            // not CALayer implicit animations).
            if needsNewestInsertCompensation {
                collectionView.layout.preBatchContentHeight = collectionView.contentSize.height
                collectionView.layout.isAdjustingForTopInserts = true
            }

            let updates: () -> Void = { [weak self] in
                guard let self = self else { return }
                // UIKit ops come from the fresh diff, not the observer's paths.
                // The diff was computed from `(appliedSnapshot, newSnapshot)`,
                // so the batch math holds by construction.
                if !diff.sectionInserts.isEmpty {
                    self.collectionView.insertSections(diff.sectionInserts)
                }
                if !diff.sectionDeletes.isEmpty {
                    self.collectionView.deleteSections(diff.sectionDeletes)
                }
                if !diff.inserts.isEmpty {
                    self.collectionView.insertItems(at: diff.inserts)
                }
                if !diff.reloads.isEmpty {
                    if #available(iOS 15.0, *) {
                        self.collectionView.reconfigureItems(at: diff.reloads)
                    } else {
                        self.collectionView.reloadItems(at: diff.reloads)
                    }
                }
                if !diff.deletes.isEmpty {
                    self.collectionView.deleteItems(at: diff.deletes)
                }
                for move in diff.moves {
                    self.collectionView.moveItem(at: move.from, to: move.to)
                }
                // The new snapshot was already computed when we built `diff`,
                // so assignment is sufficient — no observer reads at apply time.
                self.appliedSnapshot = newSnapshot
            }

            let completion: (Bool) -> Void = { [weak self] finished in
                if !animatesNewestInsert {
                    CATransaction.commit()
                }
                var scrollBottom = false
                defer {
                    if let self = self {
                        self.isCollectionViewUpdating = false
                        if scrollBottom {
                            self.scrollToBottom(animated: animatedScroll)
                        }
                    }
                }

                guard let self = self else { return }

                // Phase 4: if the animation was interrupted (view dismissed,
                // user scroll cancelled it, etc.), UIKit's internal state may
                // not match `appliedSnapshot`. Rebuild from the observer and
                // reload to recover deterministically.
                if !finished {
                    self.appliedSnapshot = self.buildSnapshotFromObserver()
                    self.collectionView.reloadData()
                    self.updateUnreadViewVisibility()
                    return
                }

                if let pinnedVisibleOffsetBefore,
                   self.restorePinnedMessageToVisibleOffset(pinnedVisibleOffsetBefore) {
                    // Pin restored at its previous viewport offset.
                } else if contentHeightBeforeInsertion == 0 {
                    // First batch into an empty collection: land on the newest
                    // message. In the mirrored list that is a constant offset.
                    self.collectionView.scrollToBottom(animated: false)
                }
                // For all other paths nothing to fix up: older-message pagination
                // grows content away from the anchor, and newest inserts either
                // stay anchored (user at bottom) or were compensated atomically
                // by the layout (user scrolled up).

                // Move destinations don't always trigger cellForItemAt during the batch,
                // so reload them here (diff.reloads were already applied by the parent batch).
                // Validate against the applied snapshot — it IS the collection view's
                // data source truth, in the same (mirrored) index space as the diff.
                let moveDestinations = diffMoves.map(\.to)
                if !moveDestinations.isEmpty {
                    let sectionCount = self.appliedSnapshot.sectionCount
                    let validReloads = moveDestinations.filter { indexPath in
                        indexPath.section < sectionCount &&
                        indexPath.item < self.appliedSnapshot.items[indexPath.section].count
                    }
                    if !validReloads.isEmpty {
                        UIView.performWithoutAnimation {
                            self.collectionView.reloadItems(at: validReloads)
                        }
                    }
                }

                if needsToScrollBottom, !(self.collectionView.isDragging || self.collectionView.isDecelerating) {
                    scrollBottom = true
                } else {
                    self.updateUnreadViewVisibility()
                }
            }

            // Phase 4 workarounds: flush pending layout (radar #28167779) and,
            // for compensated newest-edge inserts, wrap in UIView.animate(duration: 0)
            // to dodge UIKit's "preparing update visible view wasn't found"
            // crash class.
            collectionView.layoutIfNeeded()
            if needsNewestInsertCompensation {
                UIView.animate(withDuration: 0) { [weak self] in
                    self?.collectionView.performUpdates(updates, completion: completion)
                }
            } else if animatesNewestInsert {
                UIView.animate(
                    withDuration: 0.25,
                    delay: 0,
                    options: [.curveEaseOut, .allowUserInteraction]
                ) { [weak self] in
                    self?.collectionView.performUpdates(updates, completion: completion)
                }
            } else {
                collectionView.performUpdates(updates, completion: completion)
            }

        case .updateDeliveryStatus(let model, let indexPath):
            if let uiPath = uiIndexPath(fromData: indexPath),
               let cell = collectionView.cell(for: uiPath, cellType: MessageCell.self),
               cell.data?.message.id == model.message.id {
                cell.deliveryStatus = model.messageDeliveryStatus
            } else {
                NotificationCenter.default.post(name: .didUpdateDeliveryStatus, object: model)
            }
        case .pumpPrevPagination:
            // Defer until the current batch update settles — addMoreMessage relies on
            // up-to-date collection view counts, and isCollectionViewUpdating is the gate.
            if isCollectionViewUpdating {
                hasPendingPrevPagePump = true
            } else {
                addMoreMessage(scrollDirection: .up, force: false)
            }
        case .providerFinishedPrevPagination(let beforeMessageId):
            // Server page just landed in CoreData under a freshly-stored range. The
            // observer's predicate was set before the response, so new rows are
            // filtered out until we re-expand it via fetchPrevMessagesFromDB.
            // Defer mid-scroll so the insert doesn't jank inertia.
            if collectionView.isDecelerating || collectionView.isDragging {
                pendingPrevDBFetchBeforeId = beforeMessageId
            } else {
                channelViewModel.fetchPrevMessagesFromDB(before: beforeMessageId)
            }
        case .reloadData:
            if let selectMessageId, let indexPath = channelViewModel.indexPathOf(messageId: selectMessageId) {
                onEvent(.reloadDataAndSelect(indexPath: indexPath, messageId: selectMessageId))
            } else if pinnedScrollMessageId != 0 {
                let savedOffset = collectionView.contentOffset
                let pinnedVisibleOffsetBefore = pinnedMessageVisibleOffset()
                rebuildAppliedSnapshotFromObserver()
                collectionView.reloadData()
                collectionView.layoutIfNeeded()
                if let pinnedVisibleOffsetBefore,
                   restorePinnedMessageToVisibleOffset(pinnedVisibleOffsetBefore) {
                    // Pin restored at its previous viewport offset.
                } else {
                    // Mirrored list: content growth at the older end doesn't move
                    // the visual position, so keep the offset (clamped).
                    collectionView.contentOffset.y = min(
                        max(savedOffset.y, collectionView.bottomContentOffsetY),
                        collectionView.maxContentOffsetY
                    )
                }
            } else {
                rebuildAppliedSnapshotFromObserver()
                collectionView.reloadData()
            }
            updateUnreadViewVisibility()
            showEmptyViewIfNeeded()
        case .reload(let indexPaths):
            // Reloads don't change snapshot identifiers, only cell content. The
            // paths arrive in the view model's oldest-first space; conversion into
            // the mirrored UI space also bounds-checks against the applied
            // snapshot — defensive, since these paths were computed against an
            // earlier observer state.
            let safePaths = indexPaths.compactMap { uiIndexPath(fromData: $0) }
            if !safePaths.isEmpty {
                UIView.performWithoutAnimation { [weak self] in
                    guard let self else { return }
                    self.collectionView.performUpdates {
                        self.collectionView.reloadItems(at: safePaths)
                    }
                }
            }
            showEmptyViewIfNeeded()
        case .reloadDataAndScrollToBottom:
            if pinnedScrollMessageId != 0 {
                let pinnedVisibleOffsetBefore = pinnedMessageVisibleOffset()
                rebuildAppliedSnapshotFromObserver()
                collectionView.reloadData()
                collectionView.layoutIfNeeded()
                if let pinnedVisibleOffsetBefore,
                   restorePinnedMessageToVisibleOffset(pinnedVisibleOffsetBefore) {
                    // Pin restored at its previous viewport offset.
                } else {
                    collectionView.scrollToBottom(animated: false)
                }
            } else {
                rebuildAppliedSnapshotFromObserver()
                collectionView.reloadDataAndScrollToBottom()
            }
            // The first message in a brand-new (unSynched) channel arrives via a
            // full reload-and-scroll-to-bottom after the observer is restarted for
            // the freshly-created channel id. Without re-evaluating here, the
            // "No messages yet" empty state stays visible and overlaps the message
            // (siblings .reloadData / .reloadDataAndScroll already do this).
            showEmptyViewIfNeeded()
        case let .reloadDataAndScroll(indexPath, animated, pos):
            rebuildAppliedSnapshotFromObserver()
            // The view model sends its oldest-first path and a visual position;
            // both are translated into the mirrored space here.
            if let uiPath = uiIndexPath(fromData: indexPath) {
                // Opening on unread: don't center the last-read message — pin the
                // "New messages" bar at a fixed distance below the visual top so
                // the screen fills with unread messages. Positioned from the
                // anchor cell's layout frame (scrollToItem can only align cell
                // edges, which leaves the bar's spot dependent on bubble height).
                let isUnreadAnchor = channelViewModel.scrollToRepliedMessageId == 0
                    && channelViewModel.scrollToUnreadMentionMessageId == 0
                    && channelViewModel.lastDisplayedMessageId != 0
                    && channelViewModel.message(at: indexPath)?.id == channelViewModel.lastDisplayedMessageId
                if isUnreadAnchor {
                    collectionView.reloadDataAndScrollToUnreadSeparator(
                        at: uiPath,
                        separatorHeight: unreadSeparatorHeight,
                        offsetFromVisualTop: Self.unreadSeparatorScrollOffsetFromTop)
                } else {
                    collectionView.reloadDataAndScrollTo(
                        indexPath: uiPath,
                        pos: uiScrollPosition(pos),
                        animated: animated)
                }
            } else {
                collectionView.reloadData()
            }
            // Anchor the just-scrolled message so prev/next/near fetches that follow
            // don't drift the viewport. Released on scrollViewWillBeginDragging.
            if let messageId = channelViewModel.message(at: indexPath)?.id, messageId != 0 {
                pinnedScrollMessageId = messageId
            }
            updateUnreadViewVisibility()
            showEmptyViewIfNeeded()
        case .didSetUnreadIndexPath(let indexPath):
            unreadMessageIndexPath = indexPath
        case .typing(let isTyping, let user):
            if !channelViewModel.channel.isDirect {
                if showTyping(channel: channelViewModel.channel, user: user, isTyping: isTyping) == 0 {
                    updateTitle()
                }
            } else {
                if isTyping {
                    _ = showTyping(channel: channelViewModel.channel, user: user, isTyping: isTyping)
                } else {
                    updateTitle()
                }
            }
        case .recording(let isRecording, let user):
            if !channelViewModel.channel.isDirect {
                if showRecording(channel: channelViewModel.channel, user: user, isRecording: isRecording) == 0 {
                    updateTitle()
                }
            } else {
                if isRecording {
                    _ = showRecording(channel: channelViewModel.channel, user: user, isRecording: isRecording)
                } else {
                    updateTitle()
                }
            }
        case .changePresence(let userPresence):
            DispatchQueue.main.async { [weak self] in
                guard let self
                else { return }
                switch self.titleView.mode {
                case .default:
                    self.showTitle(title: self.channelViewModel.getTitleForHeader(with: appearance.headerAppearance),
                                   subTitle: self.channelViewModel.getSubtitleForHeader(with: appearance.headerAppearance))
                case .typing, .recording:
                    // Force the view to update
                    self.titleView.mode = self.titleView.mode
                }
            }
            
        case .updateChannel:
            updateTitle()
            updateJoinButtonVisibility()
            showBottomViewIfNeeded()
            showEmptyViewIfNeeded()
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
                reloadNearMessages()
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
                    color: UIColor.stateWarning
                )
            @unknown default:
                break
            }
        case let .scrollAndSelect(indexPath, messageId, mentionMode):
            // The pin is already on this message — the model is re-firing
            // scroll/select because scrollToRepliedMessageId hasn't been
            // cleared yet (it's cleared 1 s later via resetStateAfterChangeEvent).
            // Re-scrolling would yank the viewport to .centeredVertically and
            // undo the position we just preserved. Skip.
            if pinnedScrollMessageId == messageId, messageId != 0 {
                return
            }
            pinnedScrollMessageId = messageId
            // The view model's oldest-first path mapped into the mirrored UI space.
            let uiPathCandidate = uiIndexPath(fromData: indexPath)
            if selectMessageId == messageId,
               let uiPathCandidate,
               lastAnimatedIndexPath == uiPathCandidate,
               collectionView.visibleAttributes.contains(where: {$0.indexPath == uiPathCandidate}) {
                return
            }
            var mode = mentionMode ?? MessageCell.HighlightMode.search
            if channelViewModel.scrollToRepliedMessageId != 0 {
                if userSelectOnRepliedMessage != nil {
                    mode = .reply
                } else {
                    mode = .none
                }
                selectMessageId = nil
            } else {
                selectMessageId = messageId
            }
            var delayToSelect: TimeInterval = 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + delayToSelect) {
                NotificationCenter.default.post(name: .selectMessage, object: (messageId, mode))
            }
            
            if mode == .reply || mode == .mention {
                DispatchQueue.main.asyncAfter(deadline: .now() + highlightedDurationForReplyMessage + delayToSelect) {
                    NotificationCenter.default.post(name: .selectMessage, object: (messageId, MessageCell.HighlightMode.none))
                }
            }
            let viewIndexPath: IndexPath
            if let uiPathCandidate {
                viewIndexPath = uiPathCandidate
            } else if let dataPath = channelViewModel.indexPathOf(messageId: messageId),
                      let uiPath = uiIndexPath(fromData: dataPath) {
                viewIndexPath = uiPath
            } else {
                return
            }

            lastAnimatedIndexPath = viewIndexPath
            collectionView.scrollToItem(at: viewIndexPath, pos: .centeredVertically, animated: mode != .mention)
            searchControlsView
                .update(
                    with: channelViewModel.searchResult,
                    query: self.searchBar.searchTextField.text ?? ""
                )
            //ReSelect after animation
        case let .reloadDataAndSelect(indexPath, messageId):
            // Visual intent: .top shows the hit near the visual top. Translated
            // into the mirrored content space via uiScrollPosition below.
            var pos: CollectionView.ScrollPosition {
                switch channelViewModel.searchDirection {
                case .none:
                    return .centeredVertically
                case .next:
                    return .top
                case .prev:
                    return .bottom
                }
            }
            rebuildAppliedSnapshotFromObserver()
            let uiPath = uiIndexPath(fromData: indexPath)
            if let uiPath {
                collectionView.reloadDataAndScrollTo(
                    indexPath: uiPath,
                    pos: uiScrollPosition(pos)
                )
            } else {
                collectionView.reloadData()
            }
            // Anchor the restarted-to message so subsequent prev/next/near fetches
            // keep it on screen. Released on scrollViewWillBeginDragging.
            if messageId != 0 {
                pinnedScrollMessageId = messageId
            }

            lastAnimatedIndexPath = uiPath
            var mode = MessageCell.HighlightMode.search
            if channelViewModel.scrollToRepliedMessageId != 0 {
                if userSelectOnRepliedMessage != nil {
                    mode = .reply
                } else {
                    mode = .none
                }
                selectMessageId = nil
            } else {
                selectMessageId = messageId
            }
            NotificationCenter.default.post(name: .selectMessage, object: (messageId, mode))
            if let uiPath {
                collectionView.scrollToItem(at: uiPath, pos: .centeredVertically, animated: true)
            }
            showEmptyViewIfNeeded()
        }
    }
    
    open func showEmptyViewIfNeeded() {
        emptyStateView.isHidden =
        !channelViewModel.hasLoadedInitialMessages
        || channelViewModel.numberOfSections > 0
        || channelViewModel.scrollToMessageIdIfSearching != 0
        || channelViewModel.scrollToRepliedMessageId != 0
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
            bottomView.pin(to: customInputViewController.view, anchors: [.leading, .top, .trailing, .bottom])
            bottomView.icon = icon
            bottomView.message = message
            customInputViewController.shouldHideRecordButton = true
            customInputViewController.addMediaButton.isHidden = true
            customInputViewController.sendButton.isHidden = true
            customInputViewController.recordButton.isHidden = true
            customInputViewController.selectedMediaView.isHidden = true
            customInputViewController.actionView.isHidden = true
        } else {
            bottomView.removeFromSuperview()
            customInputViewController.shouldHideRecordButton = false
            customInputViewController.addMediaButton.isHidden = false
            customInputViewController.updateState()
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
    
    open func showEndPollAlert(for layoutModel: MessageLayoutModel) {
        guard let pollDetails = layoutModel.message.poll else { return }
        let pollViewModel = PollViewModel(from: pollDetails, isIncmoing: layoutModel.message.incoming)

        showAlert(
            title: L10n.Poll.EndPoll.Alert.title,
            message: L10n.Poll.EndPoll.Alert.message,
            actions: [
                .init(title: L10n.Alert.Button.cancel, style: .cancel),
                .init(title: L10n.Poll.EndPoll.Alert.end, style: .destructive) { [weak self] in
                    self?.channelViewModel.closePoll(
                        layoutModel: layoutModel,
                        pollViewModel: pollViewModel
                    ) { [weak self] error in
                        if let error = error {
                            self?.showAlert(error: error)
                        }
                    }
                }
            ],
            preferredActionIndex: 1
        )
    }

    private var isShowingRecordDiscardAlert = false
    open func showRecordDiscardAlertIfNeeded() {
        guard customInputViewController.isRecording,
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
                    self?.customInputViewController.recorderView.stopAndPreview()
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
        
        // Disable context menu for unsupported messages
        if model.contentOptions.contains(.unsupported) {
            return false
        }
        
        return true
    }
    
    open func canShowEmojis(contextMenu: ContextMenu, identifier: Identifier) -> (canShowEmojis: Bool, emojisViewAppearance: ReactionPickerViewController.Appearance) {
        guard let model = identifier.value as? MessageLayoutModel
        else { return (false, appearance.reactionPickerAppearance) }
        
        // Disable emojis for unsupported messages
        if model.contentOptions.contains(.unsupported) {
            return (false, appearance.reactionPickerAppearance)
        }
        
        return (![.pending, .failed].contains(model.message.deliveryStatus), appearance.reactionPickerAppearance)
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
        
        // Disable context menu for unsupported messages
        if model.contentOptions.contains(.unsupported) {
            return []
        }
        
        var isPoll = model.message.poll != nil
        var items: [MenuItem] = []
        if !isPoll {
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
                )
            ]
        }
        
        if isPoll {
            let pollViewModel: PollViewModel?
            if let pollDetails = model.message.poll {
                pollViewModel = PollViewModel(from: pollDetails, isIncmoing: model.message.incoming)
            } else {
                pollViewModel = nil
            }
            
            if (model.message.poll?.ownVotes.count ?? 0) > 0 || (model.message.poll?.pendingVotes?.count ?? 0) > 0 {
                items += [
                    .init(
                        title: "Retract Vote",
                        image: .messageActionRetractVote,
                        imageRenderingMode: .alwaysTemplate,
                        action: { [weak self] _ in
                            guard let pollViewModel, let self else { return }
                            self.channelViewModel.retractPollVote(
                                layoutModel: model,
                                pollViewModel: pollViewModel
                            ) { [weak self] error in
                                if let error {
                                    self?.showAlert(error: error)
                                }
                            }
                        }
                    )]
            }
            
            if !model.message.incoming && model.message.state != .deleted && model.message.poll?.closed == false {
                items += [
                    .init(
                        title: "End Poll",
                        image: .messageActionEndPoll,
                        imageRenderingMode: .alwaysTemplate,
                        action: { [weak self] _ in
                            self?.showEndPollAlert(for: model)
                        }
                    )]
            }
        }
        
        if !isPoll {
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
        }
            
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
                                    self?.delete(layoutModel: model, type: SceytChatUIKit.shared.config.hardDeleteMessageForAll ? .deleteHard : .deleteForEveryone)
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
                                        self?.delete(layoutModel: model, type: .deleteForMe)
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
        print("[deinit] ChannelViewController called")
        SimpleSinglePlayer.stop()
        avatarTask?.cancel()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        NotificationCenter.default.removeObserver(self)
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
        if customInputViewController.isRecording {
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
        if customInputViewController.isRecording {
            showRecordDiscardAlertIfNeeded()
            return false
        } else {
            return true
        }
    }
    
    //MARK: Search

    open func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        endMessagesSearchIfNeeded()
    }

    open func endMessagesSearchIfNeeded() {
        guard channelViewModel.isSearching else { return }
        searchBar.text = nil
        selectMessageId = nil
        NotificationCenter.default.post(name: .selectMessage, object: nil)
        searchBarActivityIndicator.stopAnimating()
        channelViewModel.stopMessagesSearch()
        // The $isSearching sink toggles these on the next runloop tick; flip them
        // synchronously so a caller (e.g. reply) can focus the input view right away.
        customInputViewController.view.isHidden = false
        searchControlsView.isHidden = true
    }
    
    open func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension ChannelViewController {

    /// The data-source state UIKit thinks it has. Carries section identity
    /// (`sections`) alongside per-section item keys (`items`) so the Phase 2
    /// diff can match sections across snapshots by `SectionId` rather than by
    /// raw index. Indexing is parallel: `items[i]` are the keys in
    /// `sections[i]`.
    ///
    /// Marked `internal` (rather than `private`) so the Phase 2 snapshot-diff
    /// tests can construct fixtures via `@testable import SceytChatUIKit`.
    internal struct AppliedSnapshot: Equatable {
        var sections: [ChannelViewModel.SectionId]
        var items: [[ChannelViewModel.Key]]
        /// Per-item content token captured at build time. Drives content-diff
        /// reloads in `computeDiff`; not part of structural identity (`items`
        /// stays Key-only so `CollectionDifference` move-detection is unaffected).
        /// Defaulted so existing `AppliedSnapshot(sections:items:)` sites compile.
        var versions: [ChannelViewModel.Key: UInt] = [:]

        static let empty = AppliedSnapshot(sections: [], items: [])

        var isEmpty: Bool { sections.isEmpty }
        var sectionCount: Int { sections.count }
    }

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
