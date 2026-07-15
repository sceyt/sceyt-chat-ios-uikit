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
                                UITableViewDataSource {
    
    open var memberListViewModel: ChannelMemberListViewModel!
    open lazy var router = Components.channelMemberListRouter
        .init(rootViewController: self)

    open lazy var tableView = UITableView()
        .withoutAutoresizingMask
        .rowAutomaticDimension
    
    open override func setup() {
        super.setup()

        if memberListViewModel.shouldShowOnlyAdmins {
            title = L10n.Channel.Info.Admins.title
        } else {
            title = L10n.Channel.Info.Members.title
        }

        tableView.register(Components.channelMemberCell.self)
        tableView.register(Components.channelAddMemberCell.self)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.ChannelMembers.tableView
        tableView.separatorStyle = .none
        tableView.sectionFooterHeight = 0
        tableView.estimatedSectionHeaderHeight = 0
        memberListViewModel.startDatabaseObserver()
        memberListViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        
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
        navigationController?.navigationBar.apply(appearance: appearance.navigationBarAppearance)
        view.backgroundColor = appearance.backgroundColor
        tableView.backgroundColor = .clear
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
        tableView.reloadData()
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

    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }

    open func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        if indexPath.section == 0, memberListViewModel.hasActionRows {
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelAddMemberCell.self)
            cell.parentAppearance = appearance.addCellAppearance

            // Determine which action cell to show
            if indexPath.row == 0 {
                if memberListViewModel.canAddMembers {
                    cell.titleLabel.text = memberListViewModel.addTitle
                    cell.iconView.image = .addMember
                    cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.ChannelMembers.addMemberButton
                } else if memberListViewModel.canShowInviteLink {
                    cell.titleLabel.text = memberListViewModel.inviteLinkTitle
                    cell.iconView.image = .inviteLink
                    cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.ChannelMembers.inviteLinkButton
                }
            } else if indexPath.row == 1 {
                // Row 1 only exists if both canAddMembers and canShowInviteLink are true
                cell.titleLabel.text = memberListViewModel.inviteLinkTitle
                cell.iconView.image = .inviteLink
                cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.ChannelMembers.inviteLinkButton
            }

            return cell
        }

        let item = memberListViewModel.member(at: indexPath)
        let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelMemberCell.self)
        cell.parentAppearance = appearance.cellAppearance
        guard let item else { return cell }
        cell.data = item

        // Trigger pagination when creating the last cell of a section
        if !memberListViewModel.shouldShowOnlyAdmins {
            let section = indexPath.section
            let numberOfItemsInSection = memberListViewModel.numberOfItems(section: section)

            if indexPath.row == numberOfItemsInSection - 1 {
                if section == memberListViewModel.ownerSectionIndex {
                    memberListViewModel.provider.loadOwners()
                } else if section == memberListViewModel.adminSectionIndex {
                    memberListViewModel.provider.loadAdmins()
                } else if section == memberListViewModel.otherSectionIndex {
                    memberListViewModel.provider.loadOthers()
                }
            }
        } else {
            // Original behavior for filtered view
            let lastIndex = memberListViewModel.numberOfMembers - 1
            if indexPath.row == lastIndex {
                memberListViewModel.loadMembers()
            }
        }

        return cell
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 {
            // Handle action rows
            if indexPath.row == 0 {
                if memberListViewModel.canAddMembers {
                    router.showAddMembers()
                } else if memberListViewModel.canShowInviteLink {
                    router.showInviteLink()
                }
            } else if indexPath.row == 1 {
                router.showInviteLink()
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
              member.id != SceytChatUIKit.shared.currentUserId else { return }
        if member.roleName == SceytChatUIKit.shared.config.memberRolesConfig.owner {
            return
        }
        
        if member.roleName == memberListViewModel.channel.userRole,
           member.roleName == SceytChatUIKit.shared.config.memberRolesConfig.admin {
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
            title: L10n.Channel.Info.Action.remove,
            icon: .chatDelete,
            style: .destructive,
            handler: { [weak self] in
                guard let self else { return }
                let alert = self.showAlert(
                    title: isBroadcast ? L10n.Channel.Info.Action.RemoveSubscriber.title : L10n.Channel.Info.Action.RemoveMember.title,
                    message: isBroadcast ? L10n.Channel.Info.Action.RemoveSubscriber.message(displayName) : L10n.Channel.Info.Action.RemoveMember.message(displayName),
                    actions: [
                        .init(title: L10n.Alert.Button.cancel, style: .cancel),
                        .init(title: L10n.Channel.Info.Action.remove, style: .destructive) { [weak self] in
                            self?.memberListViewModel
                                .kick(memberAt: indexPath) { [weak self] error in
                                    if let error {
                                        self?.router.showAlert(error: error)
                                    }
                                }
                        }
                    ], preferredActionIndex: 1)
                let attributedMessage = NSMutableAttributedString(
                    string: isBroadcast ? L10n.Channel.Info.Action.RemoveSubscriber.message(displayName) : L10n.Channel.Info.Action.RemoveMember.message(displayName),
                    attributes: normalAttributes)
                attributedMessage.setAttributes(
                    hightlightedAttributes,
                    range: (attributedMessage.string as NSString).range(of: displayName))
                alert.attributedMessage = attributedMessage
            })
        let isOwner = memberListViewModel.channel.userRole == SceytChatUIKit.shared.config.memberRolesConfig.owner
        let isAdmin = memberListViewModel.channel.userRole == SceytChatUIKit.shared.config.memberRolesConfig.admin
        let memberIsAdmin = memberListViewModel.member(at: indexPath)?.roleName == SceytChatUIKit.shared.config.memberRolesConfig.admin
        var actions = [SheetAction]()
        if isOwner {
            if memberIsAdmin {
                actions.append(.init(
                    title: L10n.Channel.Info.Action.RevokeAdmin.title,
                    icon: .chatRevoke) { [weak self] in
                    guard let self else { return }
                        let alert = self.showAlert(
                        title: L10n.Channel.Info.Action.RevokeAdmin.title,
                        message: isBroadcast ? L10n.Channel.Info.Action.RevokeAdmin.message(displayName) : L10n.Channel.Info.Action.RevokeAdmin.message(displayName),
                        actions: [
                            .init(title: L10n.Alert.Button.cancel, style: .cancel),
                            .init(title: L10n.Channel.Info.Action.RevokeAdmin.action, style: .destructive) { [weak self] in
                                self?.memberListViewModel
                                    .setRole(name: isBroadcast ? SceytChatUIKit.shared.config.memberRolesConfig.subscriber : SceytChatUIKit.shared.config.memberRolesConfig.participant,
                                             memberAt: indexPath) { [weak self] error in
                                    if let error {
                                        self?.router.showAlert(error: error)
                                    }
                                }
                            }
                        ], preferredActionIndex: 1)
                    let attributedMessage = NSMutableAttributedString(
                        string: isBroadcast ? L10n.Channel.Info.Action.RemoveSubscriber.message(displayName) : L10n.Channel.Info.Action.RemoveMember.message(displayName),
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
}

