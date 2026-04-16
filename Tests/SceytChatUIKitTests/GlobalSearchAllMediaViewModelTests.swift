//
//  GlobalSearchAllMediaViewModelTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import XCTest
import Combine
import SceytChat

// MARK: - Testable subclass

/// Subclasses `GlobalSearchAllMediaViewModel` to bypass CoreData:
/// - `startDatabaseObserver()` and `loadAttachments()` are no-ops.
/// - Section / item counts come from injected data.
/// - `simulateChange(_:)` lets tests trigger the event pipeline synchronously.
final class TestableGlobalSearchAllMediaViewModel: GlobalSearchAllMediaViewModel {

    // MARK: Injected data

    private var injectedSections: [[MessageLayoutModel.AttachmentLayout]] = []
    var injectedRoleQualifiedChannelIds: Set<ChannelId> = [101]

    func inject(sections: [[MessageLayoutModel.AttachmentLayout]]) {
        injectedSections = sections
    }

    // MARK: Observer (no-op)

    override func startDatabaseObserver() {}

    override func loadAttachments() {}

    override func loadRoleQualifiedChannelIds() -> Set<ChannelId> {
        injectedRoleQualifiedChannelIds
    }

    /// Stores properties without touching the database observer.
    override func search(query: String?, filterUser: ChatUser?) {
        self.filterUser = filterUser
        self.query = query
    }

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
}

// MARK: - Tests

final class GlobalSearchAllMediaViewModelTests: XCTestCase {

    private var viewModel: TestableGlobalSearchAllMediaViewModel!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        viewModel = TestableGlobalSearchAllMediaViewModel(
            attachmentTypes: ["image", "video"],
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
        let vm = TestableGlobalSearchAllMediaViewModel(
            attachmentTypes: ["image", "video"],
            appearance: MessageCell.appearance
        )
        XCTAssertEqual(vm.attachmentTypes, ["image", "video"])
    }

