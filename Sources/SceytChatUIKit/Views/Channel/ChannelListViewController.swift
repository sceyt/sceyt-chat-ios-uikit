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
    private var swipeOpenIndexPath: IndexPath?

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

    open override func setup() {
        super.setup()
        title = L10n.Channel.List.title
        tabBarItem.title = L10n.Channel.List.title

        navigationItem.rightBarButtonItem = .init(image: .channelNew,
                                                  style: .plain,
                                                  target: self,
                                                  action: #selector(newChannelAction(_:)))

        tableView.register(Components.channelCell)
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.tableFooterView = UIView()
        tableView.separatorStyle = .none
        setupTableViewDelegates()

        navigationItem.hidesSearchBarWhenScrolling = true
        searchResultsViewController.resultsUpdater = channelListViewModel
        navigationItem.searchController = searchController
        searchController.searchResultsUpdater = self
        
        if globalSearchEnabled {
            searchController.showsSearchResultsController = true
        }

        if let globalVC = searchResultsViewController as? GlobalSearchResultsViewController {
            globalVC.searchUserBarView.onSelect = { [weak self] user in
                self?.addUserSearchToken(user)
            }
        }

        definesPresentationContext = true

        emptyView.isHidden = true

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
        let ds = UITableViewDiffableDataSource<Int, ChannelId>(tableView: tableView) { [weak self] tableView, indexPath, _ in
            guard let self else { return UITableViewCell() }
            return self.tableView(tableView, cellForRowAt: indexPath)
        }
        diffableDataSource = ds
    }

    open func applyCurrentSnapshot(animation: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, ChannelId>()
        let sectionCount = channelListViewModel.numberOfSections
        let sections = Array(0..<sectionCount)
        snapshot.appendSections(sections)

        var newFingerprints: [ChannelId: ChannelFingerprint] = [:]
        var changedIds: [ChannelId] = []
        var seenIds = Set<ChannelId>()

        for section in sections {
            let ids = (0..<channelListViewModel.numberOfChannel(at: section)).compactMap { row -> ChannelId? in
                guard let channel = channelListViewModel.channel(at: IndexPath(row: row, section: section)) else { return nil }
                guard seenIds.insert(channel.id).inserted else { return nil }
                let fp = makeFingerprint(for: channel)
                newFingerprints[channel.id] = fp
                if channelFingerprints[channel.id] != fp {
                    changedIds.append(channel.id)
                }
                return channel.id
            }
            snapshot.appendItems(ids, toSection: section)
        }

        if !changedIds.isEmpty {
            snapshot.reloadItems(changedIds)
        }
        channelFingerprints = newFingerprints
        diffableDataSource?.apply(snapshot, animatingDifferences: animation)
    }

    open func applyDiffableUpdatesOnly(at indexPaths: [IndexPath]) {
        indexPaths.forEach { updateVisibleCell(indexPath: $0) }
    }

    open func updateVisibleCell(indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? ChannelCell else { return }
        cell.parentAppearance = appearance.cellAppearance
        if let item = channelListViewModel.layoutModel(at: indexPath) {
            cell.data = item
        }
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
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isViewDidAppear = false
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: false)
        }
        channelListViewModel.deselectChannel()
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
            channelListRouter.showChannelViewController(channel: channel)
        }
    }

    open func reloadTableView() {
        if dataSourceMode == .diffable {
            applyCurrentSnapshot()
        } else {
            tableView.reloadData()
        }
    }

    open func updateTableView(paths: ChannelListViewModel.Paths) {
        if dataSourceMode == .diffable {
            let hasStructuralChanges = !paths.inserts.isEmpty
                || !paths.deletes.isEmpty
                || !paths.moves.isEmpty
                || !paths.sectionInserts.isEmpty
                || !paths.sectionDeletes.isEmpty
            if hasStructuralChanges || paths.updates.isEmpty {
                let hasDraftMove = !paths.moves.isEmpty
                && paths.moves.allSatisfy { move in
                    guard let channel = channelListViewModel.channel(at: move.to) else { return false }
                    return channel.draftMessage?.string != channelFingerprints[channel.id]?.draftMessageText
                }
                && paths.inserts.isEmpty
                && paths.deletes.isEmpty
                && paths.sectionInserts.isEmpty
                && paths.sectionDeletes.isEmpty
                
                if swipeOpenIndexPath != nil {
                    swipeOpenIndexPath = nil
                    tableView.setEditing(false, animated: false)
                    applyCurrentSnapshot(animation: !hasDraftMove)
                } else {
                    applyCurrentSnapshot(animation: !hasDraftMove)
                }
            } else {
                let hasLastMessageIdChanged = paths.updates.contains { indexPath in
                    guard let channel = channelListViewModel.channel(at: indexPath) else { return false }
                    let fp = channelFingerprints[channel.id]
                    return channel.lastMessage?.tid != fp?.lastMessageTid
                    || channel.lastMessage?.id != fp?.lastMessageId
                }

                if hasLastMessageIdChanged {
                    if let openIndexPath = swipeOpenIndexPath, paths.updates.contains(openIndexPath) {
                        applyDiffableUpdatesOnly(at: paths.updates)
                    } else {
                        applyCurrentSnapshot(animation: false)
                    }
                } else {
                    let hasDraftChange = paths.updates.contains { indexPath in
                        guard let channel = channelListViewModel.channel(at: indexPath) else { return false }
                        return channel.draftMessage?.string != channelFingerprints[channel.id]?.draftMessageText
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
                        if !paths.sectionInserts.isEmpty {
                            tableView.insertSections(paths.sectionInserts, with: .none)
                        }
                        if !paths.sectionDeletes.isEmpty {
                            tableView.deleteSections(paths.sectionDeletes, with: .none)
                        }
                        tableView.insertRows(at: paths.inserts, with: .none)
                        tableView.reloadRows(at: paths.updates, with: .none)
                        tableView.deleteRows(at: paths.deletes, with: .none)
                        paths.moves.forEach { move in
                            tableView.moveRow(at: move.from, to: move.to)
                        }
                    } completion: { [weak self] _ in
                        UIView.performWithoutAnimation {
                            self?.tableView.reloadRows(at: paths.moves.map { $0.to }, with: .none)
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

    open func onSwipeAction(actions: ChannelSwipeActionsConfiguration.Actions,
                            indexPath: IndexPath) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            switchAction()
        }

        func switchAction() {
            switch actions {
            case .delete:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                channelListRouter.showAskForDelete { [weak self] in
                    if $0 {
                        self?.channelListViewModel.delete(at: indexPath)
                    }
                }
            case .leave:
                channelListViewModel.leave(at: indexPath)
            case .read:
                channelListViewModel.markAs(read: true, at: indexPath)
            case .unread:
                channelListViewModel.markAs(read: false, at: indexPath)
            case .mute:
                channelListRouter.showMuteOptionsAlert { [weak self] item in
                    self?.channelListViewModel.mute(item.timeInterval, at: indexPath)
                } canceled: {}
            case .unmute:
                channelListViewModel.unmute(at: indexPath)
            case .pin:
                channelListViewModel.pin(at: indexPath)
            case .unpin:
                channelListViewModel.unpin(at: indexPath)
            }
        }
    }

    // MARK: UITableViewDelegate

    open func tableView(_ tableView: UITableView,
                        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let channel = channelListViewModel.channel(at: indexPath)
        else { return nil }
        return ChannelSwipeActionsConfiguration
            .trailingSwipeActionsConfiguration(for: channel) { [weak self] _,_, actions, handler in
                self?.onSwipeAction(actions: actions, indexPath: indexPath)
                handler(true)
            }
    }

    open func tableView(_ tableView: UITableView,
                        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let channel = channelListViewModel.channel(at: indexPath)
        else { return nil }
        return ChannelSwipeActionsConfiguration
            .leadingSwipeActionsConfiguration(for: channel) { [weak self] _,_, actions, handler in
                self?.onSwipeAction(actions: actions, indexPath: indexPath)
                handler(true)
            }
    }

    open func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
        swipeOpenIndexPath = indexPath
    }

    open func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
        swipeOpenIndexPath = nil
    }

    open func tableView(_ tableView: UITableView,
                        didSelectRowAt indexPath: IndexPath) {
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
        cell.parentAppearance = appearance.cellAppearance
        if let item = channelListViewModel.layoutModel(at: indexPath) {
            cell.data = item
            if channelListViewModel.isSelected(item.channel) {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        }

        return cell
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        searchController.setupAppearance()
    }

    // MARK: - UISearchResultsUpdating

    public var lastSearchText: String?
    public func updateSearchResults(for searchController: UISearchController) {
        let text = searchController.searchBar.text
        if let globalVC = searchResultsViewController as? GlobalSearchResultsViewController {
            let hasTokens = !searchController.searchBar.searchTextField.tokens.isEmpty
            globalVC.setUserBarVisible(!hasTokens, animated: true)
            NSObject.cancelPreviousPerformRequests(withTarget: globalVC, selector: #selector(GlobalSearchResultsViewController.search(query:)), object: lastSearchText)
            lastSearchText = text
            globalVC.perform(#selector(GlobalSearchResultsViewController.search(query:)), with: text)
        } else {
            NSObject.cancelPreviousPerformRequests(withTarget: channelListViewModel, selector: #selector(ChannelListViewModel.search(query:)), object: lastSearchText)
            lastSearchText = text
            channelListViewModel.perform(#selector(ChannelListViewModel.search(query:)), with: text, afterDelay: 0.01)
        }
    }

    open func addUserSearchToken(_ user: ChatUser) {
        let textField = searchController.searchBar.searchTextField
        let name = SceytChatUIKit.shared.formatters.userNameFormatter.format(user)
        let token = UISearchToken(icon: nil, text: name)
        token.representedObject = user
        textField.insertToken(token, at: textField.tokens.count)
        textField.text = nil
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
