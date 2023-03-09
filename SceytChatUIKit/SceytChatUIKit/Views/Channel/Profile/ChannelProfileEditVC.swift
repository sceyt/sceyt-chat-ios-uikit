//
//  ChannelProfileEditVC.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelProfileEditVC: ViewController,
                                 UITableViewDelegate,
                                 UITableViewDataSource,
                                 UITextViewDelegate {

    open var profileViewModel: ChannelProfileEditVM!
    
    open lazy var tableView = UITableView(frame: .zero, style: .insetGrouped)
        .withoutAutoresizingMask
        .rowAutomaticDimension
    
    override open func setup() {
        super.setup()
        tableView.register(Components.channelProfileEditAvatarCell.self)
        tableView.register(Components.channelProfileEditFieldCell.self)
        tableView.register(Components.channelProfileEditURICell.self)
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.sectionHeaderHeight = 18
        tableView.sectionFooterHeight = 0
        
        KeyboardObserver()
            .willShow {[weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }.willHide {[weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }
    }
    
    open override func setupLayout() {
        super.setupLayout()
        view.addSubview(tableView)
        tableView.pin(to: view)
    }
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        if profileViewModel.canShowURI {
            return Sections.allCases.count
        }
        return Sections.allCases.count - 1
    }
    
    open func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        Sections(rawValue: section)?.numberOfRows ?? 0
    }
    
    open func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        
        let _cell: UITableViewCell
        switch Sections(rawValue: indexPath.section) {
        case .avatar:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileEditAvatarCell.self)
            cell.selectionStyle = .none
            cell.data = profileViewModel.channel
            _cell = cell
        case .fields:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileEditFieldCell.self)
            cell.selectionStyle = .none
            switch indexPath.row {
            case 0:
                cell.textView.text = profileViewModel.channel.subject
            case 1:
                cell.textView.text = profileViewModel.channel.decodedMetadata?.description ?? profileViewModel.channel.metadata
                cell.textView.delegate = self
            default:
                break
            }
            
            _cell = cell
        case .uri:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileEditURICell.self)
            cell.selectionStyle = .none
            cell.textField.text = Config.channelURIPrefix + (profileViewModel.channel.uri ?? "")
            _cell = cell
        case .none:
            _cell = UITableViewCell()
        }
        return _cell
    }
    
    open  func textViewDidChange(_ textView: UITextView) {
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    
    open func adjustTableViewToKeyboard(notification: Notification) {
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
}


extension ChannelProfileEditVC {
    
    public enum Sections: Int, CaseIterable {
        case avatar
        case fields
        case uri
        
        public var numberOfRows: Int {
            switch self {
            case .avatar:
                return 1
            case .fields:
                return 2
            case .uri:
                return 1
            }
        }
    }
}
