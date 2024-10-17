//
//  ProfileViewController.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 15.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChatUIKit

class ProfileViewController: ViewController {
    
    // MARK: - Properties
    lazy var router = Router(rootViewController: self)
    
    // MARK: - Views
    open lazy var tableView = UITableView(frame: .zero, style: .grouped)
        .withoutAutoresizingMask
        .rowAutomaticDimension
    
    // MARK: - Lifecycle
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            tableView.visibleCells.forEach { cell in
                if let borderLayer = cell.layer.sublayers?.first(where: { $0.name == "bottomBorder" }) {
                    borderLayer.borderColor = UIColor.border.cgColor
                }
            }
        }
    }
    
    override func setup() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(ChannelInfoViewController.DetailsCell.self)
        tableView.register(ChannelInfoViewController.OptionCell.self)
        tableView.register(UITableViewCell.self)
        
        if !users.contains(SceytChatUIKit.shared.chatClient.user.id) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(edit(_:)))
        }
    }
    
    override func setupAppearance() {
        super.setupAppearance()
        
        view.backgroundColor = .background
        title = "Profile"
    }
    
    override func setupLayout() {
        super.setupLayout()
        
        view.addSubview(tableView)
        tableView.pin(to: view)
    }
    
    override func setupDone() {
        super.setupDone()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadUserData), name: NSNotification.Name(rawValue: "userProfileUpdated"), object: nil)
    }
    
    // MARK: - Actions
    @objc
    private func reloadUserData() {
        tableView.reloadSections([Sections.details.rawValue], with: .none)
    }
    
    @objc
    private func edit(_ sender: UIBarButtonItem) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "EditProfileViewController")
        vc.hidesBottomBarWhenPushed = true
        show(vc, sender: self)
    }
    
    private func showLogOutAlert() {
        let deleteMessage = "Are you sure you want to log out?\nYou can choose to simply log out or delete all your account data before logging out.\nDeleting your account data will permanently remove all your information and cannot be undone."
        let logoutMessage = "Are you sure you want to log out?"
        let message = users.contains(SceytChatUIKit.shared.chatClient.user.id) ? logoutMessage : deleteMessage
        
        var actions: [SheetAction] = [
            .init(
                title: "Log Out",
                style: .destructive,
                handler: { [weak self] in
                    self?.logOut()
                }),
                .init(
                    title: "Cancel",
                    style: .cancel
                ),
        ]
        
        if !users.contains(SceytChatUIKit.shared.chatClient.user.id) {
            actions.insert(
                .init(
                    title: "Delete Account & Log Out",
                    style: .destructive,
                    handler: { [weak self] in
                        self?.deleteAndLogout()
                    }),
                at: 1
            )
        }
        
        router.showAlert(title: "Confirm Logout",
                         message: message,
                         actions: actions,
                         preferredActionIndex: actions.count - 1)
    }
    
    private func deleteAndLogout() {
        RequestManager.deleteUser(userId: SceytChatUIKit.shared.chatClient.user.id) { [weak self] success in
            if success {
                self?.logOut()
            } else {
                self?.router.showAlert(title: "Something went wrong",
                                       message: "Please try again.")
            }
        }
    }
    
    private func logOut() {
        Config.currentUserId = nil
        SceytChatUIKit.shared.currentUserId = nil
        
        SceytChatUIKit.shared.chatClient.disconnect()
        DataProvider.database.deleteAll()
        AppCoordinator.shared.showAuthFlow()
    }
}

extension ProfileViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Sections(rawValue: indexPath.section)! {
        case .details:
            return
        case .options:
            switch OptionsSection(rawValue: indexPath.row)! {
            case .notification:
                return
            case .appearanceMode:
                return
            }
        case .logout:
            showLogOutAlert()
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}

