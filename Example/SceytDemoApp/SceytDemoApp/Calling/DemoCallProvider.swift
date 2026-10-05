import Combine
import SceytCall
import SceytCallUIKit
import SceytCallUIKitCore
import SceytChat
import SceytChatUIKit
import UIKit

/// Launches permission-aware direct and group calls from a chat conversation.
@MainActor
final class DemoCallProvider: NSObject, ChatCallProviding, ChatClientDelegate {
    private let availability = CurrentValueSubject<Bool, Never>(false)
    private var subscriptions = Set<AnyCancellable>()
    private var isConnected = false
    private var isStarting = false
    private var isLoggingOut = false
    private var hasLoggedOut = false
    private var sessionGeneration = 0
    private let delegateIdentifier = "SceytDemoApp.Calling.\(UUID().uuidString)"

    var availabilityPublisher: AnyPublisher<Bool, Never> {
        availability.removeDuplicates().eraseToAnyPublisher()
    }

    var isCallActive: Bool {
        isStarting || SceytCallUIKit.controllerIfInitialized?.state.phase.isOngoing == true
    }

    override init() {
        super.init()
        let client = SceytChatUIKit.shared.chatClient
        isConnected = client.connectionState == .connected
        client.add(delegate: self, identifier: delegateIdentifier)
        SceytCallUIKit.controller.statePublisher
            .sink { [weak self] _ in self?.updateAvailability() }
            .store(in: &subscriptions)

        updateAvailability()
    }

    deinit {
        SceytChatUIKit.shared.chatClient.removeDelegate(identifier: delegateIdentifier)
    }

    func canStartCall(in channel: ChatChannel) -> Bool {
        guard availability.value else { return false }
        return Self.isCallable(channel, currentUserId: SceytChatUIKit.shared.currentUserId)
    }

    static func isCallable(_ channel: ChatChannel, currentUserId: String?) -> Bool {
        guard let currentUserId, !currentUserId.isEmpty,
              !channel.isSelfChannel, channel.channelType != .broadcast,
              channel.id != 0, !channel.unSynched else { return false }
        if channel.isDirect {
            guard let members = channel.members,
                  members.contains(where: { $0.id == currentUserId }) else { return false }
            return members.contains {
                $0.id != currentUserId && !$0.id.isEmpty && !$0.blocked && $0.state == .active
            }
        }
        return channel.userRole != nil
    }

    static func participantIds(from members: [ChatChannelMember], currentUserId: String) -> [String] {
        var seen = Set<String>()
        return members.compactMap {
            guard !$0.id.isEmpty, $0.id != currentUserId, !$0.blocked, $0.state == .active,
                  seen.insert($0.id).inserted else { return nil }
            return $0.id
        }
    }

    func startCall(in channel: ChatChannel, isVideo: Bool, from presenter: UIViewController) async {
        guard canStartCall(in: channel), let userId = SceytChatUIKit.shared.currentUserId else { return }
        isStarting = true
        updateAvailability()
        let generation = sessionGeneration
        defer {
            isStarting = false
            updateAvailability()
        }
        do {
            let members = channel.isDirect ? (channel.members ?? []) : try await loadMembers(channelId: channel.id)
            try Task.checkCancellation()
            guard generation == sessionGeneration, isConnected,
                  SceytChatUIKit.shared.currentUserId == userId else { return }
            let participantIds = Self.participantIds(from: members, currentUserId: userId)
            guard !participantIds.isEmpty else { throw StartError.noParticipants }
            guard let decision = await SceytCallUIKit.permissions?.resolveJoin(isVideoCall: isVideo, from: presenter) else {
                return // The permission coordinator has already explained a refusal.
            }
            try Task.checkCancellation()
            // Permission prompts suspend: the user may log out or receive a call while one is up.
            guard generation == sessionGeneration, isConnected,
                  SceytChatUIKit.shared.currentUserId == userId,
                  SceytCallUIKit.controller.state.phase.isOngoing == false else { return }
            let result = await SceytCallUIKit.controller.startCall(
                participantIds: participantIds,
                isVideo: isVideo,
                mediaFlow: channel.isDirect ? .p2p : .sfu,
                publishesVideo: decision.publishesVideo
            )
            // Logout can happen while creation/joining is suspended.
            guard generation == sessionGeneration, !Task.isCancelled else {
                if case .success(let call) = result,
                   SceytCallUIKit.controllerIfInitialized?.state.callId == call.id {
                    _ = SceytCallUIKit.controllerIfInitialized?.leaveCall()
                }
                return
            }
            if case .failure(let error) = result {
                presenter.showAlert(error: error)
            }
        } catch is CancellationError {
            // Navigating away before member loading completes cancels the start.
        } catch {
            guard generation == sessionGeneration else { return }
            presenter.showAlert(error: error)
        }
    }

    private func loadMembers(channelId: ChannelId) async throws -> [ChatChannelMember] {
        // A group roster is paginated; inviting only the profile's loaded page would omit members.
        let query = MemberListQuery.Builder(channelId: channelId)
            .limit(UInt(max(1, SceytChatUIKit.shared.config.queryLimits.channelMemberListQueryLimit)))
            .queryType(.all)
            .build()
        return try await Self.loadAllMemberPages(hasNext: { query.hasNext }) {
            let page: [Member] = try await withCheckedThrowingContinuation { continuation in
                query.loadNext { _, members, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: members ?? []) }
                }
            }
            return page.map { ChatChannelMember(member: $0) }
        }
    }

    static func loadAllMemberPages(hasNext: () -> Bool,
                                   loadNext: () async throws -> [ChatChannelMember]) async throws -> [ChatChannelMember] {
        var members = [ChatChannelMember]()
        repeat {
            try Task.checkCancellation()
            let page = try await loadNext()
            try Task.checkCancellation()
            members.append(contentsOf: page)
            if page.isEmpty { break }
        } while hasNext()
        return members
    }

    func prepareForLogout() async {
        sessionGeneration += 1
        isLoggingOut = true
        hasLoggedOut = true
        isConnected = false
        updateAvailability()
        _ = SceytCallUIKit.controllerIfInitialized?.leaveCall()
        SceytCallUIKit.router?.dismiss(animated: false)
    }

    func logoutDidFail() async {
        isLoggingOut = false
        hasLoggedOut = false
        isConnected = SceytChatUIKit.shared.isConnected
        updateAvailability()
    }

    nonisolated func chatClient(_ chatClient: ChatClient, didChange state: ConnectionState, error: SceytError?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            isConnected = state == .connected
            if state == .disconnected { isLoggingOut = false }
            if isConnected && !isLoggingOut { hasLoggedOut = false }
            if SceytCallUIKit.chatConnection == nil {
                SceytCallUIKit.controllerIfInitialized?.chatConnectionDidChange(isConnected: isConnected)
            }
            updateAvailability()
        }
    }

    private func updateAvailability() {
        availability.send(isConnected && !isLoggingOut && !hasLoggedOut && !isCallActive && SceytCallUIKit.isInitialized)
    }

    private enum StartError: LocalizedError {
        case noParticipants
        var errorDescription: String? {
            NSLocalizedString("call.noParticipants", bundle: .main,
                              value: "There are no available participants to call.", comment: "")
        }
    }
}
