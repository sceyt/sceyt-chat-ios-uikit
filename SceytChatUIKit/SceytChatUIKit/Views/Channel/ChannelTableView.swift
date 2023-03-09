//
//  ChannelTableView.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelTableView: TableView {

    public override func setup() {
        super.setup()
        register(Components.channelCell)
        contentInsetAdjustmentBehavior = .automatic
        tableFooterView = UIView()
        separatorStyle = .none
    }

}
