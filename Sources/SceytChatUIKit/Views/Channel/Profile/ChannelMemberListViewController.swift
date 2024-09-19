//
//  ChannelMemberListViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

open class ChannelMemberListViewController: ViewController,
                                UITableViewDelegate,
                                UITableViewDataSource,
                                UISearchControllerDelegate,
                                UISearchBarDelegate {
    
    open var memberListViewModel: ChannelMemberListViewModel!
    open lazy var router = Components.channelMemberListRouter
        .init(rootViewController: self)
    
    open lazy var searchController = Components.searchController.init(searchResultsController: nil)
    
    open lazy var tableView = UITableView()
        .withoutAutoresizingMask
        .rowAutomaticDimension
    
    open override func setup() {
        super.setup()
        
        if memberListViewModel.shouldShowOnlyAdmins {
            title = L10n.Channel.Profile.Admins.title
        } else {
            title = L10n.Channel.Profile.Members.title
        }
        
        navigationItem.searchController = searchController
        searchController.delegate = self
        searchController.searchBar.delegate = self
        
        tableView.register(Components.channelMemberCell.self)
        tableView.register(Components.channelAddMemberCell.self)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.sectionFooterHeight = 0
        tableView.sectionHeaderHeight = 0
        memberListViewModel.startDatabaseObserver()
        memberListViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        memberListViewModel.loadMembers()
        
        view.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(onLongPress)))
    }
    
    open override func setupLayout() {
        super.setupLayout()
        
        view.addSubview(tableView)
        tableView.pin(to: view, anchors: [.leading, .trailing, .bottom])
        tableView.topAnchor.pin(to: view.topAnchor)
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        navigationItem.standardAppearance = NavigationController.appearance.standard
        navigationItem.standardAppearance?.backgroundColor = .surface1
        navigationItem.scrollEdgeAppearance = NavigationController.appearance.standard
        navigationItem.scrollEdgeAppearance?.backgroundColor = appearance.backgroundColor

        view.backgroundColor = appearance.backgroundColor
        tableView.backgroundColor = .clear
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationItem.hidesSearchBarWhenScrolling = false
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        navigationItem.hidesSearchBarWhenScrolling = true
    }
    
    open func onEvent(_ event: ChannelMemberListViewModel.Event) {
        switch event {
        case .reload:
            tableView.reloadData()
        case let .change(paths):
            updateTableView(paths: paths)
        }
    }
    
    open func updateTableView(paths: ChannelMemberListViewModel.ChangeItemPaths) {
        if view.superview == nil || tableView.visibleCells.isEmpty {
            tableView.reloadData()
        } else {
            UIView.performWithoutAnimation {
                tableView.performBatchUpdates {
                    tableView.insertRows(at: paths.inserts + paths.moves.map { $0.to }, with: .none)
                    tableView.reloadRows(at: paths.updates, with: .none)
                    tableView.deleteRows(at: paths.deletes + paths.moves.map { $0.from }, with: .none)
                }
            }   
        }
    }
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        memberListViewModel.numberOfSections
    }
    
    open func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        memberListViewModel.numberOfItems(section: section)
    }
    
    open func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        if indexPath.item > memberListViewModel.numberOfMembers - 10 {
            memberListViewModel.loadMembers()
        }
        
        if indexPath.section == 0, memberListViewModel.canAddMembers {
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelAddMemberCell.self)
            cell.titleLabel.text = memberListViewModel.addTitle
            return cell
        }
        
        let item = memberListViewModel.member(at: indexPath)
        let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelMemberCell.self)
