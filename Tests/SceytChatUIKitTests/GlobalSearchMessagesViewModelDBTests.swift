//
//  GlobalSearchMessagesViewModelDBTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import XCTest
import Combine
import CoreData
import SceytChat

// MARK: - DB-backed testable subclass

/// Subclasses GlobalSearchMessagesViewModel and overrides `database`
/// to inject an in-memory MockDatabase instead of the live SQLite store.
final class DBTestableGlobalSearchMessagesViewModel: GlobalSearchMessagesViewModel {

    let mockDB: MockDatabase

    init(mockDB: MockDatabase) {
        self.mockDB = mockDB
        super.init()
    }

    required init() {
        fatalError("use init(mockDB:)")
    }

    override var database: Database { mockDB }
    override func startDatabaseObserver() {}
}

// MARK: - Tests

final class GlobalSearchMessagesViewModelDBTests: XCTestCase {

    private var mockDB: MockDatabase!
    private var viewModel: DBTestableGlobalSearchMessagesViewModel!
    private var cancellables: Set<AnyCancellable> = []

    private var directType: String { SceytChatUIKit.shared.config.channelTypesConfig.direct }
    private var groupType: String { SceytChatUIKit.shared.config.channelTypesConfig.group }
    private var broadcastType: String { SceytChatUIKit.shared.config.channelTypesConfig.broadcast }

    override func setUp() {
        super.setUp()
        mockDB = MockDatabase()
        viewModel = DBTestableGlobalSearchMessagesViewModel(mockDB: mockDB)
    }

    override func tearDown() {
        cancellables = []
        viewModel = nil
        mockDB = nil
        super.tearDown()
    }

    // MARK: - Seed helpers

    private func seedChannel(id: ChannelId, type: String) {
        let ctx = mockDB.container.viewContext
        let (ch, _) = ChannelDTO.fetchOrCreate(id: id, context: ctx)
        ch.type = type
        try? ctx.save()
    }

    private func seedMessage(id: MessageId,
                             channelId: ChannelId,
                             body: String,
                             userId: String = "u1",
                             state: Int16 = 0,
                             transient: Bool = false) {
        let ctx = mockDB.container.viewContext
        let user = UserDTO.fetchOrCreate(id: userId, context: ctx)
        let msg = MessageDTO.fetchOrCreate(id: id, tid: Int64(id), context: ctx)
        msg.channelId = Int64(channelId)
        msg.body = body
        msg.state = state
        msg.transient = transient
        msg.user = user
        msg.createdAt = Date().bridgeDate
        try? ctx.save()
    }

    private func seedMember(userId: String, channelId: ChannelId) {
        let ctx = mockDB.container.viewContext
        let user = UserDTO.fetchOrCreate(id: userId, context: ctx)
        let member = MemberDTO.fetchOrCreate(id: userId, channelId: channelId, context: ctx)
        member.user = user
        try? ctx.save()
    }

