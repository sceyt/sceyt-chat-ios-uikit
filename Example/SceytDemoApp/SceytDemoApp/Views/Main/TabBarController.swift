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
