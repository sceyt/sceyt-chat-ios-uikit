//
//  MentioningUserListVC.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import UIKit
import SceytChat

open class MentioningUserListVC: ViewController,
                                            UITableViewDelegate,
                                            UITableViewDataSource {

    open var viewModel: MentioningUserListVM!

    open var didSelectMember: ((ChatChannelMember) -> Void)?

    open lazy var tableView = IntrinsicTableView()
        .withoutAutoresizingMask
    
    open var bounceBackgroundView: UIView?

    deinit {
        print(#function)
    }
    open override func setup() {
        super.setup()
        tableView.register(Components.mentioningUserViewCell)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.clipsToBounds = true
//        tableView.tableHeaderView = UIView()
        tableView.tableFooterView = UIView()
        tableView.backgroundView = UIView()
        bounceBackgroundView = UIView()
        tableView.showsVerticalScrollIndicator = false
        tableView.showsHorizontalScrollIndicator = false
        tableView.transform = .init(scaleX: 1, y: -1)
        viewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        
        viewModel.startDatabaseObserver()
        viewModel.loadMembers()
    }

    open override func setupLayout() {
        super.setupLayout()
        view.addSubview(tableView)
        tableView.pin(to: view)
        if let bounceBackgroundView {
            tableView.backgroundView?.addSubview(bounceBackgroundView)
        }
        
    }

    open override func setupAppearance() {
        super.setupAppearance()
        bounceBackgroundView?.backgroundColor = appearance.tableViewBackgroundColor;
        tableView.tableHeaderView?.backgroundColor = .clear
        tableView.tableFooterView?.backgroundColor = .clear
        tableView.backgroundView?.backgroundColor = .clear
        
        view.backgroundColor = appearance.backgroundColor
        tableView.backgroundColor = appearance.backgroundColor
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if tableView.frame.height != 0,
           let tableHeaderView = tableView.tableFooterView,
           tableHeaderView.frame.height == 0 {
            let height = CGFloat(135)
            tableHeaderView.frame = CGRect(x: 0, y: 0, width: tableView.frame.width, height: height)
            print("[MNT] set tableHeaderView", tableHeaderView.frame)
            tableView.reloadData()
            layoutBounceBackground()
        }
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
    }

    open func onEvent(_ event: MentioningUserListVM.Event) {
        switch event {
        case let .change(paths):
            if tableView.numberOfSections == 0 || tableView.numberOfRows(inSection: 0) == 0 {
                tableView.alpha = 0
                tableView.reloadData()
                tableView.performBatchUpdates {
                } completion: {[weak self] _ in
                    self?.tableView.alpha = 1
                    self?.tableView.scrollToBottom()
                }
            } else {
                tableView.performBatchUpdates {
                    tableView.insertRows(at: paths.inserts, with: .none)
                    tableView.reloadRows(at: paths.updates, with: .none)
                    tableView.deleteRows(at: paths.deletes, with: .none)
                    paths.moves.forEach {
                        tableView.moveRow(at: $0.from, to: $0.to)
                    }
                } completion: {[weak self] _ in
                    let indexPaths = paths.moves.map(\.to)
                    if !indexPaths.isEmpty {
                        self?.tableView.reloadRows(at: indexPaths, with: .none)
                    }
                }
            }
        case .reload:
            tableView.alpha = 0
            tableView.reloadData()
            tableView.performBatchUpdates {
            } completion: {[weak self] _ in
                self?.tableView.alpha = 1
                self?.tableView.scrollToBottom()
            }
        }
        view.alpha = viewModel.numberOfMembers == 0 ? 0 : 1
    }

    open func filter(text: String?) {
        viewModel.setPredicate(query: text ?? "")
    }

    // MARK: UITableView delegate, datasource
    open func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let m = viewModel.member(at: indexPath) else { return }
        didSelectMember?(m)
    }

    open func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        viewModel.numberOfMembers
    }

    open func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.mentioningUserViewCell)
        cell.transform = .init(scaleX: 1, y: -1)
        guard let item = viewModel.member(at: indexPath)
        else { return cell }
        cell.data = item
//        if indexPath.row > indexPath.row - 10 {
//            viewModel.loadMembers()
//        }
        return cell
    }
    
    open func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        updateForShadow(cell: cell, forRowAt: indexPath)
    }
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        layoutBounceBackground()
    }
    
    open func layoutBounceBackground() {
        let contentHeight = tableView.contentSize.height
        let contentOffsetY = tableView.contentOffset.y
        let height = tableView.frame.size.height
        
        guard contentOffsetY <= 0 else { return }
        
        if contentOffsetY >= 0, contentOffsetY <= contentHeight - height {
            return
        }
        let bounceHeight: CGFloat
        let bounceY: CGFloat
        
        if contentOffsetY <= 0 {
            bounceHeight = -contentOffsetY;
            bounceY = 0;
        } else {
            bounceHeight = height - (contentHeight - contentOffsetY);
            bounceY = height - bounceHeight;
        }
        
        bounceBackgroundView?.frame = .init(
            x: 0,
            y: bounceY,
            width: tableView.backgroundView?.frame.size.width ?? 0,
            height: bounceHeight
        )
    }
    
    open func updateForShadow(cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .white
        
        if indexPath.row == tableView.numberOfRows(inSection: 0) - 1 {
            let cornerRadius = 16
            var corners: UIRectCorner = []
            var rect = cell.bounds
            let maskLayer = CAShapeLayer()
            corners.update(with: .topLeft)
            corners.update(with: .topRight)
            maskLayer.path = UIBezierPath(roundedRect: rect,
                                          byRoundingCorners: corners,
                                          cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)).cgPath
            cell.contentView.layer.mask = maskLayer
        } else {
            cell.contentView.layer.mask = nil
        }
    }
}

private extension UITableView {
    
    func scrollToBottom(animated: Bool = false, duration: CGFloat = 0.22) {
        guard contentSize.height > bounds.height - contentInset.bottom - contentInset.top
        else { return }
        
        let contentOffsetYAtBottom = contentSize.height - frame.height + adjustedContentInset.bottom
        guard contentOffsetYAtBottom > contentOffset.y
        else { return }
        
        if animated {
            UIView.animate(withDuration: duration) {[weak self] in
                guard let self else { return }
                self.setContentOffset(CGPoint(x: self.contentOffset.x, y: contentOffsetYAtBottom), animated: false)
            }
        } else {
            setContentOffset(CGPoint(x: contentOffset.x, y: contentOffsetYAtBottom), animated: false)
        }
        
    }
}