    /// Subscribes to `$event`, calls `action`, and waits for `.reload` to be published.
    private func waitForReload(timeout: TimeInterval = 3.0, action: () -> Void) {
        let exp = expectation(description: "reload event")
        viewModel.$event
            .compactMap { $0 }
            .first { if case .reload = $0 { return true }; return false }
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)
        action()
        wait(for: [exp], timeout: timeout)
    }

    // MARK: - Basic matching

    func testDB_matchingMessageInDirectChannel() {
        seedChannel(id: 10, type: directType)
        seedMessage(id: 1, channelId: 10, body: "Hello world")
        seedMessage(id: 2, channelId: 10, body: "Goodbye")

        waitForReload { viewModel.search(query: "Hello") }

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    func testDB_matchingMessageInGroupChannel() {
        seedChannel(id: 20, type: groupType)
        seedMessage(id: 1, channelId: 20, body: "project update")

        waitForReload { viewModel.search(query: "project") }

        XCTAssertEqual(viewModel.numberOfMessages(in: .chats), 1)
        XCTAssertEqual(viewModel.numberOfMessages(in: .channels), 0)
    }

    func testDB_noMatchReturnsEmpty() {
        seedChannel(id: 10, type: directType)
        seedMessage(id: 1, channelId: 10, body: "Hello world")

        waitForReload { viewModel.search(query: "xyzzy") }

        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testDB_multipleMatchesAcrossChannels() {
        seedChannel(id: 10, type: directType)
        seedChannel(id: 20, type: groupType)
        seedMessage(id: 1, channelId: 10, body: "meeting at noon")
        seedMessage(id: 2, channelId: 20, body: "meeting postponed")
        seedMessage(id: 3, channelId: 10, body: "lunch plans")

        waitForReload { viewModel.search(query: "meeting") }

        XCTAssertEqual(viewModel.messages.count, 2)
    }

    // MARK: - Section split: chats vs channels

    func testDB_broadcastMessagesGoToChannelSection() {
        seedChannel(id: 10, type: directType)
        seedChannel(id: 30, type: broadcastType)
        seedMessage(id: 1, channelId: 10, body: "update from chat")
        seedMessage(id: 2, channelId: 30, body: "update from broadcast")

        waitForReload { viewModel.search(query: "update") }

        XCTAssertEqual(viewModel.numberOfMessages(in: .chats), 1)
        XCTAssertEqual(viewModel.numberOfMessages(in: .channels), 1)
    }

    func testDB_channelMapPopulatedForChatResults() {
        seedChannel(id: 10, type: directType)
        seedMessage(id: 1, channelId: 10, body: "Hello")

        waitForReload { viewModel.search(query: "Hello") }

        XCTAssertNotNil(viewModel.chatMessageChannels[10], "chatMessageChannels should contain channel 10")
    }

    func testDB_channelMapPopulatedForBroadcastResults() {
        seedChannel(id: 30, type: broadcastType)
        seedMessage(id: 1, channelId: 30, body: "broadcast news")

        waitForReload { viewModel.search(query: "broadcast") }

        XCTAssertNotNil(viewModel.channelMessageChannels[30])
    }

    // MARK: - Message exclusions

    func testDB_deletedMessagesExcluded() {
        seedChannel(id: 10, type: directType)
        seedMessage(id: 1, channelId: 10, body: "Hello active", state: 0)
        seedMessage(id: 2, channelId: 10, body: "Hello deleted", state: 2) // deleted

        waitForReload { viewModel.search(query: "Hello") }

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    func testDB_transientMessagesExcluded() {
        seedChannel(id: 10, type: directType)
        seedMessage(id: 1, channelId: 10, body: "Hello real")
        seedMessage(id: 2, channelId: 10, body: "Hello transient", transient: true)

        waitForReload { viewModel.search(query: "Hello") }

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    func testDB_emptyBodyMessagesExcluded() {
        seedChannel(id: 10, type: directType)
        seedMessage(id: 1, channelId: 10, body: "")
        seedMessage(id: 2, channelId: 10, body: "Hello")

        waitForReload { viewModel.search(query: "Hello") }

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, 2)
    }

    // MARK: - Empty / nil query clears results

    func testDB_emptyQueryClearsResults() {
        seedChannel(id: 10, type: directType)
        seedMessage(id: 1, channelId: 10, body: "Hello")

        waitForReload { viewModel.search(query: "Hello") }
        XCTAssertEqual(viewModel.messages.count, 1)

        waitForReload { viewModel.search(query: "") }
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testDB_nilQueryClearsResults() {
        seedChannel(id: 10, type: directType)
        seedMessage(id: 1, channelId: 10, body: "Hello")

        waitForReload { viewModel.search(query: "Hello") }
        waitForReload { viewModel.search(query: nil) }

        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    // MARK: - filterUser

    func testDB_filterUser_showsOnlyThatUserMessages() {
        seedChannel(id: 10, type: directType)
        seedMember(userId: "alice", channelId: 10)
        seedMessage(id: 1, channelId: 10, body: "Hello", userId: "me")
        seedMessage(id: 2, channelId: 10, body: "Hello", userId: "alice")

        let alice = ChatUser(id: "alice")
        viewModel.filterUser = alice

        waitForReload { viewModel.search(query: "Hello") }

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, 2)
    }

    func testDB_filterUser_groupChannel_memberRestriction() {
        seedChannel(id: 20, type: groupType)
        seedMember(userId: "alice", channelId: 20)
        seedMessage(id: 1, channelId: 20, body: "standup update", userId: "alice")
        seedMessage(id: 2, channelId: 20, body: "standup notes", userId: "bob")

        let alice = ChatUser(id: "alice")
        viewModel.filterUser = alice

        waitForReload { viewModel.search(query: "standup") }

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    func testDB_filterUser_noMatchReturnsEmpty() {
        seedChannel(id: 10, type: directType)
        seedMember(userId: "alice", channelId: 10)
        seedMessage(id: 1, channelId: 10, body: "Hello", userId: "bob")

        let alice = ChatUser(id: "alice")
        viewModel.filterUser = alice

        waitForReload { viewModel.search(query: "Hello") }

        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    // MARK: - Accessor methods

    func testDB_messageAtIndexPath() {
        seedChannel(id: 10, type: directType)
        seedMessage(id: 7, channelId: 10, body: "important")

        waitForReload { viewModel.search(query: "important") }

        let msg = viewModel.message(at: IndexPath(row: 0, section: 0))
        XCTAssertNotNil(msg)
        XCTAssertEqual(msg?.id, 7)
    }

    func testDB_messageAtIndexPathOutOfBoundsReturnsNil() {
        seedChannel(id: 10, type: directType)
        seedMessage(id: 1, channelId: 10, body: "Hello")

        waitForReload { viewModel.search(query: "Hello") }

        XCTAssertNil(viewModel.message(at: IndexPath(row: 99, section: 0)))
    }

    // MARK: - Event publishing

    func testDB_searchPublishesReloadEvent() {
        seedChannel(id: 10, type: directType)
        seedMessage(id: 1, channelId: 10, body: "Hello")

        let exp = expectation(description: "reload published")
        viewModel.$event
            .compactMap { $0 }
            .sink { if case .reload = $0 { exp.fulfill() } }
            .store(in: &cancellables)

        viewModel.search(query: "Hello")
        wait(for: [exp], timeout: 3.0)
    }

    func testDB_consecutiveSearchesPublishMultipleReloadEvents() {
        seedChannel(id: 10, type: directType)
        seedMessage(id: 1, channelId: 10, body: "Hello world")

        // Wait for first search to complete before firing the second —
        // applyFilter cancels the in-flight Task on each call, so firing
        // both immediately would only produce one reload event.
        waitForReload { viewModel.search(query: "Hello") }
        waitForReload { viewModel.search(query: "world") }
    }
}
