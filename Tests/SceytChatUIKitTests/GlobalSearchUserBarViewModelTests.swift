//
//  GlobalSearchUserBarViewModelTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import XCTest
import Combine

// MARK: - Testable subclass

/// Bypasses database/observer by letting tests inject users directly.
final class TestableGlobalSearchUserBarViewModel: GlobalSearchUserBarViewModel {

    /// Inject users without touching CoreData. `allUsers` is internal so accessible via @testable.
    func inject(users: [ChatUser]) {
        allUsers = users
    }

    /// No-op: prevents the real CoreData observer from starting during tests.
    override func startDatabaseObserver() {}

    /// Bypasses debounce so tests can assert synchronously.
    override func search(query: String?) {
        searchQuery = query
        applyFilter()
    }
}

// MARK: - Tests

final class GlobalSearchUserBarViewModelTests: XCTestCase {

    private var viewModel: TestableGlobalSearchUserBarViewModel!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        viewModel = TestableGlobalSearchUserBarViewModel()
    }

    override func tearDown() {
        cancellables = []
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeUser(
        id: String,
        firstName: String? = nil,
        lastName: String? = nil,
        username: String? = nil
    ) -> ChatUser {
        ChatUser(id: id, firstName: firstName, lastName: lastName, username: username)
    }

    // MARK: - Empty / blank query

    func testEmptyQueryReturnsNoUsers() {
        viewModel.inject(users: [makeUser(id: "1", firstName: "Alice")])
        viewModel.search(query: "")
        XCTAssertTrue(viewModel.users.isEmpty, "Empty query should return no users")
    }

    func testNilQueryReturnsNoUsers() {
        viewModel.inject(users: [makeUser(id: "1", firstName: "Alice")])
        viewModel.search(query: nil)
        XCTAssertTrue(viewModel.users.isEmpty, "Nil query should return no users")
    }

    func testWhitespaceOnlyQueryReturnsNoUsers() {
        viewModel.inject(users: [makeUser(id: "1", firstName: "Alice")])
        viewModel.search(query: "   ")
        XCTAssertTrue(viewModel.users.isEmpty, "Whitespace-only query should return no users")
    }

    func testQueryWithLeadingAndTrailingWhitespaceMatchesUsers() {
        viewModel.inject(users: [
            makeUser(id: "1", firstName: "Alice"),
            makeUser(id: "2", firstName: "Bob"),
        ])
        viewModel.search(query: "  alice  ")
        XCTAssertEqual(viewModel.users.count, 1)
        XCTAssertEqual(viewModel.users.first?.id, "1", "Surrounding whitespace should be trimmed before matching")
    }
    
    func testQueryWithLeadingAndTrailingWhitespaceMatchesUsers2() {
        viewModel.inject(users: [
            makeUser(id: "1", firstName: "Alice", lastName: "Johnson"),
            makeUser(id: "2", firstName: "Bob"),
        ])
        viewModel.search(query: "Alice      Johnson")
        XCTAssertEqual(viewModel.users.count, 1)
        XCTAssertEqual(viewModel.users.first?.id, "1", "Surrounding whitespace should be trimmed before matching")
    }

    // MARK: - First name matching

    func testSearchByFirstName() {
        viewModel.inject(users: [
            makeUser(id: "1", firstName: "Alice"),
            makeUser(id: "2", firstName: "Bob"),
        ])
        viewModel.search(query: "ali")
        XCTAssertEqual(viewModel.users.count, 1)
        XCTAssertEqual(viewModel.users.first?.id, "1")
    }

    func testSearchByFirstNameCaseInsensitive() {
        viewModel.inject(users: [makeUser(id: "1", firstName: "Alice")])
        viewModel.search(query: "ALICE")
        XCTAssertEqual(viewModel.users.count, 1)
    }

    // MARK: - Last name matching

    func testSearchByLastName() {
        viewModel.inject(users: [
            makeUser(id: "1", firstName: "Alice", lastName: "Smith"),
            makeUser(id: "2", firstName: "Bob", lastName: "Jones"),
        ])
        viewModel.search(query: "smith")
        XCTAssertEqual(viewModel.users.count, 1)
        XCTAssertEqual(viewModel.users.first?.id, "1")
    }

    // MARK: - Username matching

    func testSearchByUsername() {
        viewModel.inject(users: [
            makeUser(id: "1", username: "alice_wonder"),
            makeUser(id: "2", username: "bob_builder"),
        ])
        viewModel.search(query: "alice")
        XCTAssertEqual(viewModel.users.count, 1)
        XCTAssertEqual(viewModel.users.first?.id, "1")
    }

    // MARK: - Full name matching

    func testSearchByFullName() {
        viewModel.inject(users: [
            makeUser(id: "1", firstName: "Alice", lastName: "Smith"),
            makeUser(id: "2", firstName: "Bob", lastName: "Jones"),
        ])
        viewModel.search(query: "alice smith")
        XCTAssertEqual(viewModel.users.count, 1)
        XCTAssertEqual(viewModel.users.first?.id, "1")
    }

    // MARK: - No match

    func testSearchWithNoMatchReturnsEmpty() {
        viewModel.inject(users: [
            makeUser(id: "1", firstName: "Alice"),
            makeUser(id: "2", firstName: "Bob"),
        ])
        viewModel.search(query: "xyz")
        XCTAssertTrue(viewModel.users.isEmpty)
    }

    // MARK: - Multiple matches

    func testSearchReturnsMultipleMatches() {
        viewModel.inject(users: [
            makeUser(id: "1", firstName: "Alice"),
            makeUser(id: "2", firstName: "Alicia"),
            makeUser(id: "3", firstName: "Bob"),
        ])
        viewModel.search(query: "ali")
        XCTAssertEqual(viewModel.users.count, 2)
    }

    // MARK: - Nil name fields

    func testUserWithNilNamesMatchesByUsername() {
        viewModel.inject(users: [makeUser(id: "1", firstName: nil, lastName: nil, username: "ghostuser")])
        viewModel.search(query: "ghost")
        XCTAssertEqual(viewModel.users.count, 1)
    }

    func testUserWithAllNilFieldsDoesNotMatch() {
        viewModel.inject(users: [makeUser(id: "1", firstName: nil, lastName: nil, username: nil)])
        viewModel.search(query: "something")
        XCTAssertTrue(viewModel.users.isEmpty)
    }

    // MARK: - Event publishing

    func testSearchPublishesReloadEvent() {
        viewModel.inject(users: [makeUser(id: "1", firstName: "Alice")])

        let expectation = XCTestExpectation(description: "reload event published")
        viewModel.$event
            .compactMap { $0 }
            .sink { event in
                if case .reload = event { expectation.fulfill() }
            }
            .store(in: &cancellables)

        viewModel.search(query: "ali")
        wait(for: [expectation], timeout: 1.0)
    }

    func testEmptyQueryAlsoPublishesReloadEvent() {
        viewModel.inject(users: [makeUser(id: "1", firstName: "Alice")])

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
}
