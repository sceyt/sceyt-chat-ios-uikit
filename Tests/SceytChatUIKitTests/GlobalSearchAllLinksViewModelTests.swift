//
//  GlobalSearchAllLinksViewModelTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import XCTest
import Combine

// MARK: - Testable subclass

/// Subclasses `GlobalSearchAllLinksViewModel` to bypass CoreData:
/// - `startDatabaseObserver()` and `loadAttachments()` are no-ops.
/// - Section / item counts come from injected data.
/// - `simulateChange(_:)` lets tests trigger the event pipeline synchronously.
final class TestableGlobalSearchAllLinksViewModel: GlobalSearchAllLinksViewModel {

    // MARK: Injected data

    private var injectedSections: [[MessageLayoutModel.AttachmentLayout]] = []

    func inject(sections: [[MessageLayoutModel.AttachmentLayout]]) {
        injectedSections = sections
    }

    // MARK: Observer (no-op)

    override func startDatabaseObserver() {}

    override func loadAttachments() {}

    // MARK: Data accessors (in-memory)

    override var numberOfSections: Int {
        injectedSections.count
    }

    override func numberOfAttachments(in section: Int) -> Int {
        injectedSections.indices.contains(section) ? injectedSections[section].count : 0
    }

    override func attachmentLayout(
        at indexPath: IndexPath,
        onLoadThumbnail: ((MessageLayoutModel.AttachmentLayout) -> Void)?,
        onLoadLinkMetadata: ((LinkMetadata?) -> Void)?
    ) -> MessageLayoutModel.AttachmentLayout? {
        guard injectedSections.indices.contains(indexPath.section),
              injectedSections[indexPath.section].indices.contains(indexPath.row)
        else { return nil }
        return injectedSections[indexPath.section][indexPath.row]
    }

    // MARK: Test helper

    /// Fires the change event synchronously, as if the DB observer fired.
    func simulateChange(_ paths: ChangeItemPaths) {
        onDidChangeEvent(items: paths)
    }

    /// Stores query and filterUser without touching the database observer.
    override func search(query: String?, filterUser: ChatUser?) {
        self.filterUser = filterUser
        self.query = query
    }
}

// MARK: - Tests

final class GlobalSearchAllLinksViewModelTests: XCTestCase {

