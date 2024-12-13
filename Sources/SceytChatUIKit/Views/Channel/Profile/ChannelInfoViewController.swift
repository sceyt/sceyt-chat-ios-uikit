//
//  ChannelInfoViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Photos
import UIKit

open class ChannelInfoViewController: ViewController,
    UITableViewDelegate,
    UITableViewDataSource,
    UIGestureRecognizerDelegate
{
    open var profileViewModel: ChannelProfileViewModel!
    
    open lazy var router = Components.channelProfileRouter
        .init(rootViewController: self)
    
    open lazy var tableView = Components.simultaneousGestureTableView.init(frame: .zero, style: .grouped)
        .withoutAutoresizingMask
        .rowAutomaticDimension
    
    open lazy var mediaListViewController = Components.channelInfoMediaCollectionView
        .init()
    
    open lazy var fileListViewController = Components.channelInfoFileCollectionView
        .init()
    
    open lazy var voiceListViewController = Components.channelInfoVoiceCollectionView
        .init()
    
    open lazy var linkListViewController = Components.channelInfoLinkCollectionView
        .init()
    
    open lazy var segmentViewController = Components.segmentedControlView
        .init(items: [
            .init(content: mediaListViewController,
                  title: L10n.Channel.Info.Segment.medias),
            .init(content: fileListViewController,
                  title: L10n.Channel.Info.Segment.files),
            .init(content: voiceListViewController,
                  title: L10n.Channel.Info.Segment.voice),
            .init(content: linkListViewController,
                  title: L10n.Channel.Info.Segment.links)
        ]).withoutAutoresizingMask
    
    public var sections = [Sections]()
    
    open var outerDeceleration: ScrollingDeceleration?
    
    override open func setup() {
        super.setup()
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        
        navigationItem.title = L10n.Channel.Info.title
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: .channelProfileMore,
            style: .plain,
            target: self,
            action: #selector(moreAction(_:)))
        
        mediaListViewController.mediaViewModel = profileViewModel.mediaListViewModel
        mediaListViewController.previewer = { [weak self] in
            self?.profileViewModel.previewer
        }
        fileListViewController.fileViewModel = profileViewModel.fileListViewModel
        linkListViewController.linkViewModel = profileViewModel.linkListViewModel
        voiceListViewController.voiceViewModel = profileViewModel.voiceListViewModel
        tableView.register(Components.channelInfoDetailsCell.self)
        tableView.register(Components.channelInfoDescriptionCell.self)
        tableView.register(Components.channelInfoOptionCell.self)
        tableView.register(Components.channelInfoContainerCell.self)
        tableView.showsVerticalScrollIndicator = false
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isDirectionalLockEnabled = true
        tableView.contentInsetAdjustmentBehavior = .never
        
        let footer = UIView()
        footer.frame.size.height = .leastNormalMagnitude
        tableView.tableFooterView = footer
        
        fileListViewController.onSelect = { [unowned self] indexPath in
            if let attachment = fileListViewController.fileViewModel.attachmentLayout(at: indexPath)?.attachment {
                router.showAttachment(attachment)
            }
        }
        
        segmentViewController.parentScrollView = tableView
        segmentViewController.items
            .compactMap { $0.content as? ChannelInfoViewController.AttachmentCollectionView }
            .forEach {
                $0.shouldReceiveTouch = { [weak self] in
                    guard let self else { return false }
                    let contentOffsetY = ceil(self.tableView.contentOffset.y)
                    if contentOffsetY < ceil(self.headerHeight) - ceil(self.tableView.contentInset.top) {
                        return false
                    }
                    return true
                }
            }
        tableView.shouldSimultaneous = { [weak self] in
            guard let self else { return false }
            
            (self.currentPage as? ChannelInfoViewController.AttachmentCollectionView)?.scrollingDecelerator.invalidateIfNeeded()
            
            let contentOffsetY = ceil($0.contentOffset.y)
            let shouldSimultaneous = contentOffsetY < floor(self.headerHeight - $0.contentInset.top) || (self.currentPage?.contentOffset.y ?? 0) == 0
            
            let velocity = self.tableView.panGestureRecognizer.velocity(in: self.tableView)
            
            return shouldSimultaneous && abs(velocity.y) > abs(velocity.x)
        }
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sections = availableSections()
        tableView.reloadData()
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.contentInset.top = view.safeAreaInsets.top
    }
    
    override open func setupLayout() {
        super.setupLayout()
        view.addSubview(tableView)
        tableView.pin(to: view)
    }
    
    override open func setupDone() {
        super.setupDone()
        profileViewModel.startDatabaseObserver()
        profileViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        navigationController?.navigationBar.apply(appearance: appearance.navigationBarAppearance)
        view.backgroundColor = appearance.backgroundColor
        tableView.backgroundColor = .clear
        segmentViewController.appearance = appearance.segmentedControlAppearance
        mediaListViewController.parentAppearance = appearance.mediaCollectionAppearance
        fileListViewController.parentAppearance = appearance.fileCollectionAppearance
        voiceListViewController.parentAppearance = appearance.voiceCollectionAppearance
        linkListViewController.parentAppearance = appearance.linkCollectionAppearance
    }
    
    override open func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        mediaListViewController.contentInset.bottom = view.safeAreaInsets.bottom
        fileListViewController.contentInset.bottom = view.safeAreaInsets.bottom
        linkListViewController.contentInset.bottom = view.safeAreaInsets.bottom
        voiceListViewController.contentInset.bottom = view.safeAreaInsets.bottom
    }
    
    open func onEvent(_ event: ChannelProfileViewModel.Event) {
        switch event {
        case .update:
            if !profileViewModel.isActive {
                router.goChannelListViewController()
                return
            }
            var indexPaths = [IndexPath]()
            if let cell = tableView.visibleCells.first(where: { $0 is ChannelInfoViewController.DetailsCell }) as? ChannelInfoViewController.DetailsCell,
               let indexPath = tableView.indexPath(for: cell)
            {
                indexPaths.append(indexPath)
            }
            if let cell = tableView.visibleCells.first(where: { $0 is ChannelInfoViewController.DescriptionCell }) as? ChannelInfoViewController.DescriptionCell,
               let indexPath = tableView.indexPath(for: cell)
            {
                indexPaths.append(indexPath)
            }
            tableView.reloadRows(at: indexPaths, with: .none)
        }
    }
    
    @objc
    func editAction(_ sender: UIBarButtonItem?) {
        router.showEditChannel()
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        let currentPage = segmentViewController.currentPage
        coordinator.animate { [weak self] _ in
            guard let self else { return }
            self.tableView.reloadData()
            self.segmentViewController.currentPage = currentPage
            self.segmentViewController.stackView.arrangedSubviews.forEach {
                if let collectionView = $0 as? UICollectionView {
                    collectionView.collectionViewLayout.invalidateLayout()
                }
            }
        }
    }
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }
    
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }
    
    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            return 16
        default:
            return 24
        }
    }
    
    open func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        UIView()
    }
    
    open func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    
    open func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int) -> Int
    {
        switch sections[section] {
        case .options: return options().count
        case .items: return items().count
        default: return 1
        }
    }
    
    open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch sections[indexPath.section] {
        case .attachment:
            return attachmentHeight
        default:
            return UITableView.automaticDimension
        }
    }
    
    open func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let _cell: UITableViewCell
        switch sections[indexPath.section] {
        case .header:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelInfoDetailsCell.self)
            cell.parentAppearance = appearance.detailsCellAppearance
            cell.selectionStyle = .none
            cell.data = profileViewModel.channel
            cell.avatarButton.publisher(for: .touchUpInside).sink { [weak self] _ in
                guard let self else { return }
                self.router.goAvatar()
            }.store(in: &cell.subscriptions)
            _cell = cell
        case .other:
            fatalError("handle other sections in your subclass according to your implementation")
        case .description:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelInfoDescriptionCell.self)
            cell.parentAppearance = appearance.descriptionCellAppearance
            cell.selectionStyle = .none
            if profileViewModel.channel.isDirect {
                cell.data = profileViewModel.channel.peer?.presence.status
            } else {
                cell.data = profileViewModel.channel.decodedMetadata?.description ?? ""
            }
            _cell = cell
        case .uri:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelInfoOptionCell.self)
            cell.parentAppearance = appearance.uriCellAppearance
            cell.iconView.image = appearance.optionIcons.uriIcon
            cell.titleLabel.text = SceytChatUIKit.shared.config.channelURIConfig.prefix + (profileViewModel.channel.uri)
            cell.selectionStyle = .none
            _cell = cell
        case .options, .items:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelInfoOptionCell.self)
            cell.parentAppearance = appearance.optionItemCellAppearance
            let action = (sections[indexPath.section] == .options ? options() : items())[indexPath.row]
            cell.iconView.image = action.image
            cell.titleLabel.text = action.title
            if let toggle = action.toggle {
                cell.detailLabel.text = toggle ? L10n.Common.on : L10n.Common.off
            } else {
                cell.detailLabel.text = nil
            }
            if action.tag == ActionTag.notifications {
                cell.selectionStyle = .none
                let sw = UISwitch()
                sw.onTintColor = appearance.optionItemCellAppearance.switchTintColor
                sw.addTarget(self, action: #selector(muteAction), for: .valueChanged)
                sw.isOn = !profileViewModel.channel.muted
                cell.accessoryView = sw
            } else if action.displayArrow {
                cell.selectionStyle = .gray
                cell.accessoryView = UIImageView(image: appearance.optionItemCellAppearance.accessoryImage)
            } else {
                cell.selectionStyle = .none
                cell.accessoryView = nil
            }
            _cell = cell
        case .attachment:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelInfoContainerCell.self)
            if !cell.contentView.subviews.contains(segmentViewController) {
                cell.contentView.addSubview(segmentViewController.withoutAutoresizingMask)
                segmentViewController.pin(to: cell.contentView)
            }
            _cell = cell
        }
        return _cell
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let section = sections[indexPath.section]
        var items: [ActionItem]?
        if section == .options {
            items = self.options()
        } else if section == .items {
            items = self.items()
        }
        switch items?[indexPath.row].tag {
        case ActionTag.members:
            router.showMemberList()
        case ActionTag.admins:
            router.showAdminsList()
        case ActionTag.autoDeleteMessages:
            router.showAutoDeleteOptionsAlert(selected: { [weak self] in
                self?.profileViewModel.autoDelete = $0.timeInterval
                self?.tableView.reloadData()
            }, canceled: {})
        case ActionTag.messageSearch:
            router.goMessageSearch()
        default:
            break
        }
    }
    
    open func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath)
    {
        let cornerRadius = Layouts.cellCornerRadius
        var corners: UIRectCorner = []
        
        if tableView.isFirst(indexPath) {
            corners.update(with: .topLeft)
            corners.update(with: .topRight)
        }
        
        if tableView.isLast(indexPath),
           indexPath.section != tableView.numberOfSections - 1
        {
            corners.update(with: .bottomLeft)
            corners.update(with: .bottomRight)
            cell.layer.sublayers?.first(where: { $0.name == "bottomBorder" })?.removeFromSuperlayer()
        } else {
            var layer: CALayer! = cell.layer.sublayers?.first(where: { $0.name == "bottomBorder" })
            if layer == nil {
                layer = CALayer()
                layer.name = "bottomBorder"
                cell.layer.addSublayer(layer)
            }
            layer.borderColor = appearance.separatorColor.cgColor
            layer.borderWidth = Components.channelInfoViewController.Layouts.cellSeparatorWidth
            layer.frame = CGRect(x: 0, y: cell.height - layer.borderWidth, width: cell.width, height: layer.borderWidth)
        }
        
        if !cell.isKind(of: Components.channelInfoContainerCell.self) {
            let maskLayer = CAShapeLayer()
            var rect = cell.bounds
            if sections[indexPath.section] != .attachment {
                rect.origin.x = Components.channelInfoViewController.Layouts.cellHorizontalPadding
                rect.size.width -= Components.channelInfoViewController.Layouts.cellHorizontalPadding * 2
            }
            maskLayer.path = UIBezierPath(roundedRect: rect,
                                          byRoundingCorners: corners,
                                          cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)).cgPath
            cell.layer.mask = maskLayer
        } else {
            cell.layer.mask = nil
        }
    }
    
    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        tableView.reloadData()
    }
    
    var segmentTop: CGFloat { floor(tableView.contentSize.height - tableView.height - 18) }
    
    open var titleLabel = {
        $0.font = appearance.titleLabelAppearance.font
        $0.textColor = appearance.titleLabelAppearance.foregroundColor
        return $0
    }(UILabel())
    
    open var subTitleLabel = {
        $0.font = appearance.subtitleLabelAppearance.font
        $0.textColor = appearance.subtitleLabelAppearance.foregroundColor
        return $0
    }(UILabel())
    
    open lazy var titleView = UIStackView(column: [titleLabel, subTitleLabel], alignment: .center)
    
    open var headerHeight: CGFloat {
        tableView.visibleCells.first(where: { $0.isKind(of: Components.channelInfoContainerCell.self) })?.top ?? 0
    }
    
    private var attachmentHeight: CGFloat {
        tableView.frame.height - view.safeAreaInsets.top
    }
    
    private var currentPage: UIScrollView? {
        segmentViewController.items[segmentViewController.currentPage].content as? UIScrollView
    }
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let contentOffsetY = ceil(scrollView.contentOffset.y)

        scrollView.bounces = contentOffsetY <= -scrollView.contentInset.top
        
        segmentViewController.segmentController.showCornerRadius = contentOffsetY < headerHeight - scrollView.contentInset.top

        if contentOffsetY > -scrollView.contentInset.top,
           contentOffsetY < headerHeight - scrollView.contentInset.top
        {
            segmentViewController.items
                .compactMap { $0.content as? UIScrollView }
                .forEach {
                    if $0.contentOffset.y > 0 {
                        $0.contentOffset.y = 0
                    }
                }
        }
        
        if let cell = tableView.visibleCells.first(where: { $0 is ChannelInfoViewController.DetailsCell }) as? ChannelInfoViewController.DetailsCell {
            let point = cell.subtitleLabel.convert(.init(x: 0, y: cell.subtitleLabel.height), to: view)
            if point.y <= scrollView.contentInset.top {
                titleLabel.text = cell.titleLabel.text
                subTitleLabel.text = cell.subtitleLabel.text
                navigationItem.titleView = titleView
            } else {
                navigationItem.titleView = nil
            }
        }
    }
    
    open func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        (currentPage as? ChannelInfoViewController.AttachmentCollectionView)?.scrollingDecelerator.invalidateIfNeeded()
        return true
    }
    
    open func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        outerDeceleration = ScrollingDeceleration(velocity: velocity, decelerationRate: scrollView.decelerationRate)
    }

    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y >= headerHeight - scrollView.contentInset.top {
            (currentPage as? ChannelInfoViewController.AttachmentCollectionView)?.scrollingDecelerator.decelerate(by: outerDeceleration!)
        }
    }

    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        segmentViewController.scrollView.isScrollEnabled = true
    }
    
    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        segmentViewController.scrollView.isScrollEnabled = false
        outerDeceleration = nil
    }
    
    open func options() -> [ActionItem] {
        var actions: [ActionItem] = [
            .init(title: appearance.optionTitles.notificationsTitleText,
                  image: appearance.optionIcons.notificationsIcon,
                  tag: ActionTag.notifications)
        ]
        if profileViewModel.isOwner || profileViewModel.isAdmin {
            actions += [
                .init(title: appearance.optionTitles.autoDeleteMessagesTitleText,
                      image: appearance.optionIcons.autoDeleteMessagesIcon,
                      tag: ActionTag.autoDeleteMessages,
                      toggle: profileViewModel.autoDelete > 0)
            ]
        }
        return actions
    }
    
    open func items() -> [ActionItem] {
        var actions = [ActionItem]()
        if !profileViewModel.isDirectChannel {
            switch profileViewModel.channelType {
            case .broadcast where profileViewModel.isOwner || profileViewModel.isAdmin:
                actions += [
                    .init(title: appearance.optionTitles.subscribersTitleText,
                          image: appearance.optionIcons.subscribersIcon,
                          tag: ActionTag.members)
                ]
            case .group:
                actions += [
                    .init(title: appearance.optionTitles.membersTitleText,
                          image: appearance.optionIcons.membersIcon,
                          tag: ActionTag.members)
                ]
            default:
                break
            }
            if profileViewModel.isOwner {
                actions += [.init(title: appearance.optionTitles.adminsTitleText,
                                  image: appearance.optionIcons.adminsIcon,
                                  tag: ActionTag.admins)]
            }
        }
        actions.append(.init(
            title: appearance.optionTitles.searchTitleText,
            image: appearance.optionIcons.searchIcon,
            tag: ActionTag.messageSearch,
            displayArrow: false
        ))
        return actions
    }
    
    open func availableSections() -> [Sections] {
        var sections: [Sections] = [.header]
        switch profileViewModel.channelType {
        case .broadcast:
            if !(profileViewModel.channel.decodedMetadata?.description ?? "").isEmpty {
                sections.append(.description)
            } else {
                logger.debug("[ChannelInfoViewController] decoded metadata description is missing")
            }     
            sections.append(.uri)
        case .group:
            if !(profileViewModel.channel.decodedMetadata?.description ?? "").isEmpty {
                sections.append(.description)
            } else {
                logger.debug("[ChannelInfoViewController] decoded metadata description is missing")
            }
        case .direct:
            if !(profileViewModel.channel.peer?.presence.status ?? "").isEmpty {
                sections.append(.description)
            }
        }
        if !options().isEmpty {
            sections += [.options]
        }
        if !items().isEmpty {
            sections += [.items]
        }
        sections += [.attachment]
        return sections
    }
    
    @objc
    open func muteAction(_ sender: Any?) {
        if let sender = sender as? UISwitch {
            if sender.isOn {
                unmuteAction(sender)
            } else {
                router.showMuteOptionsAlert { [weak self] option in
                    self?.mute(for: option.timeInterval, sender: sender)
                } canceled: {
                    sender.setOn(true, animated: true)
                }
            }
        }
    }
    
    open func mute(for timeInterval: TimeInterval, sender: Any) {
        profileViewModel.mute(timeInterval: timeInterval) { [weak self] error in
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
                if let sender = sender as? UISwitch {
                    sender.isOn = true
                }
            } 
        }
    }
    
    open func unmuteAction(_ sender: Any?) {
        profileViewModel.unmute { [weak self] error in
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
                if let sender = sender as? UISwitch {
                    sender.isOn = false
                }
            } 
        }
    }
    
    open func pinChat() {
        profileViewModel.channelProvider.pin()
    }
    
    open func unpinChat() {
        profileViewModel.channelProvider.unpin()
    }
        
    @objc
    open func moreAction(_ sender: Any) {
        var actions = [SheetAction]()
        
        switch profileViewModel.channelType {
        case .direct:
            if profileViewModel.channel.pinnedAt == nil {
                actions += [
                    .init(
                        title: L10n.Channel.Info.Action.Chat.pin,
                        icon: .chatPin,
                        handler: { [unowned self] in
                            pinChat()
                        })
                ]
            } else {
                actions += [
                    .init(
                        title: L10n.Channel.Info.Action.Chat.unpin,
                        icon: .chatUnpin,
                        handler: { [unowned self] in
                            unpinChat()
                        })
                ]
            }
            
            actions += [
                .init(
                    title: L10n.Channel.Info.Action.clearHistory,
                    icon: .chatClear,
                    handler: { [unowned self] in
                        deleteAllMessages()
                    })
            ]
            
            if profileViewModel.channel.peer?.blocked == true {
                actions += [
                    .init(
                        title: L10n.Channel.Info.Action.unblock,
                        icon: .chatUnBlock,
                        handler: { [unowned self] in
                            unblock()
                        })
                ]
            } else {
                actions += [
                    .init(
                        title: L10n.Channel.Info.Action.block,
                        icon: .chatBlock,
                        handler: { [unowned self] in
                            block()
                        })
                ]
            }
            
            actions += [
                .init(
                    title: L10n.Channel.Info.Action.Chat.delete,
                    icon: .chatDelete,
                    style: .destructive,
                    handler: { [unowned self] in
                        delete()
                    })
            ]
           
        case .group:
            if profileViewModel.canEdit {
                actions += [
                    .init(
                        title: L10n.Channel.Info.Action.Group.edit,
                        icon: .chatEdit,
                        handler: { [unowned self] in
                            editAction(nil)
                        })
                ]
            }
            
            if profileViewModel.channel.pinnedAt == nil {
                actions += [
                    .init(
                        title: L10n.Channel.Info.Action.Group.pin,
                        icon: .chatPin,
                        handler: { [unowned self] in
                            pinChat()
                        })
                ]
            } else {
                actions += [
                    .init(
                        title: L10n.Channel.Info.Action.Group.unpin,
                        icon: .chatUnpin,
                        handler: { [unowned self] in
                            unpinChat()
                        })
                ]
            }
            
            actions += [
                .init(
                    title: L10n.Channel.Info.Action.clearHistory,
                    icon: .chatClear,
                    handler: { [unowned self] in
                        deleteAllMessages()
                    }),
                .init(
                    title: L10n.Channel.Info.Action.Group.blockAndLeave,
                    icon: .chatBlock,
                    style: .destructive,
                    handler: { [unowned self] in
                        blockAndLeave()
                    }),
                .init(
                    title: L10n.Channel.Info.Action.Group.leave,
                    icon: .chatLeave,
                    style: .destructive,
                    handler: { [unowned self] in
                        leave()
                    })
            ]
            
            if profileViewModel.isOwner {
                actions += [
                    .init(
                        title: L10n.Channel.Info.Action.Group.delete,
                        icon: .chatDelete,
                        style: .destructive,
                        handler: { [unowned self] in
                            delete()
                        })
                ]
            }
            
        case .broadcast:
            if profileViewModel.canEdit {
                actions += [
                    .init(
                        title: L10n.Channel.Info.Action.Channel.edit,
                        icon: .chatEdit,
                        handler: { [unowned self] in
                            editAction(nil)
                        })
                ]
            }
            
            if profileViewModel.channel.pinnedAt == nil {
                actions += [
                    .init(
                        title: L10n.Channel.Info.Action.Channel.pin,
                        icon: .chatPin,
                        handler: { [unowned self] in
                            pinChat()
                        })
                ]
            } else {
                actions += [
                    .init(
                        title: L10n.Channel.Info.Action.Channel.unpin,
                        icon: .chatUnpin,
                        handler: { [unowned self] in
                            unpinChat()
                        })
                ]
            }
            
            actions += [
                .init(
                    title: L10n.Channel.Info.Action.clearHistory,
                    icon: .chatClear,
                    handler: { [unowned self] in
                        deleteAllMessages(forEveryone: true)
                    }),
                .init(
                    title: L10n.Channel.Info.Action.Channel.blockAndLeave,
                    icon: .chatBlock,
                    style: .destructive,
                    handler: { [unowned self] in
                        blockAndLeave()
                    }),
                .init(
                    title: L10n.Channel.Info.Action.Channel.leave,
                    icon: .chatLeave,
                    style: .destructive,
                    handler: { [unowned self] in
                        leave()
                    })
            ]
            
            if profileViewModel.isOwner {
                actions += [
                    .init(
                        title: L10n.Channel.Info.Action.Channel.delete,
                        icon: .chatDelete,
                        style: .destructive,
                        handler: { [unowned self] in
                            delete()
                        })
                ]
            }
        }
        guard !actions.isEmpty else { return }
        
        showBottomSheet(actions: actions, withCancel: true)
    }
    
    open func deleteAllMessages(forEveryone: Bool = false) {
        showAlert(title: L10n.Channel.Selecting.clearChat,
                  message: forEveryone ? L10n.Channel.Selecting.ClearChat.Channel.message : L10n.Channel.Selecting.ClearChat.message,
                  actions: [
                    .init(title: L10n.Alert.Button.cancel, style: .cancel),
                    .init(title: L10n.Channel.Selecting.ClearChat.clear, style: .destructive) { [weak self] in
                        self?.profileViewModel
                            .deleteAllMessages(forEveryone: forEveryone) { [weak self] error in
                                guard let self else { return }
                                if let error = error {
                                    self.showAlert(error: error)
                                } else {
                                    self.router.goChannelListViewController()
                                }
                            }
                    }
                  ],
                  preferredActionIndex: 1)
    }
    
    open func block() {
        loader.isLoading = true
        profileViewModel.block { [weak self] error in
            loader.isLoading = false
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
            } else {
                self.router.channelViewController?.channelViewModel.refreshChannel()
//                self.router.goChannelListViewController()
            }
        }
    }
    
    open func unblock() {
        loader.isLoading = true
        profileViewModel.unblock { [weak self] error in
            loader.isLoading = false
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
            } else {
                self.router.channelViewController?.channelViewModel.refreshChannel()
            }
        }
    }
    
    open func leave() {
        loader.isLoading = true
        profileViewModel.leave { [weak self] error in
            loader.isLoading = false
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
            } else {
                self.router.goChannelListViewController()
            }
        }
    }
    
    open func blockAndLeave() {
        loader.isLoading = true
        profileViewModel.blockAndLeave { [weak self] error in
            loader.isLoading = false
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
            } else {
                self.router.goChannelListViewController()
            }
        }
    }
    
    open func delete() {
        let title: String
        let message: String
        switch profileViewModel.channel.channelType {
        case .direct:
            title = L10n.Channel.Info.Action.Chat.delete
            message = L10n.Channel.Info.Action.Chat.deleteMessage
        case .group:
            title = L10n.Channel.Info.Action.Group.delete
            message = L10n.Channel.Info.Action.Group.deleteMessage
        case .broadcast:
            title = L10n.Channel.Info.Action.Channel.delete
            message = L10n.Channel.Info.Action.Channel.deleteMessage
        }
        showAlert(title: title,
                  message: message,
                  actions: [
                    .init(title: L10n.Alert.Button.cancel, style: .cancel),
                    .init(title: L10n.Alert.Button.delete, style: .destructive) { [weak self] in
                        loader.isLoading = true
                        self?.profileViewModel.delete { [weak self] error in
                            loader.isLoading = false
                            guard let self else { return }
                            if let error = error {
                                self.showAlert(error: error)
                            } else {
                                self.router.goChannelListViewController()
                            }
                        }
                    }
                  ],
                  preferredActionIndex: 1)
    }
}

