import Foundation
import SceytCallUIKitCore
import XCTest
@testable import SceytDemoApp

final class DemoPushServiceTests: XCTestCase {
    @MainActor
    func testVoIPTokenIsDeferredBySDKAndDeduplicatedAgainstServer() async {
        let client = StubPushClient()
        let service = makeService(client: client)
        let token = Data([0x01, 0xab])
        service.registerVoIPToken(token)
        XCTAssertEqual(client.voIPRegistrations, [token])
        client.isConnected = true
        client.registeredVoIPTokens = ["01ab"]
        await service.registerHeldTokens()
        XCTAssertEqual(client.voIPRegistrations, [token])
    }

    @MainActor
    func testDeviceTokenWaitsForSignInAndConnection() async {
        let client = StubPushClient()
        var startCount = 0
        let service = makeService(client: client, signedIn: false, start: { startCount += 1 })
        let token = Data([0x02])
        service.registerDeviceToken(token)
        await service.registerHeldTokens()
        XCTAssertTrue(client.deviceRegistrations.isEmpty)
        client.isConnected = true
        service.connectionDidBecomeAvailable()
        await service.registerHeldTokens()
        XCTAssertEqual(startCount, 1)
        XCTAssertEqual(client.deviceRegistrations, [token])
        await service.registerHeldTokens()
        XCTAssertEqual(client.deviceRegistrations, [token])
    }

    @MainActor
    func testFailedDeviceRegistrationIsRetriedOnConnection() async {
        let client = StubPushClient()
        client.isConnected = true
        client.registrationError = PushError()
        let service = makeService(client: client)
        let token = Data([0x03])
        service.registerDeviceToken(token)
        await service.registerHeldTokens()
        XCTAssertEqual(client.deviceRegistrations, [token])
        client.registrationError = nil
        service.connectionDidBecomeAvailable()
        await service.registerHeldTokens()
        XCTAssertEqual(client.deviceRegistrations, [token, token])
    }

    @MainActor
    func testTokenRotationDuringRegistrationSendsLatestToken() async {
        let client = StubPushClient()
        client.isConnected = true
        let began = expectation(description: "First registration began")
        var continuation: CheckedContinuation<Void, Never>?
        client.beforeDeviceRegistration = { token in
            if token == Data([0x04]) {
                await withCheckedContinuation {
                    continuation = $0
                    began.fulfill()
                }
            }
        }
        let service = makeService(client: client)
        service.registerDeviceToken(Data([0x04]))
        await fulfillment(of: [began], timeout: 2)
        service.registerDeviceToken(Data([0x05]))
        continuation?.resume()
        await service.registerHeldTokens()
        XCTAssertEqual(client.deviceRegistrations, [Data([0x04]), Data([0x05])])
    }

    @MainActor
    func testLogoutWaitsForRegistrationThenStopsDeliveryUntilNextSignIn() async {
        let client = StubPushClient()
        client.isConnected = true
        let began = expectation(description: "Registration began")
        let stopped = expectation(description: "PushKit stopped")
        var continuation: CheckedContinuation<Void, Never>?
        client.beforeDeviceRegistration = { _ in
            await withCheckedContinuation {
                continuation = $0
                began.fulfill()
            }
        }
        var reconnectCount = 0
        let service = makeService(client: client, stop: { stopped.fulfill() }, reconnect: { reconnectCount += 1 })
        service.start()
        service.registerVoIPToken(Data([0x06]))
        service.registerDeviceToken(Data([0x07]))
        await fulfillment(of: [began], timeout: 2)
        let logout = Task { await service.unregisterForLogout() }
        await fulfillment(of: [stopped], timeout: 2)
        service.incomingPushDidArrive()
        XCTAssertEqual(reconnectCount, 0)
        XCTAssertEqual(client.deviceUnregistrations, 0)
        continuation?.resume()
        let error = await logout.value
        XCTAssertNil(error)
        XCTAssertEqual(client.events, ["registerDevice", "unregisterVoIP", "unregisterDevice"])
        XCTAssertEqual(client.voIPUnregistrations, 1)
        client.beforeDeviceRegistration = nil
        service.registerVoIPToken(Data([0x08]))
        service.registerDeviceToken(Data([0x09]))
        await service.registerHeldTokens()
        XCTAssertEqual(client.voIPRegistrations, [Data([0x06])])
        XCTAssertEqual(client.deviceRegistrations, [Data([0x07])])
        service.connectionDidBecomeAvailable()
        await service.registerHeldTokens()
        XCTAssertEqual(client.voIPRegistrations, [Data([0x06]), Data([0x08])])
        XCTAssertEqual(client.deviceRegistrations, [Data([0x07]), Data([0x09])])
    }

