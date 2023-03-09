//
//  ChannelMemberListVC.swift
//  SceytChatUIKit
//

import UIKit
import SceytChat

open class ChannelMemberListVC: ViewController,
                                UITableViewDelegate,
                                UITableViewDataSource {
    
    open var memberListViewModel: ChannelMemberListVM!
    open lazy var router = Components.channelMemberListRouter
        .init(rootVC: self)
    
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
        
        tableView.register(Components.channelMemberCell.self)
        tableView.register(Components.channelMemberAddCell.self)
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
    }
    
    open override func setupLayout() {
        super.setupLayout()
        view.addSubview(tableView)
        tableView.pin(to: view)
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        view.backgroundColor = appearance.backgroundColor
    }
    
    open func onEvent(_ event: ChannelMemberListVM.Event) {
        switch event {
        case let .change(paths):
            updateTableView(paths: paths)
        }
    }
    
    open func updateTableView(paths: ChannelMemberListVM.ChangeItemPaths) {
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
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        memberListViewModel.numberOfSection
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
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelMemberAddCell.self)
            if memberListViewModel.shouldShowOnlyAdmins {
                cell.titleLabel.text = L10n.Channel.Admin.add
            } else {
                cell.titleLabel.text = L10n.Channel.Member.add
            }
            cell.selectionStyle = .none
            return cell
        }
        
        let item = memberListViewModel.member(at: indexPath)
        let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelMemberCell.self)
        cell.selectionStyle = .none
        guard let item
        else { return cell }
        cell.data = item
        return cell
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            addNewMembers()
        } else {
            kickMember(at: indexPath)
        }
    }
    
    open func addNewMembers() {
        memberListViewModel.channelProvider.add(members: [.Builder(id: "user1").build()])
    }
    
    open func kickMember(at indexPath: IndexPath) {
        router.presentAlert(alertActions: [
            UIAlertAction(
                title: L10n.Channel.Profile.Action.kickMember,
                style: .destructive,
                handler: {[unowned self] _ in
                    memberListViewModel
                        .kick(memberAt: indexPath) {[weak self] error in
                            if let error {
                                self?.showAlert(error: error)
                            } else {
                                self?.router.goChannelVC()
                            }
                    }
                })
        ])
    }
}
