//
//  GlobalSearchMessagesViewModelTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import XCTest
import Combine
import SceytChat

// MARK: - Testable subclass

/// Subclasses the real GlobalSearchMessagesViewModel to:
///   - bypass CoreData (no-op startDatabaseObserver)
///   - override applyFilter() with synchronous in-memory filtering so tests assert immediately
final class TestableGlobalSearchMessagesViewModel: GlobalSearchMessagesViewModel {

    // MARK: Injected data

    var allMessages: [ChatMessage] = []
    /// Channel type strings keyed by channelId — used when filterUser is set.
    var allChannelTypes: [ChannelId: String] = [:]

    func inject(messages: [ChatMessage], channelTypes: [ChannelId: String] = [:]) {
        allMessages = messages
        allChannelTypes = channelTypes
    }

    // MARK: Observer (no-op)

    override func startDatabaseObserver() {}

    // MARK: Search (synchronous, no Task)

    override func search(query: String?) {
        searchQuery = query
        applyFilter()
    }

    // MARK: Filter (in-memory, synchronous)

    override public func applyFilter() {
        defer { event = .reload }

        let tokens = (searchQuery ?? "")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }

        guard !tokens.isEmpty else {
            chatMessages = []
            channelMessages = []
            return
        }

        let bodyMatches: (ChatMessage) -> Bool = { message in
            guard message.state != .deleted, !message.body.isEmpty else { return false }
            let body = message.body.lowercased()
            return tokens.allSatisfy { token in
                let escaped = NSRegularExpression.escapedPattern(for: token)
                let pattern = "\\b\(escaped)"
                return body.range(of: pattern, options: .regularExpression) != nil
            }
        }

        let bodyFiltered = allMessages.filter(bodyMatches)

        if let filterUser = filterUser {
            // Direct channels containing this user: all messages matching the query.
            // Group channels containing this user: only messages sent by this user.
            let directMessages = bodyFiltered.filter {
                allChannelTypes[$0.channelId] == "direct"
            }
            let groupMessages = bodyFiltered.filter {
                allChannelTypes[$0.channelId] == "group"
                    && $0.user?.id == filterUser.id
            }
            chatMessages = directMessages + groupMessages
            channelMessages = []
        } else {
            chatMessages = bodyFiltered
            channelMessages = []
        }
    }
}

// MARK: - Tests

final class GlobalSearchMessagesViewModelTests: XCTestCase {