    private var viewModel: TestableGlobalSearchAllLinksViewModel!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        viewModel = TestableGlobalSearchAllLinksViewModel(
            attachmentTypes: ["link"],
            appearance: MessageCell.appearance
        )
    }

    override func tearDown() {
        cancellables = []
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitialSectionsAreEmpty() {
        XCTAssertEqual(viewModel.numberOfSections, 0)
    }

    func testInitialItemCountIsZero() {
        XCTAssertEqual(viewModel.numberOfAttachments(in: 0), 0)
    }

    func testAttachmentLayoutReturnsNilBeforeDataInjected() {
        XCTAssertNil(viewModel.attachmentLayout(at: IndexPath(row: 0, section: 0)))
    }

    // MARK: - Attachment types

    func testAttachmentTypesAreStoredCorrectly() {
        let vm = TestableGlobalSearchAllLinksViewModel(
            attachmentTypes: ["link"],
            appearance: MessageCell.appearance
        )
        XCTAssertEqual(vm.attachmentTypes, ["link"])
    }

    func testEmptyAttachmentTypesAreAllowed() {
        let vm = TestableGlobalSearchAllLinksViewModel(
            attachmentTypes: [],
            appearance: MessageCell.appearance
        )
        XCTAssertTrue(vm.attachmentTypes.isEmpty)
    }

    // MARK: - Section / item count after injection

    func testNumberOfSectionsAfterInjection() {
        viewModel.inject(sections: [[], []])
        XCTAssertEqual(viewModel.numberOfSections, 2)
    }

    func testNumberOfAttachmentsInOutOfBoundsSectionIsZero() {
        viewModel.inject(sections: [[]])
        XCTAssertEqual(viewModel.numberOfAttachments(in: 99), 0)
    }

    func testAttachmentLayoutOutOfBoundsReturnsNil() {
        viewModel.inject(sections: [[]])
        XCTAssertNil(viewModel.attachmentLayout(at: IndexPath(row: 0, section: 0)))
    }

    func testAttachmentLayoutNegativeSectionReturnsNil() {
        XCTAssertNil(viewModel.attachmentLayout(at: IndexPath(row: 0, section: -1)))
    }

    // MARK: - Event publishing

    func testSimulateChangePublishesEvent() {
        let expectation = XCTestExpectation(description: "event published")
        viewModel.$event
            .compactMap { $0 }
            .sink { event in
                if case .change = event { expectation.fulfill() }
            }
            .store(in: &cancellables)

        let paths = ChangeItemPaths(changeItems: [])
        viewModel.simulateChange(paths)

        wait(for: [expectation], timeout: 1.0)
    }

    func testEventPublisherEmitsChangeEvent() {
        let expectation = XCTestExpectation(description: "eventPublisher emits change")
        viewModel.eventPublisher
            .compactMap { $0 }
            .sink { event in
                if case .change = event { expectation.fulfill() }
            }
            .store(in: &cancellables)

        let paths = ChangeItemPaths(changeItems: [])
        viewModel.simulateChange(paths)

        wait(for: [expectation], timeout: 1.0)
    }

    func testMultipleSimulatedChangesPublishMultipleEvents() {
        let expectation = XCTestExpectation(description: "two events published")
        expectation.expectedFulfillmentCount = 2
        viewModel.$event
            .compactMap { $0 }
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        viewModel.simulateChange(ChangeItemPaths(changeItems: []))
        viewModel.simulateChange(ChangeItemPaths(changeItems: []))

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - No-op observer and loader

    func testStartDatabaseObserverDoesNotCrash() {
        XCTAssertNoThrow(viewModel.startDatabaseObserver())
    }

    func testLoadAttachmentsDoesNotCrash() {
        XCTAssertNoThrow(viewModel.loadAttachments())
    }

    // MARK: - minAutoDownloadSize default

    func testDefaultMinAutoDownloadSize() {
        XCTAssertEqual(viewModel.minAutoDownloadSize, 3_000_000)
    }

    // MARK: - sectionNameKeyPath default

    func testDefaultSectionNameKeyPath() {
        let vm = TestableGlobalSearchAllLinksViewModel(
            attachmentTypes: ["link"],
            appearance: MessageCell.appearance
        )
        XCTAssertEqual(vm.sectionNameKeyPath, "createdYearMonth")
    }

    func testCustomSectionNameKeyPath() {
        let vm = TestableGlobalSearchAllLinksViewModel(
            attachmentTypes: ["link"],
            sectionNameKeyPath: nil,
            appearance: MessageCell.appearance
        )
        XCTAssertNil(vm.sectionNameKeyPath)
    }

    // MARK: - Protocol conformance

    func testConformsToChannelAttachmentListViewModelProviding() {
        let _: any ChannelAttachmentListViewModelProviding = viewModel
    }

    // MARK: - search(query:filterUser:) – stores values without touching DB

    func testSearchStoresQuery() {
        viewModel.search(query: "example.com", filterUser: nil)
        XCTAssertEqual(viewModel.query, "example.com")
    }

    func testSearchStoresNilQueryAndNilUser() {
        viewModel.search(query: nil, filterUser: nil)
        XCTAssertNil(viewModel.query)
        XCTAssertNil(viewModel.filterUser)
    }

    func testSearchClearsQueryWhenNilPassed() {
        viewModel.search(query: "openai.com", filterUser: nil)
        viewModel.search(query: nil, filterUser: nil)
        XCTAssertNil(viewModel.query)
    }

    func testSearchStoresFilterUser() {
        let user = ChatUser(id: "u1")
        viewModel.search(query: nil, filterUser: user)
        XCTAssertEqual(viewModel.filterUser?.id, "u1")
    }

    func testSearchClearsFilterUserWhenNilPassed() {
        let user = ChatUser(id: "u1")
        viewModel.search(query: nil, filterUser: user)
        viewModel.search(query: nil, filterUser: nil)
        XCTAssertNil(viewModel.filterUser)
    }

    func testSearchStoresBothQueryAndUser() {
        let user = ChatUser(id: "u2")
        viewModel.search(query: "github.com", filterUser: user)
        XCTAssertEqual(viewModel.query, "github.com")
        XCTAssertEqual(viewModel.filterUser?.id, "u2")
    }

    // MARK: - isFiltered

    func testIsFiltered_withQuery_returnsTrue() {
        viewModel.search(query: "swift.org", filterUser: nil)
        XCTAssertTrue(viewModel.isFiltered)
    }

    func testIsFiltered_emptyQuery_returnsFalse() {
        viewModel.search(query: "", filterUser: nil)
        XCTAssertFalse(viewModel.isFiltered)
    }

    func testIsFiltered_whitespaceOnlyQuery_returnsFalse() {
        viewModel.search(query: "   ", filterUser: nil)
        XCTAssertFalse(viewModel.isFiltered)
    }

    func testIsFiltered_withFilterUser_returnsTrue() {
        let user = ChatUser(id: "u3")
        viewModel.search(query: nil, filterUser: user)
        XCTAssertTrue(viewModel.isFiltered)
    }

    func testIsFiltered_noQueryNoUser_returnsFalse() {
        viewModel.search(query: nil, filterUser: nil)
        XCTAssertFalse(viewModel.isFiltered)
    }

    // MARK: - buildPredicate() – link metadata summary search

    func testBuildPredicateNoFilters_doesNotContainSummaryOrUserId() {
        let predicate = viewModel.buildPredicate()
        let format = predicate.predicateFormat
        XCTAssertFalse(format.contains("summary"), "Unfiltered predicate should not include summary clause")
        XCTAssertFalse(format.contains("userId"), "Unfiltered predicate should not include userId clause")
    }

    func testBuildPredicateWithQuery_containsMessageBodyClause() {
        viewModel.search(query: "release notes", filterUser: nil)
        let predicate = viewModel.buildPredicate()
        XCTAssertTrue(
            predicate.predicateFormat.contains("message.body"),
            "Query should add a message.body CONTAINS[cd] clause"
        )
    }

    func testBuildPredicateWithQuery_containsLinkMetadataSummaryClause() {
        viewModel.search(query: "release notes", filterUser: nil)
        let predicate = viewModel.buildPredicate()
        XCTAssertTrue(
            predicate.predicateFormat.contains("summary"),
            "Query should add a message.linkMetadatas.summary CONTAINS[cd] clause"
        )
    }

    func testBuildPredicateWithQuery_containsQueryValue() {
        viewModel.search(query: "release notes", filterUser: nil)
        let predicate = viewModel.buildPredicate()
        XCTAssertTrue(
            predicate.predicateFormat.contains("release notes"),
            "Predicate format should embed the query value"
        )
    }

    func testBuildPredicateIgnoresWhitespaceOnlyQuery() {
        viewModel.search(query: "   ", filterUser: nil)
        let predicate = viewModel.buildPredicate()
        XCTAssertFalse(predicate.predicateFormat.contains("summary"))
        XCTAssertFalse(predicate.predicateFormat.contains("message.body"))
    }

    func testBuildPredicateIgnoresEmptyQuery() {
        viewModel.search(query: "", filterUser: nil)
        let predicate = viewModel.buildPredicate()
        XCTAssertFalse(predicate.predicateFormat.contains("summary"))
        XCTAssertFalse(predicate.predicateFormat.contains("message.body"))
    }

    // MARK: - buildPredicate() – user filter

    func testBuildPredicateWithFilterUser_containsUserIdClause() {
        let user = ChatUser(id: "abc123")
        viewModel.search(query: nil, filterUser: user)
        let predicate = viewModel.buildPredicate()
        XCTAssertTrue(
            predicate.predicateFormat.contains("userId"),
            "User filter should add a userId == clause"
        )
    }

    func testBuildPredicateWithFilterUser_containsUserIdValue() {
        let user = ChatUser(id: "abc123")
        viewModel.search(query: nil, filterUser: user)
        let predicate = viewModel.buildPredicate()
        XCTAssertTrue(
            predicate.predicateFormat.contains("abc123"),
            "Predicate format should embed the user id value"
        )
    }

    func testBuildPredicateWithBothQueryAndUserFilter() {
        let user = ChatUser(id: "u4")
        viewModel.search(query: "best practices", filterUser: user)
        let predicate = viewModel.buildPredicate()
        let format = predicate.predicateFormat
        XCTAssertTrue(format.contains("userId"), "Combined filter should include userId clause")
        XCTAssertTrue(format.contains("summary"), "Combined filter should include linkMetadatas.summary clause")
        XCTAssertTrue(format.contains("message.body"), "Combined filter should include message.body clause")
    }

    func testBuildPredicateWithNilUserAfterPreviousUser_doesNotContainUserId() {
        let user = ChatUser(id: "u5")
        viewModel.search(query: nil, filterUser: user)
        viewModel.search(query: nil, filterUser: nil)
        let predicate = viewModel.buildPredicate()
        XCTAssertFalse(
            predicate.predicateFormat.contains("userId"),
            "Clearing filterUser should remove the userId clause"
        )
    }
}

// Convenience typealias for ChangeItemPaths used in tests
private typealias ChangeItemPaths = LazyDatabaseObserver<AttachmentDTO, MessageLayoutModel.AttachmentLayout>.ChangeItemPaths
