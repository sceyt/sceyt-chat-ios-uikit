//
//  MessageInfoViewController.swift
//  SceytChatUIKit
//
//  Created by Duc on 21/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class MessageInfoViewController: ViewController, UITableViewDataSource, UITableViewDelegate {
    
    open var viewModel: MessageInfoViewModel!
    open lazy var router = MessageInfoRouter(rootViewController: self)

    open lazy var tableView = TableView(frame: .zero, style: .insetGrouped)
        .withoutAutoresizingMask

    required public init(messageCellAppearance: MessageCellAppearance? = nil) {
        super.init(nibName: nil, bundle: nil)
        parentAppearance = .init(
            reference: appearance,
            messageCellAppearance: messageCellAppearance
        )
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
  
    override open func setup() {
        super.setup()

        title = appearance.navigationBarTitle
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
        tableView.estimatedRowHeight = Layouts.cellHeight
        tableView.rowHeight = UITableView.automaticDimension
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
    }

    override open func setupAppearance() {
        guard isViewLoaded else { return } // handles the case when parent appearance is set before the view being loaded
        super.setupAppearance()
        navigationController?.navigationBar.apply(appearance: appearance.navigationBarAppearance)
        
        view.backgroundColor = appearance.backgroundColor
        tableView.backgroundColor = .clear
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        view.addSubview(tableView)
        tableView.pin(to: view)
    }
    
    open override func setupDone() {
        super.setupDone()
        viewModel.startDatabaseObserver()
        viewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }
            .store(in: &subscriptions)
        viewModel.loadMarkers()
    }

    // MARK: - Actions
    open func onEvent(_ event: MessageInfoViewModel.Event) {
        switch event {
        case .reload:
            tableView.reloadData()
        }
    }

    open func onCancelTapped() {
        router.dismiss()
    }

    // MARK: - UITableViewDataSource, UITableViewDelegate

    open func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.numberOfSections
    }

    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let _ = viewModel.header(section: section)
        else { return 16 }
        return 32
    }

    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = viewModel.header(section: section)
        else { return nil }
        let headerView = tableView.dequeueReusableHeaderFooterView(Components.messageInfoHeaderView.self)
        headerView.appearance = appearance
        headerView.label.text = appearance.markerTitleProvider.provideVisual(for: header)
        return headerView
    }

    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfRows(section: section)
    }

    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        switch section {
        case 0:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.messageInfoMessageCell.self)
            cell.appearance = appearance
            cell.data = viewModel.data
            return cell
        default:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.messageInfoMarkerCell.self)
            cell.parentAppearance = appearance.markerCellAppearance
            cell.data = viewModel.marker(at: indexPath)
            cell.contentInsets.top = tableView.isFirst(indexPath) ? 8 : 0
            cell.contentInsets.bottom = tableView.isLast(indexPath) ? 8 : 0
            return cell
        }
    }

    open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0: return UITableView.automaticDimension
        default:
            var cellHeight = Layouts.cellHeight
            cellHeight += tableView.isFirst(indexPath) ? 8 : 0
            cellHeight += tableView.isLast(indexPath) ? 8 : 0
            return cellHeight
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

public extension MessageInfoViewController {
    enum Layouts {
        public static var cellHeight: CGFloat = 48
    }
}
