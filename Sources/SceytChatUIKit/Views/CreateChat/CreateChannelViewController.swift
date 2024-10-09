//
//  CreateChannelViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit


open class CreateChannelViewController: ViewController, UITextViewDelegate {
    
    open var viewModel: CreatePublicChannelViewModel!
    open lazy var router = CreatePublicChannelRouter(rootViewController: self)
    
    open var channelAvatarImage: UIImage?
    
    open lazy var detailsView = Components.createChannelDetailsView.init()
        .withoutAutoresizingMask
    
    private var textViewHeightConstraint: NSLayoutConstraint?
    private var detailsViewTopConstraint: NSLayoutConstraint!
    
    override open func setup() {
        super.setup()
        
        title = L10n.Channel.New.createPublic
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.Nav.Bar.create,
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(nextAction(_:)))
        navigationItem.rightBarButtonItem?.isEnabled = false
        detailsView.avatarButton.setImage(.editAvatar, for: .normal)
        
        detailsView.subjectField.publisher(for: .editingDidEndOnExit).sink { [unowned self] _ in
            detailsView.descriptionField.becomeFirstResponder()
        }.store(in: &subscriptions)
        detailsView.subjectField.publisher(for: .editingChanged).sink { [unowned self] _ in
            enableNextButtonIfNeeded()
        }.store(in: &subscriptions)
        detailsView.uriField.textField.publisher(for: .editingChanged).sink { [unowned self] _ in
            viewModel.check(uri: detailsView.uriField.text ?? "")
        }.store(in: &subscriptions)
        detailsView.descriptionField.delegate = self
        
        detailsView.avatarButton.publisher(for: .touchUpInside).sink { [unowned self] _ in
            showCaptureAlert()
        }.store(in: &subscriptions)
        
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
        view.addSubview(detailsView)
        detailsViewTopConstraint =
        detailsView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading(), .top(), .trailing()])[1]
    }
    
    open func onEvent( _ event: CreatePublicChannelViewModel.Event) {
        detailsView.hideError()
        switch event {
        case .createdChannel(let channel):
            loader.isLoading = false
            router.showAddMember(channel: channel)
        case .error(let error):
            loader.isLoading = false
            router.showAlert(error: error)
        case let .invalidURI(error):
            detailsView.showError(error.localizedDescription)
            enableNextButtonIfNeeded()
        case .validURI:
            detailsView.showSuccess(L10n.Channel.Create.Uri.Error.success)
            enableNextButtonIfNeeded()
        }
    }
    
    @objc
    func nextAction(_ sender: UIBarButtonItem) {
        guard let subject = detailsView.subjectField.text,
              let uri = detailsView.uriField.text
        else { return}
        loader.isLoading = true
        viewModel
            .create(
                uri: uri,
                subject: subject,
                metadata: detailsView.descriptionField.text,
                image: channelAvatarImage
            )
    }
    
    func enableNextButtonIfNeeded() {
        guard viewModel.lastValidURI?.1 == detailsView.uriField.text
        else { return }
        
        func lastCheck() -> Bool {
            guard let last = viewModel.lastValidURI
            else { return false }
            return last.0 == true && last.1 == detailsView.uriField.text
        }
        
        navigationItem.rightBarButtonItem?.isEnabled =
        !(detailsView.subjectField.text ?? "").isEmpty &&
        !(detailsView.uriField.text ?? "").isEmpty &&
        lastCheck()
    }
    
    private func showCaptureAlert() {
        _ = detailsView.resignFirstResponder()
        var types = [CreatePublicChannelRouter.CaptureType.camera, .photoLibrary]
        if channelAvatarImage != nil {
            types.append(.delete)
        }
        router.showCaptureAlert(types: types,
                                sourceView: detailsView.avatarButton) { [unowned self] capture in
            switch capture {
            case .camera:
                router.showCamera(mediaTypes: [.image]) { [unowned self] picked in
                    var image = picked?.thumbnail
                    if image == nil, let path = picked?.url.path {
                        image = UIImage(contentsOfFile: path)
                    }
                    guard let image = image else { return }
                    router.editImage(image) { [unowned self] edited in
                        channelAvatarImage = edited
                        detailsView.avatarButton.setImage(channelAvatarImage, for: .normal)
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
                        channelAvatarImage = edited
                        detailsView.avatarButton.setImage(channelAvatarImage, for: .normal)
                    }
                }
            case .delete:
                channelAvatarImage = nil
                detailsView.avatarButton.setImage(.editAvatar, for: .normal)
            default:
                break
            }
        }
    }
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        _ = detailsView.resignFirstResponder()
    }
    
    func adjustTableViewToKeyboard(notification: Notification) {
        let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0
        let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
        var changed = false
        if notification.name == UIResponder.keyboardWillHideNotification {
            detailsViewTopConstraint.constant = 0
            changed = true
        } else if notification.name == UIResponder.keyboardWillShowNotification {
            let maxY = detailsView.frameRelativeToWindow().maxY
            if maxY > keyboardFrame.minY {
                detailsViewTopConstraint.constant = -(maxY - keyboardFrame.minY)
            }
            changed = true
        }
        if changed {
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: .init(rawValue: curve),
                animations: {
                    self.view?.layoutIfNeeded()
                })
        }
    }
}
