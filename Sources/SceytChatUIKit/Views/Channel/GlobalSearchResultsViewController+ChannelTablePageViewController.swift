//
//  GlobalSearchResultsViewController+ChannelTablePageViewController.swift
//  SceytChatUIKit
//

import UIKit
import SceytChat

extension GlobalSearchResultsViewController {

    open class ChannelTablePageViewController: ViewController,
        UITableViewDelegate,
        UITableViewDataSource
    {
        public var channels: [ChatChannel] = []
        public var onSelect: ((ChatChannel) -> Void)?

        open lazy var tableView = UITableView()
            .withoutAutoresizingMask

        open lazy var emptyStateView = EmptyStateStackView()
            .withoutAutoresizingMask

        override open func setup() {
            super.setup()
            tableView.delegate = self
            tableView.dataSource = self
            tableView.separatorStyle = .none
            tableView.register(Components.searchResultChannelCell.self)
            tableView.tableFooterView = UIView()
            tableView.estimatedRowHeight = 56
            if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 0 }

            emptyStateView.title = L10n.Search.NoResults.title
            emptyStateView.message = L10n.Search.NoResults.message
            emptyStateView.icon = .noResultsSearch
        }

        override open func setupLayout() {
            super.setupLayout()
            view.addSubview(tableView)
            view.addSubview(emptyStateView)
            tableView.pin(to: view)
            emptyStateView.pin(to: view, anchors: [.centerX, .top(50), .leading(16, .greaterThanOrEqual)])
        }

        override open func setupAppearance() {
            super.setupAppearance()
            view.backgroundColor = .background
            tableView.backgroundColor = .clear
        }

        static var currentKeyboardInset: CGFloat = 0

        override open func setupDone() {
            super.setupDone()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillChangeFrame(_:)),
                name: UIResponder.keyboardWillChangeFrameNotification,
                object: nil
            )
        }

        override open func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            let inset = ChannelTablePageViewController.currentKeyboardInset + GlobalSearchUserBarView.Layouts.height
            tableView.contentInset.bottom = inset
            tableView.verticalScrollIndicatorInsets.bottom = inset
        }

        @objc private func keyboardWillChangeFrame(_ notification: Notification) {
            guard
                let info = notification.userInfo,
                let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
                let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
                let curveRaw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt,
                isViewLoaded, let window = view.window
            else { return }

            let keyboardFrameInView = window.convert(endFrame, to: view)
            let overlap = max(0, view.bounds.maxY - keyboardFrameInView.minY)
            let safeBottom = view.safeAreaInsets.bottom
            let inset = max(0, overlap - safeBottom)

            ChannelTablePageViewController.currentKeyboardInset = inset

            let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
            UIView.animate(withDuration: duration, delay: 0, options: options) {
                self.tableView.contentInset.bottom = inset + GlobalSearchUserBarView.Layouts.height
                self.tableView.verticalScrollIndicatorInsets.bottom = inset + GlobalSearchUserBarView.Layouts.height
            }
        }

        open func reloadData() {
            tableView.reloadData()
            emptyStateView.isHidden = !channels.isEmpty
        }

        // MARK: UITableViewDataSource

        public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            channels.count
        }

        public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.searchResultChannelCell.self)
            cell.separatorView.isHidden = indexPath.row == channels.count - 1
            cell.channelData = channels[indexPath.row]
            return cell
        }

        public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            onSelect?(channels[indexPath.row])
        }
    }

}
