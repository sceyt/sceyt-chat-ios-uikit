//
//  ChannelSearchResultsViewController.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 01.11.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelSearchResultsViewController: ChannelSearchResultsBaseViewController {
    
    public required init() {
        super.init(nibName: nil, bundle: nil)
        parentAppearance = ChannelSearchResultsViewController.defaultAppearance
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        parentAppearance = ChannelSearchResultsViewController.defaultAppearance
    }
    
    override open func setup() {
        super.setup()
        tableView.register(Components.searchResultChannelCell.self)
    }
    
    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.searchResultChannelCell.self)
        cell.parentAppearance = (appearance as! ChannelSearchResultsViewController.Appearance).cellAppearance
        cell.separatorView.isHidden = indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1
        if let channel = resultsUpdater.searchResults.channel(at: indexPath) {
            cell.channelData = channel
        }
        return cell
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let channel = resultsUpdater.searchResults.channel(at: indexPath) {
            resultsUpdater.select(channel)
        }
    }
}
