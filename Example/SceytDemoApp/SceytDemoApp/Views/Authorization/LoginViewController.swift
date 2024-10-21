//
//  LoginViewController.swift
//  SceytDemoApp
//
//  Created by Hovsep Keropyan on 16.01.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChatUIKit

class LoginViewController: ViewController {
    
    // MARK: - Properties
    private var debouncer = Debouncer(delay: 0.2)
    private var username: String? = nil {
        didSet {
            updateConnectButton()
        }
    }
    private var task: URLSessionDataTask? = nil
    
    // MARK: - Views
    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView().withoutAutoresizingMask
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    
    lazy var titleLabel: UILabel = {
        $0.font = Appearance.Fonts.semiBold.withSize(24)
        $0.textColor = .primaryText.light
        $0.text = "Create Account"
        return $0.withoutAutoresizingMask
    }(UILabel())
    
    lazy var subtitleLabel: UILabel = {
        $0.font = Appearance.Fonts.regular.withSize(16)
        $0.textColor = .secondaryText.light
        $0.text = "Create an account by completing these details."
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(UILabel())
    
    lazy var firstNameTextField: UITextField = {
        $0.font = Appearance.Fonts.regular.withSize(16)
        $0.textColor = .primaryText.light
        $0.textContentType = .givenName
        $0.borderStyle = .none
        $0.backgroundColor = .surface1.light
        $0.layer.cornerRadius = 12
        $0.layer.cornerCurve = .continuous
        
        $0.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        $0.leftViewMode = .always
        $0.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        $0.rightViewMode = .always
        
        $0.attributedPlaceholder = NSAttributedString(
            string: "First name",
            attributes: [
                .foregroundColor: UIColor.secondaryText.light
            ]
        )
        return $0.withoutAutoresizingMask
    }(UITextField())
    
    lazy var lastNameTextField: UITextField = {
        $0.font = Appearance.Fonts.regular.withSize(16)
        $0.textColor = .primaryText.light
        $0.textContentType = .familyName
        $0.borderStyle = .none
        $0.backgroundColor = .surface1.light
        $0.layer.cornerRadius = 12
        $0.layer.cornerCurve = .continuous
        
        $0.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        $0.leftViewMode = .always
        $0.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        $0.rightViewMode = .always
        
        $0.attributedPlaceholder = NSAttributedString(
            string: "Last name",
            attributes: [.foregroundColor: UIColor.secondaryText.light]
        )
        return $0.withoutAutoresizingMask
    }(UITextField())
    
    lazy var usernameTextField: UITextField = {
        $0.font = Appearance.Fonts.regular.withSize(16)
        $0.textColor = .primaryText.light
        $0.autocapitalizationType = .none
        $0.autocorrectionType = .no
        $0.spellCheckingType = .no
        if #available(iOS 17.0, *) {
            $0.inlinePredictionType = .no
        }
        $0.borderStyle = .none
        $0.backgroundColor = .surface1.light
        $0.layer.cornerRadius = 12
        $0.layer.cornerCurve = .continuous
        
        let label = UILabel()
        label.text = "@"
        label.font = Appearance.Fonts.regular.withSize(16)
        label.textColor = .primaryText.light
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0)).withoutAutoresizingMask
        view.resize(anchors: [.width(16)])
        let stackView = UIStackView(arrangedSubviews: [view, label])
        stackView.axis = .horizontal
        stackView.alignment = .leading
        $0.leftView = stackView
        $0.leftViewMode = .always
        
        $0.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        $0.rightViewMode = .always
        
        $0.attributedPlaceholder = NSAttributedString(
            string: "username",
            attributes: [.foregroundColor: UIColor.secondaryText.light]
        )
        return $0.withoutAutoresizingMask
    }(UITextField())
    
    lazy var errorLabel: UILabel = {
        $0.text = "Username is already taken."
        $0.font = Appearance.Fonts.regular.withSize(12)
        $0.textColor = .stateWarning
        $0.isHidden = true
        return $0.withoutAutoresizingMask
    }(UILabel())
    
    lazy var subTitleLabel: UILabel = {
        $0.font = Appearance.Fonts.regular.withSize(13)
        $0.textColor = .secondaryText.light
        $0.attributedText = UsernameValidation.attributedDescription
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(UILabel())
    
    lazy var connectButton: UIButton = {
        $0.setAttributedTitle(
            NSAttributedString(
                string: "Connect",
                attributes: [
                    .font: UIFont.systemFont(
                        ofSize: .init(17),
                        weight: .semibold
                    ),
                    .foregroundColor: UIColor.onPrimary
                ]
            ),
            for: .normal
        )
        $0.setBackgroundImage(ImageBuilder.build(fillColor: UIColor.accent.light), for: .normal)
        $0.setBackgroundImage(ImageBuilder.build(fillColor: UIColor.accent.light.withAlphaComponent(0.5)), for: .disabled)
        $0.layer.cornerRadius = 8
        $0.layer.masksToBounds = true
        return $0.withoutAutoresizingMask
    }(UIButton(type: .system))
    
    lazy var stackView: UIStackView = {
        $0.axis = .vertical
        $0.spacing = 15
        return $0.withoutAutoresizingMask
    }(UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, firstNameTextField, lastNameTextField, usernameTextField, errorLabel, subTitleLabel, connectButton]))
    
    // MARK: - Lifecycle
    override func setupAppearance() {
        super.setupAppearance()
        view.backgroundColor = .background.light
        connectButton.isEnabled = false
    }
    
    override func setupLayout() {
        super.setupLayout()
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        
        firstNameTextField.heightAnchor.pin(constant: 50)
        lastNameTextField.heightAnchor.pin(constant: 50)
        usernameTextField.heightAnchor.pin(constant: 50)
        connectButton.heightAnchor.pin(constant: 44)
    }
    
    override func setupDone() {
        super.setupDone()
        connectButton.addTarget(self, action: #selector(connect(_:)), for: .touchUpInside)
        firstNameTextField.delegate = self
        lastNameTextField.delegate = self
        usernameTextField.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateConnectButton), name: UITextField.textDidChangeNotification, object: firstNameTextField)
        NotificationCenter.default.addObserver(self, selector: #selector(updateConnectButton), name: UITextField.textDidChangeNotification, object: lastNameTextField)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        view.endEditing(true)
    }
    
    // MARK: - Keyboard Handling
    @objc
    private func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }
        let keyboardFrame = keyboardFrameValue.cgRectValue
        let keyboardHeight = keyboardFrame.height - view.safeAreaInsets.bottom
        scrollView.contentInset.bottom = keyboardHeight
        scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight
    }
    
    @objc
    private func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }
    
    // MARK: - Actions
    @objc
    private func connect(_ sender: UIButton) {
        guard let username else { return }
        loader.isLoading = true
        ConnectionService.shared.connect(username: username) { [weak self] error in
            loader.isLoading = false
            guard let self else { return }
            self.dismissSheet()
            if let error {
                self.showAlert(error: error)
                return
            }
            loader.isLoading = true
            self.updateProfile {
                loader.isLoading = false
                AppCoordinator.shared.showMainFlow()
            }
        }
    }
    
    private func updateProfile(completion: @escaping () -> Void) {
        guard let firstName = firstNameTextField.text,
              let lastName = lastNameTextField.text,
              let username else {
            completion()
            return
        }
        UserProfile.update(firstName: firstName,
                           lastName: lastName,
                           username: username) { _ in
            completion()
        }
    }
}

