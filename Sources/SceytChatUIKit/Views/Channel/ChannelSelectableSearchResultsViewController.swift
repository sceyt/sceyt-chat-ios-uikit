//
//  ChannelSelectableSearchResultsViewController.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 01.11.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelSelectableSearchResultsViewController: ChannelSearchResultsBaseViewController {
    
    public required init() {
        super.init(nibName: nil, bundle: nil)
        parentAppearance = ChannelSelectableSearchResultsViewController.defaultAppearance
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        parentAppearance = ChannelSelectableSearchResultsViewController.defaultAppearance
    }
    
    override open func setup() {
        super.setup()
        tableView.register(Components.selectableChannelCell.self)
    }
    
    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.selectableChannelCell.self)
        cell.parentAppearance = (appearance as! ChannelSelectableSearchResultsViewController.Appearance).selectableCellAppearance
        cell.separatorView.isHidden = indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1
        if let channel = resultsUpdater.searchResults.channel(at: indexPath) {
            cell.channelData = channel
            cell.checkBoxView.isSelected = resultsUpdater.isSelected(channel)
        }
        return cell
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let channel = resultsUpdater.searchResults.channel(at: indexPath) {
            resultsUpdater.select(channel)
            tableView.cell(for: indexPath, cellType: Components.selectableChannelCell.self)?.checkBoxView.isSelected = resultsUpdater.isSelected(channel)
        }
    }
}
