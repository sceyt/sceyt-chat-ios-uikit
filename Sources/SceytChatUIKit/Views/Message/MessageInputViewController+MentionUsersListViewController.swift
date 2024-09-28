//
//  MessageInputViewController+MentionUsersListViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

extension MessageInputViewController {
    open class MentionUsersListViewController: ViewController,
                                   UITableViewDelegate,
                                   UITableViewDataSource {
        
        open var viewModel: MentioningUserListViewModel!
        
        open var didSelectMember: ((ChatChannelMember) -> Void)?
        
        open lazy var tableView = IntrinsicTableView()
            .withoutAutoresizingMask
        
        open lazy var shadowsView = UIView()
        
        open override func setup() {
            super.setup()
            
            tableView.register(Components.messageInputMentionUsersCell)
            tableView.delegate = self
            tableView.dataSource = self
            tableView.separatorColor = appearance.separatorColor
            tableView.clipsToBounds = true
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
        
        func keykoardWillShow(_ notification: Notification) {
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
                  let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
            else { return }
            UIView.animate(withDuration: duration, delay: 0, options: .init(rawValue: curve)) { [weak self] in
                guard let self else { return }
                self.shadowsView.top -= keyboardFrame.height - (self.view.window?.safeAreaInsets.bottom ?? 0)
            } completion: { [weak self] _ in
                guard let self else { return }
                self.updateShadows()
            }
        }
        
        open override func setupLayout() {
            super.setupLayout()
            
            view.addSubview(shadowsView)
            view.addSubview(tableView)
            tableView.pin(to: view, anchors: [
                .leading(Layouts.horizontalPadding),
                .trailing(-Layouts.horizontalPadding),
                .top(0),
                .bottom(-Layouts.bottomPadding)
            ])
            
            shadowsView.layer.cornerRadius = Layouts.cornerRadius
            shadowsView.layer.maskedCorners = Layouts.maskedCorners
            if Layouts.shadowRadius > 0 {
                shadowsView.layer.shadowRadius = Layouts.shadowRadius
                shadowsView.layer.masksToBounds = false
                shadowsView.layer.shadowOpacity = 1
                shadowsView.layer.shadowOffset = .zero
                shadowsView.layer.shouldRasterize = true
            }
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            
            shadowsView.backgroundColor = appearance.backgroundColor
            if Layouts.shadowRadius > 0 {
                shadowsView.layer.shadowColor = appearance.shadowColor?.cgColor
            }
            
            tableView.backgroundColor = .clear
            
            view.backgroundColor = .clear
            view.clipsToBounds = true
        }
        
        open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            shadowsView.backgroundColor = appearance.backgroundColor
        }
        
        private var firstLayout = true
        
        open override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            
            let cellHeight = Components.messageInputMentionUsersCell.Layouts.cellHeight
            let newHeight = round(tableView.height - cellHeight * 4 - 4 * 2 - view.safeAreaInsets.bottom)
            if tableView.frame.height != 0,
               tableView.contentInset.bottom != newHeight {
                tableView.contentInset.bottom = newHeight
                if firstLayout {
                    tableView.scrollToBottom()
                } else {
                    updateShadows(animated: true)
                }
                firstLayout = false
            }
            
            updateTableViewMask()
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            updateShadows()
        }
        
        @discardableResult
        func updateTableViewMask() -> CAShapeLayer {
            let maskLayer = CAShapeLayer()
            let maskPath = UIBezierPath(roundedRect: shadowsView.convert(shadowsView.bounds, to: tableView), cornerRadius: shadowsView.layer.cornerRadius)
            maskLayer.path = maskPath.cgPath
            tableView.layer.mask = maskLayer
            return maskLayer
        }
        
