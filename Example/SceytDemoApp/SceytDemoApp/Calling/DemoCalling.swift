import Foundation
import SceytCall
import SceytCallUIKit
import SceytCallUIKitCore
import SceytChatUIKit
import UIKit

/// The demo owns calling; the reusable Chat UIKit has no call dependency.
@MainActor
enum DemoCalling {
    static var provider: ChatCallProviding?
    static private(set) var pushService: DemoPushService?
    private static var isLoggingOut = false

    @discardableResult
    static func initialize(reconnect: @escaping () -> Void) -> DemoCallProvider {
        if let provider = provider as? DemoCallProvider, SceytCallUIKit.isInitialized {
            return provider
        }
        CallClient.initialise(chatClient: SceytChatUIKit.shared.chatClient)
        SceytCallUIKit.shared.config.broadcastExtensionBundleIdentifier = Config.broadcastExtensionBundleIdentifier
        SceytCallUIKit.initialize()
        let provider = DemoCallProvider()
        self.provider = provider
        let bridge = SceytCallUIKit.pushBridge
        let pushes = DemoPushService(
            client: DefaultChatPushRegistering(client: SceytChatUIKit.shared.chatClient),
            isSignedIn: Config.currentUserId != nil || SceytChatUIKit.shared.isConnected,
            isVoIPRegistryActive: bridge != nil,
            startVoIPPushes: { [weak bridge] in bridge?.register() },
            stopVoIPPushes: { [weak bridge] in bridge?.unregister() },
            reconnect: {
                for scene in UIApplication.shared.connectedScenes {
                    (scene.delegate as? SceneDelegate)?.cancelPendingDisconnect()
                }
                reconnect()
            }
        )
        pushService = pushes
        bridge?.pushRegistration = pushes
        let previousPushHandler = bridge?.onPushReceived
        bridge?.onPushReceived = { [weak pushes] in
            previousPushHandler?()
            pushes?.incomingPushDidArrive()
        }
        // Call UIKit created its registry at launch; stop it until a user is signed in.
        pushes.start()
        if SceytChatUIKit.shared.isConnected { pushes.connectionDidBecomeAvailable() }
        return provider
    }

    @discardableResult
    static func handleCallUserActivity(_ userActivity: NSUserActivity) -> Bool {
        guard provider != nil else { return false }
        return SceytCallUIKit.handle(userActivity: userActivity)
    }

    static func logout(completion: @escaping (Error?) -> Void) {
        guard !isLoggingOut else { return }
        isLoggingOut = true
        Task {
            defer { isLoggingOut = false }
            await provider?.prepareForLogout()
            let error: Error?
            if let pushService {
                error = await pushService.unregisterForLogout()
            } else {
                error = await DefaultChatPushRegistering(client: SceytChatUIKit.shared.chatClient)
                    .unregisterDeviceToken()
            }
            if let error {
                await provider?.logoutDidFail()
                completion(error)
                return
            }
            ConnectionService.shared.removeDeviceToken()
            SceytChatUIKit.shared.disconnect()
            SceytChatUIKit.shared.setCurrentUserId(nil)
            SceytChatUIKit.shared.database.deleteAll()
            Config.currentUserId = nil
            Config.chatToken = nil
            completion(nil)
        }
    }
}
