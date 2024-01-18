//
//  ViewController.swift
//  SceytDemoApp
//
//  Created by Hovsep Keropyan on 28.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChatUIKit
import SceytChat

class DemoTabBarController: UITabBarController {
    
    lazy var activityIndicatorView: UIActivityIndicatorView = {
        UIActivityIndicatorView(style: .large)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        tabBar.items?.first?.image = UIImage(named: "chats_tabbar")
        tabBar.items?.last?.image = UIImage(named: "profile_tabbar")
        
        if Config.currentUserId == nil {
            Config.currentUserId = users.randomElement()
        }
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
        guard ChatClient.shared.connectionState == .disconnected
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