public extension ChannelInfoViewController {
    enum Sections: Int, CaseIterable {
        case header
        case other
        case description
        case uri
        case options
        case items
        case attachment
    }
    
    struct ActionItem {
        public var title: String
        public var image: UIImage
        public var tag: Int
        public var toggle: Bool?
        public var displayArrow: Bool
        
        public init(
            title: String,
            image: UIImage,
            tag: Int,
            toggle: Bool? = nil,
            displayArrow: Bool = true
        ) {
            self.title = title
            self.image = image
            self.tag = tag
            self.toggle = toggle
            self.displayArrow = displayArrow
        }
    }
    
    enum ActionTag {
        public static var mute = 10001
        public static var unmute = 10002
        public static var join = 10003
        public static var more = 10004
        public static var report = 10005
        public static var members = 10006
        public static var admins = 10007
        public static var message = 10008
        public static var notifications = 10009
        public static var autoDeleteMessages = 10010
        public static var messageSearch = 10011
    }
}

public extension ChannelInfoViewController {
    enum Layouts {
        public static var itemIconSize: CGFloat = 32
        public static var itemVerticalPadding: CGFloat = 12
        public static var cellCornerRadius: CGFloat = 10
        public static var cellHorizontalPadding: CGFloat = 16
        public static var cellSeparatorWidth: CGFloat = 1
    }
}

private extension UITableView {
    func isFirst(_ indexPath: IndexPath) -> Bool {
        indexPath.item == 0
    }
    
    func isLast(_ indexPath: IndexPath) -> Bool {
        indexPath.item == numberOfRows(inSection: indexPath.section) - 1
    }
}
