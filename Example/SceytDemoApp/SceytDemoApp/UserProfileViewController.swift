//
//  UserProfileViewController.swift
//  SceytDemoApp
//
//  Created by Hovsep Keropyan on 15.01.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat
import SceytChatUIKit


class UserProfileViewController: UIViewController {
    
    lazy var profileView = ProfileView()
        .withoutAutoresizingMask
   
    lazy var notificationView = ActionView()
        .withoutAutoresizingMask
    
    lazy var appearanceModeView = ActionView()
        .withoutAutoresizingMask
    
    lazy var userInterfaceModeView = ActionView()
        .withoutAutoresizingMask

    lazy var signOutButton = UIButton()
        .withoutAutoresizingMask
    
    lazy var router = Router(rootVC: self)
    
    fileprivate var userAvatarImage: UIImage?
    fileprivate var isDeleted = false
    private var needsToUpdateProfileAfterViewAppear = false
    
    lazy var stackView: UIStackView = {
        $0.axis = .vertical
        $0.spacing = 16
        $0.alignment = .fill
        return $0.withoutAutoresizingMask
    }(UIStackView(arrangedSubviews: [profileView, notificationView, appearanceModeView, userInterfaceModeView, signOutButton]))

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "My Profile"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(edit(_:)))
        ChatClient.shared.add(delegate: self, identifier: String(reflecting: self))
        
        view.addSubview(stackView)
        
        updateUI()
        
        stackView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading(8), .trailing(-8), .top(8)])
        profileView.heightAnchor.pin(constant: 72)
        profileView.editButton.addTarget(self, action: #selector(editAvatar(_:)), for: .touchUpInside)
        notificationView.switch.addTarget(self, action: #selector(onMute(_:)), for: .valueChanged)
        appearanceModeView.switch.addTarget(self, action: #selector(onAppearanceModeView(_:)), for: .valueChanged)
        userInterfaceModeView.switch.addTarget(self, action: #selector(onUserInterfaceModeView(_:)), for: .valueChanged)
        signOutButton.setTitle("Sign Out", for: .normal)
        signOutButton.setTitleColor(.red, for: .normal)
        signOutButton.addTarget(self, action: #selector(onSignOut(_:)), for: .touchUpInside)
        stackView.setCustomSpacing(64, after: userInterfaceModeView)
        
        updateSettings()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if needsToUpdateProfileAfterViewAppear {
            updateProfile()
            needsToUpdateProfileAfterViewAppear = false
        }
        
    }

    fileprivate func updateUI() {
        updateProfile()
        updateNotification()
        updateAppearanceMode()
    }
    
    fileprivate func updateProfile() {
        let user = ChatUser(user: ChatClient.shared.user)
        profileView.displayNameLabel.text = SceytChatUIKit.shared.formatters.userDisplayName.format(user)
        _ = AvatarBuilder.loadAvatar(into: profileView.imageView, for: user)
    }
    
    fileprivate func updateNotification() {
        let settings = ChatClient.shared.settings
        if settings.muted {
            notificationView.titleView.titleLabel.text = "Unmute Notifications"
            notificationView.titleView.iconView.image = UIImage(systemName: "speaker.fill")
        } else {
            notificationView.titleView.titleLabel.text = "Mute Notifications"
            notificationView.titleView.iconView.image = UIImage(systemName: "speaker.slash.fill")
        }
        notificationView.switch.isOn = settings.muted
    }
    
    fileprivate func updateAppearanceMode() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let sceneDelegate = scene.delegate as? SceneDelegate,
              let window = sceneDelegate.window
        else { return }

        switch window.overrideUserInterfaceStyle {
        case .dark:
            appearanceModeView.titleView.titleLabel.text = "Appearance"
            appearanceModeView.titleView.iconView.image = UIImage(systemName: "paintbrush")
            appearanceModeView.switch.isOn = false
            userInterfaceModeView.titleView.titleLabel.text = "Dark mode"
            userInterfaceModeView.titleView.iconView.image = UIImage(systemName: "moon.zzz.fill")
            userInterfaceModeView.switch.isOn = true
            userInterfaceModeView.isHidden = false
        case .light:
            appearanceModeView.titleView.titleLabel.text = "Appearance"
            appearanceModeView.titleView.iconView.image = UIImage(systemName: "paintbrush")
            appearanceModeView.switch.isOn = false
            userInterfaceModeView.titleView.titleLabel.text = "Light mode"
            userInterfaceModeView.titleView.iconView.image = UIImage(systemName: "sun.max.fill")
            userInterfaceModeView.switch.isOn = false
            userInterfaceModeView.isHidden = false
        case .unspecified:
            appearanceModeView.titleView.titleLabel.text = "Appearance: System"
            appearanceModeView.titleView.iconView.image = UIImage(systemName: "paintbrush.fill")
            appearanceModeView.switch.isOn = true
            userInterfaceModeView.isHidden = true
        @unknown default:
            fatalError()
        }
    }
    
    @objc
    private func onMute(_ sender: UISwitch) {
        if sender.isOn {
            showMuteOptionsAlert {[unowned self] item in
                mute(for: item.timeInterval)
            } canceled: {[unowned self] in
                updateNotification()
            }
        } else {
            unmute()
        }
    }
    
    @objc
    private func onAppearanceModeView(_ sender: UISwitch) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let sceneDelegate = scene.delegate as? SceneDelegate,
              let window = sceneDelegate.window
        else { return }
        
        window.overrideUserInterfaceStyle = sender.isOn ? .unspecified : .light
        updateAppearanceMode()
    }
    
    @objc
    private func onUserInterfaceModeView(_ sender: UISwitch) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let sceneDelegate = scene.delegate as? SceneDelegate,
              let window = sceneDelegate.window
        else { return }

        window.overrideUserInterfaceStyle = sender.isOn ? .dark : .light
        updateAppearanceMode()
    }

    @objc
    private func editAvatar(_ sender: UIButton) {
        showCaptureAlert()
    }
    
    @objc
    private func onSignOut(_ sender: UIButton) {
        Config.currentUserId = nil
        ChatClient.shared.disconnect()
        Provider.database.deleteAll()
        let lvc = LoginViewController()
        lvc.modalPresentationStyle = .fullScreen
        present(lvc, animated: true)
        needsToUpdateProfileAfterViewAppear = true
    }
    
    @objc
    private func edit(_ sender: UIBarButtonItem) {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save(_:)))
        profileView.isEditing = true
    }
    
    @objc
    private func save(_ sender: UIBarButtonItem) {
        let displayName = profileView.displayNameLabel.text
        hud.isLoading = true
        UserProfile.update(displayName: displayName) {[weak self] error in
            hud.isLoading = false
            guard let self
            else { return }
            if let error {
                self.showAlert(error: error)
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(edit(_:)))
                self.profileView.isEditing = false
            }
        }
    }
    
    private func showMuteOptionsAlert(
        selected: @escaping (SceytChatUIKit.Config.OptionItem) -> Void,
        canceled: @escaping () -> Void
    ) {
        showBottomSheet(
            title: "Mute",
            actions: SceytChatUIKit.shared.config.muteItems.map { item in
                    .init(title: item.title, style: .default) { selected(item) }
            } + [.init(title: "Cancel", style: .cancel) { canceled() }])
    }
    
    open func mute(for timeInterval: TimeInterval) {
        ChatClient.shared.mute(timeInterval: timeInterval) {[weak self] error in
            guard let self else { return }
            if let error {
                self.showAlert(error: error)
            }
            self.updateNotification()
        }
    }
    
    open func unmute() {
        ChatClient.shared.unmute {[weak self] error in
            guard let self else { return }
            if let error {
                self.showAlert(error: error)
            }
            self.updateNotification()
        }
    }
    
    private func updateSettings() {
        if ChatClient.shared.connectionState == .connected {
            ChatClient.shared.getUserSettings {[weak self] _, _ in
                self?.updateNotification()
            }
        }
    }
    
    deinit {
        ChatClient.shared.removeDelegate(identifier: String(reflecting: self))
    }
}