extension ProfileViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        Sections.allCases.count
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Sections(rawValue: section)! {
        case .details:
            1
        case .options:
            OptionsSection.allCases.count
        case .logout:
            1
        }
    }
    
    open func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let cornerRadius = 10
        var corners: UIRectCorner = []
        
        if tableView.isFirst(indexPath) {
            corners.update(with: .topLeft)
            corners.update(with: .topRight)
        }
        
        if tableView.isLast(indexPath) {
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
            layer.borderColor = UIColor.border.cgColor
            layer.borderWidth = 1
            layer.frame = CGRect(x: 0, y: cell.height - layer.borderWidth, width: cell.width, height: layer.borderWidth)
        }
        
        let maskLayer = CAShapeLayer()
        var rect = cell.bounds
        
        rect.origin.x = 16
        rect.size.width -= 16 * 2
        
        maskLayer.path = UIBezierPath(roundedRect: rect,
                                      byRoundingCorners: corners,
                                      cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)).cgPath
        cell.layer.mask = maskLayer
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Sections(rawValue: indexPath.section)! {
        case .details:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: ChannelInfoViewController.DetailsCell.self)
            cell.selectionStyle = .none
            let user = ChatUser(user: SceytChatUIKit.shared.chatClient.user)
            cell.titleLabel.text = SceytChatUIKit.shared.formatters.userNameFormatter.format(user)
            cell.subtitleLabel.text = user.username == nil ? nil : "@\(user.username!)"
            _ = AvatarBuilder.loadAvatar(into: cell.avatarButton, for: user)
            return cell
        case .options:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: ChannelInfoViewController.OptionCell.self)
            
            cell.selectionStyle = .none
            let sw = UISwitch()
            sw.onTintColor = .accent
            
            switch OptionsSection(rawValue: indexPath.row)! {
            case .notification:
                cell.iconView.image = .channelProfileBell
                cell.titleLabel.text = "Notifications"
                sw.addTarget(self, action: #selector(notificationsAction), for: .valueChanged)
                sw.isOn = !SceytChatUIKit.shared.chatClient.settings.muted
            case .appearanceMode:
                cell.iconView.image = .appearanceIcon
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let sceneDelegate = scene.delegate as? SceneDelegate,
                   let window = sceneDelegate.window {
                    cell.titleLabel.text = switch window.overrideUserInterfaceStyle {
                    case .dark: "Dark mode"
                    case .light: "Light mode"
                    case .unspecified: "System appearance"
                    @unknown default: fatalError()
                    }
                    
                    sw.isOn = switch window.overrideUserInterfaceStyle {
                    case .dark: true
                    case .light: false
                    case .unspecified: true
                    @unknown default: fatalError()
                    }
                }
                sw.addTarget(self, action: #selector(appearanceAction), for: .valueChanged)
            }
            
            cell.accessoryView = sw
            return cell
        case .logout:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: UITableViewCell.self)
            cell.backgroundColor = .backgroundSections
            cell.indentationLevel = 1
            cell.indentationWidth = 16
            cell.textLabel?.text = "Log Out"
            cell.textLabel?.textColor = .stateWarning
            return cell
        }
    }
    
    @objc
    open func notificationsAction(_ sender: UISwitch) {
        if !sender.isOn {
            showMuteOptionsAlert { [unowned self] item in
                mute(for: item.timeInterval)
            } canceled: {[unowned self] in
                updateNotification()
            }
        } else {
            unmute()
        }
    }
}

extension ProfileViewController {
    
    private func showMuteOptionsAlert(
        selected: @escaping (SceytChatUIKit.Config.IntervalOption) -> Void,
        canceled: @escaping () -> Void
    ) {
        showBottomSheet(
            title: "Mute",
            actions: SceytChatUIKit.shared.config.muteChannelNotificationOptions.map { item in
                    .init(title: item.title, style: .default) { selected(item) }
            } + [.init(title: "Cancel", style: .cancel) { canceled() }])
    }
    
    func mute(for timeInterval: TimeInterval) {
        SceytChatUIKit.shared.chatClient.mute(timeInterval: timeInterval) {[weak self] error in
            guard let self else { return }
            if let error {
                self.showAlert(error: error)
            }
            updateNotification()
        }
    }
    
    func unmute() {
        SceytChatUIKit.shared.chatClient.unmute {[weak self] error in
            guard let self else { return }
            if let error {
                self.showAlert(error: error)
            }
            updateNotification()
        }
    }
    
    func updateNotification() {
        tableView.reloadRows(at: [IndexPath(row: OptionsSection.notification.rawValue,
                                            section: Sections.options.rawValue)],
                             with: .none)
    }
    
    
    @objc
    open func appearanceAction(_ sender: UISwitch) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let sceneDelegate = scene.delegate as? SceneDelegate,
              let window = sceneDelegate.window
        else { return }
        
        window.overrideUserInterfaceStyle = sender.isOn ? .dark : .light
        tableView.reloadRows(at: [IndexPath(row: OptionsSection.appearanceMode.rawValue,
                                            section: Sections.options.rawValue)],
                             with: .none)
        
    }
}

extension ProfileViewController {
    enum Sections: Int, CaseIterable {
        case details
        case options
        case logout
    }
    enum OptionsSection: Int, CaseIterable {
        case notification
        case appearanceMode
    }
}
