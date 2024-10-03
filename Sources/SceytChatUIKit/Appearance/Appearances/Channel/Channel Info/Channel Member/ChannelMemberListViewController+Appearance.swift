//
//  ChannelMemberListViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelMemberListViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor = .background
        public var cellAppearance: ChannelMemberListViewController.MemberCell.Appearance = SceytChatUIKit.Components.channelMemberCell.appearance
        public var addCellAppearance: ChannelMemberListViewController.AddMemberCell.Appearance = SceytChatUIKit.Components.channelAddMemberCell.appearance
        
        public init(
            backgroundColor: UIColor = .background,
            cellAppearance: ChannelMemberListViewController.MemberCell.Appearance = SceytChatUIKit.Components.channelMemberCell.appearance,
            addCellAppearance: ChannelMemberListViewController.AddMemberCell.Appearance = SceytChatUIKit.Components.channelAddMemberCell.appearance
        ) {
            self.backgroundColor = backgroundColor
            self.cellAppearance = cellAppearance
            self.addCellAppearance = addCellAppearance
        }
    }
}
