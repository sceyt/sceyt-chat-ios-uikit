//
//  ConnectionService.swift
//  SceytDemoApp
//
//  Created by Hovsep Keropyan on 16.01.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import SceytChatUIKit
import UIKit

final class ConnectionService: ClientConnectionHandler {
    
    static let shared = ConnectionService()
    
    required init() {
        super.init()
        SceytChatUIKit.shared.chatClient.add(delegate: self, identifier: String(reflecting: self))
    }
    
    deinit {
        SceytChatUIKit.shared.chatClient.removeDelegate(identifier: String(reflecting: self))
    }
    
    private var deviceToken: Data?
    func setDeviceToken(_ deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")

        if SceytChatUIKit.shared.chatClient.connectionState == .connected {
            print("Device Token: Attempting to set \(token)")
            guard Config.deviceToken != deviceToken else {
                print("Device Token: Already set. Stored token \((Config.deviceToken ?? Data()).map { data in String(format: "%02.2hhx", data) }.joined() )")
                return
            }
            SceytChatUIKit.shared.chatClient.registerDevicePushToken(deviceToken) { error in
                if let error {
                    print("Device Token: Received error while registering \(error)")
                }
                print("Device Token: Registered")
            }
            
            Config.deviceToken = deviceToken
            print("Device Token: Did set \(token)")
        } else {
            print("Device Token: Saved to set later")
            self.deviceToken = deviceToken
        }
    }
    
    func removeDeviceToken() {
        print("Device Token: Removing and unregustering for push notifications")
        UIApplication.shared.unregisterForRemoteNotifications()
        Config.deviceToken = nil
    }

    private var callbacks = [((Error?) -> Void)]()
    func connect(username: String, callback: @escaping (Error?) -> Void) {
        getToken(user: username) { token, error in
            guard let token = token else {
                callback(error)
                return
            }
            Config.chatToken = token
            SceytChatUIKit.shared.connect(token: token)
            self.callbacks.append(callback)
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
    
    //MARK: ChatClientDelegate
    func chatClient(_ chatClient: ChatClient, tokenWillExpire timeInterval: TimeInterval) {
        if let user = Config.currentUserId {
            getToken(user: user) { token, error in
                guard let token = token else {
                    return
                }
                Config.chatToken = token
                SceytChatUIKit.shared.chatClient.update(token: token) { _ in
                    
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
                SceytChatUIKit.shared.chatClient.connect(token: token)
            }
        }
    }
    
    override func chatClient(_ chatClient: ChatClient, didChange state: ConnectionState, error: SceytError?) {
        super.chatClient(chatClient, didChange: state, error: error)
        if state == .connected {
            Config.currentUserId = chatClient.user.id
            SceytChatUIKit.shared.chatClient.setPresence(state: .online, status: "I'm online")
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "userProfileUpdated"), object: nil)
            if let deviceToken {
                print("Device Token: Setting saved device token and registering for push notifications")
                (UIApplication.shared.delegate as? AppDelegate)?.registerForPushNotifications()
            }
        }
        switch state {
        case .connected, .disconnected, .failed:
            let cbs = callbacks
            callbacks.removeAll()
            cbs.forEach {
                $0(error)
            }
        default:
            break
        }
    }
}
