//
//  SelectUsersViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class SelectUsersViewController: ViewController,
    UITableViewDelegate, UITableViewDataSource,
    UISearchControllerDelegate, UISearchBarDelegate
{
    open var selectMemberViewModel: SelectChannelMembersViewModel!
    open lazy var router = SelectChannelMembersRouter(rootViewController: self)
    
    open lazy var tableView = UITableView()
        .withoutAutoresizingMask

    open lazy var searchController = Components.searchController.init(searchResultsController: nil)
    
    open lazy var selectedUserListView = Components.selectedUserListView.init()
        .withoutAutoresizingMask
    
    open var selectedUserListViewHeight: NSLayoutConstraint!
    open var selectedUserListViewTop: NSLayoutConstraint!

    override open func setup() {
        super.setup()
        
        title = L10n.Channel.New.createPrivate
        
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.searchController = searchController
        searchController.delegate = self
        searchController.searchBar.delegate = self
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.allowsMultipleSelection = true
        tableView.register(Components.selectableUserCell.self)
        tableView.register(Components.separatorHeaderView.self)
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.tableFooterView = UIView()
        tableView.estimatedRowHeight = 56
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.Nav.Bar.next,
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(nextAction(_:)))
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        definesPresentationContext = true

        KeyboardObserver()
            .willShow { [weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }.willHide { [weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }
        selectMemberViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        
        selectedUserListView.$removeContact
            .compactMap { $0 }
            .sink { [weak self] in
                self?.selectMemberViewModel.deselect(user: $0)
                self?.deselectRowFor(user: $0)
            }.store(in: &subscriptions)
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        view.addSubview(tableView)
        view.addSubview(selectedUserListView)

        tableView.pin(to: view, anchors: [.leading, .trailing, .bottom])
        selectedUserListView.pin(to: view, anchors: [.leading, .trailing])
        selectedUserListViewTop = selectedUserListView.topAnchor.pin(to: view.topAnchor)
        selectedUserListView.bottomAnchor.pin(to: tableView.topAnchor)
        selectedUserListViewHeight = selectedUserListView.heightAnchor.pin(constant: 0)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        navigationController?.navigationBar.apply(appearance: appearance.navigationBarAppearance)
        searchController.parentAppearance = appearance.searchControllerAppearance
        tableView.backgroundColor = .clear
        view.backgroundColor = appearance.backgroundColor
        selectedUserListView.appearance = appearance.selectedUserCellAppearance
    }
    
    override open func setupDone() {
        super.setupDone()
        selectMemberViewModel.fetch(reload: true)
    }
    
    override open func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        
        if selectedUserListViewTop.constant != view.safeAreaInsets.top {
            UIView.animate(withDuration: 0.25) { [weak self] in
                guard let self else { return }
                self.selectedUserListViewTop.constant = self.view.safeAreaInsets.top
                self.view.layoutIfNeeded()
            }
        }
    }
    
    func adjustTableViewToKeyboard(notification: Notification) {
        tableView.adjustInsetsToKeyboard(notification: notification, container: view)
    }
    
    func onEvent(_ event: SelectChannelMembersViewModel.Event) {
        switch event {
        case .reload:
            tableView.reloadData()
        case let .select(user: user, isSelected: isSelected):
            if isSelected {
                selectedUserListView.add(user: user)
                if selectedUserListViewHeight.constant == 0 {
                    UIView.animate(withDuration: 0.25) { [weak self] in
                        guard let self else { return }
                        self.selectedUserListViewHeight.constant = Layouts.selectedViewHeight
                        self.view.layoutIfNeeded()
                    }
                }
            } else {
                selectedUserListView.remove(user: user)
                if selectMemberViewModel.selectedUsers.isEmpty,
                   selectedUserListViewHeight.constant > 0
                {
                    UIView.animate(withDuration: 0.25) { [weak self] in
                        guard let self else { return }
                        self.selectedUserListViewHeight.constant = 0
                        self.view.layoutIfNeeded()
                    }
                }
            }
            navigationItem.rightBarButtonItem?.isEnabled = !selectMemberViewModel.selectedUsers.isEmpty
        }
    }
    
    @objc
    open func closeAction(_ sender: UIBarButtonItem) {
        router.dismiss()
    }
    
    @objc
    open func nextAction(_ sender: UIBarButtonItem) {
        router.showCreatePrivateChannel()
    }
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        Sections.allCases.count
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return selectMemberViewModel.numberOfUser
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Sections(rawValue: indexPath.section) {
        case .user:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.selectableUserCell.self)
            cell.parentAppearance = appearance.userCellAppearance
            cell.selectionStyle = .none
            cell.userData = selectMemberViewModel.user(at: indexPath)
            return cell
        default:
            fatalError("Unchecked section")
        }
    }
    
    open func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if selectMemberViewModel.isSelect(at: indexPath) {
            DispatchQueue.main.async {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        }
        switch Sections(rawValue: indexPath.section) {
        case .user:
            if indexPath.row + 1 >= selectMemberViewModel.numberOfUser {
                selectMemberViewModel.fetch(reload: false)
            }
        default:
            break
        }
    }
    
    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        Components.separatorHeaderView.Layouts.height
    }
    
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let separatorHeaderView = tableView.dequeueReusableHeaderFooterView(Components.separatorHeaderView.self)
        separatorHeaderView.parentAppearance = appearance.separatorViewAppearance
        return separatorHeaderView
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Sections(rawValue: indexPath.section) {
        case .user:
            DispatchQueue.main.async {
                _ = self.selectMemberViewModel.select(at: indexPath)
            }
        default:
            fatalError("Unchecked section")
        }
        if searchController.isActive {
            searchController.isActive = false
            selectMemberViewModel.cancelSearch()
        }
    }
    
    open func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        switch Sections(rawValue: indexPath.section) {
        case .user:
            DispatchQueue.main.async {
                _ = self.selectMemberViewModel.deselect(at: indexPath)
            }
        default:
            fatalError("Unchecked section")
        }
    }
    
    // MARK: UISearchControllerDelegate delegates
    
    open func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchController.resignFirstResponder()
    }
    
    open func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        selectMemberViewModel.cancelSearch()
    }
    
    private var lastSearchText: String?
    open func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        NSObject.cancelPreviousPerformRequests(withTarget: selectMemberViewModel!, selector: #selector(SelectChannelMembersViewModel.search(query:)), object: lastSearchText)
        if let text = searchBar.text, !text.isEmpty {
            lastSearchText = text
            selectMemberViewModel.perform(#selector(SelectChannelMembersViewModel.search(query:)), with: text, afterDelay: 0.01)
        } else {
            selectMemberViewModel.cancelSearch()
        }
    }
    
    override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        searchController.setupAppearance()
    }
}

private extension SelectUsersViewController {
    func deselectRowFor(user: ChatUser) {
        for indexPath in tableView.indexPathsForVisibleRows ?? [] {
            if let cell = tableView.cell(for: indexPath, cellType: Components.selectableUserCell.self),
               cell.userData?.id == user.id
            {
                if let indexPathsForSelectedRows = tableView.indexPathsForSelectedRows,
                   indexPathsForSelectedRows.contains(indexPath)
                {
                    tableView.deselectRow(at: indexPath, animated: true)
                } else {
                    tableView.reloadRows(at: [indexPath], with: .none)
                }
            }
        }
    }
}

extension SelectUsersViewController {
    enum Sections: Int, CaseIterable {
        case user
    }
}

public extension SelectUsersViewController {
    enum Layouts {
        public static var selectedViewHeight: CGFloat = 96
    }
}
