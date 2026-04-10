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

        let trimmed = (searchQuery ?? "").trimmingCharacters(in: .whitespaces)
        let tokens = trimmed
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }

        let bodyMatches: (ChatMessage) -> Bool = { message in
            guard message.state != .deleted, !message.body.isEmpty else { return false }
            let body = message.body.lowercased()
            return tokens.allSatisfy { token in
                let escaped = NSRegularExpression.escapedPattern(for: token)
                let pattern = "\\b\(escaped)"
                return body.range(of: pattern, options: .regularExpression) != nil
            }
        }

        if let filterUser = filterUser {
            // User filter active:
            //   - Empty query  → show all messages from that user (no body filter).
            //   - Any query    → filter their messages by tokens (1+ char is enough).
            // Broadcast channels go to channelMessages; direct/group go to chatMessages.
            let userMessages = allMessages.filter {
                allChannelTypes[$0.channelId] != nil
                    && $0.user?.id == filterUser.id
                    && $0.state != .deleted
                    && !$0.body.isEmpty
            }
            let filtered = tokens.isEmpty ? userMessages : userMessages.filter(bodyMatches)
            chatMessages    = filtered.filter { allChannelTypes[$0.channelId] != "broadcast" }
            channelMessages = filtered.filter { allChannelTypes[$0.channelId] == "broadcast" }
        } else {
            // No user filter: require >= 2 characters before searching.
            guard trimmed.count >= 2, !tokens.isEmpty else {
                chatMessages = []
                channelMessages = []
                return
            }
            chatMessages = allMessages.filter(bodyMatches)
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

    // MARK: - Empty / blank query (no filterUser)

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

    // MARK: - Character count threshold (no filterUser)

    func testSingleCharacterQuery_noFilter_returnsEmpty() {
        // Without a user filter, a 1-character query is below the 2-char threshold.
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "Apple"),
            makeMessage(id: 2, body: "Banana"),
        ])
        viewModel.search(query: "a")
        XCTAssertTrue(viewModel.messages.isEmpty, "1-char query without filterUser must return nothing (threshold is >= 2)")
    }

    func testTwoCharacterQuery_noFilter_returnsResults() {
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "Apple"),
            makeMessage(id: 2, body: "Ant"),
            makeMessage(id: 3, body: "Banana"),
        ])
        viewModel.search(query: "an")
        // "Ant" starts with "an"; "Banana" does not start with "an" (mid-word only). Only "Ant" matches.
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, 2)
    }

    // MARK: - Body text matching (no filterUser, >= 2 chars)

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
        viewModel.search(query: "or")
        XCTAssertTrue(viewModel.messages.isEmpty, "Suffix-only token 'or' must not match 'world'")
    }

    func testSearchByMidWordBodyTextShouldNotMatch() {
        // "ello" is a mid/suffix match of "Hello" → must NOT match
        viewModel.inject(messages: [
            makeMessage(id: 1, body: "Hello world"),
            makeMessage(id: 2, body: "Goodbye"),
        ])
        viewModel.search(query: "el")
        XCTAssertTrue(viewModel.messages.isEmpty, "Mid-word token 'el' must not match 'Hello'")
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
        viewModel.search(query: "co")
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

    // MARK: - shouldShowMessagesSection

    func testShouldShowMessagesSection_noFilter_emptyQuery_isFalse() {
        viewModel.search(query: "")
        XCTAssertFalse(viewModel.shouldShowMessagesSection)
    }

    func testShouldShowMessagesSection_noFilter_oneChar_isFalse() {
        viewModel.search(query: "a")
        XCTAssertFalse(viewModel.shouldShowMessagesSection, "1 char without filterUser is below threshold")
    }

    func testShouldShowMessagesSection_noFilter_twoChars_isTrue() {
        viewModel.search(query: "ab")
        XCTAssertTrue(viewModel.shouldShowMessagesSection, "2 chars without filterUser meets threshold")
    }

    func testShouldShowMessagesSection_filterUser_emptyQuery_isTrue() {
        viewModel.filterUser = makeUser(id: "alice")
        viewModel.search(query: "")
        XCTAssertTrue(viewModel.shouldShowMessagesSection, "filterUser active → always show messages section")
    }

    func testShouldShowMessagesSection_filterUser_oneChar_isTrue() {
        viewModel.filterUser = makeUser(id: "alice")
        viewModel.search(query: "h")
        XCTAssertTrue(viewModel.shouldShowMessagesSection, "filterUser active → 1 char is enough to show section")
    }

    func testShouldShowMessagesSection_filterUser_nilQuery_isTrue() {
        viewModel.filterUser = makeUser(id: "alice")
        viewModel.search(query: nil)
        XCTAssertTrue(viewModel.shouldShowMessagesSection, "filterUser active → nil query still shows section")
    }

    // MARK: - filterUser: empty query shows all user messages

    func testFilterUser_emptyQuery_showsAllUserMessages() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 10, body: "Good morning",  userId: "alice"),
                makeMessage(id: 2, channelId: 10, body: "How are you",   userId: "alice"),
                makeMessage(id: 3, channelId: 10, body: "See you later", userId: "me"),
            ],
            channelTypes: [10: "direct"]
        )
        viewModel.search(query: "")
        XCTAssertEqual(viewModel.messages.count, 2, "Empty query with filterUser should show all user messages")
        let ids = Set(viewModel.messages.map { $0.id })
        XCTAssertTrue(ids.contains(1))
        XCTAssertTrue(ids.contains(2))
        XCTAssertFalse(ids.contains(3))
    }

    func testFilterUser_nilQuery_showsAllUserMessages() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 10, body: "Hello", userId: "alice"),
                makeMessage(id: 2, channelId: 10, body: "Hi",    userId: "me"),
            ],
            channelTypes: [10: "direct"]
        )
        viewModel.search(query: nil)
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    func testFilterUser_emptyQuery_excludesDeletedMessages() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 10, body: "Hello",   userId: "alice", state: .none),
                makeMessage(id: 2, channelId: 10, body: "Deleted", userId: "alice", state: .deleted),
            ],
            channelTypes: [10: "direct"]
        )
        viewModel.search(query: "")
        XCTAssertEqual(viewModel.messages.count, 1, "Deleted messages must be excluded even with empty query")
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    func testFilterUser_emptyQuery_excludesEmptyBodyMessages() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 10, body: "Hello", userId: "alice"),
                makeMessage(id: 2, channelId: 10, body: "",       userId: "alice"),
            ],
            channelTypes: [10: "direct"]
        )
        viewModel.search(query: "")
        XCTAssertEqual(viewModel.messages.count, 1, "Empty body messages must be excluded even with empty query")
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    // MARK: - filterUser: 1-char query filters user messages

    func testFilterUser_singleCharQuery_filtersUserMessages() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 10, body: "Apple",  userId: "alice"),
                makeMessage(id: 2, channelId: 10, body: "Banana", userId: "alice"),
                makeMessage(id: 3, channelId: 10, body: "Other",  userId: "me"),
            ],
            channelTypes: [10: "direct"]
        )
        viewModel.search(query: "a")
        XCTAssertEqual(viewModel.messages.count, 1, "filterUser active: 1-char query should filter results")
        XCTAssertEqual(viewModel.messages.first?.id, 1)
    }

    // MARK: - filterUser: direct channel

    func testFilterUser_directChannel_showsOnlyFilterUserMessages() {
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
        XCTAssertEqual(viewModel.messages.count, 1, "Direct channel: only the selected user's messages must appear")
        XCTAssertEqual(viewModel.messages.first?.id, 2)
    }

    func testFilterUser_directChannel_excludesMyOwnMessages() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 10, body: "Hello",   userId: "me"),
                makeMessage(id: 2, channelId: 10, body: "Goodbye", userId: "alice"),
            ],
            channelTypes: [10: "direct"]
        )
        viewModel.search(query: "Hello")
        XCTAssertTrue(viewModel.messages.isEmpty, "My own messages must not appear when filterUser is set")
    }

    func testFilterUser_directChannel_onlyFilterUserMessagesIncluded() {
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
        XCTAssertEqual(viewModel.messages.count, 2, "Only alice's messages (ids 2, 4) should be included")
        let ids = Set(viewModel.messages.map { $0.id })
        XCTAssertTrue(ids.contains(2))
        XCTAssertTrue(ids.contains(4))
    }

    // MARK: - filterUser: group channel

    func testFilterUser_groupChannel_showsOnlyFilterUserMessages() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 20, body: "project update",   userId: "alice"),
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
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 10, body: "Hello from me",    userId: "me"),    // direct ✗ (not alice)
                makeMessage(id: 2, channelId: 10, body: "Hello from alice", userId: "alice"), // direct ✓
                makeMessage(id: 3, channelId: 20, body: "Hello alice group", userId: "alice"), // group ✓
                makeMessage(id: 4, channelId: 20, body: "Hello bob group",   userId: "bob"),  // group ✗
            ],
            channelTypes: [10: "direct", 20: "group"]
        )
        viewModel.search(query: "Hello")
        XCTAssertEqual(viewModel.messages.count, 2)
        let ids = Set(viewModel.messages.map { $0.id })
        XCTAssertFalse(ids.contains(1))
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

    // MARK: - filterUser: channel type unknown / unregistered

    func testFilterUser_channelWithUnknownType_excluded() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [makeMessage(id: 1, channelId: 99, body: "Hello", userId: "alice")],
            channelTypes: [:]  // channel 99 not registered
        )
        viewModel.search(query: "Hello")
        XCTAssertTrue(viewModel.messages.isEmpty, "Messages in channels with unknown type must be excluded")
    }

    func testFilterUser_channelWithUnknownType_excludedEvenWithEmptyQuery() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [makeMessage(id: 1, channelId: 99, body: "Hello", userId: "alice")],
            channelTypes: [:]
        )
        viewModel.search(query: "")
        XCTAssertTrue(viewModel.messages.isEmpty, "Unknown-type channel excluded even when query is empty")
    }

    // MARK: - filterUser: broadcast channel messages

    func testFilterUser_broadcastChannel_emptyQuery_showsAllUserMessages() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 30, body: "Announcement", userId: "alice"),
                makeMessage(id: 2, channelId: 30, body: "Update",       userId: "alice"),
                makeMessage(id: 3, channelId: 30, body: "Other news",   userId: "admin"),
            ],
            channelTypes: [30: "broadcast"]
        )
        viewModel.search(query: "")
        XCTAssertTrue(viewModel.chatMessages.isEmpty, "Broadcast messages must not appear in chatMessages")
        XCTAssertEqual(viewModel.channelMessages.count, 2, "Both alice's broadcast messages shown with empty query")
        let ids = Set(viewModel.channelMessages.map { $0.id })
        XCTAssertTrue(ids.contains(1))
        XCTAssertTrue(ids.contains(2))
    }

    func testFilterUser_broadcastChannel_queryFiltersUserMessages() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 30, body: "Announcement today", userId: "alice"),
                makeMessage(id: 2, channelId: 30, body: "Update available",   userId: "alice"),
                makeMessage(id: 3, channelId: 30, body: "Announcement notes", userId: "admin"),
            ],
            channelTypes: [30: "broadcast"]
        )
        viewModel.search(query: "Announcement")
        XCTAssertEqual(viewModel.channelMessages.count, 1)
        XCTAssertEqual(viewModel.channelMessages.first?.id, 1)
    }

    func testFilterUser_broadcastChannel_singleCharQuery_filtersUserMessages() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 30, body: "Alert",  userId: "alice"),
                makeMessage(id: 2, channelId: 30, body: "Update", userId: "alice"),
            ],
            channelTypes: [30: "broadcast"]
        )
        viewModel.search(query: "a")
        XCTAssertEqual(viewModel.channelMessages.count, 1, "filterUser + 1-char query filters broadcast messages")
        XCTAssertEqual(viewModel.channelMessages.first?.id, 1)
    }

    func testFilterUser_mixedAllChannelTypes_correctSplit() {
        // Messages split correctly across chatMessages (direct/group) and channelMessages (broadcast).
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 10, body: "Hello direct",    userId: "alice"), // direct → chat
                makeMessage(id: 2, channelId: 20, body: "Hello group",     userId: "alice"), // group → chat
                makeMessage(id: 3, channelId: 30, body: "Hello broadcast", userId: "alice"), // broadcast → channel
                makeMessage(id: 4, channelId: 10, body: "Hello from me",   userId: "me"),    // direct, wrong user
                makeMessage(id: 5, channelId: 30, body: "Hello from admin",userId: "admin"), // broadcast, wrong user
            ],
            channelTypes: [10: "direct", 20: "group", 30: "broadcast"]
        )
        viewModel.search(query: "")
        XCTAssertEqual(viewModel.chatMessages.count, 2)
        XCTAssertEqual(viewModel.channelMessages.count, 1)
        XCTAssertEqual(Set(viewModel.chatMessages.map { $0.id }), [1, 2])
        XCTAssertEqual(viewModel.channelMessages.first?.id, 3)
    }

    func testFilterUser_broadcastChannel_nilQuery_showsAllUserMessages() {
        let alice = makeUser(id: "alice")
        viewModel.filterUser = alice
        viewModel.inject(
            messages: [
                makeMessage(id: 1, channelId: 30, body: "News item", userId: "alice"),
            ],
            channelTypes: [30: "broadcast"]
        )
        viewModel.search(query: nil)
        XCTAssertEqual(viewModel.channelMessages.count, 1)
        XCTAssertEqual(viewModel.channelMessages.first?.id, 1)
    }
}
