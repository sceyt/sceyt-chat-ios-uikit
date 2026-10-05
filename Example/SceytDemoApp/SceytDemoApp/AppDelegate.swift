//
//  AppDelegate.swift
//  SceytDemoApp
//
//  Created by Hovsep Keropyan on 28.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChatUIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        configureSceytChatUIKit()
        if !UITestSupport.isActive {
            DemoCalling.initialize(reconnect: {
                ConnectionService.shared.reconnectIfNeeded()
            })
        }
        UITestSupport.bootstrapIfNeeded()
        setupAppearance()
        // Skip the system push-permission prompt under UI tests: it would block
        // the channel list behind a system alert.
        if !UITestSupport.isActive {
            registerForPushNotifications()
        }

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
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        ConnectionService.shared.setDeviceToken(deviceToken)
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register: \(error)")
    }

    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        DemoCalling.handleCallUserActivity(userActivity)
    }
    
    func setupAppearance() {
        UIBarButtonItem.appearance()
            .setTitleTextAttributes([
                .font: Appearance.Fonts.bold.withSize(16),
                .foregroundColor: SceytChatUIKit.shared.theme.colors.accent
            ], for: [])
        UITabBar.appearance().tintColor = SceytChatUIKit.shared.theme.colors.accent
        UISwitch.appearance().onTintColor = SceytChatUIKit.shared.theme.colors.accent
        
        QRCodeViewController.appearance = QRCodeViewController.Appearance(
            reference: QRCodeViewController.appearance,
            logoImage: getAppIcon(),
            logoSize: CGSize(width: 50, height: 50),
            logoBackgroundColor: .white,
            logoCornerRadius: 12
        )
    }
    
    // MARK: - App Icon Helper
    
    private func getAppIcon() -> UIImage? {
        if let iconName = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
           let icon = UIImage(named: iconName) {
            return icon
        }
        
        if let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let firstIcon = iconFiles.first,
           let icon = UIImage(named: firstIcon) {
            return icon
        }
        
        return nil
    }
    
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().delegate = self
        // APNs registration is independent of permission to show notification alerts.
        // VoIP registration is owned by DemoPushService and Call UIKit's PushKit bridge.
        UIApplication.shared.registerForRemoteNotifications()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error { print("[Push] Notification authorization failed: \(error)") }
        }
    }

}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound, .badge])
    }
}