    @MainActor
    func testFailedLogoutRestoresVoIPRegistrationAndIncomingPushHandling() async {
        let client = StubPushClient()
        client.isConnected = true
        client.unregistrationError = PushError()
        var startCount = 0
        var stopCount = 0
        var reconnectCount = 0
        let service = makeService(client: client, start: { startCount += 1 }, stop: { stopCount += 1 },
                                  reconnect: { reconnectCount += 1 })
        let token = Data([0x0a])
        service.start()
        service.registerVoIPToken(token)
        let error = await service.unregisterForLogout()
        XCTAssertNotNil(error)
        XCTAssertEqual(startCount, 2)
        XCTAssertEqual(stopCount, 1)
        XCTAssertEqual(client.voIPRegistrations, [token, token])
        service.incomingPushDidArrive()
        XCTAssertEqual(reconnectCount, 1)
    }

    @MainActor
    func testInvalidatedVoIPTokenIsNotRegisteredOnReconnect() async {
        let client = StubPushClient()
        let service = makeService(client: client)
        service.registerVoIPToken(Data([0x0b]))
        service.unregisterVoIPToken()
        client.isConnected = true
        service.connectionDidBecomeAvailable()
        await service.registerHeldTokens()
        XCTAssertEqual(client.voIPRegistrations, [Data([0x0b])])
        XCTAssertEqual(client.voIPUnregistrations, 1)
    }

    @MainActor
    func testSignedOutLaunchStopsExistingRegistryAndIgnoresIncomingPushHook() {
        let client = StubPushClient()
        var stopCount = 0
        var reconnectCount = 0
        let service = DemoPushService(client: client, isSignedIn: false, isVoIPRegistryActive: true,
                                      startVoIPPushes: {}, stopVoIPPushes: { stopCount += 1 },
                                      reconnect: { reconnectCount += 1 })
        service.start()
        service.incomingPushDidArrive()
        XCTAssertEqual(stopCount, 1)
        XCTAssertEqual(reconnectCount, 0)
    }

    @MainActor
    private func makeService(client: StubPushClient, signedIn: Bool = true,
                             start: @escaping () -> Void = {}, stop: @escaping () -> Void = {},
                             reconnect: @escaping () -> Void = {}) -> DemoPushService {
        DemoPushService(client: client, isSignedIn: signedIn,
                        startVoIPPushes: start, stopVoIPPushes: stop, reconnect: reconnect)
    }
}

private struct PushError: Error {}

@MainActor
private final class StubPushClient: ChatPushRegistering {
    var isConnected = false
    var registeredDeviceTokens = Set<String>()
    var registeredVoIPTokens = Set<String>()
    var deviceRegistrations = [Data]()
    var voIPRegistrations = [Data]()
    var deviceUnregistrations = 0
    var voIPUnregistrations = 0
    var events = [String]()
    var registrationError: Error?
    var unregistrationError: Error?
    var beforeDeviceRegistration: ((Data) async -> Void)?

    func registerDeviceToken(_ token: Data) async -> Error? {
        deviceRegistrations.append(token)
        events.append("registerDevice")
        await beforeDeviceRegistration?(token)
        if registrationError == nil { registeredDeviceTokens.insert(hex(token)) }
        return registrationError
    }

    func unregisterDeviceToken() async -> Error? {
        deviceUnregistrations += 1
        events.append("unregisterDevice")
        if unregistrationError == nil { registeredDeviceTokens.removeAll() }
        return unregistrationError
    }

    func registerVoIPToken(_ token: Data) {
        voIPRegistrations.append(token)
        registeredVoIPTokens.insert(hex(token))
    }

    func unregisterVoIPToken() {
        voIPUnregistrations += 1
        events.append("unregisterVoIP")
        registeredVoIPTokens.removeAll()
    }

    private func hex(_ token: Data) -> String { token.map { String(format: "%02x", $0) }.joined() }
}