extension LoginViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        defer {
            updateConnectButton()
        }
        
        switch textField {
        case usernameTextField:
            let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
            let characterSet = CharacterSet(charactersIn: string.lowercased())
            
            if !allowedCharacters.isSuperset(of: characterSet) {
                return false
            }
            
            let currentText = textField.text ?? ""
            guard let stringRange = Range(range, in: currentText) else {
                return false
            }
            let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
            
            if updatedText.count > 20 {
                return false
            }
            
            debouncer.debounce { [weak self] in
                guard let self else { return }
                checkUsername(updatedText)
            }
            self.username = nil
            return true
        default:
            return true
        }
    }
}

extension LoginViewController {
    
    private func checkUsername(_ username: String) {
        self.username = nil
        
        if let validation = UsernameValidation.validateUsername(username) {
            handle(validation: validation)
            return
        }
        task?.cancel()
        
        task = RequestManager.checkUsernameAvailability(username: username) { [weak self] isAvailable in
            guard let self = self else { return }
            
            task = nil
            
            DispatchQueue.main.async {
                self.username = isAvailable ?? false ? username : nil
                self.updateErrorLabel(isAvailable: isAvailable)
            }
        }
    }
    
    private func updateErrorLabel(isAvailable: Bool?) {
        errorLabel.isHidden = false
        errorLabel.textColor = isAvailable ?? false ? .stateSuccess : .stateWarning
        if let isAvailable {
            errorLabel.text = isAvailable ? "Username is available. You can use it." : "Username is already taken."
        } else {
            errorLabel.text = "Something went wrong. Please try again."
        }
    }
    
    private func handle(validation: UsernameValidation) {
        errorLabel.isHidden = false
        errorLabel.textColor = .stateWarning
        errorLabel.text = validation.description.description
    }
    
    @objc
    private func updateConnectButton() {
        let isFirstNameEmpty = (firstNameTextField.text ?? "").isEmpty
        let isLastNameEmpty = (lastNameTextField.text ?? "").isEmpty
        let isUsernameValid = username != nil
        connectButton.isEnabled = !isFirstNameEmpty && !isLastNameEmpty && isUsernameValid && (task == nil)
    }
}
