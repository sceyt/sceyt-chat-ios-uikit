//
//  LoginViewController.swift
//  SceytDemoApp
//
//  Created by Hovsep Keropyan on 16.01.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChatUIKit

class LoginViewController: UIViewController {
    
    lazy var titleLabel: UILabel = {
        $0.font = Appearance.Fonts.bold.withSize(24)
        $0.text = "Getting Started"
        return $0.withoutAutoresizingMask
    }(UILabel())
    
    lazy var subtitleLabel: UILabel = {
        $0.font = Appearance.Fonts.regular.withSize(16)
        $0.text = "Just enter your username, clock connect button and start"
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(UILabel())
    
    lazy var usernameTextField: UITextField = {
        $0.font = Appearance.Fonts.regular.withSize(16)
        $0.placeholder = "Username"
        $0.borderStyle = .none
        return $0.withoutAutoresizingMask
    }(UITextField())
    
    lazy var displayNameTextField: UITextField = {
        $0.font = Appearance.Fonts.regular.withSize(16)
        $0.placeholder = "Display name"
        $0.borderStyle = .none
        return $0.withoutAutoresizingMask
    }(UITextField())
    
    lazy var connectButton: UIButton = {
        $0.setTitle("CONNECT", for: .normal)
        $0.setTitleColor(.white, for: .normal)
        
        $0.setBackgroundImage(ImageBuilder.build(fillColor: UIColor.accent), for: .normal)
        $0.setBackgroundImage(ImageBuilder.build(fillColor: UIColor.accent.withAlphaComponent(0.5)), for: .disabled)
        $0.layer.cornerRadius = 8
        $0.layer.masksToBounds = true
        return $0.withoutAutoresizingMask
    }(UIButton(type: .system))
    
    lazy var stackView: UIStackView = {
        $0.axis = .vertical
        $0.spacing = 15
        return $0.withoutAutoresizingMask
    }(UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, usernameTextField, displayNameTextField, connectButton]))
        
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        setupLayout()
        connectButton.isEnabled = false
        connectButton.addTarget(self, action: #selector(connect(_:)), for: .touchUpInside)
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChangeNotification(_:)), name: UITextField.textDidChangeNotification, object: usernameTextField)
    }
    
    private func setupLayout() {
        view.addSubview(stackView)
        stackView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading(16), .trailing(-16), .top(64)])
        usernameTextField.heightAnchor.pin(constant: 50)
        displayNameTextField.heightAnchor.pin(constant: 50)
        addSeparatorView(to: usernameTextField)
        addSeparatorView(to: displayNameTextField)
        
        connectButton.heightAnchor.pin(constant: 50)
    }
    
    private func addSeparatorView(to textField: UITextField) {
        let separatorView = UIView().withoutAutoresizingMask
        separatorView.backgroundColor = .border
        textField.addSubview(separatorView)
        separatorView.pin(to: textField, anchors: [.bottom, .leading, .trailing])
        separatorView.heightAnchor.pin(constant: 1)
    }
    
    @objc
    private func connect(_ sender: UIButton) {
        guard let username = usernameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                !username.isEmpty
        else { return }
        hud.isLoading = true
        ConnectionService.shared.connect(username: username) { [weak self] error in
            hud.isLoading = false
            guard let self
            else { return }
            self.dismissSheet()
            if let error {
                self.showAlert(error: error)
                return
            }
            hud.isLoading = true
            self.updateProfile {[weak self] in
                hud.isLoading = false
                self?.dismiss(animated: true)
            }
            
        }
    }
    
    @objc
    private func textDidChangeNotification(_ notification: Notification) {
        connectButton.isEnabled =  !(usernameTextField.text ?? "").isEmpty
    }
    
    private func updateProfile(completion: @escaping () -> Void) {
        guard let displayName = displayNameTextField.text, !displayName.isEmpty
        else {
            completion()
            return
        }
        UserProfile.update(displayName: displayName) { _ in
            completion()
        }
    }
    
}