//        cell.selectionStyle = .none
        guard let item
        else { return cell }
        cell.data = item
        return cell
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            if memberListViewModel.canAddMembers {
                router.showAddMembers()
            }
        } else {
            memberListViewModel.createChannel(userAt: indexPath) { [weak self] channel, error in
                guard let self else { return }
                if let channel {
                    self.router.showChannelInfoViewController(channel: channel)
                } else if let error {
                    self.showAlert(error: error)
                }
            }
        }
    }
    
    @objc open
    func onLongPress(_ longPressGesture: UILongPressGestureRecognizer) {
        let location = longPressGesture.location(in: tableView)
        guard let indexPath = self.tableView.indexPathForRow(at: location),
              longPressGesture.state == .began, let member = memberListViewModel.member(at: indexPath),
              member.id != me else { return }
        if member.roleName == SceytChatUIKit.shared.config.chatRoleOwner {
            return
        }
        
        if member.roleName == memberListViewModel.channel.userRole,
           member.roleName == SceytChatUIKit.shared.config.chatRoleAdmin {
            return
        }
        let displayName = SceytChatUIKit.shared.formatters.userNameFormatter.format(member)
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.regular.withSize(13),
            .foregroundColor: UIColor.secondaryText,
            .paragraphStyle: {
                $0.alignment = .center
                return $0
            }(NSMutableParagraphStyle()),
        ]
        let hightlightedAttributes: [NSAttributedString.Key: Any] = [
            .font: Fonts.semiBold.withSize(13),
            .foregroundColor: UIColor.secondaryText,
        ]
        let isBroadcast = memberListViewModel.channel.channelType == .broadcast
        let remove = SheetAction(
            title: L10n.Channel.Profile.Action.remove,
            icon: .chatDelete,
            style: .destructive,
            handler: { [weak self] in
                guard let self else { return }
                let alert = self.showAlert(
                    title: isBroadcast ? L10n.Channel.Profile.Action.RemoveSubscriber.title : L10n.Channel.Profile.Action.RemoveMember.title,
                    message: isBroadcast ? L10n.Channel.Profile.Action.RemoveSubscriber.message(displayName) : L10n.Channel.Profile.Action.RemoveMember.message(displayName),
                    actions: [
                        .init(title: L10n.Alert.Button.cancel, style: .cancel),
                        .init(title: L10n.Channel.Profile.Action.remove, style: .destructive) { [weak self] in
                            self?.memberListViewModel
                                .kick(memberAt: indexPath) { [weak self] error in
                                    if let error {
                                        self?.router.showAlert(error: error)
                                    }
                                }
                        }
                    ], preferredActionIndex: 1)
                let attributedMessage = NSMutableAttributedString(
                    string: isBroadcast ? L10n.Channel.Profile.Action.RemoveSubscriber.message(displayName) : L10n.Channel.Profile.Action.RemoveMember.message(displayName),
                    attributes: normalAttributes)
                attributedMessage.setAttributes(
                    hightlightedAttributes,
                    range: (attributedMessage.string as NSString).range(of: displayName))
                alert.attributedMessage = attributedMessage
            })
        let isOwner = memberListViewModel.channel.userRole == SceytChatUIKit.shared.config.chatRoleOwner
        let isAdmin = memberListViewModel.channel.userRole == SceytChatUIKit.shared.config.chatRoleAdmin
        let memberIsAdmin = memberListViewModel.member(at: indexPath)?.roleName == SceytChatUIKit.shared.config.chatRoleAdmin
        var actions = [SheetAction]()
        if isOwner {
            if memberIsAdmin {
                actions.append(.init(
                    title: L10n.Channel.Profile.Action.RevokeAdmin.title,
                    icon: .chatRevoke) { [weak self] in
                    guard let self else { return }
                        let alert = self.showAlert(
                        title: L10n.Channel.Profile.Action.RevokeAdmin.title,
                        message: isBroadcast ? L10n.Channel.Profile.Action.RevokeAdmin.message(displayName) : L10n.Channel.Profile.Action.RevokeAdmin.message(displayName),
                        actions: [
                            .init(title: L10n.Alert.Button.cancel, style: .cancel),
                            .init(title: L10n.Channel.Profile.Action.RevokeAdmin.action, style: .destructive) { [weak self] in
                                self?.memberListViewModel
                                    .setRole(name: isBroadcast ? SceytChatUIKit.shared.config.channelRoleSubscriber : SceytChatUIKit.shared.config.groupRoleParticipant,
                                             memberAt: indexPath) { [weak self] error in
                                    if let error {
                                        self?.router.showAlert(error: error)
                                    }
                                }
                            }
                        ], preferredActionIndex: 1)
                    let attributedMessage = NSMutableAttributedString(
                        string: isBroadcast ? L10n.Channel.Profile.Action.RemoveSubscriber.message(displayName) : L10n.Channel.Profile.Action.RemoveMember.message(displayName),
                        attributes: normalAttributes)
                    attributedMessage.setAttributes(
                        hightlightedAttributes,
                        range: (attributedMessage.string as NSString).range(of: displayName))
                    alert.attributedMessage = attributedMessage
                })
            }
            actions += [remove]
        } else if isAdmin {
            actions += [remove]
        }
        if !actions.isEmpty {
            showBottomSheet(actions: actions, withCancel: true)
        }
    }
    
    // MARK: UISearchControllerDelegate delegates
    
    open func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchController.resignFirstResponder()
    }
    
    open func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        memberListViewModel.cancelSearch()
    }
    
    private var lastSearchText: String?
    open func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        NSObject.cancelPreviousPerformRequests(withTarget: memberListViewModel!, selector: #selector(ChannelMemberListViewModel.search(query:)), object: lastSearchText)
        if let text = searchBar.text, !text.isEmpty {
            lastSearchText = text
            memberListViewModel.perform(#selector(ChannelMemberListViewModel.search(query:)), with: text, afterDelay: 0.01)
        } else {
            memberListViewModel.cancelSearch()
        }
    }
    
    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        searchController.setupAppearance()
    }
}
