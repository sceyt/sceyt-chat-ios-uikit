//
//  CreatePrivateChannelVC.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class CreatePrivateChannelVC: ViewController,
    UITableViewDelegate, UITableViewDataSource,
    UITextViewDelegate
{
    open var viewModel: CreatePrivateChannelVM!
    open lazy var router = CreatePrivateChannelRouter(rootVC: self)
    
    open var channelAvatarImage: UIImage?
    
    open lazy var tableView: UITableView = {
        $0.delegate = self
        $0.dataSource = self
        $0.separatorStyle = .none
        $0.allowsMultipleSelection = true
        return $0.withoutAutoresizingMask
    }(UITableView())
    
    lazy var profileView = CreatePrivateChannelProfileView()
        .withoutAutoresizingMask
    
    var textViewHeightConstraint: NSLayoutConstraint?
    
    override open func setup() {
        super.setup()
        title = L10n.Channel.New.createPrivate
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.Nav.Bar.create,
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(createAction(_:)))
        navigationItem.rightBarButtonItem?.isEnabled = false
        tableView.register(Components.createChannelUserCell.self)
        tableView.register(Components.createChannelHeaderView.self)
        
        profileView.subjectField.publisher(for: .editingDidEndOnExit).sink { [unowned self] _ in
            profileView.descriptionField.becomeFirstResponder()
        }.store(in: &subscriptions)
        profileView.subjectField.publisher(for: .editingChanged).sink { [unowned self] _ in
            navigationItem.rightBarButtonItem?.isEnabled = !(profileView.subjectField.text ?? "").isEmpty
        }.store(in: &subscriptions)
        profileView.descriptionField.delegate = self
        
        profileView.avatarButton.publisher(for: .touchUpInside).sink { [unowned self] _ in
            showCaptureAlert()
        }.store(in: &subscriptions)
        
        viewModel.$event
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
    }
    
    override open func setupLayout() {
        super.setupLayout()
        view.addSubview(profileView)
        view.addSubview(tableView)
        profileView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .top, .trailing])
        tableView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .bottom, .trailing])
        tableView.topAnchor.pin(to: profileView.bottomAnchor)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        definesPresentationContext = true
        
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = .clear
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        
        view.backgroundColor = appearance.backgroundColor
    }
    
    @objc
    open func cancelAction(_ sender: UIBarButtonItem) {
        router.dismiss()
    }
    
    @objc
    open func createAction(_ sender: UIBarButtonItem) {
        create()
    }
    
    private func create() {
        hud.isLoading = true
        viewModel
            .create(subject: profileView.subjectField.text ?? "",
                    metadata: profileView.descriptionField.text,
                    image: channelAvatarImage)
    }
    
    func onEvent(_ event: CreatePrivateChannelVM.Event) {
        switch event {
        case .createdChannel(let channel):
            hud.isLoading = false
            router.showChannel(channel)
        case .createChannelError(let error):
            hud.isLoading = false
            router.showAlert(error: error)
        }
    }
    
    private func showCaptureAlert() {
        _ = profileView.resignFirstResponder()
        var types = [CreatePrivateChannelRouter.CaptureType.camera, .photoLibrary]
        if channelAvatarImage != nil {
            types.append(.delete)
        }
        router.showCaptureAlert(types: types,
                                sourceView: profileView.avatarButton)
        { [unowned self] capture in
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
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        Sections.allCases.count
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfUser
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Sections(rawValue: indexPath.section) {
        case .user:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.createChannelUserCell.self)
            cell.selectionStyle = .none
            if let user = viewModel.user(at: indexPath) {
                cell.userData = user
            }
            return cell
        default:
            fatalError("Unchecked section")
        }
    }
    
    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        Components.createChannelHeaderView.Layouts.height
    }
    
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        tableView.dequeueReusableHeaderFooterView(Components.createChannelHeaderView.self)
    }
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if profileView.canResignFirstResponder,
           scrollView == tableView
        {
            _ = profileView.resignFirstResponder()
        }
    }
    
    @objc
    open func textViewDidChange(_ textView: UITextView) {
        let font = textView.font ?? Fonts.regular.withSize(16)
        let numberOfLines = textView.contentSize.height / font.lineHeight
        if Int(numberOfLines) > 4 {
            textView.isScrollEnabled = true
            if textViewHeightConstraint == nil {
                textViewHeightConstraint = textView.heightAnchor.pin(constant: textView.frame.height)
            }
        } else {
            if let textViewHeightConstraint = textViewHeightConstraint {
                textView.removeConstraint(textViewHeightConstraint)
                self.textViewHeightConstraint = nil
                textView.isScrollEnabled = false
                let text = textView.text
                textView.text = ""
                textView.text = text
            }
        }
        textView.layoutIfNeeded()
    }
}

extension CreatePrivateChannelVC {
    enum Sections: Int, CaseIterable {
        case user
    }
}