extension UserProfileViewController: ChatClientDelegate {
    
    func chatClient(_ chatClient: ChatClient, didChange state: ConnectionState, error: SceytError?) {
        if state == .connected {
            updateProfile()
            chatClient.getUserSettings {[weak self] _, _ in
                self?.updateNotification()
            }
        }
    }
}

extension UserProfileViewController {
    
    class ProfileView: UIStackView {
        
        lazy var imageView: CircleImageView = {
            $0.image = .init(named: "avatar")
            return $0.withoutAutoresizingMask
        }(CircleImageView())
        
        lazy var editButton: UIButton = {
            $0.setImage(Appearance.Images.channelProfileEditAvatar, for: .normal)
            return $0.withoutAutoresizingMask
        }(UIButton())
            
        lazy var displayNameLabel: UITextField = {
            $0.borderStyle = .none
            return $0.withoutAutoresizingMask
        }(UITextField())
            
        lazy var separatorView = UIView()
            .withoutAutoresizingMask
        
        var isEditing: Bool = false {
            didSet {
                updateUI()
            }
        }
        
        init() {
            super.init(frame: .zero)
            addArrangedSubview(imageView)
            addArrangedSubview(displayNameLabel)
            addSubview(separatorView)
            axis = .horizontal
            alignment = .center
            spacing = 8
            displayNameLabel.isEnabled = false
            imageView.widthAnchor.pin(to: imageView.heightAnchor)
            imageView.heightAnchor.pin(to: self.heightAnchor)
            displayNameLabel.centerYAnchor.pin(to: self.centerYAnchor)
            addSubview(editButton)
            editButton.centerXAnchor.pin(to: imageView.centerXAnchor)
            editButton.centerYAnchor.pin(to: imageView.centerYAnchor)
            editButton.widthAnchor.pin(to: imageView.widthAnchor)
            editButton.isHidden = true
            
            separatorView.pin(to: displayNameLabel, anchors: [.bottom(2), .leading, .trailing(-8)])
            separatorView.heightAnchor.pin(constant: 1)
            separatorView.isHidden = true
            separatorView.backgroundColor = .border
        }
        
        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func updateUI() {
            displayNameLabel.isEnabled = isEditing
            editButton.isHidden = !isEditing
            separatorView.isHidden = !isEditing
            displayNameLabel.becomeFirstResponder()
        }
    }
    
