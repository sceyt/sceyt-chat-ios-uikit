//
//  NewChannelVC.swift
//  SceytChatUIKit
//

import UIKit

open class NewChannelVC: ViewController,
                            UITableViewDelegate,
                            UITableViewDataSource {
    
    open var viewModel: NewChannelVM!
    lazy var router = NewChannelRouter(rootVC: self)
    
    open lazy var tableView = TableView()
        .withoutAutoresizingMask
       
    lazy var createChatActionsView: CreateChatActionsView = {
        return $0.withoutAutoresizingMask
    }(CreateChatActionsView())
    
    override open func setup() {
        super.setup()
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: L10n.Nav.Bar.cancel,
                                                           style: .done,
                                                           target: self,
                                                           action: #selector(doneAction(_:)))
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(CreateChannelUserCell.self)
        tableView.register(CreateChannelHeaderView.self,
                           forHeaderFooterViewReuseIdentifier: CreateChannelHeaderView.reuseId)
        
        navigationItem.hidesSearchBarWhenScrolling = false
        KeyboardObserver()
            .willShow {[weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }.willHide {[weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }
        viewModel.$event
            .compactMap { $0 }
            .sink { [weak self] (event) in
                self?.onEvent(event)
            }.store(in: &subscriptions)
        
        createChatActionsView.groupView.onTouchUpInside { [unowned self] in
            router.showCreatePrivateChannel()
        }
        
        createChatActionsView.channelView.onTouchUpInside { [unowned self] in
            router.showCreatePublicChannel()
        }
    }
    
    override open func setupLayout() {
        super.setupLayout()
        view.addSubview(createChatActionsView)
        view.addSubview(tableView)
        
        
        createChatActionsView.resize(anchors: [.height(96)])
        createChatActionsView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading(), .top(), .trailing()])
        tableView.pin(to: view, anchors: [.leading(), .bottom(), .trailing()])
        tableView.topAnchor.pin(to: createChatActionsView.bottomAnchor)
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
        
        title = L10n.Channel.New.title
    }
    
    open override func setupDone() {
        super.setupDone()
        viewModel.loadNextPage()
    }
    
    func adjustTableViewToKeyboard(notification: Notification) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        
        let keyboardScreenEndFrame = keyboardValue.cgRectValue
        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)
        
        if notification.name == UIResponder.keyboardWillHideNotification {
            tableView.contentInset = .zero
        } else if notification.name == UIResponder.keyboardWillShowNotification {
            tableView.contentInset = .init(top: 0, left: 0, bottom: keyboardViewEndFrame.height - view.safeAreaInsets.bottom, right: 0)
        }
        tableView.scrollIndicatorInsets = tableView.contentInset
    }
    
    @objc
    func doneAction(_ sender: UIBarButtonItem) {
        router.dismiss()
    }
    
    func onEvent( _ event: NewChannelVM.Event) {
        switch event {
        case .reload:
            tableView.reloadData()
        case .createChannelError(let error):
            router.showAlert(error: error)
        case .createdChannel(let channel):
            router.showChannel(channel)
        }
    }
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        Sections.allCases.count
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfUser
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Sections(rawValue: indexPath.section)  {
        case .user:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: CreateChannelUserCell.self)
            if let user = viewModel.user(at: indexPath) {
                cell.data = user
            }
            return cell
        default:
            fatalError("Unchecked section")
        }
    }
    
    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        32
    }
    
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return tableView.dequeueReusableHeaderFooterView(withIdentifier:
                                                            CreateChannelHeaderView.reuseId) as! CreateChannelHeaderView
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row > viewModel.numberOfUser - 3 {
            viewModel.loadNextPage()
        }
        tableView.deselectRow(at: indexPath, animated: true)
        switch Sections(rawValue: indexPath.section) {
        case .user:
            viewModel.createDirectChannel(userAt: indexPath)
        default:
            fatalError("Unchecked section")
        }
    }
}

extension NewChannelVC {
    
    enum Sections: Int, CaseIterable {
        case user
    }
}
