import Combine
import UIKit
import SceytChatUIKit

/// Connects conversation actions to a calling implementation.
@MainActor
protocol ChatCallProviding: AnyObject {
    /// Emits when connection, call state, or a pending start changes call availability.
    var availabilityPublisher: AnyPublisher<Bool, Never> { get }
    var isCallActive: Bool { get }
    func canStartCall(in channel: ChatChannel) -> Bool
    func startCall(in channel: ChatChannel, isVideo: Bool, from presenter: UIViewController) async
    func prepareForLogout() async
    func logoutDidFail() async
}

extension ChatCallProviding {
    func logoutDidFail() async {}
}