    class ActionView: UIView {
        
        class TitleView: UIStackView {
            
            lazy var iconView = UIImageView()
                .withoutAutoresizingMask
            
            lazy var titleLabel = UILabel()
                .withoutAutoresizingMask
            
            init() {
                super.init(frame: .zero)
                addArrangedSubview(iconView)
                addArrangedSubview(titleLabel)
                axis = .horizontal
                alignment = .center
                spacing = 8
            }
            
            required init(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
        }
        
        lazy var titleView = TitleView()
            .withoutAutoresizingMask
        
        lazy var `switch` = UISwitch()
            .withoutAutoresizingMask
        
        init() {
            super.init(frame: .zero)
            addSubview(titleView)
            addSubview(`switch`)
            titleView.pin(to: self, anchors: [.top, .leading, .bottom])
            `switch`.pin(to: self, anchors: [.top, .trailing, .bottom])
        }
        
        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

extension UserProfileViewController {
    
    private func showCaptureAlert() {
        _ = profileView.displayNameLabel.resignFirstResponder()
        var types = [Router<UserProfileViewController>.CaptureType.camera, .photoLibrary]
        if userAvatarImage != nil {
            types.append(.delete)
        }
        router.showCaptureAlert(types: types,
                                sourceView: profileView.imageView) { [unowned self] capture in
            switch capture {
            case .camera:
                router.showCamera(mediaTypes: [.image]) { [unowned self] picked in
                    var image = picked?.thumbnail
                    if image == nil, let path = picked?.url.path {
                        image = UIImage(contentsOfFile: path)
                    }
                    guard let image = image else { return }
                    router.editImage(image) { [unowned self] edited in
                        userAvatarImage = edited
                        isDeleted = false
                        profileView.imageView.image = userAvatarImage
                        profileView.displayNameLabel.becomeFirstResponder()
                    }
                }
            case .photoLibrary:
                router.selectPhoto { [unowned self] picked in
                    var image = picked?.thumbnail
                    if image == nil, let path = picked?.url.path {
                        image = UIImage(contentsOfFile: path)
                    }
                    guard let image = image else { return }
                    router.editImage(image) { [unowned self] edited in
                        userAvatarImage = edited
                        isDeleted = false
                        profileView.imageView.image = userAvatarImage
                        profileView.displayNameLabel.becomeFirstResponder()
                    }
                }
            case .delete:
                userAvatarImage = nil
                isDeleted = true
                profileView.imageView.image = .init(named: "avatar")
                profileView.displayNameLabel.becomeFirstResponder()
            default:
                break
            }
        }
    }
}

