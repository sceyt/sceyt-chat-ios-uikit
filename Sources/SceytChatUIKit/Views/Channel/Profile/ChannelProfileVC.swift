//
//  ChannelProfileVC.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Photos
import UIKit

open class ChannelProfileVC: ViewController,
    UITableViewDelegate,
    UITableViewDataSource,
    UIGestureRecognizerDelegate
{
    open var profileViewModel: ChannelProfileVM!
    
    open lazy var router = Components.channelProfileRouter
        .init(rootVC: self)
    
    open lazy var tableView = ProfileTableView(frame: .zero, style: .grouped)
        .withoutAutoresizingMask
        .rowAutomaticDimension
    
    open lazy var mediaListVC = Components.channelMediaListView
        .init()
    
    open lazy var fileListVC = Components.channelFileListView
        .init()
    
    open lazy var linkListVC = Components.channelLinkListView
        .init()
    
    open lazy var voiceListVC = Components.channelVoiceListView
        .init()
    
    open lazy var segmentVC = Components.segmentedControlView
        .init(items: [
            SegmentedControlView.SectionItem(content: mediaListVC,
                                             title: L10n.Channel.Profile.Segment.medias),
            SegmentedControlView.SectionItem(content: fileListVC,
                                             title: L10n.Channel.Profile.Segment.files),
            SegmentedControlView.SectionItem(content: voiceListVC,
                                             title: L10n.Channel.Profile.Segment.voice),
            SegmentedControlView.SectionItem(content: linkListVC,
                                             title: L10n.Channel.Profile.Segment.links)
        ]).withoutAutoresizingMask
    
    public var sections = [Sections]()
    
    open var outerDeceleration: ScrollingDeceleration?
    
    override open func setup() {
        super.setup()
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        
        navigationItem.title = L10n.Channel.Profile.title
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: .channelProfileMore,
            style: .plain,
            target: self,
            action: #selector(moreAction(_:)))
        
        mediaListVC.mediaViewModel = profileViewModel.mediaListViewModel
        mediaListVC.previewer = { [weak self] in
            self?.profileViewModel.previewer
        }
        fileListVC.fileViewModel = profileViewModel.fileListViewModel
        linkListVC.linkViewModel = profileViewModel.linkListViewModel
        voiceListVC.voiceViewModel = profileViewModel.voiceListViewModel
        tableView.register(Components.channelProfileHeaderCell.self)
        tableView.register(Components.channelProfileMenuCell.self)
        tableView.register(Components.channelProfileDescriptionCell.self)
        tableView.register(Components.channelProfileItemCell.self)
        tableView.register(Components.channelProfileContainerCell.self)
        tableView.showsVerticalScrollIndicator = false
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isDirectionalLockEnabled = true
        tableView.contentInsetAdjustmentBehavior = .never
        
        let footer = UIView()
        footer.frame.size.height = .leastNormalMagnitude
        tableView.tableFooterView = footer
        
        fileListVC.onSelect = { [unowned self] indexPath in
            if let attachment = fileListVC.fileViewModel.attachmentLayout(at: indexPath)?.attachment {
                router.showAttachment(attachment)
            }
        }
        
        segmentVC.parentScrollView = tableView
        segmentVC.items
            .compactMap { $0.content as? ChannelAttachmentListView }
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
            
            (self.currentPage as? ChannelAttachmentListView)?.scrollingDecelerator.invalidateIfNeeded()
            
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
        
        navigationItem.standardAppearance = NavigationController.appearance.standard
        navigationItem.standardAppearance?.backgroundColor = appearance.cellBackgroundColor
        navigationItem.scrollEdgeAppearance = NavigationController.appearance.standard
        navigationItem.scrollEdgeAppearance?.backgroundColor = .background4
        
        view.backgroundColor = appearance.backgroundColor
        tableView.backgroundColor = .clear        
    }
    
    override open func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        mediaListVC.contentInset.bottom = view.safeAreaInsets.bottom
        fileListVC.contentInset.bottom = view.safeAreaInsets.bottom
        linkListVC.contentInset.bottom = view.safeAreaInsets.bottom
        voiceListVC.contentInset.bottom = view.safeAreaInsets.bottom
    }
    
    open func onEvent(_ event: ChannelProfileVM.Event) {
        switch event {
        case .update:
            if !profileViewModel.isActive {
                router.goChannelListVC()
                return
            }
            var indexPaths = [IndexPath]()
            if let cell = tableView.visibleCells.first(where: { $0 is ChannelProfileHeaderCell }) as? ChannelProfileHeaderCell,
               let indexPath = tableView.indexPath(for: cell)
            {
                indexPaths.append(indexPath)
            }
            if let cell = tableView.visibleCells.first(where: { $0 is ChannelProfileDescriptionCell }) as? ChannelProfileDescriptionCell,
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
        
        let currentPage = segmentVC.currentPage
        coordinator.animate { [weak self] _ in
            guard let self else { return }
            self.tableView.reloadData()
            self.segmentVC.currentPage = currentPage
            self.segmentVC.stackView.arrangedSubviews.forEach {
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
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileHeaderCell.self)
            cell.selectionStyle = .none
            cell.data = profileViewModel.channel
            cell.avatarButton.publisher(for: .touchUpInside).sink { [weak self] _ in
                guard let self else { return }
                self.router.goAvatar()
            }.store(in: &cell.subscriptions)
            _cell = cell
        case .actionMenu:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileMenuCell.self)
            cell.selectionStyle = .none
            cell.data = preferredMenuButtons()
            _cell = cell
        case .description:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileDescriptionCell.self)
            cell.selectionStyle = .none
            if !profileViewModel.channel.isGroup {
                cell.data = profileViewModel.channel.peer?.presence.status
            } else {
                cell.data = profileViewModel.channel.decodedMetadata?.description ?? profileViewModel.channel.metadata
            }
            _cell = cell
        case .uri:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileItemCell.self)
            cell.iconView.image = .channelProfileURI
            cell.titleLabel.text = "@" + (profileViewModel.channel.uri)
            cell.selectionStyle = .none
            _cell = cell
        case .options, .items:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileItemCell.self)
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
                sw.onTintColor = .kitBlue
                sw.addTarget(self, action: #selector(muteAction), for: .valueChanged)
                sw.isOn = !profileViewModel.channel.muted
                cell.accessoryView = sw
            } else if action.displayArrow {
                cell.selectionStyle = .gray
                cell.accessoryView = UIImageView(image: .chevron)
            } else {
                cell.selectionStyle = .none
                cell.accessoryView = nil
            }
            _cell = cell
        case .attachment:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileContainerCell.self)
            if !cell.contentView.subviews.contains(segmentVC) {
                cell.contentView.addSubview(segmentVC.withoutAutoresizingMask)
                segmentVC.pin(to: cell.contentView)
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
            layer.borderColor = appearance.cellSeparatorColor?.cgColor
            layer.borderWidth = ChannelProfileVC.Layouts.cellSeparatorWidth
            layer.frame = CGRect(x: 0, y: cell.height - layer.borderWidth, width: cell.width, height: layer.borderWidth)
        }
        
        if !cell.isKind(of: Components.channelProfileContainerCell.self) {
            let maskLayer = CAShapeLayer()
            var rect = cell.bounds
            if sections[indexPath.section] != .attachment {
                rect.origin.x = ChannelProfileVC.Layouts.cellHorizontalPadding
                rect.size.width -= ChannelProfileVC.Layouts.cellHorizontalPadding * 2
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
        $0.font = ChannelProfileVC.appearance.titleFont?.withSize(16)
        $0.textColor = ChannelProfileVC.appearance.titleColor
        return $0
    }(UILabel())
    
    open var subTitleLabel = {
        $0.font = ChannelProfileVC.appearance.subtitleFont?.withSize(13)
        $0.textColor = ChannelProfileVC.appearance.subtitleColor
        return $0
    }(UILabel())
    
    open lazy var titleView = UIStackView(column: [titleLabel, subTitleLabel], alignment: .center)
    
    open var headerHeight: CGFloat {
        tableView.visibleCells.first(where: { $0.isKind(of: Components.channelProfileContainerCell.self) })?.top ?? 0
    }
    
    private var attachmentHeight: CGFloat {
        tableView.frame.height - view.safeAreaInsets.top
    }
    
    private var currentPage: UIScrollView? {
        segmentVC.items[segmentVC.currentPage].content as? UIScrollView
    }
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let contentOffsetY = ceil(scrollView.contentOffset.y)

        scrollView.bounces = contentOffsetY <= -scrollView.contentInset.top
        
        segmentVC.segmentController.showCornerRadius = contentOffsetY < headerHeight - scrollView.contentInset.top

        if contentOffsetY > -scrollView.contentInset.top,
           contentOffsetY < headerHeight - scrollView.contentInset.top
        {
            segmentVC.items
                .compactMap { $0.content as? UIScrollView }
                .forEach {
                    if $0.contentOffset.y > 0 {
                        $0.contentOffset.y = 0
                    }
                }
        }
        
        if let cell = tableView.visibleCells.first(where: { $0 is ChannelProfileHeaderCell }) as? ChannelProfileHeaderCell {
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
        (currentPage as? ChannelAttachmentListView)?.scrollingDecelerator.invalidateIfNeeded()
        return true
    }
    
    open func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        outerDeceleration = ScrollingDeceleration(velocity: velocity, decelerationRate: scrollView.decelerationRate)
    }

    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y >= headerHeight - scrollView.contentInset.top {
            (currentPage as? ChannelAttachmentListView)?.scrollingDecelerator.decelerate(by: outerDeceleration!)
        }
    }

    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        segmentVC.scrollView.isScrollEnabled = true
    }
    
    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        segmentVC.scrollView.isScrollEnabled = false
        outerDeceleration = nil
    }
    
    open func preferredMenuButtons() -> [HoldButton] {
        func button(item: ActionItem) -> HoldButton {
            let hb = Components.holdButton.init(image: item.image, title: item.title, tag: item.tag)
                .withoutAutoresizingMask
            hb.backgroundColor = .white
            hb.addTarget(self, action: #selector(profileAction(_:)), for: .touchUpInside)
            return hb
        }
        
        var mute: HoldButton {
            profileViewModel.channel.muted ?
                button(item:
                    .init(
                        title: L10n.Channel.Profile.Action.unmute,
                        image: .channelProfileUnmute,
                        tag: ActionTag.unmute)
                ) :
                button(item:
                    .init(
                        title: L10n.Channel.Profile.Action.mute,
                        image: .channelProfileMute,
                        tag: ActionTag.mute)
                )
        }
        
        switch profileViewModel.channelType {
        case .broadcast:
            if profileViewModel.isUnsubscribedChannel {
                return [button(item:
                    .init(
                        title: L10n.Channel.Profile.Action.join,
                        image: .channelProfileJoin,
                        tag: ActionTag.join))]
            } else {
                return [
                    mute,
                    button(item:
                        .init(
                            title: L10n.Channel.Profile.Action.more,
                            image: .channelProfileMore,
                            tag: ActionTag.more))
                ]
            }
        case .private:
            return [
                mute,
                button(item:
                    .init(
                        title: L10n.Channel.Profile.Action.more,
                        image: .channelProfileMore,
                        tag: ActionTag.more))
            ]
        case .direct:
            return [
                mute,
                button(item:
                    .init(
                        title: L10n.Channel.Profile.Action.more,
                        image: .channelProfileMore,
                        tag: ActionTag.more))
            ]
        }
    }
    
    open func options() -> [ActionItem] {
        var actions: [ActionItem] = [
            .init(title: L10n.Channel.Profile.notifications, image: .channelProfileBell, tag: ActionTag.notifications)
        ]
        if profileViewModel.isOwner || profileViewModel.isAdmin {
            actions += [
                .init(title: L10n.Channel.Profile.Item.Title.autoDeleteMessages, image: .channelProfileAutoDeleteMessages, tag: ActionTag.autoDeleteMessages, toggle: profileViewModel.autoDelete > 0)
            ]
        }
        return actions
    }
    
    open func items() -> [ActionItem] {
        var actions = [ActionItem]()
        if profileViewModel.isGroupChannel {
            switch profileViewModel.channelType {
            case .broadcast where profileViewModel.isOwner || profileViewModel.isAdmin:
                actions += [
                    .init(title: L10n.Channel.Profile.Item.Title.subscribers, image: .channelProfileMembers, tag: ActionTag.members)
                ]
            case .private:
                actions += [
                    .init(title: L10n.Channel.Profile.Item.Title.members, image: .channelProfileMembers, tag: ActionTag.members)
                ]
            default:
                break
            }
            if profileViewModel.isOwner {
                actions += [.init(title: L10n.Channel.Profile.Item.Title.admins, image: .channelProfileAdmins, tag: ActionTag.admins)]
            }
        }
        actions.append(.init(
            title: L10n.Channel.Profile.Item.Title.messageSearch,
            image: .searchFill,
            tag: ActionTag.messageSearch,
            displayArrow: false
        ))
        return actions
    }
    
    @objc
    open func profileAction(_ sender: HoldButton) {
        switch sender.tag {
        case ActionTag.mute:
            muteAction(sender)
        case ActionTag.unmute:
            unmuteAction(sender)
        case ActionTag.report:
            reportAction(sender)
        case ActionTag.join:
            joinAction(sender)
        case ActionTag.more:
            moreAction(sender)
        case ActionTag.message:
            messageAction(sender)
        default:
            break
        }
    }
    
    open func availableSections() -> [Sections] {
        var sections: [Sections] = [.header]
        switch profileViewModel.channelType {
        case .broadcast:
            if !(profileViewModel.channel.decodedMetadata?.description ?? profileViewModel.channel.metadata ?? "").isEmpty {
                sections.append(.description)
            }
            sections.append(.uri)
        case .private:
            if !(profileViewModel.channel.decodedMetadata?.description ?? profileViewModel.channel.metadata ?? "").isEmpty {
                sections.append(.description)
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
        if let sender = sender as? HoldButton {
            router.showMuteOptionsAlert { [weak self] option in
                self?.mute(for: option.timeInterval, sender: sender)
            } canceled: {}
        } else if let sender = sender as? UISwitch {
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
            } else if let sender = sender as? HoldButton {
                sender.imageView.image = .channelProfileUnmute
                sender.titleLabel.text = L10n.Channel.Profile.Action.unmute
                sender.tag = ActionTag.unmute
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
            } else if let sender = sender as? HoldButton {
                sender.imageView.image = .channelProfileMute
                sender.titleLabel.text = L10n.Channel.Profile.Action.mute
                sender.tag = ActionTag.mute
            }
        }
    }
    
    open func pinChat() {
        profileViewModel.channelProvider.pin()
    }
    
    open func unpinChat() {
        profileViewModel.channelProvider.unpin()
    }
    
    open func reportAction(_ sender: HoldButton) {
        // TODO: Report User
        logger.debug("Report User")
    }
    
    open func joinAction(_ sender: HoldButton) {
        profileViewModel.join { [weak self] error in
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
            } else {
                self.router.goChannelVC()
            }
        }
    }
    
    @objc
    open func moreAction(_ sender: Any) {
        var actions = [SheetAction]()
        
        switch profileViewModel.channelType {
        case .direct:
            if profileViewModel.channel.pinnedAt == nil {
                actions += [
                    .init(
                        title: L10n.Channel.Profile.Action.Chat.pin,
                        icon: .chatPin,
                        handler: { [unowned self] in
                            pinChat()
                        })
                ]
            } else {
                actions += [
                    .init(
                        title: L10n.Channel.Profile.Action.Chat.unpin,
                        icon: .chatUnpin,
                        handler: { [unowned self] in
                            unpinChat()
                        })
                ]
            }
            
            actions += [
                .init(
                    title: L10n.Channel.Profile.Action.clearHistory,
                    icon: .chatClear,
                    handler: { [unowned self] in
                        deleteAllMessages()
                    })
            ]
            
            if profileViewModel.channel.peer?.blocked == true {
                actions += [
                    .init(
                        title: L10n.Channel.Profile.Action.unblock,
                        icon: .chatUnBlock,
                        handler: { [unowned self] in
                            unblock()
                        })
                ]
            } else {
                actions += [
                    .init(
                        title: L10n.Channel.Profile.Action.block,
                        icon: .chatBlock,
                        handler: { [unowned self] in
                            block()
                        })
                ]
            }
            
            actions += [
                .init(
                    title: L10n.Channel.Profile.Action.Chat.delete,
                    icon: .chatDelete,
                    style: .destructive,
                    handler: { [unowned self] in
                        block()
                    })
            ]
           
        case .private:
            if profileViewModel.canEdit {
                actions += [
                    .init(
                        title: L10n.Channel.Profile.Action.Group.edit,
                        icon: .chatEdit,
                        handler: { [unowned self] in
                            editAction(nil)
                        })
                ]
            }
            
            if profileViewModel.channel.pinnedAt == nil {
                actions += [
                    .init(
                        title: L10n.Channel.Profile.Action.Group.pin,
                        icon: .chatPin,
                        handler: { [unowned self] in
                            pinChat()
                        })
                ]
            } else {
                actions += [
                    .init(
                        title: L10n.Channel.Profile.Action.Group.unpin,
                        icon: .chatUnpin,
                        handler: { [unowned self] in
                            unpinChat()
                        })
                ]
            }
            
            actions += [
                .init(
                    title: L10n.Channel.Profile.Action.clearHistory,
                    icon: .chatClear,
                    handler: { [unowned self] in
                        deleteAllMessages()
                    }),
                .init(
                    title: L10n.Channel.Profile.Action.Group.blockAndLeave,
                    icon: .chatBlock,
                    style: .destructive,
                    handler: { [unowned self] in
                        blockAndLeave()
                    }),
                .init(
                    title: L10n.Channel.Profile.Action.Group.leave,
                    icon: .chatLeave,
                    style: .destructive,
                    handler: { [unowned self] in
                        leave()
                    })
            ]
            
            if profileViewModel.isOwner {
                actions += [
                    .init(
                        title: L10n.Channel.Profile.Action.Group.delete,
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
                        title: L10n.Channel.Profile.Action.Channel.edit,
                        icon: .chatEdit,
                        handler: { [unowned self] in
                            editAction(nil)
                        })
                ]
            }
            
            if profileViewModel.channel.pinnedAt == nil {
                actions += [
                    .init(
                        title: L10n.Channel.Profile.Action.Channel.pin,
                        icon: .chatPin,
                        handler: { [unowned self] in
                            pinChat()
                        })
                ]
            } else {
                actions += [
                    .init(
                        title: L10n.Channel.Profile.Action.Channel.unpin,
                        icon: .chatUnpin,
                        handler: { [unowned self] in
                            unpinChat()
                        })
                ]
            }
            
            actions += [
                .init(
                    title: L10n.Channel.Profile.Action.clearHistory,
                    icon: .chatClear,
                    handler: { [unowned self] in
                        deleteAllMessages(forEveryone: true)
                    }),
                .init(
                    title: L10n.Channel.Profile.Action.Channel.blockAndLeave,
                    icon: .chatBlock,
                    style: .destructive,
                    handler: { [unowned self] in
                        blockAndLeave()
                    }),
                .init(
                    title: L10n.Channel.Profile.Action.Channel.leave,
                    icon: .chatLeave,
                    style: .destructive,
                    handler: { [unowned self] in
                        leave()
                    })
            ]
            
            if profileViewModel.isOwner {
                actions += [
                    .init(
                        title: L10n.Channel.Profile.Action.Channel.delete,
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
    
    open func messageAction(_ sender: HoldButton) {
        logger.debug("message")
        ChannelListRouter.findAndShowChannel(id: profileViewModel.channel.id)
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
                                    self.router.goChannelListVC()
                                }
                            }
                    }
                  ],
                  preferredActionIndex: 1)
    }
    
    open func block() {
        hud.isLoading = true
        profileViewModel.block { [weak self] error in
            hud.isLoading = false
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
            } else {
                self.router.channelVC?.channelViewModel.refreshChannel()
//                self.router.goChannelListVC()
            }
        }
    }
    
    open func unblock() {
        hud.isLoading = true
        profileViewModel.unblock { [weak self] error in
            hud.isLoading = false
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
            } else {
                self.router.channelVC?.channelViewModel.refreshChannel()
            }
        }
    }
    
    open func leave() {
        hud.isLoading = true
        profileViewModel.leave { [weak self] error in
            hud.isLoading = false
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
            } else {
                self.router.goChannelListVC()
            }
        }
    }
    
    open func blockAndLeave() {
        hud.isLoading = true
        profileViewModel.blockAndLeave { [weak self] error in
            hud.isLoading = false
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
            } else {
                self.router.goChannelListVC()
            }
        }
    }
    
    open func delete() {
        let title: String
        let message: String
        switch profileViewModel.channel.channelType {
        case .direct:
            title = L10n.Channel.Profile.Action.Chat.delete
            message = L10n.Channel.Profile.Action.Chat.deleteMessage
        case .private:
            title = L10n.Channel.Profile.Action.Group.delete
            message = L10n.Channel.Profile.Action.Group.deleteMessage
        case .broadcast:
            title = L10n.Channel.Profile.Action.Channel.delete
            message = L10n.Channel.Profile.Action.Channel.deleteMessage
        }
        showAlert(title: title,
                  message: message,
                  actions: [
                    .init(title: L10n.Alert.Button.cancel, style: .cancel),
                    .init(title: L10n.Alert.Button.delete, style: .destructive) { [weak self] in
                        hud.isLoading = true
                        self?.profileViewModel.delete { [weak self] error in
                            hud.isLoading = false
                            guard let self else { return }
                            if let error = error {
                                self.showAlert(error: error)
                            } else {
                                self.router.goChannelListVC()
                            }
                        }
                    }
                  ],
                  preferredActionIndex: 1)
    }
}

public extension ChannelProfileVC {
    enum Sections: Int, CaseIterable {
        case header
        case actionMenu
        case description
        case uri
        case options
        case items
//        case uri
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

public extension ChannelProfileVC {
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