        func updateShadows(animated: Bool = false) {
            tableView.sendSubviewToBack(shadowsView)
            
            DispatchQueue.main.async { [weak self] in
                guard let self, let last = self.tableView.visibleCells.last else { return }
                let top = last.frameRelativeTo(view: self.view).minY
                
                func perform() {
                    // Update the shadowsView frame and shadow path
                    self.shadowsView.frame = CGRect(
                        x: self.tableView.left,
                        y: top,
                        width: self.tableView.width,
                        height: self.tableView.bottom - top
                    )
                    self.shadowsView.layer.shadowPath = UIBezierPath(roundedRect: self.shadowsView.bounds,
                                                                     cornerRadius: Layouts.cornerRadius).cgPath
                    
                    updateTableViewMask()
                }
                
                let maskLayer = updateTableViewMask()
                
                if animated {
                    CATransaction.begin()
                    CATransaction.setAnimationDuration(0.25)
                    CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))
                    
                    UIView.animate(withDuration: 0.25) {
                        perform()
                    }
                    
                    let newMaskPath = UIBezierPath(
                        roundedRect: self.shadowsView.convert(self.shadowsView.bounds, to: self.tableView),
                        cornerRadius: self.shadowsView.layer.cornerRadius
                    ).cgPath

                    // Animate mask path
                    let pathAnimation = CABasicAnimation(keyPath: "path")
                    pathAnimation.fromValue = maskLayer.path
                    pathAnimation.toValue = newMaskPath
                    pathAnimation.duration = 0.25
                    maskLayer.add(pathAnimation, forKey: "pathAnimation")
                    maskLayer.path = newMaskPath
                    tableView.layer.mask = maskLayer
                    
                    CATransaction.commit()
                } else {
                    perform()
                }
            }
        }
        
        open func onEvent(_ event: MentioningUserListViewModel.Event) {
            switch event {
            case .change(_):
                if tableView.numberOfSections == 0 || tableView.numberOfRows(inSection: 0) == 0 {
                    tableView.alpha = 0
                    tableView.performBatchUpdates {
                    } completion: { [weak self] _ in
                        guard let self else { return }
                        self.tableView.alpha = 1
                        self.tableView.scrollToBottom()
                        self.updateShadows()
                    }
                } else {
                    tableView.reloadData()
                }
            case .reload:
                tableView.alpha = 0
                tableView.reloadData()
                tableView.performBatchUpdates {
                } completion: { [weak self] _ in
                    guard let self else { return }
                    self.tableView.alpha = 1
                    self.tableView.scrollToBottom()
                    self.updateShadows()
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
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.messageInputMentionUsersCell)
            cell.parentAppearance = appearance.cellAppearance
            cell.transform = .init(scaleX: 1, y: -1)
            guard let item = viewModel.member(at: indexPath)
            else { return cell }
            cell.data = item
            return cell
        }
        
        public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            var height = Components.messageInputMentionUsersCell.Layouts.cellHeight
            if tableView.isFirst(indexPath) {
                height += Components.messageInputMentionUsersCell.Layouts.verticalPadding
            }
            if tableView.isLast(indexPath) {
                height += Components.messageInputMentionUsersCell.Layouts.verticalPadding
            }
            return height
        }
        
        open func tableView(
            _ tableView: UITableView,
            willDisplay cell: UITableViewCell,
            forRowAt indexPath: IndexPath
        ) {
            if indexPath.row == 0 {
                cell.separatorInset.left = tableView.width
            } else {
                cell.separatorInset.left = Components.messageInputMentionUsersCell.Layouts.avatarSize + Components.messageInputMentionUsersCell.Layouts.avatarLeftPadding
            }
        }
    }
}

private extension UITableView {
    func scrollToBottom(animated: Bool = false, duration: CGFloat = 0.25) {
        let lastRow = numberOfRows(inSection: 0) - 1
        if lastRow > 0 {
            scrollToRow(at: .init(row: lastRow, section: 0), at: .bottom, animated: animated)
        }
    }
}

public extension MessageInputViewController.MentionUsersListViewController {
    enum Layouts {
        public static var horizontalPadding: CGFloat = 8
        public static var bottomPadding: CGFloat = 8
        public static var shadowRadius: CGFloat = 24
        public static var cornerRadius: CGFloat = 16
        public static var maskedCorners: CACornerMask = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMinXMaxYCorner,
            .layerMaxXMaxYCorner
        ]
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
