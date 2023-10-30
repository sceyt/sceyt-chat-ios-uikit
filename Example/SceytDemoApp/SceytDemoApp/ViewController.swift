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

class DemoTabBarController: UITabBarController, ChatClientDelegate {
    
    lazy var activityIndicatorView: UIActivityIndicatorView = {
        UIActivityIndicatorView(style: .large)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        UIBarButtonItem.appearance()
            .setTitleTextAttributes([
                .font: Appearance.Fonts.bold.withSize(16),
                .foregroundColor: Appearance.Colors.kitBlue
            ], for: [])
        UITabBar.appearance().tintColor = Appearance.Colors.kitBlue
        tabBar.items?.first?.image = UIImage(named: "chats_tabbar")
        
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
        getToken(user: user) {[weak self] token, error in
            guard let token = token else {
                if let error {
                    self?.showAlert(error: error)
                }
                return
            }
            self?.dismissSheet()
            Config.chatToken = token
            SCTUIKitConfig.connect(accessToken: token)
        }
    }
    
    private func getToken(user: String, callback: @escaping (_ token: String?, _ error: Error?) -> Void) {
        let urlString = (Config.genToken + user)
        guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
        let url = URL(string: encoded) else {
            callback(nil, NSError(domain: "com.sceyt.uikit.DemoApp", code: -1, userInfo: [NSLocalizedDescriptionKey: "\(Config.genToken + user)"]))
           return
       }
       URLSession.shared.dataTask(with: url) { (data, response, error) in
           func _callback(_ token: String?, _ error: Error?) {
               DispatchQueue.main.async {
                   callback(token, error)
               }
           }
           if let data = data {
               if let token =  (try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: String])?["token"] {
                   _callback(token, error)
               } else {
                   _callback(nil, NSError(domain: "com.sceyt.uikit.DemoApp", code: -2, userInfo: [NSLocalizedDescriptionKey: "\(String(describing: String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)))"]))
               }
           } else {
               _callback(nil, error)
           }
       }.resume()
    }
    
    func chatClient(_ chatClient: ChatClient, tokenWillExpire timeInterval: TimeInterval) {
        if let user = Config.currentUserId {
            getToken(user: user) { token, error in
                guard let token = token else {
                    return
                }
                Config.chatToken = token
                chatClient.update(token: token) { _ in
                    
                }
            }
        }
    }
    
    func chatClientTokenExpired(_ chatClient: ChatClient) {
        if let user = Config.currentUserId {
            getToken(user: user) { token, error in
                guard let token = token else {
                    return
                }
                Config.chatToken = token
                chatClient.connect(token: token)
            }
        }
    }
    
    func chatClient(_ chatClient: ChatClient, didChange state: ConnectionState, error: SceytError?) {
        if state == .connected {
            Config.currentUserId = chatClient.user.id
            SCTUIKitConfig.currentUserId = chatClient.user.id
            chatClient.setPresence(state: .online, status: "I'm online")
        }
    }
}
