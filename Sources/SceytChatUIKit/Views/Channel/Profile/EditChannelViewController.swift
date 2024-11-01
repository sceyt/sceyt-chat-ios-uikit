//
//  EditChannelViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class EditChannelViewController: ViewController,
    UITableViewDelegate,
    UITableViewDataSource
{
    open var profileViewModel: ChannelProfileEditViewModel!
    open lazy var router = ChannelProfileEditRouter(rootViewController: self)
    
    open lazy var tableView = UITableView(frame: .zero, style: .insetGrouped)
        .withoutAutoresizingMask
        .rowAutomaticDimension
    
    open lazy var errorLabel = ContentInsetLabel()
    
    override open func setup() {
        super.setup()
        
        title = L10n.Nav.Bar.edit
        
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.register(Components.channelEditAvatarCell.self)
        tableView.register(Components.channelEditTextFieldCell.self)
        tableView.register(Components.channelEditURICell.self)
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.sectionHeaderHeight = 24
        tableView.sectionFooterHeight = 0
        
        errorLabel.numberOfLines = 0
        
        navigationItem.rightBarButtonItem = .init(title: L10n.Nav.Bar.done,
                                                  style: .done,
                                                  cancellables: &subscriptions,
                                                  action: { [weak self] in self?.onDone() })
        
        profileViewModel.$isDoneEnabled.receive(on: DispatchQueue.main).sink { [weak self] in
            self?.navigationItem.rightBarButtonItem?.isEnabled = $0
        }.store(in: &subscriptions)
        
        KeyboardObserver()
            .willShow { [weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }.willHide { [weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }
        
        profileViewModel
            .event
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handle(event: event)
            }.store(in: &subscriptions)
    }
    
    open func handle(event: ChannelProfileEditViewModel.Event) {
        switch event {
        case .invalidURI(let error):
            tableView.performBatchUpdates { [weak self] in guard let self else { return }
                errorLabel.text = error.localizedDescription
                errorLabel.textColor = appearance.uriValidationAppearance.errorLabelAppearance.foregroundColor
                errorLabel.font = appearance.uriValidationAppearance.errorLabelAppearance.font
                errorLabel.sizeToFit()
                tableView.tableFooterView = errorLabel
            }
        case .validURI:
            tableView.performBatchUpdates { [weak self] in guard let self else { return }
                errorLabel.text = profileViewModel.uri == profileViewModel.channel.uri ? nil : L10n.Channel.Create.Uri.Error.success
                errorLabel.textColor = appearance.uriValidationAppearance.successLabelAppearance.foregroundColor
                errorLabel.font = appearance.uriValidationAppearance.successLabelAppearance.font
                errorLabel.sizeToFit()
                tableView.tableFooterView = errorLabel
            }
        case .error(let error):
            showAlert(error: error)
        }
    }
    
    override open func setupLayout() {
        super.setupLayout()
        view.addSubview(tableView)
        tableView.pin(to: view)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        view.backgroundColor = appearance.backgroundColor
        tableView.backgroundColor = .clear
        errorLabel.edgeInsets = .init(top: 8, left: 16, bottom: 8, right: 16)
    }
    
    func onDone() {
        loader.isLoading = true
        profileViewModel.update { [weak self] error in
            loader.isLoading = false
            guard let self else { return }
            if let error {
                self.showAlert(error: error)
            } else {
                self.router.pop()
            }
        }
    }
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        if profileViewModel.canShowURI {
            return Sections.allCases.count
        }
        return Sections.allCases.count - 1
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 24
        }
        return 30
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
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelEditAvatarCell.self)
            cell.parentAppearance = appearance.avatarCellAppearance
            cell.selectionStyle = .none
            profileViewModel.$avatarUrl.receive(on: DispatchQueue.main).sink {
                cell.data = URL(string: $0 ?? "")
            }.store(in: &cell.subscriptions)
            cell.avatarButton.publisher(for: .touchUpInside).sink { [weak self] _ in
                self?.onEditAvatar()
            }.store(in: &cell.subscriptions)
            _cell = cell
        case .fields:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelEditTextFieldCell.self)
            cell.parentAppearance = appearance.textFieldCellAppearance
            cell.selectionStyle = .none
            cell.onTextChanged = { [weak self] in
                self?.onTextChanged(text: $0, row: indexPath.row)
            }
            switch indexPath.row {
            case 0:
                cell.allowsNewline = false
                cell.textView.placeholder = profileViewModel.subjectPlaceholder
                cell.textView.text = profileViewModel.subject
                cell.separatorView.isHidden = false
            case 1:
                cell.allowsNewline = true
                cell.textView.placeholder = profileViewModel.aboutPlaceholder
                cell.textView.text = profileViewModel.metadata
                cell.separatorView.isHidden = true
            default:
                break
            }
            
            _cell = cell
        case .uri:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelEditURICell.self)
            cell.parentAppearance = appearance.uriCellAppearance
            cell.textField.text = profileViewModel.channel.uri
            cell.onTextChanged = { [weak self] in guard let self else { return }
                let uri = $0?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                self.profileViewModel.uri = uri
            }
            _cell = cell
        case .none:
            _cell = UITableViewCell()
        }
        return _cell
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat {
        if profileViewModel.canShowURI,
           section == Sections.allCases.count - 1
        {
            return 16 + 8 + 8
        }
        return .leastNormalMagnitude
    }
    
    open func onTextChanged(text: String, row: Int) {
        tableView.beginUpdates()
        switch row {
        case 0:
            profileViewModel.subject = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case 1:
            profileViewModel.metadata = text.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            break
        }
        tableView.endUpdates()
    }
    
    open func adjustTableViewToKeyboard(notification: Notification) {
        tableView.adjustInsetsToKeyboard(notification: notification, container: view)
    }
    
    open func onEditAvatar() {
        var types = [ChannelProfileEditRouter.CaptureType.camera, .photoLibrary]
        if profileViewModel.avatarUrl != nil {
            types.append(.delete)
        }
        router.showCaptureAlert(types: types) { [weak self] type in
            guard let self else { return }
            switch type {
            case .camera:
                self.router.showCamera(mediaTypes: [.image]) { [weak self] picked in
                    guard let self, let picked else { return }
                    self.router.editImage(picked.thumbnail) { [weak self] edited in
                        guard let self,
                              let jpeg = Components.imageBuilder.init(image: edited).jpegData(compressionQuality: SceytChatUIKit.shared.config.imageAttachmentResizeConfig.compressionQuality),
                              let url = Components.storage.storeData(jpeg, filePath: picked.url.path)
                        else { return }
                        self.profileViewModel.avatarUrl = url.absoluteString
                    }
                }
            case .photoLibrary:
                self.router.selectPhoto(mediaTypes: [.image]) { [weak self] picked in
                    guard let self, let picked else { return }
                    self.router.editImage(picked.thumbnail) { [weak self] edited in
                        guard let self,
                              let jpeg = Components.imageBuilder.init(image: edited).jpegData(compressionQuality: SceytChatUIKit.shared.config.imageAttachmentResizeConfig.compressionQuality),
                              let url = Components.storage.storeData(jpeg, filePath: picked.url.path)
                        else { return }
                        self.profileViewModel.avatarUrl = url.absoluteString
                    }
                }
            case .delete:
                self.profileViewModel.avatarUrl = nil
            case .none:
                break
            }
        }
    }
}

public extension EditChannelViewController {
    enum Sections: Int, CaseIterable {
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
