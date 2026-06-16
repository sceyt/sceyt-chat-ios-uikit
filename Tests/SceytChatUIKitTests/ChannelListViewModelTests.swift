//
//  ChannelListViewModelTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import CoreData
import Combine
import XCTest

private let defaultTimeout: TimeInterval = 5

// MARK: - Testable subclass

/// `ChannelListViewModel` subclass that:
/// - Routes the observer's CoreData context to a test-owned one (so writes can stay
///   in-process and unsaved entities can be injected via `ChannelTestFetchedResultsController`).
/// - Substitutes a stub `NSFetchedResultsController` so test code can inject the
///   observed channel snapshot directly.
private final class TestableChannelListViewModel: ChannelListViewModel {

    let testContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.testContext = context
        super.init()
    }

    required init() {
        fatalError("use init(context:)")
    }

    required init(cellAppearance: ChannelListViewController.ChannelCell.Appearance) {
        fatalError("use init(context:)")
    }

    override func makeChannelObserver() -> LazyDBObserver<ChatChannel, ChannelDTO> {
        let request: NSFetchRequest<ChannelDTO> = ChannelDTO.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ChannelDTO.pinnedAt, ascending: false),
            NSSortDescriptor(keyPath: \ChannelDTO.sortingKey, ascending: false)
        ]
        request.predicate = fetchPredicate
        return LazyDBObserver<ChatChannel, ChannelDTO>(
            context: testContext,
            fetchRequest: request,
            itemCreator: { [weak self] dto in
                let channel = dto.convert()
                self?.createLayoutModel(channel: channel)
                return channel
            },
            fetchedResultsControllerType: ChannelTestFetchedResultsController.self
        )
    }

    var testFRC: ChannelTestFetchedResultsController {
        channelObserver.frc as! ChannelTestFetchedResultsController
    }
}

// MARK: - Tests

final class ChannelListViewModelTests: XCTestCase {

