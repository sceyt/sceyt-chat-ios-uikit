import Combine
import UIKit
import XCTest
import SceytChatUIKit
@testable import SceytDemoApp

final class ChatCallIntegrationTests: XCTestCase {
    @MainActor
    func testDirectCallRequiresSignedInMemberAndAvailablePeer() {
        let channel = directChannel()
        XCTAssertTrue(DemoCallProvider.isCallable(channel, currentUserId: "me"))
        XCTAssertFalse(DemoCallProvider.isCallable(channel, currentUserId: nil))
        XCTAssertFalse(DemoCallProvider.isCallable(channel, currentUserId: ""))
        XCTAssertFalse(DemoCallProvider.isCallable(channel, currentUserId: "other-account"))
        XCTAssertFalse(DemoCallProvider.isCallable(directChannel(peer: .init(id: "peer", blocked: true)), currentUserId: "me"))
        XCTAssertFalse(DemoCallProvider.isCallable(directChannel(peer: .init(id: "peer", activityState: .deleted)), currentUserId: "me"))
    }

    @MainActor
    func testSelfBroadcastAndUnsyncedConversationsCannotBeCalled() {
        let selfChannel = directChannel()
        selfChannel.decodedMetadata = .init(isSelf: 1)
        XCTAssertFalse(DemoCallProvider.isCallable(selfChannel, currentUserId: "me"))
        let broadcast = ChatChannel(id: 10, type: "broadcast", uri: "", userRole: "owner")
        XCTAssertFalse(DemoCallProvider.isCallable(broadcast, currentUserId: "me"))
        let unsynced = directChannel()
        unsynced.unSynched = true
        XCTAssertFalse(DemoCallProvider.isCallable(unsynced, currentUserId: "me"))
    }

    @MainActor
    func testGroupCallRequiresChannelMembership() {
        let member = ChatChannel(id: 10, type: "group", uri: "", userRole: "participant")
        let left = ChatChannel(id: 11, type: "group", uri: "")
        XCTAssertTrue(DemoCallProvider.isCallable(member, currentUserId: "me"))
        XCTAssertFalse(DemoCallProvider.isCallable(left, currentUserId: "me"))
    }

    @MainActor
    func testRosterFiltersSelfDuplicatesBlockedDeletedAndEmptyIds() {
        let members: [ChatChannelMember] = [
            .init(id: "me"), .init(id: "alice"), .init(id: "alice"),
            .init(id: ""), .init(id: "blocked", blocked: true),
            .init(id: "deleted", activityState: .deleted), .init(id: "bob")
        ]
        XCTAssertEqual(DemoCallProvider.participantIds(from: members, currentUserId: "me"), ["alice", "bob"])
    }

    @MainActor
    func testGroupRosterLoadsEveryPageBeforeInviting() async throws {
        let pages: [[ChatChannelMember]] = [
            [.init(id: "me"), .init(id: "alice")],
            [.init(id: "bob"), .init(id: "alice")],
            [.init(id: "carol")]
        ]
        var pageIndex = 0
        let members = try await DemoCallProvider.loadAllMemberPages(hasNext: { pageIndex < pages.count }) {
            defer { pageIndex += 1 }
            return pages[pageIndex]
        }
        XCTAssertEqual(pageIndex, 3)
        XCTAssertEqual(DemoCallProvider.participantIds(from: members, currentUserId: "me"), ["alice", "bob", "carol"])
    }

    @MainActor
    func testFailedRosterPageDoesNotReturnAPartialInvitationList() async {
        struct PageError: Error {}
        var pageIndex = 0
        do {
            _ = try await DemoCallProvider.loadAllMemberPages(hasNext: { true }) {
                defer { pageIndex += 1 }
                if pageIndex == 1 { throw PageError() }
                return [.init(id: "alice")]
            }
            XCTFail("A failed page must prevent starting a call with an incomplete roster")
        } catch {
            XCTAssertTrue(error is PageError)
            XCTAssertEqual(pageIndex, 2)
        }
    }

    @MainActor
    func testCancelledRosterDoesNotFetchAnyPages() async {
        var loadCount = 0
        let task = Task {
            try await DemoCallProvider.loadAllMemberPages(hasNext: { true }) {
                loadCount += 1
                return [.init(id: "alice")]
            }
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Cancellation must prevent an outgoing call")
        } catch {
            XCTAssertTrue(error is CancellationError)
            XCTAssertEqual(loadCount, 0)
        }
    }

    @MainActor
    func testConversationActionsFollowProviderAvailability() {
        let previous = DemoCalling.provider
        defer { DemoCalling.provider = previous }
        let provider = StubCallProvider()
        DemoCalling.provider = provider
        let controller = CallChannelViewController()
        controller.channelViewModel = ChannelViewModel(channel: directChannel())
        let buttons = controller.callBarButtonItems()
        XCTAssertEqual(buttons.compactMap(\.accessibilityIdentifier), [
            CallChannelViewController.videoCallIdentifier,
            CallChannelViewController.audioCallIdentifier
        ])
        XCTAssertNotNil(buttons[0].image)
        XCTAssertNotNil(buttons[1].image)
        controller.channelViewModel.isEditing = true
        XCTAssertTrue(controller.callBarButtonItems().isEmpty)
        controller.channelViewModel.isEditing = false
        controller.channelViewModel.isSearching = true
        XCTAssertTrue(controller.callBarButtonItems().isEmpty)
        controller.channelViewModel.isSearching = false
        XCTAssertEqual(controller.callBarButtonItems().count, 2)
        provider.available = false
        XCTAssertTrue(controller.callBarButtonItems().isEmpty)
        DemoCalling.provider = nil
        XCTAssertTrue(controller.callBarButtonItems().isEmpty)
    }

    @MainActor
    private func directChannel(peer: ChatChannelMember = .init(id: "peer")) -> ChatChannel {
        ChatChannel(id: 10, type: "direct", uri: "", members: [.init(id: "me"), peer])
    }
}

@MainActor
private final class StubCallProvider: ChatCallProviding {
    var available = true
    var availabilityPublisher: AnyPublisher<Bool, Never> { Just(available).eraseToAnyPublisher() }
    var isCallActive: Bool { false }
    func canStartCall(in channel: ChatChannel) -> Bool { available }
    func startCall(in channel: ChatChannel, isVideo: Bool, from presenter: UIViewController) async {}
    func prepareForLogout() async {}
}
