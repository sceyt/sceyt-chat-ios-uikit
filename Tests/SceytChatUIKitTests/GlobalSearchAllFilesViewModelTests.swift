//
//  GlobalSearchAllFilesViewModelTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import XCTest
import Combine

// MARK: - Testable subclass

/// Subclasses `GlobalSearchAllFilesViewModel` to bypass CoreData:
/// - `startDatabaseObserver()` and `loadAttachments()` are no-ops.
/// - Section / item counts come from injected data.
/// - `simulateChange(_:)` lets tests trigger the event pipeline synchronously.
final class TestableGlobalSearchAllFilesViewModel: GlobalSearchAllFilesViewModel {

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

final class GlobalSearchAllFilesViewModelTests: XCTestCase {

    private var viewModel: TestableGlobalSearchAllFilesViewModel!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        viewModel = TestableGlobalSearchAllFilesViewModel(
            attachmentTypes: ["file"],
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
        let vm = TestableGlobalSearchAllFilesViewModel(
            attachmentTypes: ["file"],
            appearance: MessageCell.appearance
        )
        XCTAssertEqual(vm.attachmentTypes, ["file"])
    }

    func testEmptyAttachmentTypesAreAllowed() {
        let vm = TestableGlobalSearchAllFilesViewModel(
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
        let vm = TestableGlobalSearchAllFilesViewModel(
            attachmentTypes: ["file"],
            appearance: MessageCell.appearance
        )
        XCTAssertEqual(vm.sectionNameKeyPath, "createdYearMonth")
    }

    func testCustomSectionNameKeyPath() {
        let vm = TestableGlobalSearchAllFilesViewModel(
            attachmentTypes: ["file"],
            sectionNameKeyPath: nil,
            appearance: MessageCell.appearance
        )
        XCTAssertNil(vm.sectionNameKeyPath)
    }

    // MARK: - Protocol conformance

    func testConformsToChannelAttachmentListViewModelProviding() {
        let _: any ChannelAttachmentListViewModelProviding = viewModel
    }

    // MARK: - search(query:filterUser:) – find file by name

    func testSearchStoresQuery() {
        viewModel.search(query: "annual_report", filterUser: nil)
        XCTAssertEqual(viewModel.query, "annual_report")
    }

    func testSearchStoresNilQueryAndNilUser() {
        viewModel.search(query: nil, filterUser: nil)
        XCTAssertNil(viewModel.query)
        XCTAssertNil(viewModel.filterUser)
    }

    func testSearchClearsQueryWhenNilPassed() {
        viewModel.search(query: "invoice", filterUser: nil)
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
        viewModel.search(query: "contract.pdf", filterUser: user)
        XCTAssertEqual(viewModel.query, "contract.pdf")
        XCTAssertEqual(viewModel.filterUser?.id, "u2")
    }

    // MARK: - isFiltered

    func testIsFiltered_withFileNameQuery_returnsTrue() {
        viewModel.search(query: "report", filterUser: nil)
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

    // MARK: - buildPredicate() – file name search

    func testBuildPredicateNoFilters_doesNotContainNameOrUserId() {
        let predicate = viewModel.buildPredicate()
        let format = predicate.predicateFormat
        XCTAssertFalse(format.contains("name"), "Unfiltered predicate should not include name clause")
        XCTAssertFalse(format.contains("userId"), "Unfiltered predicate should not include userId clause")
    }

    func testBuildPredicateWithFileNameQuery_containsNameClause() {
        // When searching for a file by name the predicate filters on the attachment's name field
        viewModel.search(query: "invoice_2025", filterUser: nil)
        let predicate = viewModel.buildPredicate()
        XCTAssertTrue(
            predicate.predicateFormat.contains("name"),
            "File name query should add a name CONTAINS[cd] clause"
        )
    }

    func testBuildPredicateWithFileNameQuery_containsQueryValue() {
        viewModel.search(query: "invoice_2025", filterUser: nil)
        let predicate = viewModel.buildPredicate()
        XCTAssertTrue(
            predicate.predicateFormat.contains("invoice_2025"),
            "Predicate format should embed the query value"
        )
    }

    func testBuildPredicateIgnoresWhitespaceOnlyQuery() {
        viewModel.search(query: "   ", filterUser: nil)
        let predicate = viewModel.buildPredicate()
        XCTAssertFalse(predicate.predicateFormat.contains("name CONTAINS"))
    }

    func testBuildPredicateIgnoresEmptyQuery() {
        viewModel.search(query: "", filterUser: nil)
        let predicate = viewModel.buildPredicate()
        XCTAssertFalse(predicate.predicateFormat.contains("name CONTAINS"))
    }

    // MARK: - buildPredicate() – all files from selected user

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

    func testBuildPredicateWithBothFileNameAndUserFilter() {
        let user = ChatUser(id: "u4")
        viewModel.search(query: "contract.pdf", filterUser: user)
        let predicate = viewModel.buildPredicate()
        let format = predicate.predicateFormat
        XCTAssertTrue(format.contains("userId"), "Combined filter should include userId clause")
        XCTAssertTrue(format.contains("name"), "Combined filter should include name CONTAINS[cd] clause")
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
