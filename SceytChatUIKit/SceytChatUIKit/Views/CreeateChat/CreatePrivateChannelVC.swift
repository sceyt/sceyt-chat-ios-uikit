//
//  CreatePrivateChannelVC.swift
//  SceytChatUIKit
//

import UIKit

open class CreatePrivateChannelVC: ViewController,
                                    UITableViewDelegate,
                                    UITableViewDataSource,
                                    UITextViewDelegate {
    
    
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
        tableView.register(CreateChannelUserCell.self)
        tableView.register(CreateChannelHeaderView.self,
                           forHeaderFooterViewReuseIdentifier: CreateChannelHeaderView.reuseId)
        
        profileView.subjectField.onEditingDidEndOnExit { [unowned self] in
            profileView.descriptionField.becomeFirstResponder()
        }
        profileView.subjectField.onEditingChanged { [unowned self] in
            navigationItem.rightBarButtonItem?.isEnabled = !(profileView.subjectField.text ?? "").isEmpty
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
    }
    
    override open func setupLayout() {
        super.setupLayout()
        view.addSubview(profileView)
        view.addSubview(tableView)
        profileView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .top, .trailing])
        tableView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .bottom, .trailing])
        tableView.topAnchor.pin(to: profileView.bottomAnchor)
//        profileView.heightAnchor.pin(constant: 0)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        navigationController?.navigationBar.isTranslucent = true
        definesPresentationContext = true
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.textBlack]
        
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = .white
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
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
        viewModel
            .create(subject: profileView.subjectField.text ?? "",
                    metadata: profileView.descriptionField.text,
                    image: channelAvatarImage)
    }
    
    func onEvent( _ event: CreatePrivateChannelVM.Event) {
        switch event {
        case .createdChannel(let channel):
            router.dismiss(animated: false)
            ChannelListRouter.findAndShowChannel(id: channel.id)
        case .createChannelError(let error):
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
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        Sections.allCases.count
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfUser
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Sections(rawValue: indexPath.section)  {
        case .user:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: CreateChannelUserCell.self)
            cell.selectionStyle = .none
            if let user = viewModel.user(at: indexPath) {
                cell.data = user
            }
            return cell
        default:
            fatalError("Unchecked section")
        }
    }
    
    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 32
    }
    
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier:
                                                                CreateChannelHeaderView.reuseId) as! CreateChannelHeaderView
        view.titleLabel.text = L10n.Channel.Private.sectionTitle
        return view
    }
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if profileView.canResignFirstResponder,
            scrollView == tableView {
            _ = profileView.resignFirstResponder()
        }
    }
    
    @objc
    open func textViewDidChange(_ textView: UITextView) {
        let font = textView.font ?? Fonts.regular.withSize(16)
        let numberOfLines = textView.contentSize.height/font.lineHeight
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