    private var database: MockDatabase!
    private var context: NSManagedObjectContext!
    private var vm: TestableChannelListViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        database = MockDatabase()
        context = database.container.newBackgroundContext()
        vm = TestableChannelListViewModel(context: context)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        vm = nil
        context = nil
        database = nil
        super.tearDown()
    }

    // MARK: Accessors without an active observer

    func test_numberOfSections_isAlwaysOne() {
        XCTAssertEqual(vm.numberOfSections, 1)
    }

    func test_numberOfChannel_invalidSection_returnsZero() {
        XCTAssertEqual(vm.numberOfChannel(at: 1), 0)
        XCTAssertEqual(vm.numberOfChannel(at: 5), 0)
    }

    func test_channelAt_outOfRange_returnsNil() {
        XCTAssertNil(vm.channel(at: IndexPath(row: 0, section: 0)))
        XCTAssertNil(vm.channel(at: IndexPath(row: 0, section: 1)))
    }

    func test_channelById_unknownId_returnsNil() {
        XCTAssertNil(vm.channel(id: 42))
    }

    // MARK: Observer-driven scenarios

    func test_startObserver_populatesChannels() throws {
        let dtos = [makeChannel(id: 1, subject: "a"),
                    makeChannel(id: 2, subject: "b")]
        injectFetched(dtos)

        let event = try waitForEvent { vm.startDatabaseObserver() }

        XCTAssertEqual(vm.channels.count, 2)
        XCTAssertEqual(vm.channels.map(\.id).sorted(), [1, 2])
        assertChange(event)
    }

    func test_oneChannel_emitsChangeWithSingleInsert() throws {
        injectFetched([makeChannel(id: 1)])

        let event = try waitForEvent { vm.startDatabaseObserver() }
        let paths = assertChange(event)
        XCTAssertEqual(paths.inserts.count, 1)
        XCTAssertEqual(paths.deletes.count, 0)
        XCTAssertEqual(paths.updates.count, 0)
        XCTAssertEqual(paths.moves.count, 0)
    }

    func test_manyChannels_emitsReloadAboveStructuralThreshold() throws {
        // `applyChanges` emits `.reload` once inserts + deletes + moves crosses 10.
        // 11 fresh inserts is the smallest input that trips it.
        injectFetched((1...11).map { makeChannel(id: Int64($0)) })

        let event = try waitForEvent { vm.startDatabaseObserver() }
        assertReload(event)
        XCTAssertEqual(vm.channels.count, 11)
    }

    func test_belowStructuralThreshold_emitsChange() throws {
        // 10 fresh inserts is right at the threshold — still a `.change`, not a `.reload`.
        injectFetched((1...10).map { makeChannel(id: Int64($0)) })

        let event = try waitForEvent { vm.startDatabaseObserver() }
        let paths = assertChange(event)
        XCTAssertEqual(paths.inserts.count, 10)
        XCTAssertEqual(vm.channels.count, 10)
    }

    func test_duplicateChannelId_isDedupedAndEmitsReload() throws {
        // Same `id`, different subject — first occurrence wins (sort order: pinned DESC, sortingKey DESC).
        let first  = makeChannel(id: 7, subject: "first")
        let second = makeChannel(id: 7, subject: "second")
        injectFetched([first, second])

        let event = try waitForEvent { vm.startDatabaseObserver() }

        XCTAssertEqual(vm.channels.count, 1)
        XCTAssertEqual(vm.channels[0].id, 7)
        XCTAssertEqual(vm.channels[0].subject, "first")
        assertReload(event)
    }

    func test_runtimeInsertWithSameId_isDedupedToOne() throws {
        // Step 1: start with channel id 7.
        let original = makeChannel(id: 7, subject: "original")
        injectFetched([original])
        let firstEvent = try waitForEvent { vm.startDatabaseObserver() }
        XCTAssertEqual(vm.channels.count, 1)
        XCTAssertEqual(vm.channels[0].subject, "original")
        let firstPaths = assertChange(firstEvent)
        XCTAssertEqual(firstPaths.inserts.count, 1)

        // Step 2: simulate the observer reporting a NEW insert for the same id.
        // We drive the relay's onDidChange directly on the observer's CoreData
        // queue so DTO conversion runs on the right thread; the observer's wiring
        // then re-reads frc.fetchedObjects, rebuilds rawItems, and notifies the VM.
        let duplicate = makeChannel(id: 7, subject: "duplicate")

        let secondEvent = try waitForEvent {
            context.perform { [self] in
                vm.testFRC.test_fetchedObjects = [original, duplicate]
                let duplicateChannel = duplicate.convert()
                vm.channelObserver.changeRelay.onDidChange?([
                    .insert(duplicateChannel, IndexPath(item: 1, section: 0))
                ])
            }
        }

        // Dedup kept the first occurrence; the duplicate is dropped.
        XCTAssertEqual(vm.channels.count, 1)
        XCTAssertEqual(vm.channels[0].id, 7)
        XCTAssertEqual(vm.channels[0].subject, "original")
        assertReload(secondEvent)
    }

    func test_accessorsAfterStart_returnCorrectChannels() throws {
        let dtos = [makeChannel(id: 10),
                    makeChannel(id: 20)]
        injectFetched(dtos)
        _ = try waitForEvent { vm.startDatabaseObserver() }

        XCTAssertEqual(vm.numberOfSections, 1)
        XCTAssertEqual(vm.numberOfChannel(at: 0), 2)
        XCTAssertEqual(vm.numberOfChannel(at: 1), 0)

        XCTAssertEqual(vm.channel(at: IndexPath(row: 0, section: 0))?.id, 10)
        XCTAssertEqual(vm.channel(at: IndexPath(row: 1, section: 0))?.id, 20)
        XCTAssertNil(vm.channel(at: IndexPath(row: 2, section: 0)))
        XCTAssertNil(vm.channel(at: IndexPath(row: 0, section: 1)))

        XCTAssertEqual(vm.channel(id: 10)?.id, 10)
        XCTAssertEqual(vm.channel(id: 20)?.id, 20)
        XCTAssertNil(vm.channel(id: 99))
    }

    // MARK: - Helpers

    /// Creates an unsaved `ChannelDTO` in the test context. Not saving keeps the
    /// Core Data uniqueness constraint on `id` from collapsing duplicates — which
    /// is what we need to exercise the dedup path in the VM.
    @discardableResult
    private func makeChannel(
        id: Int64,
        isPinned: Bool = false,
        subject: String? = nil
    ) -> ChannelDTO {
        var dto: ChannelDTO!
        context.performAndWait {
            dto = (NSEntityDescription.insertNewObject(forEntityName: "ChannelDTO", into: context) as! ChannelDTO)
            dto.id = id
            dto.type = "group"
            dto.subject = subject
            dto.createdAt = Date().bridgeDate
        }
        return dto
    }

    private func injectFetched(_ dtos: [ChannelDTO]) {
        vm.testFRC.test_fetchedObjects = dtos
    }

    /// Captures the first structural (`.change` / `.reload`) event after `block` runs.
    /// Clears any stale value first so back-to-back waits in a single test don't catch
    /// the previous emission, and filters out the async `.unreadMessagesCount` refresh
    /// that `applyChanges` / `applyReset` kick off after they set the structural event.
    private func waitForEvent(_ block: () throws -> Void) throws -> ChannelListViewModel.Event {
        vm.event = nil

        let exp = expectation(description: "structural event emitted")
        var captured: ChannelListViewModel.Event?
        vm.$event
            .compactMap { $0 }
            .filter { event in
                if case .unreadMessagesCount = event { return false }
                return true
            }
            .first()
            .sink { value in
                captured = value
                exp.fulfill()
            }
            .store(in: &cancellables)

        try block()
        wait(for: [exp], timeout: defaultTimeout)
        return try XCTUnwrap(captured)
    }

    @discardableResult
    private func assertChange(
        _ event: ChannelListViewModel.Event,
        file: StaticString = #file,
        line: UInt = #line
    ) -> DBChangeItemPaths {
        guard case let .change(paths) = event else {
            XCTFail("expected .change(_); got \(event)", file: file, line: line)
            return DBChangeItemPaths(inserts: [], updates: [], deletes: [], moves: [])
        }
        return paths
    }

    private func assertReload(
        _ event: ChannelListViewModel.Event,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        if case .reload = event { return }
        XCTFail("expected .reload; got \(event)", file: file, line: line)
    }
}
