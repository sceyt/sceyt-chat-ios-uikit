//
//  CreatePublicChannelVC.swift
//  SceytChatUIKit
//

import UIKit

open class CreatePublicChannelVC: ViewController, UITextViewDelegate {
    
    open var viewModel: CreatePublicChannelVM!
    open lazy var router = CreatePublicChannelRouter(rootVC: self)
    
    open var channelAvatarImage: UIImage?
    
    open lazy var profileView = CreatePublicChannelProfileView()
        .withoutAutoresizingMask
    
    private var textViewHeightConstraint: NSLayoutConstraint?
    private var profileViewTopConstraint: NSLayoutConstraint!
    
    override open func setup() {
        super.setup()
        
        title = L10n.Channel.New.createPublic
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.Nav.Bar.create,
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(nextAction(_:)))
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        
        profileView.subjectField.onEditingDidEndOnExit { [unowned self] in
            profileView.descriptionField.becomeFirstResponder()
        }
        profileView.subjectField.onEditingChanged { [unowned self] in
            enableNextButtonIfNeeded()
        }
        profileView.uriField.textField.onEditingChanged { [unowned self] in
            viewModel.check(uri: profileView.uriField.text ?? "")
        }
        profileView.descriptionField.delegate = self
        
        profileView.avatarButton.onTouchUpInside { [unowned self] in
            showCaptureAlert()
        }
        
        viewModel.$event
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        
        KeyboardObserver()
            .willShow {[weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }.willHide {[weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }
    }
    
    override open func setupLayout() {
        super.setupLayout()
        view.addSubview(profileView)
        profileViewTopConstraint =
        profileView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading(), .top(), .trailing()])[1]
    }
    
    open func onEvent( _ event: CreatePublicChannelVM.Event) {
        profileView.hideError()
        switch event {
        case .createdChannel(let channel):
            router.showAddMember(channel: channel)
        case .error(let error):
            router.showAlert(error: error)
        case let .invalidURI(error):
            profileView.showError(error.localizedDescription)
            enableNextButtonIfNeeded()
        case .validURI:
            profileView.showSuccess(L10n.Channel.Create.Uri.Error.success)
            enableNextButtonIfNeeded()
        }
    }
    
    @objc
    func nextAction(_ sender: UIBarButtonItem) {
        guard let subject = profileView.subjectField.text,
              let uri = profileView.uriField.text
        else { return}
        viewModel
            .create(
                uri: uri,
                subject: subject,
                metadata: profileView.descriptionField.text,
                image: channelAvatarImage
            )
    }
    
    func enableNextButtonIfNeeded() {
        guard viewModel.lastValidURI?.1 == profileView.uriField.text
        else { return }
        
        func lastCheck() -> Bool {
            guard let last = viewModel.lastValidURI
            else { return false }
            return last.0 == true && last.1 == profileView.uriField.text
        }
        
        navigationItem.rightBarButtonItem?.isEnabled =
        !(profileView.subjectField.text ?? "").isEmpty &&
        !(profileView.uriField.text ?? "").isEmpty &&
        lastCheck()
    }
    
    private func showCaptureAlert() {
        _ = profileView.resignFirstResponder()
        var types = [CreatePublicChannelRouter.CaptureType.camera, .photoLibrary]
        if channelAvatarImage != nil {
            types.append(.delete)
        }
        router.showCaptureAlert(types: types,
                                sourceView: profileView.avatarButton) { [unowned self] capture in
            switch capture {
            case .camera:
                router.showCamera(mediaTypes: [.image]) { [unowned self] picked in
                    var image = picked?.thumbnail
                    if image == nil, let path = picked?.url.path {
                        image = UIImage(contentsOfFile: path)
                    }
                    guard let image = image else { return }
                    router.editImage(image) { [unowned self] edited in
                        guard let edited = edited else { return }
                        channelAvatarImage = edited
                        profileView.avatarButton.setImage(channelAvatarImage, for: .normal)
                    }
                }
            case .photoLibrary:
                router.selectPhoto(mediaTypes: [.image]) { [unowned self] picked in
                    var image = picked?.thumbnail
                    if image == nil, let path = picked?.url.path {
                        image = UIImage(contentsOfFile: path)
                    }
                    guard let image = image else { return }
                    router.editImage(image) { [unowned self] edited in
                        guard let edited = edited else { return }
                        channelAvatarImage = edited
                        profileView.avatarButton.setImage(channelAvatarImage, for: .normal)
                    }
                }
            case .delete:
                channelAvatarImage = nil
                profileView.avatarButton.setImage(.editAvatar, for: .normal)
            default:
                break
            }
        }
    }
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        _ = profileView.resignFirstResponder()
    }
    
    func adjustTableViewToKeyboard(notification: Notification) {
//        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        
//        let keyboardScreenEndFrame = keyboardValue.cgRectValue
//        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber
        var changed = false
        if notification.name == UIResponder.keyboardWillHideNotification {
            profileViewTopConstraint.constant = 0
            changed = true
        } else if notification.name == UIResponder.keyboardWillShowNotification {
            profileViewTopConstraint.constant = -20
            changed = true
        }
        if changed {
            UIView.animate(
                withDuration: duration ?? 0,
                delay: 0,
                options: .init(rawValue: curve?.uintValue ?? 0),
                animations: {
                    self.view?.layoutIfNeeded()
                }, completion: { finished in
                })
        }
    }
}
