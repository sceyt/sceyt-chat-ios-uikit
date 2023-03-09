//
//  ChannelListVC.swift
//  SceytChatUIKit
//

import UIKit
import SceytChat

open class ChannelListVC: ViewController,
                          UITableViewDelegate,
                          UITableViewDataSource,
                          UISearchControllerDelegate,
                          UISearchBarDelegate,
                          UITextFieldDelegate {
    
    open lazy var channelListViewModel = Components.channelListVM
        .init()
    
    open lazy var channelListRouter = Components.channelListRouter
        .init(rootVC: self)
    
    open lazy var tableView = Components.channelTableView
        .init()
        .withoutAutoresizingMask
        .rowAutomaticDimension
    
    open lazy var emptyView = Components.channelListEmptyView
        .init()
        .withoutAutoresizingMask
    
    public var isSearching = false
    
    open override func setup() {
        super.setup()
        title = L10n.Channel.List.title
        tabBarItem.title = L10n.Channel.List.title
        
        navigationItem.rightBarButtonItem = .init(image: Images.channelNew,
                                                  style: .plain,
                                                  target: self,
                                                  action: #selector(newChannelAction(_:)))
        
        tableView.delegate = self
        tableView.dataSource = self
        
        navigationItem.hidesSearchBarWhenScrolling = true
        navigationItem.searchController = ChannelSearchController(searchResultsController: nil)
        navigationItem.searchController!.delegate = self
        navigationItem.searchController!.searchBar.delegate = self
        
        navigationController?.navigationBar.isTranslucent = true
        definesPresentationContext = true
        
        emptyView.isHidden = true
        
        KeyboardObserver()
            .willShow {[weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }.willHide {[weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }
    }
    
    open override func setupLayout() {
        super.setupLayout()
        view.addSubview(tableView)
        view.addSubview(emptyView)
        tableView.pin(to: view)
        emptyView.pin(to: view.safeAreaLayoutGuide)
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        tabBarItem.badgeColor = appearance.tabBarItemBadgeColor
        view.backgroundColor = appearance.backgroundColor
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.textBlack]
    }
    
    open override func setupDone() {
        super.setupDone()
        channelListViewModel.startDatabaseObserver()
        channelListViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        channelListViewModel.loadChannels()
    }
    
    open func adjustTableViewToKeyboard(notification: Notification) {
        tableView.adjustInsetsToKeyboard(notification: notification, container: view)
    }
    
    @objc
    func newChannelAction(_ sender: UIBarItem) {
        channelListRouter.showNewChannel()
    }
    // MARK: UISearchController delegates
    
    open func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        navigationItem.searchController?.resignFirstResponder()
    }
    
    open func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        isSearching = false
        channelListViewModel.cancelSearch()
    }
    
    open func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if let text = searchBar.text, text.count > 0 {
            isSearching = true
            channelListViewModel.search(query: text)
        } else {
            isSearching = false
            channelListViewModel.cancelSearch()
        }
    }
    
    // MARK: ViewModel Event
    
    open func onEvent(_ event: ChannelListVM.Event) {
//        guard view.superview != nil else { return }
        switch event {
        case let .change(paths):
            updateTableView(paths: paths)
            showEmptyViewIfNeeded()
        case .reload:
            tableView.reloadData()
            showEmptyViewIfNeeded()
        case let .unreadMessagesCount(count):
            updateUnreadMessages(count: count)
        case let .connection(state):
            updateConnectionState(state)
        case let .typing(isTyping, member, channel):
            for cell in tableView.visibleCells where cell is ChannelCell {
                let channelCell = (cell as! ChannelCell)
                if channelCell.data.id == channel.id {
                    if isTyping {
                        channelCell.didStartTyping(member: member)
                    } else {
                        channelCell.didStopTyping(member: member)
                    }
                    return
                }
            }
        }
    }
    
    open func updateTableView(paths: DBChangeItemPaths) {
        if view.superview == nil || tableView.visibleCells.isEmpty {
            tableView.reloadData()
        } else {
            tableView.performBatchUpdates {
                tableView.insertRows(at: paths.inserts + paths.moves.map { $0.to }, with: .none)
                tableView.reloadRows(at: paths.updates, with: .none)
                tableView.deleteRows(at: paths.deletes + paths.moves.map { $0.from }, with: .none)
            }
        }
    }
    
    open func showEmptyViewIfNeeded() {
        emptyView.isHidden = channelListViewModel.numberOfChannels > 0 || isSearching
    }
    
    open func updateUnreadMessages(count: Int) {
        navigationController?.tabBarItem.badgeValue = count == 0 ?
        nil :
        Formatters.channelUnreadMessageCount.format(UInt64(count))
        UIApplication.shared.applicationIconBadgeNumber = Int(count)
    }
    
    open func updateConnectionState(_ state: ConnectionState) {
        title = L10n.Channel.List.title
        tabBarItem.title = L10n.Channel.List.title
        navigationItem.titleView = ConnectionStateView(state: state)
    }
    
    open func onSwipeAction(
        actions: ChannelSwipeActionsConfiguration.Actions,
        indexPath: IndexPath) {
            switch actions {
            case .delete:
                channelListViewModel.delete(at: indexPath)
            case .leave:
                channelListViewModel.leave(at: indexPath)
            case .read:
                channelListViewModel.markAsRead(at: indexPath)
            case .unread:
                channelListViewModel.markAsUnread(at: indexPath)
            }
        }
    
    // MARK: UITableViewDelegate
    
    open func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
            guard let channel = channelListViewModel.channel(at: indexPath)
            else { return nil }
            return ChannelSwipeActionsConfiguration
                .trailingSwipeActionsConfiguration(for: channel) {[weak self] _,_, actions, handler in
                    self?.onSwipeAction(actions: actions, indexPath: indexPath)
                    handler(true)
                }
        }
    
    open func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
            guard let channel = channelListViewModel.channel(at: indexPath)
            else { return nil }
            return ChannelSwipeActionsConfiguration
                .leadingSwipeActionsConfiguration(for: channel) {[weak self] _,_, actions, handler in
                    self?.onSwipeAction(actions: actions, indexPath: indexPath)
                    handler(true)
                }
        }
    
    open func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath) {
            let lastElement = channelListViewModel.numberOfChannels - 9
            if indexPath.row == lastElement ||
                tableView.contentOffset.y + tableView.bounds.height > tableView.contentSize.height {
                channelListViewModel.loadChannels()
            }
            (cell as? ChannelCell)?.subscribeForPresence()
        }
    open func tableView(
        _ tableView: UITableView,
        didEndDisplaying cell: UITableViewCell,
        forRowAt indexPath: IndexPath) {
            
            let rectOfCell = tableView.convert(
                tableView.rectForRow(at: indexPath),
                to: tableView.superview
            )
            
            if rectOfCell.maxY <= 0 ||
                rectOfCell.minY >= tableView.bounds.maxY {
                (cell as? ChannelCell)?.unsubscribeFromPresence()
            }
    }
    
    open func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            channelListRouter.showChannelVC(at: indexPath)
        }
    
    open func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int) -> Int {
            channelListViewModel.numberOfChannels
        }
    
    open  func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(for: indexPath,
                                                     cellType: Components.channelCell)
            if let item = channelListViewModel.channel(at: indexPath) {
                cell.data = item
            }
            
            return cell
        }
}
