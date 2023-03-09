//
//  ChannelProfileVC.swift
//  SceytChatUIKit
//

import UIKit
import Photos

open class ChannelProfileVC: ViewController,
                             UITableViewDelegate,
                             UITableViewDataSource,
                             UIGestureRecognizerDelegate {

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
            SegmentedControlView.SectionItem(content: linkListVC,
                                           title: L10n.Channel.Profile.Segment.links),
            SegmentedControlView.SectionItem(content: voiceListVC,
                                           title: L10n.Channel.Profile.Segment.voice)
        ]).withoutAutoresizingMask
    
    public var sections = [Sections]()
    
    open override func setup() {
        super.setup()
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        
        if profileViewModel.canEdit {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .edit,
                target: self,
                action: #selector(editAction(_:))
            )
        }
        
        mediaListVC.mediaViewModel = profileViewModel.mediaListViewModel
        mediaListVC.previewer = profileViewModel.previewer
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
        tableView.sectionHeaderHeight = 18
        tableView.sectionFooterHeight = 0
        tableView.isDirectionalLockEnabled = true
        sections = availableSections()
        
        fileListVC.onSelect = { [unowned self] indexPath in
            if let attachment = fileListVC.fileViewModel.attachment(at: indexPath) {
                router.showAttachment(attachment)
            }
        }
    }
    
    open override func setupLayout() {
        super.setupLayout()
        view.addSubview(tableView)
        tableView.pin(to: view)
    }
    
    open override func setupDone() {
        super.setupDone()
        profileViewModel.startDatabaseObserver()
        profileViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        view.backgroundColor = appearance.backgroundColor
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        if navigationController?.interactivePopGestureRecognizer != nil {
//            tableView.panGestureRecognizer.require(toFail: navigationController!.interactivePopGestureRecognizer!)
//        }
    }
    
    open override func viewSafeAreaInsetsDidChange() {
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
            if let cell = tableView.visibleCells.first(where: { $0 is ChannelProfileHeaderCell}) as? ChannelProfileHeaderCell,
                let indexPath = tableView.indexPath(for: cell) {
                indexPaths.append(indexPath)
            }
            if let cell = tableView.visibleCells.first(where: { $0 is ChannelProfileDescriptionCell}) as? ChannelProfileDescriptionCell,
                let indexPath = tableView.indexPath(for: cell) {
                indexPaths.append(indexPath)
            }
            tableView.reloadRows(at: indexPaths, with: .none)
        }
    }
    
    @objc
    func editAction(_ sender: UIBarButtonItem) {
        router.showEditChannel()
    }
  
    open func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }
    
    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
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
    
    open func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        sections[section] == .items ? 2 : 1
    }
    
    open func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        
        let _cell: UITableViewCell
        switch sections[indexPath.section] {
        case .header:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileHeaderCell.self)
            cell.selectionStyle = .none
            cell.data = profileViewModel.channel
            _cell = cell
        case .actionMenu:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileMenuCell.self)
            cell.selectionStyle = .none
            cell.data = preferredMenuButtons()
            _cell = cell
        case .description:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileDescriptionCell.self)
            cell.selectionStyle = .none
            if profileViewModel.channel.type == .direct {
                cell.data = profileViewModel.channel.peer?.presence.status
            } else {
                cell.data = profileViewModel.channel.decodedMetadata?.description
            }
            _cell = cell
