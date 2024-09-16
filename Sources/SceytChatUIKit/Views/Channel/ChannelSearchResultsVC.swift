//
//  ChannelSearchResultsVC.swift
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
    var showCheckBox: Bool { get }
}

open class ChannelSearchResultsVC: ViewController,
    UITableViewDelegate, UITableViewDataSource
{
    open weak var resultsUpdater: ChannelSearchResultsUpdating!
    
    open lazy var tableView = UITableView()
        .withoutAutoresizingMask
    
    open lazy var noDataView = Components.noDataView
        .init()
        .withoutAutoresizingMask
    
    public var noDataViewBottom: NSLayoutConstraint!
    
    override open func setup() {
        super.setup()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.allowsMultipleSelection = true
        tableView.register(Components.channelUserCell.self)
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
        view.addSubview(noDataView)
        tableView.pin(to: view)
        noDataViewBottom = noDataView.pin(to: view.safeAreaLayoutGuide, anchors: [.bottom, .top, .leading, .trailing])[0]
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        tableView.backgroundColor = .clear
        view.backgroundColor = appearance.backgroundColor
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
        noDataView.isHidden = !resultsUpdater.searchResults.isEmpty
    }
    
    func adjustTableViewToKeyboard(notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }

        tableView.adjustInsetsToKeyboard(notification: notification, container: view)
        if notification.name == UIResponder.keyboardWillHideNotification {
            noDataViewBottom.constant = 0
        } else if notification.name == UIResponder.keyboardWillShowNotification {
            noDataViewBottom.constant = -keyboardFrame.height/2
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
        let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelUserCell.self)
        cell.separatorView.isHidden = indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1
        cell.showCheckBox = resultsUpdater.showCheckBox
        if let channel = resultsUpdater.searchResults.channel(at: indexPath) {
            cell.channelData = channel
            cell.checkBoxView.isSelected = resultsUpdater.isSelected(channel)
        }
        return cell
    }
    
    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        resultsUpdater.searchResults.header(for: section) != nil ? Components.separatorHeaderView.Layouts.height : 0
    }
    
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = resultsUpdater.searchResults.header(for: section)
            else { return nil }
        
        let headerView = tableView.dequeueReusableHeaderFooterView(Components.separatorHeaderView.self)
        headerView.titleLabel.text = header
        return headerView
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let channel = resultsUpdater.searchResults.channel(at: indexPath) {
            resultsUpdater.select(channel)
            tableView.cell(for: indexPath, cellType: Components.channelUserCell.self)?.checkBoxView.isSelected = resultsUpdater.isSelected(channel)
        }
    }
}
