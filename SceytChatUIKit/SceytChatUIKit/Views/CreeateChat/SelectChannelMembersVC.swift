//
//  SelectChannelMembersVC.swift
//  SceytChatUIKit
//

import UIKit

open class SelectChannelMembersVC: ViewController,
                                    UITableViewDelegate,
                                    UITableViewDataSource {
    
    open var selectMemberViewModel: SelectChannelMembersVM!
    open lazy var router = SelectChannelMembersRouter(rootVC: self)
    
    open lazy var tableView = UITableView()
        .withoutAutoresizingMask
     
    
    open lazy var selectedUserListView = SelectedUserListView()
        .withoutAutoresizingMask
    
    private let selectedUserListViewHeight = CGFloat(108)
    private var selectedUserListViewHeightConstraint: NSLayoutConstraint!
    
    override open func setup() {
        super.setup()
        title = L10n.Channel.New.createPrivate
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.allowsMultipleSelection = true
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.Nav.Bar.next,
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(nextAction(_:)))
        navigationItem.rightBarButtonItem?.isEnabled = false
        tableView.register(CreateChannelUserCell.self)
        tableView.register(CreateChannelHeaderView.self,
                           forHeaderFooterViewReuseIdentifier: CreateChannelHeaderView.reuseId)
//        createSearchController()
        navigationItem.hidesSearchBarWhenScrolling = false
        KeyboardObserver()
            .willShow {[weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }.willHide {[weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }
        selectMemberViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        
        selectedUserListView.$removeContact
            .compactMap { $0 }
            .sink { [weak self] in
                self?.selectMemberViewModel.deselect(user: $0)
                self?.deselectRowFor(user: $0)
            }.store(in: &subscriptions)
        
        
    }
    
    override open func setupLayout() {
        super.setupLayout()
        view.addSubview(selectedUserListView)
        view.addSubview(tableView)
        selectedUserListView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading(), .top(), .trailing()])
        tableView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading(), .bottom(), .trailing()])
        tableView.topAnchor.pin(to: selectedUserListView.bottomAnchor)
        selectedUserListViewHeightConstraint = selectedUserListView.heightAnchor.pin(constant: 0)
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
    
    open override func setupDone() {
        super.setupDone()
        selectMemberViewModel.loadNextPage()
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
    
    func onEvent( _ event: SelectChannelMembersVM.Event) {
        switch event {
        case .reload:
            tableView.reloadData()
        case let .select(user: user, isSelected: isSelected):
            if isSelected {
                if selectedUserListViewHeightConstraint.constant == 0 {
                    selectedUserListViewHeightConstraint.constant = selectedUserListViewHeight
                    view.setNeedsLayout()
                    UIView.animate(withDuration: 0.25) {
                        self.view.layoutIfNeeded()
                    } completion: { _ in
                        self.selectedUserListView.add(user: user)
                    }
                } else {
                    selectedUserListView.add(user: user)
                }

            } else {
                selectedUserListView.remove(user: user)
                if selectedUserListViewHeightConstraint.constant == selectedUserListViewHeight,
                    selectMemberViewModel.selectedUsers.isEmpty {
                    selectedUserListViewHeightConstraint.constant = 0
                    view.setNeedsLayout()
                    UIView.animate(withDuration: 0.25) {
                        self.view.layoutIfNeeded()
                    }
                }
            }
            navigationItem.rightBarButtonItem?.isEnabled = !selectMemberViewModel.selectedUsers.isEmpty
            
        }
    }
    
    @objc
    open func closeAction(_ sender: UIBarButtonItem) {
        router.dismiss()
    }
    
    @objc
    open func nextAction(_ sender: UIBarButtonItem) {
        router.showCreatePrivateChannel()
    }
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        Sections.allCases.count
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return selectMemberViewModel.numberOfUser
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Sections(rawValue: indexPath.section)  {
        case .user:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: CreateChannelUserCell.self)
            cell.showCheckBox = true
            cell.selectionStyle = .none
            
            if let contact = selectMemberViewModel.user(at: indexPath) {
                cell.data = contact
            }
            return cell
        default:
            fatalError("Unchecked section")
        }
    }
    
    open func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if selectMemberViewModel.isSelect(at: indexPath) {
            DispatchQueue.main.async {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        }
    }
    
    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 32
    }
    
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier:
                                                                CreateChannelHeaderView.reuseId) as! CreateChannelHeaderView
        return view
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Sections(rawValue: indexPath.section)  {
        case .user:
            DispatchQueue.main.async {
                _ = self.selectMemberViewModel.select(at: indexPath)
            }
        default:
            fatalError("Unchecked section")
        }
    }
    
    open func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        switch Sections(rawValue: indexPath.section)  {
        case .user:
            DispatchQueue.main.async {
                _ = self.selectMemberViewModel.deselect(at: indexPath)
            }
        default:
            fatalError("Unchecked section")
        }
    }
}

private extension SelectChannelMembersVC {
    
    func deselectRowFor(user: ChatUser) {
        for indexPath in tableView.indexPathsForVisibleRows ?? [] {
            if let cell = tableView.cell(for: indexPath, cellType: CreateChannelUserCell.self),
               cell.data?.id == user.id {
                if let indexPathsForSelectedRows = tableView.indexPathsForSelectedRows,
                   indexPathsForSelectedRows.contains(indexPath) {
                    tableView.deselectRow(at: indexPath, animated: true)
                } else {
                    tableView.reloadRows(at: [indexPath], with: .none)
                }
            }
        }
    }
}

extension SelectChannelMembersVC {
    
    enum Sections: Int, CaseIterable {
        case user
    }
}