//        case .uri:
//            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileURICell.self)
//            cell.data = profileViewModel.channel.uri
//            _cell = cell
        case .items:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileItemCell.self)
            cell.selectionStyle = .gray
            cell.accessoryView = UIImageView(image: .chevron)
            if indexPath.row == 0 {
                cell.iconView.image = .channelProfileMembers
                switch profileViewModel.channel.type {
                case .public:
                    cell.itemLable.text = L10n.Channel.Profile.Item.Title.subscribers
                case .private:
                    cell.itemLable.text = L10n.Channel.Profile.Item.Title.members
                case .direct:
                    cell.iconView.image = nil
    //                fatalError()
                }
            } else if indexPath.row == 1 {
                cell.iconView.image = .channelProfileAdmins
                cell.itemLable.text = L10n.Channel.Profile.Item.Title.admins
            }
            
            _cell = cell
        case .attachment:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileContainerCell.self)
            cell.selectionStyle = .none
            cell.heightAnchorConstant = view.frame.height - view.safeAreaInsets.top
            cell.containerView = segmentVC.withoutAutoresizingMask
            _cell = cell
        }
        return _cell
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if sections[indexPath.section] == .items {
            switch indexPath.row {
            case 0:
                router.showMemberList()
            case 1:
                router.showAdminsList()
            default:
                break
            }
        }
    }
    
    open func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        var cornerRadius = 12
        var corners: UIRectCorner = []
        
        if indexPath.row == 0 {
            corners.update(with: .topLeft)
            corners.update(with: .topRight)
        }
        
        if indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1,
           indexPath.section != tableView.numberOfSections - 1 {
            corners.update(with: .bottomLeft)
            corners.update(with: .bottomRight)
        }
        
        let maskLayer = CAShapeLayer()
        var rect = cell.bounds
        if sections[indexPath.section] != .attachment {
            rect.origin.x = 16
            rect.size.width -= 32
        } else {
            cornerRadius = 24
        }
        maskLayer.path = UIBezierPath(roundedRect: rect,
                                      byRoundingCorners: corners,
                                      cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)).cgPath
        cell.layer.mask = maskLayer
    }
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let velocity = scrollView.panGestureRecognizer.velocity(in: scrollView).y
        let y = scrollView.contentSize.height - scrollView.frame.height - 18
        if scrollView.contentOffset.y >= y {
            scrollView.contentOffset = .init(x: 0, y: y)
            navigationItem.title = profileViewModel.channel.displayName
        } else if velocity < 0 {
            if !scrollView.isDecelerating, scrollView.contentOffset.y != y {
                (segmentVC.selectedItem.content as? UIScrollView)?.contentOffset = .zero
            }
        } else if (((segmentVC.selectedItem.content as? UIScrollView)?.contentOffset.y ?? 0) > 10), velocity > 0 {
            scrollView.contentOffset = .init(x: 0, y: y)
            navigationItem.title = profileViewModel.channel.displayName
        } else if ((segmentVC.selectedItem.content as? UIScrollView)?.contentOffset.y ?? 0) > 0 {
            scrollView.contentOffset = .init(x: 0, y: y)
            navigationItem.title = profileViewModel.channel.displayName
        }
        if let cell = tableView.visibleCells.first(where: { $0 is ChannelProfileHeaderCell}) as? ChannelProfileHeaderCell {
            let point = cell.convert(cell.titleLabel.center, to: view)
            if point.y <= view.safeAreaInsets.top {
                navigationItem.title = cell.titleLabel.text
            } else {
                navigationItem.title = nil
            }
        }
    }
    
    open func preferredMenuButtons() -> [HoldButton] {
        
        func button(item: ActionItem) -> HoldButton {
            let hb = HoldButton(image: item.image, title: item.title, tag: item.tag)
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
        
        switch profileViewModel.channel.type {
        case .public:
            if profileViewModel.isUnsubscribedChannel {
                return [button(item:
                        .init(
                            title: L10n.Channel.Profile.Action.join,
                            image: .channelProfileJoin,
                            tag: ActionTag.join))
                ]
            } else {
                return [
                    mute,
                    button(item:
                            .init(
                                title: L10n.Channel.Profile.Action.more,
                                image: .channelProfileMore,
                                tag: ActionTag.more
                            ))
                ]
            }
        case .private:
            return [
                mute,
                button(item:
                        .init(
                            title: L10n.Channel.Profile.Action.more,
                            image: .channelProfileMore,
                            tag: ActionTag.more
                        ))
            ]
        case .direct:
            return [
                mute,
                button(item:
                        .init(
                            title: L10n.Channel.Profile.Action.more,
                            image: .channelProfileMore,
                            tag: ActionTag.more
                        ))
            ]
        }
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
        default:
            break
        }
    }
    
    open func availableSections() -> [Sections] {
        var sections = [Sections]()
        switch profileViewModel.channel.type {
        case .public:
            sections = [.header, .actionMenu]
            if !(profileViewModel.channel.decodedMetadata?.description ?? "").isEmpty {
                sections.append(.description)
            }
            sections.append(.items)
//            sections.append(.uri)
        case .private:
            sections = [.header, .actionMenu]
            if !(profileViewModel.channel.decodedMetadata?.description ?? "").isEmpty {
                sections.append(.description)
            }
            sections.append(.items)
        case .direct:
            sections = [.header, .actionMenu]
            if !(profileViewModel.channel.peer?.presence.status ?? "").isEmpty {
                sections.append(.description)
            }
        }
        sections += [.attachment]
        return sections
    }
    
    open func muteAction(_ sender: HoldButton) {
        router.showMuteOptionsAlert {[unowned self] mute in
            profileViewModel
                .mute(timeInterval: mute.timeInterval)
            {[weak self] error in
                guard let self else { return }
                if let error = error {
                    self.showAlert(error: error)
                } else {
                    sender.imageView.image = .channelProfileUnmute
                    sender.titleLabel.text = L10n.Channel.Profile.Action.unmute
                    sender.tag = ActionTag.unmute
                }
            }
        } canceled: {
        }

    }
    
    open func unmuteAction(_ sender: HoldButton) {
        profileViewModel.unmute { [weak self] error in
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
            } else {
                sender.imageView.image = .channelProfileMute
                sender.titleLabel.text = L10n.Channel.Profile.Action.mute
                sender.tag = ActionTag.mute
            }
        }
    }
    
    open func reportAction(_ sender: HoldButton) {
        
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
    
    open func moreAction(_ sender: HoldButton) {
        var alertActions = [UIAlertAction]()
        
        switch profileViewModel.channel.type {
        case .direct:
            alertActions += [
                UIAlertAction(
                    title: L10n.Channel.Profile.Action.clearHistory,
                    style: .destructive,
                    handler: {[unowned self] _ in
                    deleteAllMessages()
                })
            ]
            
            if profileViewModel.channel.peer?.blocked == true {
                alertActions += [
                    UIAlertAction(
                        title: L10n.Channel.Profile.Action.unblock,
                        style: .default,
                        handler: {[unowned self] _ in
                        unblock()
                    })
                ]
            } else {
                alertActions += [
                    UIAlertAction(
                        title: L10n.Channel.Profile.Action.block,
                        style: .destructive,
                        handler: {[unowned self] _ in
                        block()
                    })
                ]
            }
            
            alertActions += [
                UIAlertAction(
                    title: L10n.Channel.Profile.Action.Chat.delete,
                    style: .destructive,
                    handler: {[unowned self] _ in
                    block()
                })
            ]
           
        case .private:
            alertActions += [
                UIAlertAction(
                    title: L10n.Channel.Profile.Action.clearHistory,
                    style: .destructive,
                    handler: {[unowned self] _ in
                    deleteAllMessages()
                }),
                UIAlertAction(
                    title: L10n.Channel.Profile.Action.Group.leave,
                    style: .destructive,
                    handler: {[unowned self] _ in
                        leave()
                }),
                
                UIAlertAction(
                    title: L10n.Channel.Profile.Action.Group.blockAndLeave,
                    style: .destructive,
                    handler: {[unowned self] _ in
                        blockAndLeave()
                }),
                
                UIAlertAction(
                    title: L10n.Channel.Profile.Action.Group.delete,
                    style: .destructive,
                    handler: {[unowned self] _ in
                        delete()
                })
            ]
            
        case .public:
            alertActions += [
                UIAlertAction(
                    title: L10n.Channel.Profile.Action.clearHistory,
                    style: .destructive,
                    handler: {[unowned self] _ in
                    deleteAllMessages()
                }),
                UIAlertAction(
                    title: L10n.Channel.Profile.Action.Channel.leave,
                    style: .destructive,
                    handler: {[unowned self] _ in
                        leave()
                }),
                
                UIAlertAction(
                    title: L10n.Channel.Profile.Action.Channel.blockAndLeave,
                    style: .destructive,
                    handler: {[unowned self] _ in
                        blockAndLeave()
                }),
                
                UIAlertAction(
                    title: L10n.Channel.Profile.Action.Channel.delete,
                    style: .destructive,
                    handler: {[unowned self] _ in
                        delete()
                })
            ]
        }
        guard !alertActions.isEmpty else { return }
        
        router.presentAlert(alertActions: alertActions) {
            
        }
    }
    
    open func deleteAllMessages(forEveryone: Bool = false) {
        profileViewModel
            .deleteAllMessages(forEveryone: forEveryone)
        { [weak self] error in
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
            } else {
                self.router.goChannelListVC()
            }
        }
    }
    
    open func block() {
        profileViewModel.block {[weak self] error in
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
            } else {
                self.router.goChannelListVC()
            }
        }
    }
    
    open func unblock() {
        profileViewModel.unblock {[weak self] error in
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
            } else {
                self.router.goChannelVC()
            }
        }
    }
    
    open func leave() {
        profileViewModel.leave {[weak self] error in
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
            } else {
                self.router.goChannelListVC()
            }
        }
    }
    
    open func blockAndLeave() {
        profileViewModel.blockAndLeave {[weak self] error in
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
            } else {
                self.router.goChannelListVC()
            }
        }
    }
    
    open func delete() {
        profileViewModel.delete {[weak self] error in
            guard let self else { return }
            if let error = error {
                self.showAlert(error: error)
            } else {
                self.router.goChannelListVC()
            }
        }
    }
}

extension ChannelProfileVC {
    
    public enum Sections: Int, CaseIterable {
        case header
        case actionMenu
        case description
        case items
//        case uri
        case attachment
    }
    
    public struct ActionItem {
        public var title: String
        public var image: UIImage
        public var tag: Int
        
        public init(
            title: String,
            image: UIImage,
            tag: Int
        ) {
            self.title = title
            self.image = image
            self.tag = tag
        }
    }
    
    public enum ActionTag {
        static var mute = 10001
        static var unmute = 10002
        static var join = 10003
        static var more = 10004
        static var report = 10005
    }
}

