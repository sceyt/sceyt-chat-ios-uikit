//
//  TabBarController.swift
//  SceytDemoApp
//
//  Created by Hovsep Keropyan on 28.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChatUIKit
import SceytChat

class TabBarController: UITabBarController {
    
    lazy var activityIndicatorView: UIActivityIndicatorView = {
        UIActivityIndicatorView(style: .large)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabBar.items?.first?.image = .chatsTabbar
        tabBar.items?.last?.image = .profileTabbar
        tabBar.items?.last?.title = "Profile"
        
        addAppNotifications()
        // UI tests render the channel list from seeded local data only — no
        // spinner, no live connection.
        guard !UITestSupport.isActive else { return }
        showSheet(activityIndicatorView, style: .center, backgroundDismiss: false) { [unowned self] in
            activityIndicatorView.startAnimating()
        }
        connect()
    }
    
    private func addAppNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActiveNotification(_:)),
            name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackgroundNotification(_:)),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc
    func didBecomeActiveNotification(_ notification: Notification) {
        guard SceytChatUIKit.shared.chatClient.connectionState == .disconnected
        else { return }
        connect()
    }
    
    @objc
    func didEnterBackgroundNotification(_ notification: Notification) {
        
    }
    
    private func connect() {
        // UI-test mode renders exclusively from seeded local data. This guard
        // also has to cover `didBecomeActiveNotification` (which fires right
        // after launch): `startUITestSession` sets `currentUserId` to skip the
        // login screen, so without it the app connects to the live server and
        // the real account's sync overwrites the seeded fixtures mid-test.
        guard !UITestSupport.isActive else { return }
        guard let user = Config.currentUserId
        else { return }
        ConnectionService.shared.connect(username: user) {[weak self] error in
            self?.dismissSheet()
            if let error {
                self?.showAlert(error: error)
                return
            }
        }
    }    
}
