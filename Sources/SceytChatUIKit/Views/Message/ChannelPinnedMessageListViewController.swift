//
//  ChannelPinnedMessageListViewController.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit

/// The standalone pinned-messages screen: every live pin in one channel, opened from the
/// pin button at the trailing edge of `ChannelViewController.PinnedMessagesView`.
///
/// The rows are the conversation's own message cells, so the screen behaves like the
/// conversation: long press opens the conversation's own context menu — minus the actions
/// that belong to the conversation rather than the pin, see `hiddenMenuActionTitles` — with
/// the same reaction row, media opens in the same previewer, polls take votes, links
/// follow. It also
/// reads in the conversation's direction — oldest pin at the top, newest at the bottom, the
/// screen opening on the newest one and scrolling up through the older ones.
///
/// The screen is presented modally over the conversation, so it closes itself through the
/// "X" at the trailing edge of its navigation bar rather than a back button.
///
/// What it does *not* do is navigate on a tap — the bubble's own gestures own that touch.
/// Each row carries an arrow button instead, and picking it closes the screen and hands the
/// pin back through `onSelect`, so the jump runs on `ChannelViewController` — the only place
/// that can scroll the message list. See `ChannelRouter.showPinnedMessageList`.
///
/// Picking several pins at once works here too, rather than sending the user back: "Select"
/// puts the screen into selection mode — checkboxes on the rows, the count in the navigation
/// bar, the conversation's own actions bar along the bottom — and delete, share and forward
/// then run against the picked pins. See `menuActionTitlesReturningToConversation` for what
/// still goes back.
///
/// Actions the screen cannot serve on its own — the composer, anything presented over the
/// conversation — are handed back to `channelViewController`, after the screen closes, so the
/// user lands where the action actually happens.
open class ChannelPinnedMessageListViewController: ViewController,
                                                  UITableViewDelegate,
                                                  UITableViewDataSource,
                                                  UIGestureRecognizerDelegate,
                                                  ContextMenuDataSource,
                                                  ContextMenuDelegate,
                                                  ContextMenuSnapshotDelegate {

    open var viewModel: ChannelPinnedMessageListViewModel!

    /// Called with the picked pin, after the screen has closed itself.
    open var onSelect: ((PinnedMessage) -> Void)?

    /// The conversation the pins belong to, and the owner of every action this screen
    /// hands off. Set by `ChannelRouter.showPinnedMessageList`.
    open weak var channelViewController: ChannelViewController?

    open lazy var tableView = UITableView()
        .withoutAutoresizingMask

    open lazy var emptyStateView = Components.emptyStateView
        .init()
        .withoutAutoresizingMask

    /// The screen is presented, so the navigation bar carries an "X" rather than a back
    /// button. A plain bar button item rather than a custom view, the way every other
    /// navigation-bar control in the kit is built: the system then draws the button's own
    /// background — the circular glass one from iOS 26 on — instead of the flat disc a
    /// hand-rolled button would have to fake.
    open lazy var closeButton = UIBarButtonItem(
        image: appearance.closeIcon,
        style: .plain,
        target: self,
        action: #selector(closeButtonTapped)
    )

    /// The bar of actions along the bottom while messages are being picked — delete, share,
    /// forward. Literally the conversation's own view, so the two screens offer the same
    /// three actions, in the same order, drawn the same way.
    open lazy var selectingView = Components.messageInputSelectedMessagesActionsView
        .init()
        .withoutAutoresizingMask

    /// Fills the home-indicator strip under `selectingView`, which stops at the safe area so
    /// its buttons stay clear of it. The conversation gets this for free from the input bar
    /// the actions bar sits on; this screen has no input bar, so the strip is its own view.
    open lazy var selectingViewBackgroundView = UIView()
        .withoutAutoresizingMask

    /// Takes the "X"'s place while messages are being picked: the button then leaves the
    /// mode rather than the screen, so a selection is never closed out from under the user.
    open lazy var cancelSelectingButton = UIBarButtonItem(
        title: L10n.Alert.Button.cancel,
        style: .done,
        target: self,
        action: #selector(cancelSelecting)
    )

    /// The channel picker while a forward is being addressed, so the handler can close
    /// exactly it once the copies are away. Weak: the picker is owned by whatever UIKit
    /// made its presenter.
    public private(set) weak var presentedForwardViewController: UIViewController?

    /// Feeds the carousel a tapped attachment opens. The attachment views present it
    /// themselves, from the window, so this screen owns its own previewer rather than
    /// borrowing the conversation's.
    open lazy var previewer = AttachmentPreviewDataSource(channel: viewModel.channel)

    /// The same two recognizers the conversation installs on its message list: the cell
    /// routes a tap to a link, a mention or an avatar, and a long press into the context
    /// menu. Everything else inside a bubble tracks its own touches.
    @objc public lazy var tapGestureRecognizer = UITapGestureRecognizer()
    @objc public lazy var longPressGestureRecognizer = UILongPressGestureRecognizer()

    /// The bubble a long press is travelling through, held for the duration of the press
    /// the way `ChannelViewController` holds it.
    public var longPressItem: ChatMessageCell.LongPressItem?

    /// `true` while the screen is still opening onto the newest pin — the last row — the
    /// way the conversation opens on the newest message.
    ///
    /// One attempt is not enough. The first reload can land before the table has rows or a
    /// height; the pins themselves can arrive later, from the sweep the view model kicks
    /// off; and the content size and the safe-area insets both settle over several layout
    /// passes on the way in, so an offset that was the bottom in one pass is short of it in
    /// the next. So the anchor is re-applied — cheaply, and only when it would actually
    /// move — from every reload and every layout pass until the screen is up and showing
    /// pins, or until the user takes over by dragging.
    public private(set) var needsInitialScrollToBottom = true

    /// Whether the screen is on screen. Until it is, the layout is still settling, so the
    /// opening anchor is not considered final.
    public private(set) var hasAppeared = false

    /// The pins the table is showing right now, by `messageTid`, in row order — what the
    /// next reload is diffed against, so an unpin fades its own row out and slides the rest
    /// together instead of the whole list being swapped at once. The view model's `items`
    /// have already moved on by the time the event lands, which is why the table keeps its
    /// own copy.
    public private(set) var displayedMessageTids: [Int64] = []

    /// A reload is queued for the end of this run-loop turn. One unpin writes both the pin
    /// row and the message's own pin mark, so the two observers behind the list fire from the
    /// same save, in no fixed order — played one by one, the leaving row was first rebound
    /// without its pin mark and then faded out, as two overlapping animations. Coalesced,
    /// they are one update.
    public private(set) var isListReloadScheduled = false

    /// A row animation is on screen. A reload that arrives meanwhile — a server ack touching
    /// a message, a reaction — waits for it rather than retargeting rows mid-flight.
    public private(set) var isAnimatingListReload = false
    public private(set) var needsListReloadAfterAnimation = false

    public private(set) lazy var contextMenu: ContextMenu = {
        let contextMenu = ContextMenu(parent: self)
        contextMenu.dataSource = self
        contextMenu.delegate = self
        contextMenu.snapshotDelegate = self
        return contextMenu
    }()

    /// Menu actions that need the conversation itself on screen: they drive its composer or
    /// present over it. The screen closes and hands those over; everything else — copy, pin,
    /// unpin, delete, retract vote, and picking several messages at once — runs right here,
    /// the way the row's swipe action does.
    open var menuActionTitlesReturningToConversation: Set<String> = [
        // `ChannelViewController` builds this one from a bare string, and it opens a
        // confirmation alert over the conversation.
        "End Poll"
    ]

    /// Menu actions this screen leaves out of the message menu entirely. Message info is
    /// the conversation's own screen — it lists who received and read the message, which
    /// is a detour from a list whose one job is finding a pin and jumping to it. Reply and
    /// edit are composer actions: both would close this screen to hand the conversation a
    /// quoted or editable draft, which is not what someone scanning the pins is here for —
    /// so the pinned rows drop all three and keep the menu to the actions that act on the
    /// pin itself.
    open var hiddenMenuActionTitles: Set<String> = [
        L10n.Message.Action.Title.info,
        L10n.Message.Action.Title.reply,
        L10n.Message.Action.Title.edit
    ]

    open override func setup() {
        super.setup()

        title = appearance.titleText

        // The rows are the conversation's own message cells, so they must be measured
        // against the appearance they are rendered with — a model measured against one
        // appearance and drawn with another clips its own content.
        viewModel.messageCellAppearance = appearance.messageCellAppearance

        tableView.register(Components.channelPinnedMessageIncomingCell.self)
        tableView.register(Components.channelPinnedMessageOutgoingCell.self)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        // Nothing selects a row: the bubble handles its own touches and the arrow button
        // carries the jump.
        tableView.allowsSelection = false
        // The models carry the conversation's spacing *above* each bubble, so the bottom
        // of the list is the one edge nothing pads — except by the actions bar, while one
        // is up.
        tableView.contentInset.bottom = listBottomInset
        tableView.sectionFooterHeight = 0
        tableView.estimatedSectionHeaderHeight = 0
        // No estimates anywhere: every row's height is already known — its layout model
        // measured it — and an estimated `contentSize` is a guess that keeps changing as
        // rows are realized, which is not something the screen can anchor its opening
        // position against.
        tableView.estimatedRowHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        tableView.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.PinnedMessageList.tableView
        emptyStateView.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.PinnedMessageList.emptyView

        selectingView.isHidden = true
        selectingViewBackgroundView.isHidden = true
        selectingView.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers
            .PinnedMessageList.selectingView
        cancelSelectingButton.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers
            .PinnedMessageList.cancelSelectingButton
        selectingView.onAction = { [weak self] in
            guard let self else { return }
            switch $0 {
            case .delete:
                showDeleteOptionsForSelectedMessages()
            case .share:
                shareSelectedMessages()
            case .forward:
                forwardSelectedMessages()
            }
        }

        setupNavigationBarItems()
        setupGestureRecognizers()

        viewModel.startDatabaseObserver()
        viewModel.$event
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)

        // Both hop to the main queue before reading the view model back: `@Published` fires
        // from `willSet`, so the property still holds the old value when the sink runs
        // inline.
        viewModel.$isEditing
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateEditingState()
            }.store(in: &subscriptions)

        viewModel.$selectedMessageTids
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateSelectionState()
            }.store(in: &subscriptions)

        updateEmptyState()
    }

    open func setupNavigationBarItems() {
        closeButton.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers
            .PinnedMessageList.closeButton
        updateNavigationBarItems()
    }

    /// The bar shows what the screen is doing: the pins' title and the "X" while browsing,
    /// the running count and Cancel while picking.
    open func updateNavigationBarItems() {
        if viewModel.isEditing {
            navigationItem.title = L10n.Channel.Selecting.selected(viewModel.selectedMessageTids.count)
            navigationItem.rightBarButtonItem = cancelSelectingButton
        } else {
            navigationItem.title = appearance.titleText
            navigationItem.rightBarButtonItem = closeButton
        }
    }

    /// Mirrors the conversation's setup: the tap only runs once the long press has failed,
    /// so pressing a bubble opens the menu instead of following the link under the finger.
    open func setupGestureRecognizers() {
        tapGestureRecognizer.addTarget(self, action: #selector(handleTapGestureRecognizer(_:)))
        tapGestureRecognizer.delegate = self
        tableView.addGestureRecognizer(tapGestureRecognizer)

        longPressGestureRecognizer.minimumPressDuration = 0.2
        longPressGestureRecognizer.addTarget(self, action: #selector(handleLongPressGestureRecognizer(_:)))
        longPressGestureRecognizer.delegate = self
        tableView.addGestureRecognizer(longPressGestureRecognizer)

        tapGestureRecognizer.require(toFail: longPressGestureRecognizer)
    }

    open override func setupLayout() {
        super.setupLayout()

        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(selectingViewBackgroundView)
        view.addSubview(selectingView)

        tableView.pin(to: view, anchors: [.leading, .trailing, .top, .bottom])
        emptyStateView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .trailing, .top, .bottom])

        // Above the safe area, so the three buttons are not under the home indicator; the
        // strip below it is filled by the background view rather than by stretching the bar.
        selectingView.pin(to: view, anchors: [.leading, .trailing])
        selectingView.bottomAnchor.pin(to: view.safeAreaLayoutGuide.bottomAnchor)
        selectingViewBackgroundView.pin(to: view, anchors: [.leading, .trailing, .bottom])
        selectingViewBackgroundView.topAnchor.pin(to: selectingView.bottomAnchor)
    }

    open override func setupAppearance() {
        super.setupAppearance()

        navigationController?.navigationBar.apply(appearance: appearance.navigationBarAppearance)
        view.backgroundColor = appearance.backgroundColor
        tableView.backgroundColor = .clear
        emptyStateView.parentAppearance = appearance.emptyStateAppearance

        closeButton.image = appearance.closeIcon
        closeButton.tintColor = appearance.closeIconTintColor

        let selectedMessagesActionsAppearance = Components.messageInputViewController
            .appearance.selectedMessagesActionsAppearance
        selectingView.parentAppearance = selectedMessagesActionsAppearance
        selectingViewBackgroundView.backgroundColor = selectedMessagesActionsAppearance.backgroundColor
    }

    open func onEvent(_ event: ChannelPinnedMessageListViewModel.Event) {
        switch event {
        case .reload:
            setNeedsListReload()
        }
    }

    /// Queues one reload for the end of this run-loop turn, or for the end of the row
    /// animation on screen — see `isListReloadScheduled` and `isAnimatingListReload`.
    open func setNeedsListReload() {
        if isAnimatingListReload {
            needsListReloadAfterAnimation = true
            return
        }
        guard !isListReloadScheduled else { return }
        isListReloadScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isListReloadScheduled = false
            if isAnimatingListReload {
                needsListReloadAfterAnimation = true
            } else {
                reloadList()
            }
        }
    }

    /// Brings the table up to the view model's pins — as row changes when it can, with a
    /// `reloadData()` otherwise.
    open func reloadList() {
        // Read before the reload: whether the list was resting on the newest pin is what
        // decides if it follows a pin taken while the screen is open. The conversation
        // follows a new message on the same terms — only from the bottom, so a user who
        // has scrolled back through the older pins is left where they are.
        let wasAtBottom = isAtBottom
        let tids = viewModel.items.map { $0.messageTid }
        if canAnimateReload(to: tids) {
            animateReload(to: tids, wasAtBottom: wasAtBottom)
            return
        }
        displayedMessageTids = tids
        tableView.reloadData()
        updateEmptyState()
        // The pins that just arrived — or the one that just left — decide how much of
        // the screen the content fills, and therefore how far down it has to be pushed.
        tableView.layoutIfNeeded()
        updateTopPaddingForShortContent()
        if needsInitialScrollToBottom {
            scrollToBottom(animated: false)
        } else if wasAtBottom {
            scrollToBottom(animated: true)
        }
    }

    /// Whether a reload can be played as row changes rather than a `reloadData()`.
    ///
    /// Not while the screen is still opening — that anchor is placed without animation —
    /// nor off screen, nor into or out of the empty state, which swaps the table for the
    /// empty view. Tids must be unique for the diff to mean anything.
    open func canAnimateReload(to tids: [Int64]) -> Bool {
        guard hasAppeared,
              !needsInitialScrollToBottom,
              tableView.window != nil,
              !displayedMessageTids.isEmpty,
              !tids.isEmpty,
              tableView.numberOfRows(inSection: 0) == displayedMessageTids.count,
              Set(tids).count == tids.count
        else { return false }
        return true
    }

    /// Plays a reload as row changes: an unpinned row fades out and the ones around it close
    /// the gap, a new pin fades in, and a row whose message changed — a reaction, an edit —
    /// grows or shrinks in place.
    ///
    /// The rows that stay are rebound where they stand rather than reloaded: their models are
    /// mutated in place by the view model, and a neighbour of the row that left may now head
    /// its sender's run or carry different spacing, which a crossfading reload would flicker.
    /// Updating the table this way, rather than with `reloadData()`, also lets a message
    /// change that lands mid-animation join it instead of cutting it short.
    open func animateReload(to tids: [Int64], wasAtBottom: Bool) {
        let difference = tids.difference(from: displayedMessageTids)
        var deletedRows = [IndexPath]()
        var insertedRows = [IndexPath]()
        for change in difference {
            switch change {
            case let .remove(offset, _, _):
                deletedRows.append(IndexPath(row: offset, section: 0))
            case let .insert(offset, _, _):
                insertedRows.append(IndexPath(row: offset, section: 0))
            }
        }
        let newRows = Dictionary(uniqueKeysWithValues: tids.enumerated().map { ($1, $0) })
        let deleted = Set(deletedRows)

        for case let cell as MessageCell in tableView.visibleCells {
            guard let oldIndexPath = tableView.indexPath(for: cell),
                  !deleted.contains(oldIndexPath),
                  displayedMessageTids.indices.contains(oldIndexPath.row),
                  let newRow = newRows[displayedMessageTids[oldIndexPath.row]]
            else { continue }
            configure(cell, at: IndexPath(row: newRow, section: 0))
        }

        displayedMessageTids = tids
        isAnimatingListReload = true

        // One animation for everything that moves: the rows, the padding that holds a short
        // list against the bottom, and the offset once the content has shrunk under it. Run
        // on separate clocks — the table's own row animation and a second block for the
        // insets — the two curves disagreed and the rows wobbled. Batch updates made inside
        // an animation block take that block's timing.
        UIView.animate(
            withDuration: Layouts.rowAnimationDuration,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut]
        ) { [self] in
            tableView.performBatchUpdates {
                tableView.deleteRows(at: deletedRows, with: .fade)
                tableView.insertRows(at: insertedRows, with: .fade)
            }
            updateTopPaddingForShortContent()
            let topOffsetY = -tableView.adjustedContentInset.top
            let bottomOffsetY = max(topOffsetY, bottomContentOffsetY)
            let offsetY = wasAtBottom
                ? bottomOffsetY
                : min(max(tableView.contentOffset.y, topOffsetY), bottomOffsetY)
            if abs(tableView.contentOffset.y - offsetY) > 0.5 {
                tableView.contentOffset.y = offsetY
            }
        } completion: { [weak self] _ in
            guard let self else { return }
            isAnimatingListReload = false
            if needsListReloadAfterAnimation {
                needsListReloadAfterAnimation = false
                setNeedsListReload()
            }
        }
        updateEmptyState()
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateListBottomInset()
        updateTopPaddingForShortContent()
        // Every pass while the screen is still opening: the one that first gives the table
        // a height, and each later one that changes what "the bottom" is.
        if needsInitialScrollToBottom {
            scrollToBottom(animated: false)
        }
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        hasAppeared = true
        // The last word on the opening position: the presentation has finished, so the
        // insets and the content size are final.
        if needsInitialScrollToBottom {
            scrollToBottom(animated: false)
        }
    }

    /// How much room the list keeps under its last bubble: the trailing padding, plus the
    /// actions bar while one is up, so the newest pin is never behind it.
    open var listBottomInset: CGFloat {
        guard viewModel.isEditing else { return Layouts.bottomPadding }
        return Layouts.bottomPadding + selectingView.bounds.height
    }

    /// Applied from the layout pass, because the actions bar's own height is only known once
    /// it has been laid out.
    ///
    /// The offset moves with the inset. A bottom inset is room reserved *under* the content
    /// and changing it does not move the content itself, so a list resting on its last pin
    /// would simply end up with that pin behind the bar; shifting by the same amount keeps
    /// the rows where they were on screen, above the bar rather than under it. Content too
    /// short to scroll is held from the other side, by `updateTopPaddingForShortContent()`,
    /// and the clamps here leave it alone.
    open func updateListBottomInset() {
        let inset = listBottomInset
        let delta = inset - tableView.contentInset.bottom
        guard abs(delta) > 0.5 else { return }
        tableView.contentInset.bottom = inset

        let topOffsetY = -tableView.adjustedContentInset.top
        let offsetY = tableView.contentOffset.y + delta
        tableView.contentOffset.y = min(max(offsetY, topOffsetY), max(topOffsetY, bottomContentOffsetY))
    }

    /// Holds the pins against the bottom of the screen when there are too few of them to
    /// fill it, by padding the empty space above them.
    ///
    /// This is what the conversation gets for free from being mirrored — a handful of
    /// messages rests on the input bar, not under the navigation bar. This screen's table
    /// is upright, because mirroring a table view turns its trailing unpin swipe upside
    /// down, so the same resting position is an inset instead.
    open func updateTopPaddingForShortContent() {
        let viewport = tableView.bounds.height
            - tableView.safeAreaInsets.top
            - tableView.safeAreaInsets.bottom
            - listBottomInset
        // `contentSize` does not depend on `contentInset`, so writing one from the other
        // settles in a single pass rather than chasing itself.
        let padding = max(0, viewport - tableView.contentSize.height)
        guard abs(tableView.contentInset.top - padding) > 0.5 else { return }
        tableView.contentInset.top = padding
    }

    /// Whether the list is resting on the newest pin, within a row's worth of slack so a
    /// list nudged a few points off the end still counts as being at the end.
    open var isAtBottom: Bool {
        tableView.contentOffset.y >= bottomContentOffsetY - Layouts.followBottomThreshold
    }

    /// Puts the newest pin — the last row — at the bottom of the screen. A list too short
    /// to scroll is already there, held by `updateTopPaddingForShortContent()`, and the two
    /// agree on the offset that means it.
    open func scrollToBottom(animated: Bool) {
        guard !viewModel.isEmpty, tableView.bounds.height > 0 else { return }
        // `contentSize` is only current once the reload this follows has been laid out.
        tableView.layoutIfNeeded()
        // The opening anchor is settled only once the screen is actually up: before that
        // the insets and the content size are still moving under it, so the next layout
        // pass has to be allowed to re-apply it.
        if hasAppeared {
            needsInitialScrollToBottom = false
        }

        let offsetY = max(-tableView.adjustedContentInset.top, bottomContentOffsetY)
        guard abs(tableView.contentOffset.y - offsetY) > 0.5 else { return }
        tableView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: animated)
    }

    /// The user taking hold of the list ends the opening anchor, whatever it was doing —
    /// a screen that opened with no pins and received them later must not yank the list
    /// out from under a finger.
    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        needsInitialScrollToBottom = false
    }

    /// The offset at which the last row's bottom — the list's trailing padding included —
    /// sits at the bottom of the visible area. For content too short to scroll this is the
    /// resting offset itself, `-adjustedContentInset.top`.
    open var bottomContentOffsetY: CGFloat {
        tableView.contentSize.height
            + tableView.adjustedContentInset.bottom
            - tableView.bounds.height
    }

    open func updateEmptyState() {
        emptyStateView.isHidden = !viewModel.isEmpty
        tableView.isHidden = viewModel.isEmpty
    }

    // MARK: - Actions

    open func unpin(at indexPath: IndexPath) {
        guard let item = viewModel.item(at: indexPath) else { return }
        viewModel.unpin(item) { [weak self] error in
            guard let error else { return }
            self?.showAlert(error: error)
        }
    }

    /// Unpins from the row's menu, but only once the menu is completely gone.
    ///
    /// The menu runs its action from its dismissal's completion, which lands while UIKit is
    /// still tearing the presentation down — the bubble has only just been handed back its
    /// alpha and the blur is still coming off. Removing the row right then starts its fade
    /// and the neighbours' slide against a screen that has not settled, which is what made
    /// the removal look abrupt at times. So the unpin waits for any transition still in
    /// flight, then for the next run-loop turn, and only then touches the store.
    open func unpinAfterMenuDismissal(_ model: MessageLayoutModel) {
        let unpin: () -> Void = { [weak self] in
            DispatchQueue.main.async {
                guard let self,
                      let indexPath = self.indexPath(for: model)
                else { return }
                self.unpin(at: indexPath)
            }
        }
        // `animate` refuses — and never calls back — when the transition is already over.
        if let coordinator = presentedViewController?.transitionCoordinator ?? transitionCoordinator,
           coordinator.animate(alongsideTransition: nil, completion: { _ in unpin() }) {
            return
        }
        unpin()
    }

    /// The row's arrow: the screen closes and the conversation moves onto that pin.
    open func navigate(to item: PinnedMessage) {
        guard let target = viewModel.jumpTarget(for: item) else { return }
        close { [weak self] in
            self?.onSelect?(target)
        }
    }

    @objc
    open func closeButtonTapped() {
        close()
    }

    /// Closes the screen the same way it was opened — a modal dismisses, and a screen a
    /// host app chose to push instead pops.
    open func close(completion: (() -> Void)? = nil) {
        if let navigationController, navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
            completion?()
        } else if presentingViewController != nil {
            dismiss(animated: true, completion: completion)
        } else {
            completion?()
        }
    }

    // MARK: - Selection

    /// The row's "Select": the screen switches into selection mode with this pin picked,
    /// rather than closing and switching the conversation into it.
    open func select(_ model: MessageLayoutModel) {
        viewModel.select(messageTid: model.message.tid)
    }

    @objc
    open func cancelSelecting() {
        viewModel.isEditing = false
    }

    /// Entering or leaving the mode: the whole screen changes — the bar, the actions, and
    /// every row, which gains or loses a checkbox and therefore has to be laid out again.
    open func updateEditingState() {
        let isEditing = viewModel.isEditing
        selectingView.isHidden = !isEditing
        selectingViewBackgroundView.isHidden = !isEditing
        // Nothing may open the message menu while picking: the menu is what the picking
        // replaced, and its actions run against one message.
        longPressGestureRecognizer.isEnabled = !isEditing
        updateNavigationBarItems()
        updateSelectedMessagesActionsState()
        displayedMessageTids = viewModel.items.map { $0.messageTid }
        tableView.reloadData()
        // The actions bar takes room off the bottom of the list, or gives it back.
        view.setNeedsLayout()
    }

    /// A pick added or dropped: the count in the bar, what the actions can do, and the
    /// checkboxes already on screen — reloading the rows here would fight the tap that
    /// caused it.
    open func updateSelectionState() {
        updateNavigationBarItems()
        updateSelectedMessagesActionsState()
        for case let cell as MessageCell in tableView.visibleCells {
            guard let indexPath = tableView.indexPath(for: cell) else { continue }
            cell.isChecked = viewModel.isSelected(at: indexPath)
        }
    }

    /// Which of the three actions can run. Nothing picked means nothing to act on; override
    /// to rule out more, e.g. a message kind that cannot be forwarded.
    open func updateSelectedMessagesActionsState() {
        let hasSelection = !viewModel.selectedMessageTids.isEmpty
        selectingView.buttonDelete.isEnabled = hasSelection
        selectingView.buttonShare.isEnabled = hasSelection
        selectingView.buttonForward.isEnabled = hasSelection
    }

    /// The picked pins as the *conversation* models them, which is what every action that
    /// writes — deleting, forwarding — has to run against.
    open var selectedConversationLayoutModels: [MessageLayoutModel] {
        viewModel.selectedLayoutModels.map { conversationLayoutModel(for: $0) }
    }

    // MARK: - Selection actions

    /// Deleting needs nothing but the store, so the sheet opens over this screen and the
    /// messages go from here — the list drops them as their rows lapse.
    open func showDeleteOptionsForSelectedMessages() {
        let models = selectedConversationLayoutModels
        guard !models.isEmpty else { return }
        showBottomSheet(actions: deleteOptionsSheetActions(for: models), withCancel: true)
    }

    /// The rows of that sheet. The conversation's own two, with its rule for what
    /// "for everyone" means; override to offer fewer — e.g. to drop "for everyone" when
    /// someone else's message is among the picks.
    open func deleteOptionsSheetActions(for models: [MessageLayoutModel]) -> [SheetAction] {
        [
            .init(
                title: L10n.Message.Action.Subtitle.deleteAll,
                icon: .chatDelete,
                style: .destructive
            ) { [weak self] in
                self?.deleteSelectedMessages(
                    models,
                    type: SceytChatUIKit.shared.config.hardDeleteMessageForAll ? .deleteHard : .deleteForEveryone
                )
            },
            .init(
                title: L10n.Message.Action.Subtitle.deleteMe,
                icon: .chatDelete,
                style: .destructive
            ) { [weak self] in
                self?.deleteSelectedMessages(models, type: .deleteForMe)
            }
        ]
    }

    /// Deletes through the conversation's view model — the one that owns the sender and the
    /// pending-delete bookkeeping; this screen has neither.
    open func deleteSelectedMessages(_ models: [MessageLayoutModel], type: DeleteMessageType) {
        guard let channelViewController else { return }
        models.forEach {
            channelViewController.channelViewModel.deleteMessage(layoutModel: $0, type: type)
        }
        viewModel.isEditing = false
    }

    /// The system share sheet over this screen, with the same items the conversation puts
    /// in it: each message's body as it formats it, plus every attachment's file.
    open func shareSelectedMessages() {
        let models = viewModel.selectedLayoutModels
        guard !models.isEmpty else { return }
        viewModel.isEditing = false

        var items = [Any]()
        for model in models {
            let message = model.message
            guard message.user != nil else { continue }
            let body = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty {
                items.append(messageShareBodyFormatter.format(message))
            }
            items += message.attachments?.compactMap {
                // A link attachment is the body's own URL, already in `items`.
                $0.type == "link" ? nil : ($0.fileUrl ?? $0.originUrl)
            } ?? []
        }
        guard !items.isEmpty else { return }
        // The screen itself is the popover's anchor, not a button on the actions bar —
        // leaving the mode above has just hidden that bar.
        share(items, from: view)
    }

    /// The conversation's formatter, so a message shared from the pins reads exactly as one
    /// shared from the conversation.
    open var messageShareBodyFormatter: any MessageFormatting {
        channelViewController?.appearance.messageShareBodyFormatter
            ?? SceytChatUIKit.shared.formatters.messageShareBodyFormatter
    }

    /// Presents the system share sheet from this screen rather than from the conversation
    /// behind it — a `UIActivityViewController` put up by a covered view controller never
    /// appears.
    open func share(_ items: [Any], from sourceView: Any?) {
        Router(rootViewController: self).share(items, from: sourceView)
    }

    open func forwardSelectedMessages() {
        let messages = selectedConversationLayoutModels.map { $0.message }
        guard !messages.isEmpty else { return }
        viewModel.isEditing = false
        forward(messages: messages)
    }

    // MARK: - Message cell actions

    /// The conversation's own model for a pinned message, so an action handed back runs
    /// against the model its message list is showing rather than this screen's copy.
    open func conversationLayoutModel(for model: MessageLayoutModel) -> MessageLayoutModel {
        channelViewController?.channelViewModel.createLayoutModel(for: model.message) ?? model
    }

    /// Everything a bubble can ask its screen to do. What needs nothing but the store — a
    /// poll vote, a paused download, a played voice note, a reaction removed from the
    /// pill — happens here, as does anything this screen can present over itself, such as
    /// the reaction details; the rest is the conversation's, and the screen closes before
    /// handing it over so the user sees where it landed.
    open func handleMessageCellAction(
        _ action: ChatMessageCell.Action,
        layoutModel model: MessageLayoutModel
    ) {
        switch action {
        case .didTapReadMore:
            expandText(for: model)
        case .tapReaction:
            // Who reacted is about the pinned message itself, so it opens over this screen
            // rather than sending the user back to the conversation to read it.
            showReactions(for: model)
        case .didTapPollOption,
             .pauseTransfer,
             .resumeTransfer,
             .playedAudio,
             .openedViewOnce,
             .deleteReaction,
             .updateReactionScore,
             .selectMentionedUser:
            channelViewController?.handleMessageCellAction(action, layoutModel: conversationLayoutModel(for: model))
        case .selectAttachment(let index):
            // A photo or a video opens its own previewer, over the window, so the list
            // must stay where it is. A file is opened by a screen, which is the
            // conversation's job.
            guard let attachments = model.message.attachments,
                  index < attachments.count,
                  attachments[index].type == "file"
            else { break }
            handOffToConversation(for: model) { channelViewController, conversationModel in
                channelViewController.handleMessageCellAction(action, layoutModel: conversationModel)
            }
        default:
            handOffToConversation(for: model) { channelViewController, conversationModel in
                channelViewController.handleMessageCellAction(action, layoutModel: conversationModel)
            }
        }
    }

    /// Closes the screen, then runs `action` on the conversation with its own layout model.
    open func handOffToConversation(
        for model: MessageLayoutModel,
        _ action: @escaping (ChannelViewController, MessageLayoutModel) -> Void
    ) {
        guard let channelViewController else { return }
        let conversationModel = conversationLayoutModel(for: model)
        close {
            action(channelViewController, conversationModel)
        }
    }

    /// Who reacted to this pin, opened from this screen. The conversation presents the same
    /// screen from itself; the two differ only in what the details screen can hand back —
    /// removing one's own reaction needs nothing on screen and runs right here, while a
    /// profile is the conversation's to push, so that one closes both screens first.
    open func showReactions(for model: MessageLayoutModel) {
        let reactionsInfoViewController = ReactionsInfoViewController.build(message: model.message)
        reactionsInfoViewController.onEvent = { [weak self, weak reactionsInfoViewController] event in
            guard let self,
                  let channelViewController = self.channelViewController
            else { return }

            switch event {
            case .removeReaction(let reaction):
                guard channelViewController.channelViewModel
                    .canDeleteReaction(message: model.message, key: reaction.key)
                else { return }
                reactionsInfoViewController?.dismiss(animated: true) { [weak self] in
                    guard let self else { return }
                    channelViewController.deleteReaction(
                        layoutModel: self.conversationLayoutModel(for: model),
                        reaction: reaction.key
                    )
                }
            case .showUserProfile(let user):
                reactionsInfoViewController?.dismiss(animated: true) { [weak self] in
                    self?.close {
                        channelViewController.showProfile(user: user)
                    }
                }
            }
        }
        present(reactionsInfoViewController, animated: true)
    }

    /// A menu action this screen runs itself, in place of the conversation's own handler.
    ///
    /// The conversation builds the menu, so its handlers present from the conversation. The
    /// few that this screen can present just as well — forwarding picks its channels in a
    /// screen of its own — are swapped for a handler that presents from here, so the list
    /// stays up behind them instead of closing first. Returns `nil` for an action this
    /// screen does not take over, which is most of them.
    open func localMenuItem(replacing item: MenuItem, for model: MessageLayoutModel) -> MenuItem? {
        switch item.title {
        case L10n.Message.Action.Title.forward:
            var item = item
            item.action = { [weak self] _ in
                self?.forward(model)
            }
            return item
        case L10n.Message.Action.Title.select:
            var item = item
            item.action = { [weak self] _ in
                self?.select(model)
            }
            return item
        case L10n.Message.Action.Title.unpin:
            var item = item
            item.action = { [weak self] _ in
                self?.unpinAfterMenuDismissal(model)
            }
            return item
        default:
            return nil
        }
    }

    /// Forwards the one pin a row's menu was opened on.
    open func forward(_ model: MessageLayoutModel) {
        guard let channelViewController else { return }
        // A half-recorded voice message is the conversation's to discard, over its own
        // composer, so that one still goes back.
        guard !channelViewController.customInputViewController.isRecording else {
            handOffToConversation(for: model) { channelViewController, conversationModel in
                channelViewController.forward(messages: [conversationModel.message])
            }
            return
        }
        forward(messages: [conversationLayoutModel(for: model).message])
    }

    /// Forwards pins — one from a row's menu, or everything picked in selection mode —
    /// picking the channels in the same screen the conversation uses, presented over this
    /// one.
    ///
    /// Where the user lands afterwards is the conversation's rule, kept: a copy sent into
    /// this very channel leaves them here, on the pins, with the conversation behind already
    /// scrolled to it, and a copy sent to a single other channel opens that channel. That
    /// channel is pushed onto the navigation stack *underneath* this screen, so the list has
    /// to close before the push — otherwise it happens behind the modal and the user is left
    /// looking at the pins.
    ///
    /// A half-recorded voice message is the conversation's to discard, over its own composer,
    /// so that case still goes back.
    open func forward(messages: [ChatMessage]) {
        guard let channelViewController, !messages.isEmpty else { return }
        guard !channelViewController.customInputViewController.isRecording else {
            close { channelViewController.forward(messages: messages) }
            return
        }

        // The picker outlives this call, so it holds nothing of the two screens: the
        // conversation is read back off this screen when the channels come in.
        let forwardViewController = ForwardViewController.build { [weak self] channels in
            guard let self,
                  let channelViewController = self.channelViewController
            else { return }

            loader.show()
            channelViewController.channelViewModel.share(messages: messages, to: channels.map { $0.id }) { [weak self] in
                loader.hide()
                guard let self else { return }
                // Dismissed through the picker itself rather than through this screen: a
                // view controller dismisses whatever it presented, and this one may not be
                // the presenter — inside a navigation controller, UIKit hands the
                // presentation to the ancestor that covers the screen.
                self.presentedForwardViewController?.dismiss(animated: true) { [weak self] in
                    guard let self else { return }
                    if channels.contains(channelViewController.channelViewModel.channel) {
                        channelViewController.collectionView.scrollToBottom(animated: false) { _ in }
                    } else if channels.count == 1 {
                        self.close {
                            ChannelListRouter.showChannel(channels[0])
                        }
                    }
                }
            }
        }
        presentedForwardViewController = forwardViewController
        present(forwardViewController, animated: true)
    }

    /// The cell has already expanded its own model, so the row only has to be measured
    /// again — which is what reloading it does.
    open func expandText(for model: MessageLayoutModel) {
        guard let indexPath = indexPath(for: model) else { return }
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    open func indexPath(for model: MessageLayoutModel) -> IndexPath? {
        guard let row = viewModel.items.firstIndex(where: { $0.messageTid == model.message.tid })
        else { return nil }
        return IndexPath(row: row, section: 0)
    }

    // MARK: - Gesture actions

    /// The bubble under a gesture, or `nil` when the gesture missed the rows.
    open func messageView(forGesture gesture: UIGestureRecognizer) -> ChatMessageCell? {
        let location = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: location),
              let cell = tableView.cellForRow(at: indexPath) as? MessageCell
        else { return nil }
        return cell.messageView
    }

    @objc
    open func handleTapGestureRecognizer(_ sender: UITapGestureRecognizer) {
        guard sender.state == .recognized else { return }
        // While picking, a tap anywhere in the row is the pick — the bubble's own gestures
        // are off for the duration, exactly as they are in the conversation.
        if viewModel.isEditing {
            guard let indexPath = tableView.indexPathForRow(at: sender.location(in: tableView))
            else { return }
            viewModel.didChangeSelection(at: indexPath)
            return
        }
        messageView(forGesture: sender)?.handleTap(sender: sender)
    }

    @objc
    open func handleLongPressGestureRecognizer(_ sender: UILongPressGestureRecognizer) {
        guard !viewModel.isEditing else { return }

        func reset() {
            sender.isEnabled = false
            sender.isEnabled = true
        }

        switch sender.state {
        case .began:
            guard let messageView = messageView(forGesture: sender)
            else {
                reset()
                return
            }
            longPressItem = messageView.handleLongPress(sender: sender)
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

    // MARK: - UIGestureRecognizerDelegate

    open func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard gestureRecognizer is UITapGestureRecognizer else { return true }
        // While picking, the row has no live controls left — the bubble is inert and the
        // arrow is gone — so every touch is the selection's.
        if viewModel.isEditing { return true }
        // The bubble's own controls — a reaction pill, a reply preview, a link card — and
        // the row's arrow button track their touches themselves, exactly as they do in the
        // conversation. The screen's tap recognizer must not take those away.
        if touch.view is UIControl { return false }
        if touch.view is ChatMessageCell.LinkPreviewView { return false }
        return true
    }

    // MARK: - UITableViewDataSource

    open func numberOfSections(in tableView: UITableView) -> Int { 1 }

    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfItems
    }

    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let model = viewModel.layoutModel(at: indexPath)
        else { return UITableViewCell() }

        // Which side of the screen the bubble sits on is the cell's class, the same way
        // the conversation picks between its two message cells.
        let cell: MessageCell = model.message.incoming
            ? tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelPinnedMessageIncomingCell.self)
            : tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelPinnedMessageOutgoingCell.self)
        configure(cell, at: indexPath)
        return cell
    }

    /// Binds a row to the pin at `indexPath` — from `cellForRowAt`, and again for a row that
    /// stays on screen through an animated reload.
    open func configure(_ cell: MessageCell, at indexPath: IndexPath) {
        guard let item = viewModel.item(at: indexPath),
              let model = viewModel.layoutModel(at: indexPath)
        else { return }

        cell.appearance = appearance
        // Before `data`: the checkbox's constraints are built by the hosted bubble's own
        // `data` setter, so the mode has to be in place by then.
        cell.isSelecting = viewModel.isEditing
        cell.data = model
        cell.isChecked = viewModel.isSelected(at: indexPath)
        // A row that cannot be picked — a deleted message — is dimmed rather than hidden,
        // the way the conversation dims it.
        cell.contentView.alpha = viewModel.isEditing && !viewModel.canSelect(at: indexPath) ? 0.5 : 1
        cell.onNavigate = { [weak self] in
            self?.navigate(to: item)
        }
        cell.messageView.contextMenu = contextMenu
        cell.messageView.previewer = { [weak self] in
            self?.previewer
        }
        cell.messageView.onAction = { [weak self] action in
            self?.handleMessageCellAction(action, layoutModel: model)
        }
        cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers
            .PinnedMessageList.identifier(for: item.messageId)
        cell.navigateButton.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers
            .PinnedMessageList.navigateButton
        // Same as the conversation: a pinned photo that is not on disk yet is fetched, so
        // the row fills in instead of staying a placeholder.
        channelViewController?.channelViewModel.downloadMessageAttachmentsIfNeeded(layoutModel: model)
    }

    // MARK: - UITableViewDelegate

    /// The height the conversation would give the same message, insets included.
    open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        viewModel.layoutModel(at: indexPath)?.measureSize.height ?? 0
    }

    open func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        return nil
    }

    // MARK: - ContextMenuDataSource

    open func canShow(contextMenu: ContextMenu, identifier: Identifier) -> Bool {
        channelViewController?.canShow(contextMenu: contextMenu, identifier: identifier) ?? false
    }

    open func canShowEmojis(
        contextMenu: ContextMenu,
        identifier: Identifier
    ) -> (canShowEmojis: Bool, emojisViewAppearance: ReactionPickerViewController.Appearance) {
        channelViewController?.canShowEmojis(contextMenu: contextMenu, identifier: identifier)
            ?? (false, ChannelViewController.appearance.reactionPickerAppearance)
    }

    open func emojis(contextMenu: ContextMenu, identifier: Identifier) -> [String] {
        channelViewController?.emojis(contextMenu: contextMenu, identifier: identifier) ?? []
    }

    open func showPlusAfterEmojis(contextMenu: ContextMenu, identifier: Identifier) -> Bool {
        channelViewController?.showPlusAfterEmojis(contextMenu: contextMenu, identifier: identifier) ?? false
    }

    open func selectedEmojis(contextMenu: ContextMenu, identifier: Identifier) -> [String] {
        channelViewController?.selectedEmojis(contextMenu: contextMenu, identifier: identifier) ?? []
    }

    /// The conversation's own menu, built by the same code so the two screens can never
    /// drift apart — minus `hiddenMenuActionTitles`. Only the handful that need the
    /// conversation on screen are wrapped, to close this one first.
    open func items(contextMenu: ContextMenu, identifier: Identifier) -> [MenuItem] {
        guard let channelViewController,
              let model = identifier.value as? MessageLayoutModel
        else { return [] }

        let conversationModel = conversationLayoutModel(for: model)
        return channelViewController
            .items(contextMenu: contextMenu, identifier: .init(value: conversationModel))
            .filter { !hiddenMenuActionTitles.contains($0.title) }
            .map { item in
                if let localItem = localMenuItem(replacing: item, for: model) {
                    return localItem
                }
                guard menuActionTitlesReturningToConversation.contains(item.title)
                else { return item }
                var item = item
                let action = item.action
                item.action = { [weak self] menuItem in
                    self?.close {
                        action(menuItem)
                    }
                }
                return item
            }
    }

    // MARK: - ContextMenuDelegate

    /// Reacting needs nothing on screen, so it happens right here — against the
    /// conversation's own model, and the row picks the reaction up through the message
    /// observer, the same way the conversation's cell does.
    open func didSelect(emoji: String, forViewWith identifier: Identifier) {
        guard let model = identifier.value as? MessageLayoutModel else { return }
        channelViewController?.channelViewModel
            .addReaction(layoutModel: conversationLayoutModel(for: model), key: emoji)
    }

    open func didDeselect(emoji: String, forViewWith identifier: Identifier) {
        guard let model = identifier.value as? MessageLayoutModel else { return }
        channelViewController?.channelViewModel
            .deleteReaction(layoutModel: conversationLayoutModel(for: model), key: emoji)
    }

    /// The "+" at the end of the reaction row opens the full picker, which the
    /// conversation presents.
    open func didSelectMoreAction(forViewWith identifier: Identifier) {
        guard let model = identifier.value as? MessageLayoutModel else { return }
        handOffToConversation(for: model) { channelViewController, conversationModel in
            channelViewController.addReaction(layoutModel: conversationModel)
        }
    }

    // MARK: - ContextMenuSnapshotDelegate

    open func willMakeSnapshot(forViewWith identifier: Identifier) {
        if #unavailable(iOS 16) {
            snapshotProvider(forViewWith: identifier)?.onPrepareSnapshot()
        }
    }

    open func didMakeSnapshot(forViewWith identifier: Identifier) {
        if #unavailable(iOS 16) {
            snapshotProvider(forViewWith: identifier)?.onFinishSnapshot()
        }
    }

    private func snapshotProvider(forViewWith identifier: Identifier) -> ContextMenuSnapshotProviding? {
        guard let model = identifier.value as? MessageLayoutModel else { return nil }
        return tableView.visibleCells
            .compactMap { ($0 as? MessageCell)?.messageView }
            .first { $0.data?.message == model.message }
    }
}

public extension ChannelPinnedMessageListViewController {
    enum Layouts {
        /// Trailing space under the last bubble; the spacing above every bubble is the
        /// conversation's own, carried by the layout models.
        public static var bottomPadding: CGFloat = 8

        /// How far off the end the list may rest and still follow a pin taken while the
        /// screen is open.
        public static var followBottomThreshold: CGFloat = 40

        /// How long the space around the rows takes to settle after a pin is added or
        /// removed — matched to the table's own row animation.
        public static var rowAnimationDuration: TimeInterval = 0.3
    }
}
