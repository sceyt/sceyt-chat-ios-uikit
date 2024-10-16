//
//  EditProfileViewController.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 15.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChatUIKit

class EditProfileViewController: ViewController {

    // MARK: - Properties
    lazy var router = Router(rootViewController: self)
    var editedAvatarImage: UIImage?
    var originalAvatarImage: UIImage?
    private var debouncer = Debouncer(delay: 0.2)
    private let user = ChatUser(user: SceytChatUIKit.shared.chatClient.user)
    private var username: String? = nil {
        didSet {
            updateConnectButton(forceDisable: username == nil)
        }
    }
        
    private var hasAvatar = false
    
    // MARK: - Views
    lazy var tableView: UITableView = {
        $0.delegate = self
        $0.dataSource = self
        $0.separatorStyle = .none
        if #available(iOS 15.0, *) {
            $0.sectionHeaderTopPadding = 0
        }
        return $0.withoutAutoresizingMask
    }(UITableView(frame: .zero, style: .insetGrouped))
    
    lazy var usernameTextField: UITextField = {
        $0.delegate = self
        $0.font = .systemFont(ofSize: .init(16), weight: .regular)
        $0.textColor = .primaryText
        $0.backgroundColor = .backgroundSections
        $0.autocapitalizationType = .none
        $0.autocorrectionType = .no
        $0.spellCheckingType = .no
        if #available(iOS 17.0, *) {
            $0.inlinePredictionType = .no
        }
        $0.borderStyle = .none
        $0.layer.cornerRadius = 12
        $0.layer.cornerCurve = .continuous
        
        let label = UILabel()
        label.text = "@"
        label.font = .systemFont(ofSize: .init(16), weight: .regular)
        label.textColor = .primaryText
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
            attributes: [.foregroundColor: UIColor.secondaryText]
        )
        $0.resize(anchors: [.height(50)])
        return $0.withoutAutoresizingMask
    }(UITextField())
    
    lazy var footerStackView: UIStackView = {
        $0.axis = .vertical
        $0.alignment = .leading
        $0.distribution = .fillProportionally
        $0.setCustomSpacing(8, after: errorLabel)
        return $0.withoutAutoresizingMask
    }(UIStackView(arrangedSubviews: [errorLabel, descriptionLabel]))
    
    lazy var errorLabel: UILabel = {
        $0.text = "Username is already taken."
        $0.font = .systemFont(ofSize: .init(12), weight: .regular)
        $0.textColor = .stateWarning
        $0.isHidden = true
        return $0.withoutAutoresizingMask
    }(UILabel())
    
    lazy var descriptionLabel: UILabel = {
        $0.font = .systemFont(ofSize: .init(16), weight: .regular)
        $0.textColor = .secondaryText
        $0.attributedText = UsernameValidation.attributedDescription
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(UILabel())
    
    // MARK: - Lifecycle
    override func setup() {
        super.setup()
        tableView.register(ProfileEditAvatarCell.self)
        tableView.register(ProfileEditNameCell.self)
        tableView.register(UITableViewCell.self)
        navigationItem.title = "Edit"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done",
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(doneAction(_:)))
        navigationItem.rightBarButtonItem?.isEnabled = false
    }
    
    override func setupLayout() {
        super.setupLayout()
        view.addSubview(tableView)
        tableView.pin(to: view)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        view.endEditing(true)
    }
    
    // MARK: - Actions
    @objc
    func doneAction(_ sender: UINavigationItem) {
        var editedFirstName: String?
        var editedLastName: String?
        
        if let cell = tableView.cellForRow(
            at: .init(row: 0, section: Sections.name.rawValue))
            as? ProfileEditNameCell
        {
            editedFirstName = cell.firstNameField.text
            editedLastName = cell.lastNameField.text
        }
        guard editedFirstName.isNotBlank else {
            router.showAlert(title: "First name cannot be empty")
            return
        }
        guard editedLastName.isNotBlank else {
            router.showAlert(title: "Last name cannot be empty")
            return
        }
        guard let username = username ?? user.username else {
            router.showAlert(title: "Username cannot be empty")
            return
        }
        editProfile(
            firstName: editedFirstName!,
            lastName: editedLastName!,
            username: username,
            editedAvatarImage: editedAvatarImage,
            originalAvatarImage: originalAvatarImage
        )
    }
    
    func editProfile(
        firstName: String,
        lastName: String,
        username: String,
        editedAvatarImage: UIImage?,
        originalAvatarImage: UIImage?
    ) {
        
        loader.isLoading = true
        let avatar = originalAvatarImage == editedAvatarImage ? nil : editedAvatarImage
        let deletedAvatar = originalAvatarImage != nil && editedAvatarImage == nil
        UserProfile.update(firstName: firstName,
                           lastName: lastName,
                           username: username,
                           avatarImage: avatar,
                           deleteAvatar: deletedAvatar) { [weak self] error in
            loader.isLoading = false
            guard let self
            else { return }
            if let error {
                self.showAlert(error: error)
            } else {
                navigationController?.popViewController(animated: true)
            }
        }
    }

    @objc
    private func avatarButtonTapped(_ sender: UIButton) {
        // Find the cell associated with the tapped button
        if let cell = sender.superview?.superview as? ProfileEditAvatarCell {
            showCaptureAlert(cell: cell)
        }
    }
    
    @objc
    private func showCaptureAlert(cell: ProfileEditAvatarCell) {
        var types: [Router<EditProfileViewController>.CaptureType] = [.camera, .photoLibrary]
        if hasAvatar {
            types.append(.delete)
        }
        view.endEditing(true)
        router.showCaptureAlert(types: types, sourceView: cell.avatarButton) { [unowned self] capture in
            switch capture {
            case .camera:
                router.showCamera(mediaTypes: [.image]) { [unowned self] picked in
                    var image = picked?.thumbnail
                    if image == nil, let path = picked?.url.path {
                        image = UIImage(contentsOfFile: path)
                    }
                    guard let image = image else { return }
                    router.editImage(image) { [unowned self] edited in
                        editedAvatarImage = edited
                        originalAvatarImage = image
                        hasAvatar = true
                        cell.avatarButton.image = edited
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
                        editedAvatarImage = edited
                        originalAvatarImage = image
                        hasAvatar = true
                        cell.avatarButton.image = edited
                    }
                }
            case .delete:
                editedAvatarImage = nil
                originalAvatarImage = nil
                hasAvatar = false
                cell.avatarButton.image = .channelProfileEditAvatar
            default:
                break
            }
        }
    }
}

