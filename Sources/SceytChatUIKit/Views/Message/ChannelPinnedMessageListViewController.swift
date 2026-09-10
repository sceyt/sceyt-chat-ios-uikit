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
/// reaction row, media opens in the same previewer, polls take votes, links follow.
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
            tableView.reloadData()
            updateEmptyState()
        }
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
    }
}
