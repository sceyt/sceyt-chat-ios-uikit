//
//  ForwardViewController.swift
//  SceytChatUIKit
//
//  Created by Duc on 24/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ForwardViewController: ViewController,
    UITableViewDelegate, UITableViewDataSource,
    UISearchResultsUpdating
{
    open var viewModel: ChannelForwardViewModel!
    open lazy var router = Components.channelForwardRouter.init(rootViewController: self)
    
    open lazy var tableView = UITableView()
        .withoutAutoresizingMask
    
    open lazy var searchController = Components.searchController.init(searchResultsController: searchResultsViewController)
    
    open lazy var searchResultsViewController = Components.channelSelectableSearchResultsViewController.init()
    
    open lazy var selectedChannelListView = Components.selectedChannelListView.init()
        .withoutAutoresizingMask
    
    open var selectedChannelListViewHeight: NSLayoutConstraint!
    open var selectedChannelListViewTop: NSLayoutConstraint!
    
    override open func setup() {
        super.setup()
        
        title = L10n.Channel.Forward.title
        
        navigationItem.hidesSearchBarWhenScrolling = false
        searchResultsViewController.resultsUpdater = viewModel
        navigationItem.searchController = searchController
        searchController.searchResultsUpdater = self
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.allowsMultipleSelection = true
        tableView.register(Components.selectableChannelCell.self)
        tableView.register(Components.separatorHeaderView.self)
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.tableFooterView = UIView()
        tableView.estimatedRowHeight = 56
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: L10n.Nav.Bar.cancel,
                                                           style: .done,
                                                           target: self,
                                                           action: #selector(onCancelTapped(_:)))
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.Nav.Bar.forward,
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(onForwardTapped(_:)))
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        definesPresentationContext = true
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        view.addSubview(tableView)
        view.addSubview(selectedChannelListView)

        tableView.pin(to: view, anchors: [.leading, .trailing, .bottom])
        selectedChannelListView.pin(to: view, anchors: [.leading, .trailing])
        selectedChannelListViewTop = selectedChannelListView.topAnchor.pin(to: view.topAnchor)
        selectedChannelListView.bottomAnchor.pin(to: tableView.topAnchor)
        selectedChannelListViewHeight = selectedChannelListView.heightAnchor.pin(constant: 0)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        navigationController?.navigationBar.apply(appearance: appearance.navigationBarAppearance)
        tableView.backgroundColor = .clear
        view.backgroundColor = appearance.backgroundColor
        searchController.parentAppearance = appearance.searchControllerAppearance
        searchResultsViewController.parentAppearance = appearance.searchResultControllerAppearance
        selectedChannelListView.appearance = appearance.selectedChannelCellAppearance
    }
    
    override open func setupDone() {
        super.setupDone()
            
        viewModel.startDatabaseObserver()
        
        viewModel.event
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        
        selectedChannelListView.onDelete = { [weak self] in
            guard let self else { return }
            self.viewModel.deselect($0)
            self.tableView.reloadData()
        }
    }
    
    override open func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        
        if selectedChannelListViewTop.constant != view.safeAreaInsets.top {
            UIView.animate(withDuration: 0.25) { [weak self] in
                guard let self else { return }
                self.selectedChannelListViewTop.constant = self.view.safeAreaInsets.top
                self.view.layoutIfNeeded()
            }
        }
    }
    
    func adjustTableViewToKeyboard(notification: Notification) {
        tableView.adjustInsetsToKeyboard(notification: notification, container: view)
    }
    
    func onEvent(_ event: ChannelForwardViewModel.Event) {
        switch event {
        case .reload:
            tableView.reloadData()
        case .reloadSearch:
            searchResultsViewController.reloadData()
        case let .update(channel, isSelected: isSelected):
            if isSelected {
                selectedChannelListView.add(item: channel)
                if selectedChannelListViewHeight.constant == 0 {
                    UIView.animate(withDuration: 0.25) { [weak self] in
                        guard let self else { return }
                        self.selectedChannelListViewHeight.constant = Layouts.selectedViewHeight
                        self.view.layoutIfNeeded()
                    }
                }
            } else {
                selectedChannelListView.remove(item: channel)
                if viewModel.selectedChannels.isEmpty,
                   selectedChannelListViewHeight.constant > 0
                {
                    UIView.animate(withDuration: 0.25) { [weak self] in
                        guard let self else { return }
                        self.selectedChannelListViewHeight.constant = 0
                        self.view.layoutIfNeeded()
                    }
                }
            }
            navigationItem.rightBarButtonItem?.isEnabled = !viewModel.selectedChannels.isEmpty
        }
    }
    
    // MARK: - Actions
    
    @objc open func onCancelTapped(_ sender: UIBarButtonItem) {
        router.dismiss()
    }
    
    @objc open func onForwardTapped(_ sender: UIBarButtonItem) {
        viewModel.handler(viewModel.selectedChannels)
    }
    
    // MARK: - UITableViewDelegate, UITableViewDataSource
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.channelObserver.numberOfSections
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.channelObserver.numberOfItems(in: section)
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.selectableChannelCell.self)
        cell.parentAppearance = appearance.channelCellAppearance
        cell.selectionStyle = .none
        if let channel = viewModel.channel(at: indexPath) {
            cell.checkBoxView.isSelected = viewModel.isSelected(channel)
            cell.channelData = channel
        }
        return cell
    }
    
    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        viewModel.searchResults.header(for: section) != nil ? Components.separatorHeaderView.Layouts.height : 0
    }
    
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = viewModel.searchResults.header(for: section)
        else { return nil }
        
        let headerView = tableView.dequeueReusableHeaderFooterView(Components.separatorHeaderView.self)
        headerView.parentAppearance = appearance.separatorViewAppearance
        headerView.titleLabel.text = header
        return headerView
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let channel = viewModel.channel(at: indexPath) {
            viewModel.select(channel)
            tableView.cell(for: indexPath, cellType: Components.selectableChannelCell.self)?.checkBoxView.isSelected = viewModel.isSelected(channel)
        }
    }
    
    override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        searchController.setupAppearance()
    }
    
    // MARK: - UISearchResultsUpdating

    private var lastSearchText: String?
    public func updateSearchResults(for searchController: UISearchController) {
        NSObject.cancelPreviousPerformRequests(withTarget: viewModel!, selector: #selector(ChannelForwardViewModel.search(query:)), object: lastSearchText)
        let text = searchController.searchBar.text
        lastSearchText = text
        viewModel.perform(#selector(ChannelForwardViewModel.search(query:)), with: text, afterDelay: 0.01)
    }
}

public extension ForwardViewController {
    enum Layouts {
        public static var selectedViewHeight: CGFloat = 96
    }
}