extension EditProfileViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        Sections.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Sections(rawValue: section)?.numberOfRows ?? 0
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard Sections(rawValue: section) == .username else { return nil }
        let container = UIView()
        container.addSubview(footerStackView)
        footerStackView.pin(to: container, anchors: [.leading(0), .trailing(0), .top(12), .bottom(-12, .lessThanOrEqual)])
        return container
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard Sections(rawValue: section) == .username else { return 0 }
        return 100
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let section = Sections(rawValue: indexPath.section)!
        switch section {
        case .avatar:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: ProfileEditAvatarCell.self)
            
            _ = AvatarBuilder.loadAvatar(into: cell.avatarButton, for: user, defaultImage: .channelProfileEditAvatar, preferMemCache: false) { [weak self] image in
                self?.hasAvatar = image != nil
            }
            cell.selectionStyle = .none
            cell.avatarButton.addTarget(self, action: #selector(avatarButtonTapped(_:)), for: .touchUpInside)
            return cell
        case .name:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: ProfileEditNameCell.self)
            cell.firstNameField.placeholder = "First name"
            cell.lastNameField.placeholder = "Last name"
            cell.firstNameField.text = user.firstName
            cell.lastNameField.text = user.lastName
            cell.selectionStyle = .none
            cell.onTextFieldChange = { [weak self] textField in
                guard let self else { return }
                updateConnectButton()
            }
            return cell
        case .username:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: UITableViewCell.self)
            cell.addSubview(usernameTextField)
            usernameTextField.pin(to: cell)
            usernameTextField.text = user.username
            cell.selectionStyle = .none
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if Sections(rawValue: indexPath.section) == .username {
            usernameTextField.becomeFirstResponder()
            return
        }
        view.endEditing(true)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }
}

extension EditProfileViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
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

extension EditProfileViewController {
    
    private func checkUsername(_ username: String) {
        self.username = nil
        
        if let validation = UsernameValidation.validateUsername(username) {
            handle(validation: validation)
            return
        }
        
        RequestManager.checkUsernameAvailability(username: username) { [weak self] isAvailable in
            guard let self = self else { return }
            
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
    private func updateConnectButton(forceDisable: Bool = false) {
        var editedFirstName: String?
        var editedLastName: String?
        
        if let cell = tableView.cellForRow(at: .init(row: 0,
                                                     section: Sections.name.rawValue)) as? ProfileEditNameCell {
            editedFirstName = cell.firstNameField.text
            editedLastName = cell.lastNameField.text
        }
        
        let isFirstNameEmpty = (editedFirstName ?? "").isEmpty
        let isLastNameEmpty = (editedLastName ?? "").isEmpty
        
        let isUsernameValidAndChanged = (user.username ?? "").isEmpty ? username != nil : (username == nil ? false : user.username != username)

        let isFirstNameValidChanged = !isFirstNameEmpty && editedFirstName != user.firstName
        let isLastNameValidChanged = !isLastNameEmpty && editedLastName != user.lastName
        
        navigationItem.rightBarButtonItem?.isEnabled = forceDisable ? false : isFirstNameValidChanged || isLastNameValidChanged || isUsernameValidAndChanged
    }
}

extension EditProfileViewController {
    enum Sections: Int, CaseIterable {
        case avatar
        case name
        case username
        
        var numberOfRows: Int {
            1
        }
    }
}
