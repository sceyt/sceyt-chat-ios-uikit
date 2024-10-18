//
//  CustomChannelInfoViewController.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 17.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChatUIKit

class CustomChannelInfoViewController: ChannelInfoViewController {
    override func options() -> [ChannelInfoViewController.ActionItem] {
        [
            .init(title: appearance.optionTitles.notificationsTitleText,
                  image: appearance.optionIcons.notificationsIcon,
                  tag: ActionTag.notifications)
        ]
    }
}
