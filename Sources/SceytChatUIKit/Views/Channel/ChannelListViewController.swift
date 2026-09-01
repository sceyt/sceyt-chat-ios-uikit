//
//  ChannelListViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

open class ChannelListViewController: ViewController,
                          UITableViewDelegate, UITableViewDataSource,
                          UITextFieldDelegate,
                          UISearchResultsUpdating {

    // MARK: - Data Source Configuration

    public enum DataSourceMode {
        case imperative
        case diffable
    }

    open var dataSourceMode: DataSourceMode = .imperative

    private var diffableDataSource: UITableViewDiffableDataSource<Int, ChannelId>?
    private var channelFingerprints: [ChannelId: ChannelFingerprint] = [:]

    // MARK: - Swipe Actions

    /// Which side of a row is showing its actions.
    public enum SwipeSide {
        case leading
        case trailing
    }

    /// The one row whose swipe actions are open.
    public struct SwipeState: Equatable {
        public let channelId: ChannelId
        public let side: SwipeSide
        public var offset: CGFloat
    }

    /// The open swipe, keyed by **channel id** rather than index path.
    ///
    /// This is the whole reason the channel list draws its own swipe actions:
    /// UIKit keys its open swipe to a cell instance and an index path, and a
    /// channel bump invalidates both — there is no public API to carry an open
    /// swipe across a row move, nor to re-open one. Keying by id means the row
    /// that moves from position 5 to 0 comes back out of `cellForRowAt` already
    /// open, and its action still targets the channel the user swiped.
    public private(set) var openSwipe: SwipeState?

    /// Renders swipe actions with `UISwipeActionsConfiguration` instead of the
    /// in-cell implementation.
    ///
    /// The native path cannot keep the actions open across a channel reorder —
    /// that limitation is why the in-cell implementation exists — but it is kept
    /// as a one-line escape hatch for integrators who had customized the
    /// `UITableViewDelegate` swipe methods.
    open var usesNativeSwipeActions = false

    /// Whether an over-drag performs the outermost action, the way
    /// `UISwipeActionsConfiguration.performsFirstActionWithFullSwipe` does.
    ///
    /// Off by default, unlike UIKit: both trailing actions this SDK ships are
    /// destructive (`.delete` / `.leave`), and `.delete` opens a confirmation
    /// sheet, so an accidental over-drag would throw a modal at the user. Turn
    /// it on if your `trailingActions(chatChannel:)` puts a safe, reversible
    /// action first.
    open var performsFirstActionWithFullSwipe = false

    /// `tableView.isScrollEnabled` as it was before a swipe suppressed it.
    private var tableScrollWasEnabledBeforeSwipe = true

    // MARK: -

    open lazy var channelListViewModel = Components.channelListViewModel
        .init(cellAppearance: appearance.cellAppearance)

    open lazy var channelListRouter = Components.channelListRouter
        .init(rootViewController: self)

    open lazy var tableView = TableView
        .init()
        .withoutAutoresizingMask
        .rowAutomaticDimension

    open lazy var emptyView = Components.emptyStateView
        .init()
        .withoutAutoresizingMask

    open var globalSearchEnabled: Bool = false
    
    open lazy var searchController = Components.channelSearchController
        .init(searchResultsController: searchResultsViewController)

    open lazy var searchResultsViewController: ChannelSearchResultsBaseViewController = {
        if globalSearchEnabled {
            return Components.globalSearchResultsViewController.init()
        } else {
            return Components.channelSearchResultsViewController.init()
        }
    }()

    private var isViewDidAppear = false

    /// Channel opened from a search result while the search was active. The search is
    /// ended only if the user actually sends a message there — merely looking into the
    /// channel and coming back keeps the search and its results.
    private var searchOpenedChannelId: ChannelId?

    open override func setup() {
        super.setup()
        title = L10n.Channel.List.title
        tabBarItem.title = L10n.Channel.List.title

        navigationItem.rightBarButtonItem = .init(image: .channelNew,
                                                  style: .plain,
                                                  target: self,
                                                  action: #selector(newChannelAction(_:)))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier =
            SceytChatUIKit.AccessibilityIdentifiers.ChannelList.newChannelButton

        tableView.register(Components.channelCell)
        tableView.accessibilityIdentifier =
            SceytChatUIKit.AccessibilityIdentifiers.ChannelList.tableView
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.tableFooterView = UIView()
        tableView.separatorStyle = .none
        // Fixed row height so the cell doesn't change between 1-line and 2-line previews.
        // Sized for the current Dynamic Type category; recomputed in traitCollectionDidChange.
        tableView.rowHeight = ChannelCell.Layouts.cellHeight(compatibleWith: traitCollection)
        tableView.estimatedRowHeight = ChannelCell.Layouts.cellHeight(compatibleWith: traitCollection)
        setupTableViewDelegates()

        navigationItem.hidesSearchBarWhenScrolling = true
        searchResultsViewController.resultsUpdater = channelListViewModel
        navigationItem.searchController = searchController
        searchController.searchResultsUpdater = self
        searchController.searchBar.accessibilityIdentifier =
            SceytChatUIKit.AccessibilityIdentifiers.ChannelList.searchBar
        
        if globalSearchEnabled {
            searchController.showsSearchResultsController = true
            searchController.delegate = self
        }

        if let globalVC = searchResultsViewController as? GlobalSearchResultsViewController {
            globalVC.searchUserBarView.onSelect = { [weak self] user in
                self?.addUserSearchToken(user)
            }
            globalVC.onSelectMessage = { [weak self] message, channel in
                self?.searchOpenedChannelId = channel.id
                self?.channelListRouter.showChannelViewController(channel: channel, scrollToMessageId: message.id)
            }
            globalVC.onSelectAttachment = { [weak self] attachment in
                self?.channelListRouter.showAttachment(attachment)
            }
        }

        definesPresentationContext = true

        emptyView.isHidden = true
        emptyView.accessibilityIdentifier =
            SceytChatUIKit.AccessibilityIdentifiers.ChannelList.emptyView

        KeyboardObserver()
            .willShow { [weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }.willHide { [weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }
    }

    open func setupTableViewDelegates() {
        tableView.delegate = self
        if dataSourceMode == .diffable {
            setupDiffableDataSource()
            applyCurrentSnapshot()
        } else {
            tableView.dataSource = self
        }
    }

    open func setupDiffableDataSource() {
        let ds = UITableViewDiffableDataSource<Int, ChannelId>(tableView: tableView) { [weak self] tableView, indexPath, channelId in
            guard let self else { return UITableViewCell() }
            return self.tableView(tableView, cellForRowAt: indexPath, channelId: channelId)
        }
        diffableDataSource = ds
    }

    open func applyCurrentSnapshot(animation: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, ChannelId>()
        snapshot.appendSections([0])

        var newFingerprints: [ChannelId: ChannelFingerprint] = [:]
        var changedIds: [ChannelId] = []
        var seenIds = Set<ChannelId>()
        let count = channelListViewModel.numberOfChannel(at: 0)
        var ids: [ChannelId] = []
        ids.reserveCapacity(count)

        for row in 0..<count {
            guard let channel = channelListViewModel.channel(at: IndexPath(row: row, section: 0)) else { continue }
            guard seenIds.insert(channel.id).inserted else { continue }
            let fp = makeFingerprint(for: channel)
            newFingerprints[channel.id] = fp
            if channelFingerprints[channel.id] != fp {
                changedIds.append(channel.id)
            }
            ids.append(channel.id)
        }
        snapshot.appendItems(ids, toSection: 0)

        // `reloadItems` re-dequeues the cell, which drops an open swipe's offset
        // for a frame — `cellForRowAt` restores it, but the buttons visibly
        // rebuild. Rebind the open row in place instead.
        let openChannelId = openSwipe?.channelId
        let reloadableIds = openChannelId == nil
            ? changedIds
            : changedIds.filter { $0 != openChannelId }
        if !reloadableIds.isEmpty {
            snapshot.reloadItems(reloadableIds)
        }
        channelFingerprints = newFingerprints
        diffableDataSource?.apply(snapshot, animatingDifferences: animation) { [weak self] in
            guard let self,
                  let openChannelId,
                  changedIds.contains(openChannelId)
            else { return }
            self.reconfigureOpenSwipeRow(channelId: openChannelId)
        }
    }

    /// Re-binds the open row's content while preserving its cell — and therefore
    /// its swipe offset.
    ///
    /// `reconfigureItems` keeps the cell instance but is iOS 15+; on iOS 13/14
    /// `updateVisibleCell(indexPath:)` is the equivalent in-place rebind.
    private func reconfigureOpenSwipeRow(channelId: ChannelId) {
        guard let dataSource = diffableDataSource,
              let indexPath = dataSource.indexPath(for: channelId)
        else { return }
        if #available(iOS 15.0, *) {
            var snapshot = dataSource.snapshot()
            snapshot.reconfigureItems([channelId])
            dataSource.apply(snapshot, animatingDifferences: false)
        } else {
            updateVisibleCell(indexPath: indexPath)
        }
    }

    open func applyDiffableUpdatesOnly(at indexPaths: [IndexPath]) {
        indexPaths.forEach { updateVisibleCell(indexPath: $0) }
    }

    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        closeOpenSwipe(animated: true)
        guard let indexPath = tableView.indexPathForSelectedRow else { return }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    open func updateVisibleCell(indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? ChannelCell else { return }
        cell.parentAppearance = appearance.cellAppearance
        let item: ChannelLayoutModel?
        if dataSourceMode == .diffable,
           let channelId = diffableDataSource?.itemIdentifier(for: indexPath) {
            item = channelListViewModel.layoutModel(id: channelId)
        } else {
            item = channelListViewModel.layoutModel(at: indexPath)
        }
        if let item {
            cell.data = item
            // Re-binding can change which actions the channel offers (a
            // mute/unmute or read/unread flip), and therefore the reveal width,
            // so the offset has to be re-applied and re-clamped.
            bindSwipe(on: cell, channelId: item.channel.id)
        }
    }

    /// Attaches the swipe callbacks to a cell and restores this channel's open
    /// offset, if it is the open one.
    ///
    /// Called from both `cellForRowAt` paths and from `updateVisibleCell`. This
    /// is load-bearing rather than defensive: every update path in this file
    /// re-dequeues the bumped channel's cell — the imperative branch reloads the
    /// moved rows after the batch, and the diffable branch's `reloadItems`
    /// recreates the cell (`reconfigureItems`, which would preserve it, is iOS
    /// 15+ while this SDK targets iOS 13). So the offset can only survive a
    /// reorder by being re-applied here.
    open func bindSwipe(on cell: ChannelCell, channelId: ChannelId) {
        cell.swipeActionsEnabled = !usesNativeSwipeActions
        cell.performsFirstActionWithFullSwipe = performsFirstActionWithFullSwipe
        cell.onSwipeEvent = { [weak self, weak cell] event in
            guard let self, let cell else { return }
            self.handleSwipeEvent(event, channelId: channelId, cell: cell)
        }
        if let openSwipe, openSwipe.channelId == channelId {
            cell.setSwipeOffset(openSwipe.offset, animated: false)
        } else {
            cell.setSwipeOffset(0, animated: false)
        }
    }

    /// The cell currently displaying `channelId`, if it is on screen.
    open func visibleCell(for channelId: ChannelId) -> ChannelCell? {
        tableView.visibleCells
            .compactMap { $0 as? ChannelCell }
            .first { $0.data?.channel.id == channelId }
    }

    open func handleSwipeEvent(_ event: ChannelCell.SwipeEvent,
                               channelId: ChannelId,
                               cell: ChannelCell) {
        switch event {
        case .began:
            // UIKit allowed only one open swipe at a time; so do we.
            closeOpenSwipe(except: channelId, animated: true)
            if let selected = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: selected, animated: true)
            }
            channelListViewModel.deselectChannel()
            swipeDidBegin(on: cell)

        case let .changed(offset):
            openSwipe = swipeState(channelId: channelId, offset: offset)

        case let .settled(offset):
            openSwipe = swipeState(channelId: channelId, offset: offset)
            swipeDidEnd(on: cell)

        case let .action(action):
            guard let channel = channelListViewModel.channel(id: channelId) else { return }
            // Sequenced on the close animation rather than a fixed delay, so an
            // alert is never presented over a still-collapsing row.
            closeOpenSwipe(animated: true) { [weak self] in
                self?.onSwipeAction(action, channel: channel)
            }
        }
    }

    private func swipeState(channelId: ChannelId, offset: CGFloat) -> SwipeState? {
        guard offset != 0 else { return nil }
        return SwipeState(channelId: channelId,
                          side: offset < 0 ? .trailing : .leading,
                          offset: offset)
    }

    /// Stops the table scrolling for the duration of a swipe. A scroll view
    /// begins its pan on any direction, so without this the list would scroll
    /// under a horizontal drag.
    open func swipeDidBegin(on cell: ChannelCell) {
        tableScrollWasEnabledBeforeSwipe = tableView.isScrollEnabled
        tableView.isScrollEnabled = false
    }

    open func swipeDidEnd(on cell: ChannelCell) {
        restoreTableScrollAfterSwipe()
    }

    /// Restored unconditionally — a scroll left disabled is a frozen list, the
    /// one severe failure mode of suppressing it during a gesture.
    private func restoreTableScrollAfterSwipe() {
        tableView.isScrollEnabled = tableScrollWasEnabledBeforeSwipe
    }

    /// Closes the open swipe, unless it belongs to `channelId`.
    open func closeOpenSwipe(except channelId: ChannelId? = nil,
                             animated: Bool,
                             completion: (() -> Void)? = nil) {
        guard let open = openSwipe, open.channelId != channelId else {
            completion?()
            return
        }
        openSwipe = nil
        guard let cell = visibleCell(for: open.channelId) else {
            completion?()
            return
        }
        cell.setSwipeOffset(0, animated: animated, completion: completion)
    }

    open override func setupLayout() {
        super.setupLayout()
        SceytChatUIKit.shared.config.storageConfig.userDefaults.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        view.addSubview(tableView)
        view.addSubview(emptyView)
        tableView.pin(to: view)
        emptyView.pin(to: view.safeAreaLayoutGuide)
    }

    open override func setupAppearance() {
        super.setupAppearance()
        navigationController?.navigationBar.apply(appearance: appearance.navigationBarAppearance)
        
        tabBarItem.badgeColor = appearance.tabBarItemBadgeColor
        view.backgroundColor = appearance.backgroundColor
        tableView.backgroundColor = .clear
        emptyView.parentAppearance = appearance.emptyViewAppearance
        searchController.parentAppearance = appearance.searchControllerAppearance
        if let globalVC = searchResultsViewController as? GlobalSearchResultsViewController {
            globalVC.parentAppearance = appearance.globalSearchControllerAppearance
        } else {
            searchResultsViewController.parentAppearance = appearance.searchResultControllerAppearance
        }
    }

    open override func setupDone() {
        super.setupDone()
        channelListViewModel.startDatabaseObserver()
        channelListViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: .didSendUserMessage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.didSendUserMessage(notification)
            }.store(in: &subscriptions)
    }

    /// A message was sent somewhere in the app. If it went to the channel this search
    /// opened, the result has served its purpose — end the search now, while the channel
    /// screen still covers the list, so coming back reveals the plain channel list.
    open func didSendUserMessage(_ notification: Notification) {
        guard let openedChannelId = searchOpenedChannelId,
              let channelId = notification.userInfo?[ChannelViewModel.didSendUserMessageChannelIdKey] as? ChannelId,
              channelId == openedChannelId
        else { return }
        searchOpenedChannelId = nil
        endSearch()
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isViewDidAppear = true
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.visibleCells.forEach {
            ($0 as? ChannelCell)?.subscribeForPresence()
        }
        // Back on the list: nothing was sent in the opened channel, so the search stays.
        searchOpenedChannelId = nil
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isViewDidAppear = false
        closeOpenSwipe(animated: false)
        // Unconditional: a mid-gesture navigation must not leave the list frozen.
        restoreTableScrollAfterSwipe()
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: false)
        }
        channelListViewModel.deselectChannel()
    }

    /// Clears the search bar text, tokens and dismisses the search controller.
    /// Called after a search result opened a channel, so coming back shows the plain channel list.
    open func endSearch() {
        let searchBar = searchController.searchBar
        let textField = searchBar.searchTextField

        if let globalVC = searchResultsViewController as? GlobalSearchResultsViewController {
            NSObject.cancelPreviousPerformRequests(
                withTarget: globalVC,
                selector: #selector(GlobalSearchResultsViewController.search(query:)),
                object: lastSearchText
            )
            globalVC.hasSearchToken = false
            globalVC.filterUser = nil
        } else {
            NSObject.cancelPreviousPerformRequests(
                withTarget: channelListViewModel,
                selector: #selector(ChannelListViewModel.search(query:)),
                object: lastSearchText
            )
        }
        lastSearchText = nil

        while !textField.tokens.isEmpty {
            textField.removeToken(at: textField.tokens.count - 1)
        }
        searchBar.text = nil
        searchBar.resignFirstResponder()
        searchController.isActive = false
    }

    open func adjustTableViewToKeyboard(notification: Notification) {
        tableView.adjustInsetsToKeyboard(notification: notification, container: view)
    }

    @objc
    func newChannelAction(_ sender: UIBarItem) {
        channelListRouter.showNewChannel()
    }

    @objc
    private func leftButtonAction(_ sender: UIBarItem, event: UIEvent) {
        guard let touch = event.allTouches?.first
        else { return }
        guard touch.tapCount == 5
        else { return }
        sender.isEnabled = false
        channelListViewModel.deleteDataBase { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
                sender.isEnabled = true
            }
        }
    }

    // MARK: ViewModel Event

    open func onEvent(_ event: ChannelListViewModel.Event) {
        switch event {
        case let .change(paths):
            updateTableView(paths: paths)
            showEmptyViewIfNeeded()
        case .reload:
            reloadTableView()
            showEmptyViewIfNeeded()
        case .resetFingerprints:
            channelFingerprints = [:]
        case .reloadSearch:
            searchResultsViewController.reloadData()
        case let .unreadMessagesCount(count):
            updateUnreadMessages(count: count)
        case let .connection(state):
            updateConnectionState(state)
        case let .typing(isTyping, user, channel):
            for cell in tableView.visibleCells where cell is ChannelCell {
                let channelCell = (cell as! ChannelCell)
                if channelCell.data?.channel.id == channel.id {
                    if isTyping {
                        channelCell.didStartTyping(user: user)
                    } else {
                        channelCell.didStopTyping(user: user)
                    }
                    return
                }
            }
        case let .recording(isRecording, user, channel):
            for cell in tableView.visibleCells where cell is ChannelCell {
                let channelCell = (cell as! ChannelCell)
                if channelCell.data?.channel.id == channel.id {
                    if isRecording {
                        channelCell.didStartRecording(user: user)
                    } else {
                        channelCell.didStopRecording(user: user)
                    }
                    return
                }
            }
        case .showChannel(let channel):
            if searchController.isActive {
                searchOpenedChannelId = channel.id
            }
            channelListRouter.showChannelViewController(channel: channel)
        }
    }

    open func reloadTableView() {
        // A full reload rebuilds every cell, so there is nothing for an open
        // swipe to stay attached to.
        closeOpenSwipe(animated: false)
        if dataSourceMode == .diffable {
            applyCurrentSnapshot()
        } else {
            tableView.reloadData()
        }
    }

    open func reloadTableViewAfterContentSizeCategoryChange() {
        // The action button widths change with the content size category, so an
        // open offset would no longer match its buttons.
        closeOpenSwipe(animated: false)
        UIView.performWithoutAnimation {
            tableView.reloadData()
            tableView.setNeedsLayout()
            tableView.layoutIfNeeded()
        }
    }

    open func updateTableView(paths: ChannelListViewModel.Paths) {
        // The swiped channel may have been deleted elsewhere. Drop the state
        // before applying, so nothing tries to restore an offset onto a row that
        // no longer exists.
        if let open = openSwipe, channelListViewModel.channel(id: open.channelId) == nil {
            openSwipe = nil
        }
        if dataSourceMode == .diffable {
            let hasStructuralChanges = !paths.inserts.isEmpty
                || !paths.deletes.isEmpty
                || !paths.moves.isEmpty
            if hasStructuralChanges || paths.updates.isEmpty {
                let hasDraftMove = !paths.moves.isEmpty
                && paths.moves.allSatisfy { move in
                    guard let channel = channelListViewModel.channel(at: move.to) else { return false }
                    return hasDraftChanged(channel)
                }
                && paths.inserts.isEmpty
                && paths.deletes.isEmpty

                applyCurrentSnapshot(animation: !hasDraftMove)
            } else {
                let hasLastMessageIdChanged = paths.updates.contains { indexPath in
                    guard let channel = channelListViewModel.channel(at: indexPath) else { return false }
                    let fp = channelFingerprints[channel.id]
                    return channel.lastMessage?.tid != fp?.lastMessageTid
                    || channel.lastMessage?.id != fp?.lastMessageId
                }

                if hasLastMessageIdChanged {
                    // No longer special-cased for an open swipe: the offset is
                    // keyed by channel id and restored in `cellForRowAt`, so the
                    // list can always apply the correct order.
                    applyCurrentSnapshot(animation: false)
                } else {
                    let hasDraftChange = paths.updates.contains { indexPath in
                        guard let channel = channelListViewModel.channel(at: indexPath) else { return false }
                        return hasDraftChanged(channel)
                    }
                    if hasDraftChange {
                        applyCurrentSnapshot(animation: false)
                    } else {
                        applyDiffableUpdatesOnly(at: paths.updates)
                    }
                }
            }
        } else {
            if view.window == nil || tableView.visibleCells.isEmpty || !isViewDidAppear {
                tableView.reloadData()
            } else {
                UIView.performWithoutAnimation {
                    tableView.performBatchUpdates {
                        tableView.insertRows(at: paths.inserts, with: .none)
                        tableView.reloadRows(at: paths.updates, with: .none)
                        tableView.deleteRows(at: paths.deletes, with: .none)
                        paths.moves.forEach { move in
                            tableView.moveRow(at: move.from, to: move.to)
                        }
                    } completion: { [weak self] _ in
                        guard let self else { return }
                        UIView.performWithoutAnimation {
                            let movedTo = paths.moves.map { $0.to }
                            let openChannelId = self.openSwipe?.channelId
                            // `reloadRows` re-dequeues, which would rebuild the
                            // action buttons under the user's finger and drop the
                            // offset. The open row is rebound in place instead.
                            let (openRows, reloadableRows) = movedTo.reduce(
                                into: ([IndexPath](), [IndexPath]())
                            ) { result, indexPath in
                                if let openChannelId,
                                   self.channelListViewModel.channel(at: indexPath)?.id == openChannelId {
                                    result.0.append(indexPath)
                                } else {
                                    result.1.append(indexPath)
                                }
                            }
                            self.tableView.reloadRows(at: reloadableRows, with: .none)
                            openRows.forEach { self.updateVisibleCell(indexPath: $0) }
                        }
                    }
                }
            }
        }
    }

    open func showEmptyViewIfNeeded() {
        emptyView.isHidden = channelListViewModel.numberOfSections > 0
    }

    open func updateUnreadMessages(count: Int) {
        RunLoop.main.perform { [weak self] in
            guard let self
            else { return }
            self.navigationController?.tabBarItem.badgeValue = count == 0 ?
            nil :
            SceytChatUIKit.shared.formatters.unreadCountFormatter.format(UInt64(count))
        }
        updateApplicationBadgeNumberWithUnreadMessagesCount(count)
    }

    open func updateApplicationBadgeNumberWithUnreadMessagesCount( _ count: Int) {
        UIApplication.shared.applicationIconBadgeNumber = count
    }

    open func updateConnectionState(_ state: ConnectionState) {
        title = L10n.Channel.List.title
        tabBarItem.title = L10n.Channel.List.title
        navigationItem.titleView = Components.connectionStateView.init(state: state, appearance: appearance.connectionIndicatorAppearance)
    }

    /// Performs a swipe action on the channel it was invoked for.
    ///
    /// Takes the channel, not an index path: the previous index-path form
    /// resolved its target positionally *after* a delay — and after an
    /// unbounded, user-driven confirmation sheet for `.delete` and `.mute` — by
    /// which time an inbound message (or the action's own reorder, for `.pin`
    /// and `.markAs(read:)`) could have moved a different channel into that row.
    open func onSwipeAction(_ action: ChannelSwipeActionsConfiguration.Actions,
                            channel: ChatChannel) {
        switch action {
        case .delete:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            channelListRouter.showAskForDelete { [weak self] confirmed in
                guard confirmed else { return }
                self?.channelListViewModel.delete(channel: channel)
            }
        case .leave:
            channelListViewModel.leave(channel: channel)
        case .read:
            channelListViewModel.markAs(read: true, channel: channel)
        case .unread:
            channelListViewModel.markAs(read: false, channel: channel)
        case .mute:
            channelListRouter.showMuteOptionsAlert { [weak self] item in
                self?.channelListViewModel.mute(item.timeInterval, channel: channel)
            } canceled: {}
        case .unmute:
            channelListViewModel.unmute(channel: channel)
        case .pin:
            channelListViewModel.pin(channel: channel)
        case .unpin:
            channelListViewModel.unpin(channel: channel)
        }
    }

    @available(*, deprecated, renamed: "onSwipeAction(_:channel:)",
                message: "An index path resolves positionally and mis-targets once the list reorders, which an open swipe now survives. Override onSwipeAction(_:channel:) instead.")
    open func onSwipeAction(actions: ChannelSwipeActionsConfiguration.Actions,
                            indexPath: IndexPath) {
        guard let channel = channelListViewModel.channel(at: indexPath) else { return }
        onSwipeAction(actions, channel: channel)
    }

    // MARK: UITableViewDelegate

    /// Disables UIKit's editing machinery — and with it the swipe-action
    /// configuration methods below — unless the native path was opted back into.
    ///
    /// This is the only reliable way to stop UIKit consulting the delegate for a
    /// swipe configuration; returning `nil` from those methods is not enough,
    /// because UIKit would still run its own gesture alongside the in-cell pan.
    open func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        usesNativeSwipeActions
    }

    @available(*, deprecated, message: "Only consulted when usesNativeSwipeActions is true. The in-cell implementation is driven by ChannelSwipeActionsConfiguration.trailingActions(chatChannel:) and ChannelListViewController.onSwipeAction(_:channel:).")
    open func tableView(_ tableView: UITableView,
                        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard usesNativeSwipeActions,
              let channel = channelListViewModel.channel(at: indexPath)
        else { return nil }
        return ChannelSwipeActionsConfiguration
            .trailingSwipeActionsConfiguration(for: channel) { [weak self] _,_, actions, handler in
                self?.onSwipeAction(actions, channel: channel)
                handler(true)
            }
    }

    @available(*, deprecated, message: "Only consulted when usesNativeSwipeActions is true. The in-cell implementation is driven by ChannelSwipeActionsConfiguration.leadingActions(chatChannel:) and ChannelListViewController.onSwipeAction(_:channel:).")
    open func tableView(_ tableView: UITableView,
                        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard usesNativeSwipeActions,
              let channel = channelListViewModel.channel(at: indexPath)
        else { return nil }
        return ChannelSwipeActionsConfiguration
            .leadingSwipeActionsConfiguration(for: channel) { [weak self] _,_, actions, handler in
                self?.onSwipeAction(actions, channel: channel)
                handler(true)
            }
    }

    @available(*, deprecated, message: "The channel list no longer uses UITableView editing for swipe actions. Kept so existing overrides still compile; it is called only when usesNativeSwipeActions is true.")
    open func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        channelListViewModel.deselectChannel()
    }

    @available(*, deprecated, message: "The channel list no longer uses UITableView editing for swipe actions. Kept so existing overrides still compile; it is called only when usesNativeSwipeActions is true.")
    open func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {}

    open func tableView(_ tableView: UITableView,
                        didSelectRowAt indexPath: IndexPath) {
        // A tap while a row is open dismisses its actions instead of navigating
        // — the escape hatch UIKit's swipe actions gave by swallowing that tap.
        if openSwipe != nil {
            tableView.deselectRow(at: indexPath, animated: false)
            closeOpenSwipe(animated: true)
            return
        }
        channelListRouter.showChannelViewController(at: indexPath)
        channelListViewModel.selectChannel(at: indexPath)
    }

    open func numberOfSections(in tableView: UITableView) -> Int {
        channelListViewModel.numberOfSections
    }

    open func tableView(_ tableView: UITableView,
                        numberOfRowsInSection section: Int) -> Int {
        channelListViewModel.numberOfChannel(at: section)
    }

    open  func tableView(_ tableView: UITableView,
                         cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row > channelListViewModel.numberOfChannel(at: indexPath.section) - 3 {
            channelListViewModel.loadChannels()
        }
        let cell = tableView.dequeueReusableCell(for: indexPath,
                                                 cellType: Components.channelCell)
        if let item = channelListViewModel.layoutModel(at: indexPath) {
            configure(cell: cell, with: item, at: indexPath)
        }

        return cell
    }

    open func tableView(_ tableView: UITableView,
                        cellForRowAt indexPath: IndexPath,
                        channelId: ChannelId) -> UITableViewCell {
        if indexPath.row > channelListViewModel.numberOfChannel(at: indexPath.section) - 3 {
            channelListViewModel.loadChannels()
        }
        let cell = tableView.dequeueReusableCell(for: indexPath,
                                                 cellType: Components.channelCell)
        if let item = channelListViewModel.layoutModel(id: channelId) {
            configure(cell: cell, with: item, at: indexPath)
        }

        return cell
    }

    /// Binds a channel to a freshly dequeued cell.
    ///
    /// Shared by both data source modes so the swipe restore cannot be wired up
    /// in one and forgotten in the other.
    open func configure(cell: ChannelCell, with item: ChannelLayoutModel, at indexPath: IndexPath) {
        cell.parentAppearance = appearance.cellAppearance
        cell.data = item
        if channelListViewModel.isSelected(item.channel) {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
        bindSwipe(on: cell, channelId: item.channel.id)
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        searchController.setupAppearance()

        // Large Text / Dynamic Type changed. On-screen cells' fonts re-scale
        // themselves (adjustsFontForContentSizeCategory), but the cached
        // last-message NSAttributedString keeps the fonts it was built with —
        // and a label does not re-scale an attributed string's embedded fonts
        // when it's assigned to a reused cell. So rebuild every cached preview
        // for the new category, drop the fingerprints so the reload re-binds
        // every row (not just rows whose channel data changed), and recompute
        // the fixed row height so rows grow to fit instead of clipping.
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            channelListViewModel.reloadAttributedViews(compatibleWith: traitCollection)
            channelFingerprints = [:]

            let height = ChannelCell.Layouts.cellHeight(compatibleWith: traitCollection)
            tableView.rowHeight = height
            tableView.estimatedRowHeight = height
            reloadTableViewAfterContentSizeCategoryChange()
        }
    }

    // MARK: - UISearchResultsUpdating

    public var lastSearchText: String?
    public func updateSearchResults(for searchController: UISearchController) {
        let text = searchController.searchBar.text
        if let globalVC = searchResultsViewController as? GlobalSearchResultsViewController {
            let hasTokens = !searchController.searchBar.searchTextField.tokens.isEmpty
            globalVC.hasSearchToken = hasTokens
            if !hasTokens {
                globalVC.filterUser = nil
            }
            globalVC.setUserBarVisible(!hasTokens, animated: true)
            NSObject.cancelPreviousPerformRequests(withTarget: globalVC, selector: #selector(GlobalSearchResultsViewController.search(query:)), object: lastSearchText)
            lastSearchText = text
            globalVC.perform(#selector(GlobalSearchResultsViewController.search(query:)), with: text, afterDelay: 0.01)
        } else {
            NSObject.cancelPreviousPerformRequests(withTarget: channelListViewModel, selector: #selector(ChannelListViewModel.search(query:)), object: lastSearchText)
            lastSearchText = text
            channelListViewModel.perform(#selector(ChannelListViewModel.search(query:)), with: text, afterDelay: 0.01)
        }
    }

    open func addUserSearchToken(_ user: ChatUser) {
        let textField = searchController.searchBar.searchTextField
        let fullName = SceytChatUIKit.shared.formatters.userShortNameFormatter.format(user)
        let name = fullName.count > 12 ? String(fullName.prefix(12)) : fullName
        let token = UISearchToken(icon: nil, text: name)
        token.representedObject = user
        textField.insertToken(token, at: textField.tokens.count)
        textField.text = nil
        if let globalVC = searchResultsViewController as? GlobalSearchResultsViewController {
            globalVC.filterUser = user
        }
        updateSearchResults(for: searchController)
    }
}

// MARK: - Diffable Data Source Fingerprinting

private extension ChannelListViewController {
    // Tracks the last-seen content fingerprint for each channel so we can
    // call reloadItems only for rows whose visible content actually changed,
    // instead of reloading every cell on every snapshot apply.
    struct ChannelFingerprint: Equatable {
        // Channel header / avatar
        let subject: String?
        let avatarUrl: String?

        // Badge counters
        let newMessageCount: UInt64
        let newMentionCount: UInt64
        let newReactionMessageCount: UInt64
        let unread: Bool

        // Icons & tinting
        let muted: Bool
        let pinnedAt: Date?
        let messageRetentionPeriod: TimeInterval

        // Draft text (NSAttributedString is not Equatable, use plain string)
        let draftMessageText: String?
        // An attachments-only draft has no text, so the type is what changes its preview.
        let draftAttachmentType: String?
        // Same for a draft that is only a reply/edit target.
        let draftActionType: String?

        // Peer presence (online dot for direct channels)
        let peerPresenceState: ChatUser.Presence.State?

        // Last message
        let lastMessageId: MessageId?
        let lastMessageTid: Int64?
        let lastMessageState: ChatMessage.State?
        let lastMessageDeliveryStatus: ChatMessage.DeliveryStatus?
        let lastMessageUpdatedAt: Date?
        let lastMessageAttachmentType: String?
        let lastMessageMetadata: String?

        // Last reaction (drives "hasReaction" preview)
        let lastReactionId: ReactionId?
        let lastReactionKey: String?
    }

    /// Whether a channel's draft differs from the one its last-rendered fingerprint captured.
    /// Covers the attachments-only case, where the text is empty on both sides.
    func hasDraftChanged(_ channel: ChatChannel) -> Bool {
        let fingerprint = channelFingerprints[channel.id]
        return channel.draftMessage?.string != fingerprint?.draftMessageText
            || channel.draftAttachmentType != fingerprint?.draftAttachmentType
            || channel.draftActionType != fingerprint?.draftActionType
    }

    func makeFingerprint(for channel: ChatChannel) -> ChannelFingerprint {
        let lastMsg = channel.lastMessage
        return ChannelFingerprint(
            subject: channel.subject,
            avatarUrl: channel.avatarUrl,
            newMessageCount: channel.newMessageCount,
            newMentionCount: channel.newMentionCount,
            newReactionMessageCount: channel.newReactionMessageCount,
            unread: channel.unread,
            muted: channel.muted,
            pinnedAt: channel.pinnedAt,
            messageRetentionPeriod: channel.messageRetentionPeriod,
            draftMessageText: channel.draftMessage?.string,
            draftAttachmentType: channel.draftAttachmentType,
            draftActionType: channel.draftActionType,
            peerPresenceState: channel.peer?.presence.state,
            lastMessageId: lastMsg?.id,
            lastMessageTid: lastMsg?.tid,
            lastMessageState: lastMsg?.state,
            lastMessageDeliveryStatus: lastMsg?.deliveryStatus,
            lastMessageUpdatedAt: lastMsg?.updatedAt,
            lastMessageAttachmentType: lastMsg?.attachments?.last?.type,
            lastMessageMetadata: lastMsg?.metadata,
            lastReactionId: channel.lastReaction?.id,
            lastReactionKey: channel.lastReaction?.key
        )
    }
}

extension ChannelListViewController: UISearchControllerDelegate {
    open func willPresentSearchController(_ searchController: UISearchController) {
        // Otherwise the open row lurks behind the results controller and is
        // revealed again when the search is dismissed.
        closeOpenSwipe(animated: false)
        if let globalVC = searchResultsViewController as? GlobalSearchResultsViewController {
            if globalVC.pageViewController == nil {
                globalVC.buildPages()
                globalVC.categoryTabBar.setSelectedIndex(0, animated: false)
            }
        }
    }

    open func didDismissSearchController(_ searchController: UISearchController) {
        if let globalVC = searchResultsViewController as? GlobalSearchResultsViewController {
            globalVC.tearDownPages()
        }
    }
}
