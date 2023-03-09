//
//  SceneDelegate.swift
//  DemoApp
//
//

import UIKit
import SceytChatUIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        if window == nil, let windowScene = scene as? UIWindowScene {
            window = UIWindow(windowScene: windowScene)
            window!.rootViewController = ViewController()
            window!.makeKeyAndVisible()
        }
//        let colors = Appearance.Colors.self
//        colors.white = UIColor(hex: "#212F3D")
//        colors.blue = .brown
//        colors.red = .cyan
//        colors.textBlack = .blue
//        colors.textGray = .lightGray
//        colors.textGray2 = .darkGray
//        colors.background = .red
//        colors.background2 = .green
//        colors.background3 = UIColor(hex: "#239B56")
//        colors.background4 = UIColor(hex: "#7878b3")
//        colors.userColors = [UIColor(hex: "#82E0AA"), UIColor(hex: "#52BE80"), UIColor(hex: "##28B463"), UIColor(hex: "#1E8449"), UIColor(hex: "#186A3B")]

        window?.backgroundColor = .white
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
//        SyncService.syncChannels()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

