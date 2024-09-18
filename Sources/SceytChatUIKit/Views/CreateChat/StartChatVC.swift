//
//  StartChatViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class StartChatViewController: ViewController,
    UITableViewDelegate, UITableViewDataSource,
    UISearchControllerDelegate, UISearchBarDelegate
{
    open var viewModel: CreateNewChannelVM!
    open lazy var router = NewChannelRouter(rootViewController: self)

    open lazy var searchController = SearchController(searchResultsController: nil)

    open lazy var tableView = TableView()
        .withoutAutoresizingMask
       
    lazy var startChatActionsView = {
        $0.withoutAutoresizingMask
    }(Components.startChatActionsView.init())
    
    override open func setup() {
        super.setup()
        
        navigationItem.searchController = searchController
        searchController.delegate = self
        searchController.searchBar.delegate = self
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: L10n.Nav.Bar.cancel,
                                                           style: .done,
                                                           target: self,
                                                           action: #selector(doneAction(_:)))
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(Components.createChannelUserCell.self)
        tableView.register(Components.separatorHeaderView.self)
        
        navigationItem.hidesSearchBarWhenScrolling = false
        KeyboardObserver()
            .willShow { [weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }.willHide { [weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }
        viewModel.$event
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.onEvent(event)
            }.store(in: &subscriptions)
        
        startChatActionsView.groupView.publisher(for: .touchUpInside).sink { [unowned self] _ in
            router.showCreatePrivateChannel()
        }.store(in: &subscriptions)
        
        startChatActionsView.channelView.publisher(for: .touchUpInside).sink { [unowned self] _ in
            router.showCreatePublicChannel()
        }.store(in: &subscriptions)
    }
    
    override open func setupLayout() {
        super.setupLayout()
        view.addSubview(startChatActionsView)
        view.addSubview(tableView)
        
        startChatActionsView.resize(anchors: [.height(96)])
        startChatActionsView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading(), .top(), .trailing()])
        tableView.pin(to: view, anchors: [.leading(), .bottom(), .trailing()])
        tableView.topAnchor.pin(to: startChatActionsView.bottomAnchor)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        definesPresentationContext = true
        
        view.backgroundColor = appearance.backgroundColor
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = .clear
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        
        title = L10n.Channel.New.title
    }
    
    override open func setupDone() {
        super.setupDone()
        viewModel.fetch(reload: true)
    }
    
    open func adjustTableViewToKeyboard(notification: Notification) {
        tableView.adjustInsetsToKeyboard(notification: notification, container: view)
    }
    
    @objc
    open func doneAction(_ sender: UIBarButtonItem) {
        router.dismiss()
    }
    
    open func onEvent(_ event: CreateNewChannelVM.Event) {
        switch event {
        case .reload:
            tableView.reloadData()
        case .createChannelError(let error):
            router.showAlert(error: error)
        case .createdChannel(let channel):
            router.showChannel(channel)
        }
    }
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        Sections.allCases.count
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfUser
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row > viewModel.numberOfUser - 3 {
            viewModel.fetch(reload: false)
        }
        switch Sections(rawValue: indexPath.section) {
        case .user:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.createChannelUserCell.self)
            if let user = viewModel.user(at: indexPath) {
                cell.userData = user
            }
            return cell
        default:
            fatalError("Unchecked section")
        }
    }
    
    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        Components.separatorHeaderView.Layouts.height
    }
    
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        tableView.dequeueReusableHeaderFooterView(Components.separatorHeaderView.self)
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Sections(rawValue: indexPath.section) {
        case .user:
            viewModel.createDirectChannel(userAt: indexPath)
        default:
            fatalError("Unchecked section")
        }
        if searchController.isActive {
            searchController.isActive = false
            viewModel.cancelSearch()
        }
    }
    
    // MARK: UISearchControllerDelegate delegates
    
    open func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchController.resignFirstResponder()
    }
    
    open func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        viewModel.cancelSearch()
    }
    
    private var lastSearchText: String?
    open func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        NSObject.cancelPreviousPerformRequests(withTarget: viewModel!, selector: #selector(ChannelMemberListVM.search(query:)), object: lastSearchText)
        if let text = searchBar.text, !text.isEmpty {
            lastSearchText = text
            viewModel.perform(#selector(ChannelMemberListVM.search(query:)), with: text, afterDelay: 0.01)
        } else {
            viewModel.cancelSearch()
        }
    }
    
    override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        searchController.setupAppearance()
    }
}

extension StartChatViewController {
    enum Sections: Int, CaseIterable {
        case user
    }
}