    func testEmptyAttachmentTypesAreAllowed() {
        let vm = TestableGlobalSearchAllMediaViewModel(
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
        // Verifies the no-op override is safe to call
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
        let vm = TestableGlobalSearchAllMediaViewModel(
            attachmentTypes: ["image", "video"],
            appearance: MessageCell.appearance
        )
        XCTAssertEqual(vm.sectionNameKeyPath, "createdYearMonth")
    }

    func testCustomSectionNameKeyPath() {
        let vm = TestableGlobalSearchAllMediaViewModel(
            attachmentTypes: ["image"],
            sectionNameKeyPath: nil,
            appearance: MessageCell.appearance
        )
        XCTAssertNil(vm.sectionNameKeyPath)
    }

    // MARK: - Protocol conformance

    func testConformsToChannelAttachmentListViewModelProviding() {
        let _: any ChannelAttachmentListViewModelProviding = viewModel
    }

    // MARK: - search(query:filterUser:)

    func testSearchStoresNilQueryAndNilUser() {
        viewModel.search(query: nil, filterUser: nil)
        XCTAssertNil(viewModel.query)
        XCTAssertNil(viewModel.filterUser)
    }

    func testSearchStoresQuery() {
        viewModel.search(query: "hello", filterUser: nil)
        XCTAssertEqual(viewModel.query, "hello")
    }

    func testSearchClearsQueryWhenNilPassed() {
        viewModel.search(query: "hello", filterUser: nil)
        viewModel.search(query: nil, filterUser: nil)
        XCTAssertNil(viewModel.query)
    }

    func testSearchStoresFilterUser() {
        let user = ChatUser(id:"u1")
        viewModel.search(query: nil, filterUser: user)
        XCTAssertEqual(viewModel.filterUser?.id, "u1")
    }

    func testSearchClearsFilterUserWhenNilPassed() {
        let user = ChatUser(id:"u1")
        viewModel.search(query: nil, filterUser: user)
        viewModel.search(query: nil, filterUser: nil)
        XCTAssertNil(viewModel.filterUser)
    }

    func testSearchStoresBothQueryAndUser() {
        let user = ChatUser(id:"u2")
        viewModel.search(query: "photo", filterUser: user)
        XCTAssertEqual(viewModel.query, "photo")
        XCTAssertEqual(viewModel.filterUser?.id, "u2")
    }

    // MARK: - isFiltered threshold (Media-specific: >= 1 char)

    func testIsFiltered_noUser_oneCharacterQuery_returnsTrue() {
        viewModel.search(query: "a", filterUser: nil)
        XCTAssertTrue(viewModel.isFiltered, "Media filtering should activate from 1 character query")
    }

    func testIsFiltered_noUser_emptyQuery_returnsFalse() {
        viewModel.search(query: "", filterUser: nil)
        XCTAssertFalse(viewModel.isFiltered)
    }

    func testIsFiltered_noUser_whitespaceOnlyQuery_returnsFalse() {
        viewModel.search(query: "   ", filterUser: nil)
        XCTAssertFalse(viewModel.isFiltered)
    }

    // MARK: - buildPredicate()

    func testBuildBasePredicateIncludesRoleQualifiedChannelConstraint() {
        let predicate = viewModel.buildBasePredicate()
        XCTAssertTrue(
            predicate.predicateFormat.contains("channelId IN"),
            "Base media predicate should be scoped to channels with non-nil userRole"
        )
    }

    func testBuildBasePredicateWithNoRoleQualifiedChannelsContainsFalsePredicate() {
        viewModel.injectedRoleQualifiedChannelIds = []
        let predicate = viewModel.buildBasePredicate()
        XCTAssertTrue(
            predicate.predicateFormat.contains("FALSEPREDICATE"),
            "When no channels have userRole, media predicate should evaluate to false"
        )
    }

    func testBuildPredicateNoFilters() {
        // No filterUser, no query → predicate should only contain type + viewOnce clauses
        let predicate = viewModel.buildPredicate()
        // Should not contain userId or message.body
        let format = predicate.predicateFormat
        XCTAssertFalse(format.contains("userId"))
        XCTAssertFalse(format.contains("body"))
    }

    func testBuildPredicateIncludesRoleQualifiedChannelConstraint() {
        let predicate = viewModel.buildPredicate()
        XCTAssertTrue(
            predicate.predicateFormat.contains("channelId IN"),
            "Search media predicate should be scoped to channels with non-nil userRole"
        )
    }

    func testBuildPredicateWithUserFilter() {
        let user = ChatUser(id:"abc123")
        viewModel.search(query: nil, filterUser: user)
        let predicate = viewModel.buildPredicate()
        XCTAssertTrue(predicate.predicateFormat.contains("userId"))
    }

    func testBuildPredicateWithQueryFilter() {
        viewModel.search(query: "photo", filterUser: nil)
        let predicate = viewModel.buildPredicate()
        XCTAssertTrue(predicate.predicateFormat.contains("body"))
    }

    func testBuildPredicateWithSingleCharacterQueryFilter() {
        viewModel.search(query: "a", filterUser: nil)
        let predicate = viewModel.buildPredicate()
        XCTAssertTrue(
            predicate.predicateFormat.contains("body"),
            "Media body predicate should be applied from 1 character query"
        )
    }

    func testBuildPredicateWithBothFilters() {
        let user = ChatUser(id:"u3")
        viewModel.search(query: "video", filterUser: user)
        let predicate = viewModel.buildPredicate()
        let format = predicate.predicateFormat
        XCTAssertTrue(format.contains("userId"))
        XCTAssertTrue(format.contains("body"))
    }

    func testBuildPredicateIgnoresWhitespaceOnlyQuery() {
        viewModel.search(query: "   ", filterUser: nil)
        let predicate = viewModel.buildPredicate()
        XCTAssertFalse(predicate.predicateFormat.contains("body"))
    }

    func testBuildPredicateIgnoresEmptyQuery() {
        viewModel.search(query: "", filterUser: nil)
        let predicate = viewModel.buildPredicate()
        XCTAssertFalse(predicate.predicateFormat.contains("body"))
    }
}

// Convenience typealias for ChangeItemPaths used in tests
private typealias ChangeItemPaths = LazyDatabaseObserver<AttachmentDTO, MessageLayoutModel.AttachmentLayout>.ChangeItemPaths
