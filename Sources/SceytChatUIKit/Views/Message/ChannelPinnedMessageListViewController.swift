//
//  ChannelPinnedMessageListViewController.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import UIKit

/// The standalone pinned-messages screen: every live pin in one channel, opened from the
/// pin button at the trailing edge of `ChannelViewController.PinnedMessagesView`.
///
/// The rows are the conversation's own message cells, so the screen behaves like the
/// conversation: long press opens the same context menu with the same actions and the same
/// reaction row, media opens in the same previewer, polls take votes, links follow. It also
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
/// Actions the screen cannot serve on its own — the composer, selection mode, anything
/// presented over the conversation — are handed back to `channelViewController`, after the
/// screen closes, so the user lands where the action actually happens.
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

    public private(set) lazy var contextMenu: ContextMenu = {
        let contextMenu = ContextMenu(parent: self)
        contextMenu.dataSource = self
        contextMenu.delegate = self
        contextMenu.snapshotDelegate = self
        return contextMenu
    }()

    /// Menu actions that need the conversation itself on screen: they drive its composer,
    /// switch it into selection mode, or present over it. The screen closes and hands
    /// those over; everything else — copy, pin, unpin, delete, retract vote — runs right
    /// here, the way the row's swipe action does.
    open var menuActionTitlesReturningToConversation: Set<String> = [
        L10n.Message.Action.Title.reply,
        L10n.Message.Action.Title.edit,
        L10n.Message.Action.Title.forward,
        L10n.Message.Action.Title.select,
        // `ChannelViewController` builds this one from a bare string, and it opens a
        // confirmation alert over the conversation.
        "End Poll"
    ]

    /// Menu actions this screen leaves out of the message menu entirely. Message info is
    /// the conversation's own screen — it lists who received and read the message, which
    /// is a detour from a list whose one job is finding a pin and jumping to it — so the
    /// pinned rows drop it and keep the menu to the actions that act on the pin itself.
    open var hiddenMenuActionTitles: Set<String> = [
        L10n.Message.Action.Title.info
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
        // of the list is the one edge nothing pads.
        tableView.contentInset.bottom = Layouts.bottomPadding
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

        setupNavigationBarItems()
        setupGestureRecognizers()

        viewModel.startDatabaseObserver()
        viewModel.$event
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)

        updateEmptyState()
    }

    open func setupNavigationBarItems() {
        closeButton.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers
            .PinnedMessageList.closeButton
        navigationItem.rightBarButtonItem = closeButton
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

        tableView.pin(to: view, anchors: [.leading, .trailing, .top, .bottom])
        emptyStateView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .trailing, .top, .bottom])
    }

    open override func setupAppearance() {
        super.setupAppearance()

        navigationController?.navigationBar.apply(appearance: appearance.navigationBarAppearance)
        view.backgroundColor = appearance.backgroundColor
        tableView.backgroundColor = .clear
        emptyStateView.parentAppearance = appearance.emptyStateAppearance

        closeButton.image = appearance.closeIcon
        closeButton.tintColor = appearance.closeIconTintColor
    }

    open func onEvent(_ event: ChannelPinnedMessageListViewModel.Event) {
        switch event {
        case .reload:
            // Read before the reload: whether the list was resting on the newest pin is what
            // decides if it follows a pin taken while the screen is open. The conversation
            // follows a new message on the same terms — only from the bottom, so a user who
            // has scrolled back through the older pins is left where they are.
            let wasAtBottom = isAtBottom
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
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

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
            - Layouts.bottomPadding
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

    // MARK: - Message cell actions

    /// The conversation's own model for a pinned message, so an action handed back runs
    /// against the model its message list is showing rather than this screen's copy.
    open func conversationLayoutModel(for model: MessageLayoutModel) -> MessageLayoutModel {
        channelViewController?.channelViewModel.createLayoutModel(for: model.message) ?? model
    }

    /// Everything a bubble can ask its screen to do. What needs nothing but the store — a
    /// poll vote, a paused download, a played voice note, a reaction removed from the
    /// pill — happens here; the rest is the conversation's, and the screen closes before
    /// handing it over so the user sees where it landed.
    open func handleMessageCellAction(
        _ action: ChatMessageCell.Action,
        layoutModel model: MessageLayoutModel
    ) {
        switch action {
        case .didTapReadMore:
            expandText(for: model)
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
        messageView(forGesture: sender)?.handleTap(sender: sender)
    }

    @objc
    open func handleLongPressGestureRecognizer(_ sender: UILongPressGestureRecognizer) {
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
        guard let item = viewModel.item(at: indexPath),
              let model = viewModel.layoutModel(at: indexPath)
        else { return UITableViewCell() }

        // Which side of the screen the bubble sits on is the cell's class, the same way
        // the conversation picks between its two message cells.
        let cell: MessageCell = model.message.incoming
            ? tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelPinnedMessageIncomingCell.self)
            : tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelPinnedMessageOutgoingCell.self)
        cell.appearance = appearance
        cell.data = model
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
        return cell
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
        guard let item = viewModel.item(at: indexPath),
              viewModel.canUnpin(item)
        else { return nil }
        let unpin = UIContextualAction(
            style: .destructive,
            title: appearance.unpinActionTitleText
        ) { [weak self] _, _, handler in
            self?.unpin(at: indexPath)
            handler(true)
        }
        unpin.backgroundColor = appearance.unpinActionBackgroundColor
        return UISwipeActionsConfiguration(actions: [unpin])
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
    }
}
