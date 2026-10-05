import Foundation
import SceytCallUIKitCore

/// Owns the demo's push subscriptions across sign-in, connection changes, and logout.
/// PushKit delivery and synchronous CallKit reporting remain in Call UIKit's bridge.
@MainActor
final class DemoPushService: CallPushRegistering {
    private enum SessionState {
        case signedOut, active, loggingOut
    }

    private let client: ChatPushRegistering
    private let startVoIPPushes: () -> Void
    private let stopVoIPPushes: () -> Void
    private let reconnect: () -> Void
    private var sessionState: SessionState
    private var isVoIPRegistryActive: Bool
    private var voIPToken: Data?
    private var deviceToken: Data?
    private var deviceRegistrationTask: Task<Void, Never>?

    init(client: ChatPushRegistering,
         isSignedIn: Bool,
         isVoIPRegistryActive: Bool = false,
         startVoIPPushes: @escaping () -> Void,
         stopVoIPPushes: @escaping () -> Void,
         reconnect: @escaping () -> Void) {
        self.client = client
        sessionState = isSignedIn ? .active : .signedOut
        self.isVoIPRegistryActive = isVoIPRegistryActive
        self.startVoIPPushes = startVoIPPushes
        self.stopVoIPPushes = stopVoIPPushes
        self.reconnect = reconnect
    }

    func start() {
        if sessionState == .active {
            guard !isVoIPRegistryActive else { return }
            isVoIPRegistryActive = true
            startVoIPPushes()
        } else {
            stopRegistry()
        }
    }

    func connectionDidBecomeAvailable() {
        guard client.isConnected, sessionState != .loggingOut else { return }
        sessionState = .active
        start()
        registerVoIPTokenIfNeeded()
        startDeviceRegistrationIfNeeded()
    }

    /// Runs synchronously before Call UIKit reports the incoming call.
    func incomingPushDidArrive() {
        guard sessionState == .active else { return }
        // The host also cancels any pending background socket teardown here.
        reconnect()
    }

    func registerVoIPToken(_ token: Data) {
        voIPToken = token
        print("[Push] Received a VoIP token.")
        registerVoIPTokenIfNeeded()
    }

    func unregisterVoIPToken() {
        guard voIPToken != nil else { return }
        voIPToken = nil
        client.unregisterVoIPToken()
        print("[Push] Unregistered the VoIP token.")
    }

    private func registerVoIPTokenIfNeeded() {
        guard sessionState == .active, let token = voIPToken else { return }
        if client.isConnected, client.registeredVoIPTokens.contains(token.hexString) { return }
        // CallClient holds a VoIP token received before the socket connects.
        client.registerVoIPToken(token)
    }

    func registerDeviceToken(_ token: Data) {
        deviceToken = token
        startDeviceRegistrationIfNeeded()
    }

    func registerHeldTokens() async {
        guard sessionState == .active, client.isConnected else { return }
        registerVoIPTokenIfNeeded()
        startDeviceRegistrationIfNeeded()
        await deviceRegistrationTask?.value
    }

    private func startDeviceRegistrationIfNeeded() {
        guard sessionState == .active, client.isConnected,
              deviceToken != nil, deviceRegistrationTask == nil else { return }
        deviceRegistrationTask = Task { [weak self] in
            guard let self else { return }
            defer { self.deviceRegistrationTask = nil }
            while self.sessionState == .active, self.client.isConnected, let token = self.deviceToken {
                if self.client.registeredDeviceTokens.contains(token.hexString) { return }
                if let error = await self.client.registerDeviceToken(token) {
                    print("[Push] APNs registration failed; will retry on connection: \(error)")
                    return
                }
                // A rotated token may have arrived while registration was suspended.
                if self.deviceToken == token { return }
            }
        }
    }

    func unregisterDeviceToken() async {
        deviceToken = nil
        await deviceRegistrationTask?.value
        if let error = await client.unregisterDeviceToken() {
            print("[Push] APNs unregistration failed: \(error)")
        }
    }

    /// Waits for any registration already in flight before removing server subscriptions.
    /// On failure, restores push delivery for the user who remains signed in.
    func unregisterForLogout() async -> Error? {
        guard sessionState != .loggingOut else { return LogoutError.alreadyInProgress }
        let previousVoIPToken = voIPToken
        sessionState = .loggingOut
        stopRegistry()
        unregisterVoIPToken()
        await deviceRegistrationTask?.value
        if let error = await client.unregisterDeviceToken() {
            sessionState = .active
            voIPToken = previousVoIPToken
            start()
            if let token = previousVoIPToken { client.registerVoIPToken(token) }
            startDeviceRegistrationIfNeeded()
            return error
        }
        voIPToken = nil
        deviceToken = nil
        sessionState = .signedOut
        return nil
    }

    private func stopRegistry() {
        guard isVoIPRegistryActive else { return }
        isVoIPRegistryActive = false
        stopVoIPPushes()
    }

    private enum LogoutError: LocalizedError {
        case alreadyInProgress
        var errorDescription: String? { "Logout is already in progress." }
    }
}

private extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
