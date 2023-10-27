//
//  DemoViewController.swift
//  DemoApp
//
//  Created by Hovsep Keropyan on 27.10.23.
//

import UIKit
import SceytChatUIKit

let users = ["zoe", "thomas", "ethan", "charlie", "william", "michael", "james", "john", "lily", "david", "grace", "emma", "olivia", "ben", "emily", "isabella", "sophia", "alice", "jacob", "harry"]

class DemoViewController: UITableViewController {
    
    lazy var activityIndicatorView: UIActivityIndicatorView = {
        UIActivityIndicatorView(style: .large)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Users"
        // Do any additional setup after loading the view.
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        users.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = users[indexPath.row]
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let user = users[indexPath.row]
        showSheet(activityIndicatorView, style: .center, backgroundDismiss: false) { [unowned self] in
            activityIndicatorView.startAnimating()
        }
        connect(user: user)
    }
    
    private func changeView() {
        dismissSheet()
        let tab = TabBarController()
        
        UIBarButtonItem.appearance()
            .setTitleTextAttributes([
                .font: Appearance.Fonts.bold.withSize(16),
                .foregroundColor: Appearance.Colors.kitBlue
            ], for: [])
        UITabBar.appearance().tintColor = Appearance.Colors.kitBlue
        let nav = NavigationController(rootViewController: SCTUIKitComponents.channelListVC.init())
        nav.modalPresentationStyle = .fullScreen
        tab.viewControllers = [nav]
        view.window?.rootViewController = tab
        tab.tabBar.items?.first?.image = UIImage(named: "chats_tabbar")
    }
    
    private func connect(user: String) {
        getToken(user: user) {[weak self] token, error in
            guard let token = token else {
                if let error {
                    self?.showAlert(error: error)
                }
                return
            }
            self?.changeView()
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
}

