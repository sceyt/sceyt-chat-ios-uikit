//
//  ChannelListVC.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

open class ChannelListVC: ViewController,
                          UITableViewDelegate, UITableViewDataSource,
                          UITextFieldDelegate,
                          UISearchResultsUpdating {
    
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
    
    open lazy var searchController = ChannelSearchController(searchResultsController: searchResultsVC)

    open lazy var searchResultsVC = Components.channelSearchResultsVC.init()

    private var isViewDidAppear = false
    
    open override func setup() {
        super.setup()
        title = L10n.Channel.List.title
        tabBarItem.title = L10n.Channel.List.title
        
        navigationItem.rightBarButtonItem = .init(image: Images.channelNew,
                                                  style: .plain,
                                                  target: self,
                                                  action: #selector(newChannelAction(_:)))
        
//        navigationItem.leftBarButtonItem = .init(
//            image: ImageBuilder.build(fillColor: .clear, size: .init(width: 36, height: 36)),
//            style: .plain,
//            target: self, 
//            action: #selector(leftButtonAction(_:event:)))
        tableView.delegate = self
        tableView.dataSource = self
                
        navigationItem.hidesSearchBarWhenScrolling = true
        searchResultsVC.resultsUpdater = channelListViewModel
        navigationItem.searchController = searchController
        searchController.searchResultsUpdater = self
        
        definesPresentationContext = true
        
        emptyView.isHidden = true
        
        KeyboardObserver()
            .willShow { [weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }.willHide { [weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }
    }
    
    open override func setupLayout() {
        super.setupLayout()
        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        view.addSubview(tableView)
        view.addSubview(emptyView)
        tableView.pin(to: view)
        emptyView.pin(to: view.safeAreaLayoutGuide)
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        navigationItem.standardAppearance = NavigationController.appearance.standard
        navigationItem.standardAppearance?.backgroundColor = .surface1
        navigationItem.scrollEdgeAppearance = NavigationController.appearance.standard
        navigationItem.scrollEdgeAppearance?.backgroundColor = appearance.backgroundColor

        tabBarItem.badgeColor = appearance.tabBarItemBadgeColor
        view.backgroundColor = appearance.backgroundColor
        tableView.backgroundColor = .clear
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
    
    open func onEvent(_ event: ChannelListVM.Event) {
        //        guard view.superview != nil else { return }
        switch event {
        case let .change(paths):
            updateTableView(paths: paths)
            showEmptyViewIfNeeded()
        case .reload:
            tableView.reloadData()
            showEmptyViewIfNeeded()
        case .reloadSearch:
            searchResultsVC.reloadData()
        case let .unreadMessagesCount(count):
            updateUnreadMessages(count: count)
        case let .connection(state):
            updateConnectionState(state)
        case let .typing(isTyping, member, channel):
            for cell in tableView.visibleCells where cell is ChannelCell {
                let channelCell = (cell as! ChannelCell)
                if channelCell.data.channel.id == channel.id {
                    if isTyping {
                        channelCell.didStartTyping(member: member)
                    } else {
                        channelCell.didStopTyping(member: member)
                    }
                    return
                }
            }
        case .showChannel(let channel):
            channelListRouter.showChannelVC(channel: channel)
        }
    }
    
    open func updateTableView(paths: ChannelListVM.Paths) {
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
    
    open func showEmptyViewIfNeeded() {
        emptyView.isHidden = channelListViewModel.numberOfSections > 0
    }
    
    open func updateUnreadMessages(count: Int) {
        RunLoop.main.perform { [weak self] in
            guard let self
            else { return }
            self.navigationController?.tabBarItem.badgeValue = count == 0 ?
            nil :
            Formatters.channelUnreadMessageCount.format(UInt64(count))
        }
        updateApplicationBadgeNumberWithUnreadMessagesCount(count)
    }
    
    open func updateApplicationBadgeNumberWithUnreadMessagesCount( _ count: Int) {
        UIApplication.shared.applicationIconBadgeNumber = count
    }
    
    open func updateConnectionState(_ state: ConnectionState) {
        title = L10n.Channel.List.title
        tabBarItem.title = L10n.Channel.List.title
        navigationItem.titleView = ConnectionStateView(state: state)
    }
    
    open func onSwipeAction(
        actions: ChannelSwipeActionsConfiguration.Actions,
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
    
    open func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
            guard let channel = channelListViewModel.channel(at: indexPath)
            else { return nil }
            return ChannelSwipeActionsConfiguration
                .trailingSwipeActionsConfiguration(for: channel) { [weak self] _,_, actions, handler in
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
                .leadingSwipeActionsConfiguration(for: channel) { [weak self] _,_, actions, handler in
                    self?.onSwipeAction(actions: actions, indexPath: indexPath)
                    handler(true)
                }
        }
    
    open func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath) {
            channelListRouter.showChannelVC(at: indexPath)
            channelListViewModel.selectChannel(at: indexPath)
        }
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        channelListViewModel.numberOfSections
    }
    
    open func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int) -> Int {
            channelListViewModel.numberOfChannel(at: section)
        }
    
    open  func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            if indexPath.row > channelListViewModel.numberOfChannel(at: indexPath.section) - 3 {
                channelListViewModel.loadChannels()
            }
            let cell = tableView.dequeueReusableCell(for: indexPath,
                                                     cellType: Components.channelCell)
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
    
    private var lastSearchText: String?
    public func updateSearchResults(for searchController: UISearchController) {
        NSObject.cancelPreviousPerformRequests(withTarget: channelListViewModel, selector: #selector(ChannelListVM.search(query:)), object: lastSearchText)
        let text = searchController.searchBar.text
        lastSearchText = text
        channelListViewModel.perform(#selector(ChannelListVM.search(query:)), with: text, afterDelay: 0.01)
    }
}
