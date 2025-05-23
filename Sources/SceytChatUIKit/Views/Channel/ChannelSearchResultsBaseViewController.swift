//
//  ChannelSearchResultsBaseViewController.swift
//  SceytChatUIKit
//
//  Created by Duc on 24/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public protocol ChannelSearchResultsUpdating: AnyObject {
    var searchResults: ChannelSearchResult { get }
    func isSelected(_ channel: ChatChannel) -> Bool
    func select(_ channel: ChatChannel)
}

open class ChannelSearchResultsBaseViewController: ViewController,
    UITableViewDelegate, UITableViewDataSource
{
    open weak var resultsUpdater: ChannelSearchResultsUpdating!
    
    open lazy var tableView = UITableView()
        .withoutAutoresizingMask
    
    open lazy var emptyStateView = Components.emptyStateView
        .init()
        .withoutAutoresizingMask
    
    public var emptyStateViewBottom: NSLayoutConstraint!
    
    override open func setup() {
        super.setup()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.allowsMultipleSelection = true
        tableView.register(Components.separatorHeaderView.self)
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.tableFooterView = UIView()
        tableView.estimatedRowHeight = 56
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        
        KeyboardObserver()
            .willShow { [weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }.willHide { [weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        tableView.pin(to: view)
        emptyStateViewBottom = emptyStateView.pin(to: view.safeAreaLayoutGuide, anchors: [.bottom, .top, .leading, .trailing])[0]
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        tableView.backgroundColor = appearance.backgroundColor
        view.backgroundColor = appearance.backgroundColor
        emptyStateView.parentAppearance = appearance.emptyViewAppearance
    }
    
    override open func setupDone() {
        super.setupDone()
        
        showEmptyViewIfNeeded()
    }
    
    // MARK: - Actions
    
    func reloadData() {
        tableView.reloadData()
        showEmptyViewIfNeeded()
    }
    
    open func showEmptyViewIfNeeded() {
        emptyStateView.isHidden = !resultsUpdater.searchResults.isEmpty
    }
    
    func adjustTableViewToKeyboard(notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }

        tableView.adjustInsetsToKeyboard(notification: notification, container: view)
        if notification.name == UIResponder.keyboardWillHideNotification {
            emptyStateViewBottom.constant = 0
        } else if notification.name == UIResponder.keyboardWillShowNotification {
            emptyStateViewBottom.constant = -keyboardFrame.height/2
        }
        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: .init(rawValue: curve),
                       animations: view.layoutIfNeeded, 
                       completion: nil)
    }
    
    // MARK: - UITableViewDataSource, UITableViewDelegate

    open func numberOfSections(in tableView: UITableView) -> Int {
        resultsUpdater.searchResults.numberOfSections
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        resultsUpdater.searchResults.numberOfChannels(in: section)
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        fatalError("Override and implement in subclass")
    }
    
    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        resultsUpdater.searchResults.header(for: section) != nil ? Components.separatorHeaderView.Layouts.height : 0
    }
    
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = resultsUpdater.searchResults.header(for: section)
            else { return nil }
        
        let headerView = tableView.dequeueReusableHeaderFooterView(Components.separatorHeaderView.self)
        headerView.parentAppearance = appearance.separatorViewAppearance
        headerView.titleLabel.text = header
        return headerView
    }
}
