//
//  MessageInfoVC.swift
//  SceytChatUIKit
//
//  Created by Duc on 21/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class MessageInfoVC: ViewController, UITableViewDataSource, UITableViewDelegate {
    open var viewModel: MessageInfoVM!
    open lazy var router = MessageInfoRouter(rootVC: self)

    open lazy var tableView = TableView(frame: .zero, style: .insetGrouped)
        .withoutAutoresizingMask

    override open func setup() {
        super.setup()

        title = L10n.Message.Info.title
        navigationItem.leftBarButtonItem = .init(title: L10n.Nav.Bar.cancel,
                                                 style: .plain,
                                                 cancellables: &subscriptions,
                                                 action: { [weak self] in
                                                     self?.onCancelTapped()
                                                 })
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.register(Components.messageInfoHeaderView.self)
        tableView.register(Components.messageInfoMessageCell.self)
        tableView.register(Components.messageInfoMarkerCell.self)
        tableView.estimatedRowHeight = 48
        tableView.rowHeight = UITableView.automaticDimension
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
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
    }

    open func onCancelTapped() {
        router.dismiss()
    }

    // MARK: - UITableViewDataSource, UITableViewDelegate

    public func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(rawValue: section)! {
        case .message:
            return 16
        case .read:
            return viewModel.numberOfReads > 0 ? 32 : 0
        case .delivered:
            return viewModel.numberOfDelivered > 0 ? 32 : 0
        }
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = tableView.dequeueReusableHeaderFooterView(HeaderView.self)
        headerView.label.text = Section(rawValue: section)?.title
        return headerView
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .message:
            return 1
        case .read:
            return viewModel.numberOfReads
        case .delivered:
            return viewModel.numberOfDelivered
        }
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = Section(rawValue: indexPath.section)!
        switch section {
        case .message:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.messageInfoMessageCell.self)
            cell.data = viewModel.data
            return cell
        default:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.messageInfoMarkerCell.self)
            cell.data = section == .read ? viewModel.readMarker(at: indexPath) : viewModel.deliveredMarker(at: indexPath)
            cell.contentInsets.top = tableView.isFirst(indexPath) ? 8 : 0
            cell.contentInsets.bottom = tableView.isLast(indexPath) ? 8 : 0
            return cell
        }
    }
}

public extension MessageInfoVC {
    enum Section: Int, CaseIterable {
        case message, read, delivered

        public var title: String? {
            switch self {
            case .message:
                return nil
            case .read:
                return L10n.Message.Info.readBy
            case .delivered:
                return L10n.Message.Info.deliveredTo
            }
        }
    }
}

private extension UITableView {
    func isFirst(_ indexPath: IndexPath) -> Bool {
        indexPath.item == 0
    }
    
    func isLast(_ indexPath: IndexPath) -> Bool {
        indexPath.item == numberOfRows(inSection: indexPath.section) - 1
    }
}