    private var viewModel: TestableGlobalSearchMessagesViewModel!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        viewModel = TestableGlobalSearchMessagesViewModel()
    }

    override func tearDown() {
        cancellables = []
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeMessage(
        id: MessageId = 1,
        channelId: ChannelId = 100,
        body: String = "",
        state: ChatMessage.State = .none,
        createdAt: Date = Date(),
        userId: String? = nil
    ) -> ChatMessage {
        let user = userId.map { ChatUser(id: $0) }
        return ChatMessage(
            id: id,
            channelId: channelId,
            body: body,
            createdAt: createdAt,
            state: state,
            user: user
        )
    }

    private func makeUser(id: String) -> ChatUser {
        ChatUser(id: id)
    }

    // MARK: - Empty / blank query

    func testEmptyQueryReturnsNoMessages() {
        viewModel.inject(messages: [makeMessage(id: 1, body: "Hello world")])
        viewModel.search(query: "")
        XCTAssertTrue(viewModel.messages.isEmpty, "Empty query should return no messages")
    }

    func testNilQueryReturnsNoMessages() {
        viewModel.inject(messages: [makeMessage(id: 1, body: "Hello world")])
        viewModel.search(query: nil)
        XCTAssertTrue(viewModel.messages.isEmpty, "Nil query should return no messages")
    }

    func testWhitespaceOnlyQueryReturnsNoMessages() {
        viewModel.inject(messages: [makeMessage(id: 1, body: "Hello world")])
        viewModel.search(query: "   ")
        XCTAssertTrue(viewModel.messages.isEmpty, "Whitespace-only query should return no messages")
    }

    // MARK: - Body text matching

    func testSearchByExactBodyText() {
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "Hello world"),
            makeMessage(id: 2, body: "Goodbye"),
        ])
        viewModel.search(query: "Hello world")
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    func testSearchByPartialBodyText() {
        // "Hell" is a prefix of "Hello" → should match (prefix-only search)
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "Hello world"),
            makeMessage(id: 2, body: "Goodbye"),
        ])
        viewModel.search(query: "Hell")
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    func testSearchBySuffixBodyTextShouldNotMatch() {
        // "ord" is a suffix of "world" → must NOT match (suffix-only matches are excluded)
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "Hello world"),
            makeMessage(id: 2, body: "Goodbye"),
        ])
        viewModel.search(query: "ord")
        XCTAssertTrue(viewModel.messages.isEmpty, "Suffix-only token 'ord' must not match 'world'")
    }

    func testSearchByMidWordBodyTextShouldNotMatch() {
        // "ello" is a mid/suffix match of "Hello" → must NOT match
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "Hello world"),
            makeMessage(id: 2, body: "Goodbye"),
        ])
        viewModel.search(query: "ello")
        XCTAssertTrue(viewModel.messages.isEmpty, "Mid-word token 'ello' must not match 'Hello'")
    }

    func testSearchBodyTextCaseInsensitive() {
        viewModel.inject(messages: [makeMessage(id: 1, body: "Hello World")])
        viewModel.search(query: "HELLO")
        XCTAssertEqual(viewModel.messages.count, 1, "Body text search must be case-insensitive")
    }

    func testSearchBodyTextCaseInsensitiveMixedCase() {
        viewModel.inject(messages: [makeMessage(id: 1, body: "Quick Brown Fox")])
        viewModel.search(query: "brown fox")
        XCTAssertEqual(viewModel.messages.count, 1)
    }

    func testQueryWithLeadingAndTrailingWhitespaceMatchesMessages() {
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "Hello world"),
            makeMessage(id: 2, body: "Goodbye"),
        ])
        viewModel.search(query: "  hello  ")
        XCTAssertEqual(viewModel.messages.count, 1, "Surrounding whitespace in query should be trimmed before matching")
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    func testHeavyWhitespaceAroundSingleTokenMatchesBody() {
        // "     hello    " → token ["hello"] → matches "Hello World"
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "Hello World"),
            makeMessage(id: 2, body: "Goodbye"),
        ])
        viewModel.search(query: "     hello    ")
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    func testMultiTokenQueryWithExcessWhitespaceBetweenTokensMatchesBody() {
        // "hello     world" → tokens ["hello", "world"] → both present in "hello there world today"
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "hello there world today"),
            makeMessage(id: 2, body: "hello there today"),   // "world" missing → no match
            makeMessage(id: 3, body: "Something else"),
        ])
        viewModel.search(query: "hello     world")
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    func testMultiTokenQueryDoesNotMatchWhenOnlyOneTokenPresent() {
        // "hello world" → both tokens must be present
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "hello there today"),   // only "hello", no "world"
        ])
        viewModel.search(query: "hello world")
        XCTAssertTrue(viewModel.messages.isEmpty, "All tokens must be present in the body")
    }

    func testMultiTokenQueryDoesNotMatchWhenOnlyOneTokenPresent2() {
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "good morning everyone"),
        ])
        viewModel.search(query: "oo")
        XCTAssertEqual(viewModel.messages.count, 0, "Mid-word token 'oo' must not match 'good'")
    }

    // MARK: - No match

    func testSearchWithNoMatchReturnsEmpty() {
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "Hello world"),
            makeMessage(id: 2, body: "Good morning"),
        ])
        viewModel.search(query: "xyzzy")
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    // MARK: - Multiple matches

    func testSearchReturnsMultipleMatches() {
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "Meeting at noon"),
            makeMessage(id: 2, body: "meeting postponed"),
            makeMessage(id: 3, body: "Have a nice day"),
        ])
        viewModel.search(query: "meeting")
        XCTAssertEqual(viewModel.messages.count, 2)
    }

    func testSearchReturnsAllMatchingMessages() {
        let bodies = ["Swift is great", "I love Swift", "Swift 5.9 released", "Kotlin is cool"]
        let messages = bodies.enumerated().map { i, body in makeMessage(id: MessageId(i + 1), body: body) }
        viewModel.inject(messages: messages)
        viewModel.search(query: "Swift")
        XCTAssertEqual(viewModel.messages.count, 3)
    }

    // MARK: - Deleted messages excluded

    func testDeletedMessagesAreExcluded() {
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "Hello", state: .none),
            makeMessage(id: 2, body: "Hello deleted", state: .deleted),
        ])
        viewModel.search(query: "Hello")
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    func testOnlyDeletedMessagesReturnsEmpty() {
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "Hello", state: .deleted),
            makeMessage(id: 2, body: "World", state: .deleted),
        ])
        viewModel.search(query: "Hello")
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testEditedMessagesAreIncluded() {
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "Edited message", state: .edited),
        ])
        viewModel.search(query: "Edited")
        XCTAssertEqual(viewModel.messages.count, 1, "Edited messages should still appear in results")
    }

    // MARK: - Empty body messages excluded

    func testEmptyBodyMessagesAreExcluded() {
        viewModel.inject(messages: [
            makeMessage(id: 1, body: ""),
            makeMessage(id: 2, body: "Has content"),
        ])
        // A single-space query should NOT match an empty body
        viewModel.search(query: "c")
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, 2)
    }

    // MARK: - Channel scoping

    func testMessagesFromDifferentChannelsAllMatched() {
        viewModel.inject(messages: [
            makeMessage(id: 1, channelId: 100, body: "project update"),
            makeMessage(id: 2, channelId: 200, body: "project deadline"),
            makeMessage(id: 3, channelId: 300, body: "lunch plans"),
        ])
        viewModel.search(query: "project")
        XCTAssertEqual(viewModel.messages.count, 2, "Results should span across channels when not channel-scoped")
    }

    func testChannelIdIsPreservedOnResult() {
        viewModel.inject(messages: [
            makeMessage(id: 1, channelId: 42, body: "important message"),
        ])
        viewModel.search(query: "important")
        XCTAssertEqual(viewModel.messages.first?.channelId, 42)
    }

    // MARK: - Accessor methods

    func testMessageAtValidIndex() {
        viewModel.inject(messages: [makeMessage(id: 7, body: "Test message")])
        viewModel.search(query: "Test")
        XCTAssertNotNil(viewModel.message(at: 0))
        XCTAssertEqual(viewModel.message(at: 0)?.id, 7)
    }

    func testMessageAtNegativeIndexReturnsNil() {
        viewModel.inject(messages: [makeMessage(id: 1, body: "Hello")])
        viewModel.search(query: "Hello")
        XCTAssertNil(viewModel.message(at: -1))
    }

    func testMessageAtOutOfBoundsIndexReturnsNil() {
        viewModel.inject(messages: [makeMessage(id: 1, body: "Hello")])
        viewModel.search(query: "Hello")
        XCTAssertNil(viewModel.message(at: 99))
    }

    func testNumberOfMessagesAfterSearch() {
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "Alpha"),
            makeMessage(id: 2, body: "Alpha Beta"),
            makeMessage(id: 3, body: "Gamma"),
        ])
        viewModel.search(query: "alpha")
        XCTAssertEqual(viewModel.numberOfMessages, 2)
    }

    func testNumberOfMessagesIsZeroBeforeSearch() {
        viewModel.inject(messages: [makeMessage(id: 1, body: "Hello")])
        XCTAssertEqual(viewModel.numberOfMessages, 0, "No results until search() is called")
    }

    // MARK: - Single character query

    func testSingleCharacterQuery() {
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "Apple"),
            makeMessage(id: 2, body: "Banana"),
        ])
        viewModel.search(query: "a")
        // Only "Apple" starts with 'a' (prefix-only matching; "Banana" starts with 'B')
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    // MARK: - Event publishing

    func testSearchPublishesReloadEvent() {
        viewModel.inject(messages: [makeMessage(id: 1, body: "Hello")])

        let expectation = XCTestExpectation(description: "reload event published")
        viewModel.$event
            .compactMap { $0 }
            .sink { event in
                if case .reload = event { expectation.fulfill() }
            }
            .store(in: &cancellables)

        viewModel.search(query: "Hello")
        wait(for: [expectation], timeout: 1.0)
    }

    func testEmptyQueryAlsoPublishesReloadEvent() {
        viewModel.inject(messages: [makeMessage(id: 1, body: "Hello")])

        let expectation = XCTestExpectation(description: "reload event published for empty query")
        viewModel.$event
            .compactMap { $0 }
            .sink { event in
                if case .reload = event { expectation.fulfill() }
            }
            .store(in: &cancellables)

        viewModel.search(query: "")
        wait(for: [expectation], timeout: 1.0)
    }

    func testNilQueryAlsoPublishesReloadEvent() {
        viewModel.inject(messages: [makeMessage(id: 1, body: "Hello")])

        let expectation = XCTestExpectation(description: "reload event published for nil query")
        viewModel.$event
            .compactMap { $0 }
            .sink { event in
                if case .reload = event { expectation.fulfill() }
            }
            .store(in: &cancellables)

        viewModel.search(query: nil)
        wait(for: [expectation], timeout: 1.0)
    }

    func testConsecutiveSearchesPublishMultipleReloadEvents() {
        viewModel.inject(messages: [makeMessage(id: 1, body: "Hello world")])

        let expectation = XCTestExpectation(description: "two reload events published")
        expectation.expectedFulfillmentCount = 2
        viewModel.$event
            .compactMap { $0 }
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        viewModel.search(query: "Hello")
        viewModel.search(query: "world")
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - filterUser: direct channel

    func testFilterUser_directChannel_showsAllMatchingMessages() {
        // In a direct channel both the current user's and the selected user's messages must appear.
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 10, body: "Hello there", userId: "me"),
                makeMessage(id: 2, channelId: 10, body: "Hello back",  userId: "alice"),
            ],
            channelTypes: [10: "direct"]
        )
        viewModel.search(query: "Hello")
        XCTAssertEqual(viewModel.messages.count, 2, "Direct channel: both parties' messages must appear")
    }

    func testFilterUser_directChannel_excludesNonMatchingQuery() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 10, body: "Hello", userId: "me"),
                makeMessage(id: 2, channelId: 10, body: "Goodbye", userId: "alice"),
            ],
            channelTypes: [10: "direct"]
        )
        viewModel.search(query: "Hello")
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    func testFilterUser_directChannel_allMessagesByEitherPartyIncluded() {
        // Five messages in one direct channel; query matches all — all five must appear.
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: (1...5).map { i in
                makeMessage(id: MessageId(i), channelId: 10, body: "meeting \(i)",
                            userId: i.isMultiple(of: 2) ? "alice" : "me")
            },
            channelTypes: [10: "direct"]
        )
        viewModel.search(query: "meeting")
        XCTAssertEqual(viewModel.messages.count, 5)
    }

    // MARK: - filterUser: group channel

    func testFilterUser_groupChannel_showsOnlyFilterUserMessages() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 20, body: "project update", userId: "alice"),
                makeMessage(id: 2, channelId: 20, body: "project deadline", userId: "bob"),
            ],
            channelTypes: [20: "group"]
        )
        viewModel.search(query: "project")
        XCTAssertEqual(viewModel.messages.count, 1, "Group channel: only filterUser's messages shown")
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    func testFilterUser_groupChannel_excludesOtherUsersMessages() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 20, body: "standup update", userId: "bob"),
                makeMessage(id: 2, channelId: 20, body: "standup notes",  userId: "carol"),
            ],
            channelTypes: [20: "group"]
        )
        viewModel.search(query: "standup")
        XCTAssertTrue(viewModel.messages.isEmpty, "Group channel: messages from other users must be excluded")
    }

    func testFilterUser_groupChannel_noMessagesFromFilterUser_returnsEmpty() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 20, body: "hello world", userId: "bob"),
            ],
            channelTypes: [20: "group"]
        )
        viewModel.search(query: "hello")
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    // MARK: - filterUser: mixed direct + group

    func testFilterUser_mixedChannels_correctResults() {
        // Channel 10 = direct, channel 20 = group.
        // Direct: both users' messages appear.
        // Group: only alice's messages appear.
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 10, body: "Hello from me",    userId: "me"),    // direct ✓
                makeMessage(id: 2, channelId: 10, body: "Hello from alice", userId: "alice"), // direct ✓
                makeMessage(id: 3, channelId: 20, body: "Hello alice group", userId: "alice"), // group ✓
                makeMessage(id: 4, channelId: 20, body: "Hello bob group",   userId: "bob"),  // group ✗
            ],
            channelTypes: [10: "direct", 20: "group"]
        )
        viewModel.search(query: "Hello")
        XCTAssertEqual(viewModel.messages.count, 3)
        let ids = Set(viewModel.messages.map { $0.id })
        XCTAssertTrue(ids.contains(1))
        XCTAssertTrue(ids.contains(2))
        XCTAssertTrue(ids.contains(3))
        XCTAssertFalse(ids.contains(4))
    }

    // MARK: - filterUser nil: existing behavior unchanged

    func testNoFilterUser_returnsAllMatchingMessages() {
        viewModel.filterUser = nil
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 10, body: "Hello", userId: "me"),
                makeMessage(id: 2, channelId: 10, body: "Hello", userId: "alice"),
                makeMessage(id: 3, channelId: 20, body: "Hello", userId: "bob"),
            ],
            channelTypes: [10: "direct", 20: "group"]
        )
        viewModel.search(query: "Hello")
        XCTAssertEqual(viewModel.messages.count, 3, "No filterUser: all matching messages returned")
    }

    // MARK: - filterUser with empty query

    func testFilterUser_emptyQuery_returnsNoMessages() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [makeMessage(id: 1, channelId: 10, body: "Hello", userId: "alice")],
            channelTypes: [10: "direct"]
        )
        viewModel.search(query: "")
        XCTAssertTrue(viewModel.messages.isEmpty, "Empty query returns nothing even with filterUser set")
    }

    func testFilterUser_nilQuery_returnsNoMessages() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [makeMessage(id: 1, channelId: 10, body: "Hello", userId: "alice")],
            channelTypes: [10: "direct"]
        )
        viewModel.search(query: nil)
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    // MARK: - filterUser: channel type unknown / unregistered

    func testFilterUser_channelWithUnknownType_excluded() {
        // Message in a channel with no registered type — should be excluded when filterUser is set.
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [makeMessage(id: 1, channelId: 99, body: "Hello", userId: "alice")],
            channelTypes: [:]  // channel 99 not registered
        )
        viewModel.search(query: "Hello")
        XCTAssertTrue(viewModel.messages.isEmpty, "Messages in channels with unknown type must be excluded")
    }
}
