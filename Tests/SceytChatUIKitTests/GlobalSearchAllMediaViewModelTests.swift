//
//  GlobalSearchAllMediaViewModelTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import XCTest
import Combine

// MARK: - Testable subclass

/// Subclasses `GlobalSearchAllMediaViewModel` to bypass CoreData:
/// - `startDatabaseObserver()` and `loadAttachments()` are no-ops.
/// - Section / item counts come from injected data.
/// - `simulateChange(_:)` lets tests trigger the event pipeline synchronously.
final class TestableGlobalSearchAllMediaViewModel: GlobalSearchAllMediaViewModel {

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
}

// Convenience typealias for ChangeItemPaths used in tests
private typealias ChangeItemPaths = LazyDatabaseObserver<AttachmentDTO, MessageLayoutModel.AttachmentLayout>.ChangeItemPaths
