//
//  AppDelegate.swift
//  SceytDemoApp
//
//  Created by Hovsep Keropyan on 28.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChatUIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        configureSceytChatUIKit()
        setupAppearance()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    func setupAppearance() {
        UIBarButtonItem.appearance()
            .setTitleTextAttributes([
                .font: Appearance.Fonts.bold.withSize(16),
                .foregroundColor: UIColor.accent
            ], for: [])
        UITabBar.appearance().tintColor = UIColor.accent
        UISwitch.appearance().onTintColor = UIColor.accent
        UINavigationBar.appearance().standardAppearance = NavigationController.appearance.standard
        UINavigationBar.appearance().scrollEdgeAppearance = NavigationController.appearance.standard
    }
}

