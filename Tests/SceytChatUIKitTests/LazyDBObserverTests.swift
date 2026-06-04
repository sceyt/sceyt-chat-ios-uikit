//
//  LazyDBObserverTests.swift
//  SceytChatUIKitTests
//
//  Ported from getstream/stream-chat-swift's BackgroundListDatabaseObserver_Tests.
//

@testable import SceytChatUIKit
import CoreData
import XCTest

private let defaultTimeout: TimeInterval = 5

final class LazyDBObserverTests: XCTestCase {

    private var observer: LazyDBObserver<String, ChecksumDTO>!
    private var fetchRequest: NSFetchRequest<ChecksumDTO>!
    private var database: MockDatabase!
    private var context: NSManagedObjectContext!

    private var testFRC: TestFetchedResultsController {
        observer.frc as! TestFetchedResultsController
    }

    override func setUp() {
        super.setUp()

        database = MockDatabase()
        // Private-queue background context. Required for the concurrent-access test
        // so that performAndWait from worker threads doesn't deadlock the main runloop.
        context = database.container.newBackgroundContext()

        fetchRequest = NSFetchRequest(entityName: "ChecksumDTO")
        fetchRequest.sortDescriptors = [.init(key: "data", ascending: true)]

        observer = LazyDBObserver<String, ChecksumDTO>(
            context: context,
            fetchRequest: fetchRequest,
            itemCreator: { $0.data ?? "" },
            fetchedResultsControllerType: TestFetchedResultsController.self
        )
    }

    override func tearDown() {
        observer = nil
        fetchRequest = nil
        context = nil
        database = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func test_initialValues() {
        XCTAssertEqual(observer.frc.fetchRequest, fetchRequest)
        XCTAssertEqual(observer.frc.managedObjectContext, context)
        XCTAssertTrue(observer.rawItems.isEmpty)
    }

    // MARK: - Change relay wiring

    func test_changeRelaySetup() throws {
        let didChange = expectation(description: "onDidChange is called")
        observer.onDidChange = { _ in didChange.fulfill() }

        try observer.startObserving()

        waitForExpectations(timeout: defaultTimeout)

        XCTAssert(observer.frc.delegate === observer.changeRelay)
    }

    // MARK: - rawItems caching

    func test_itemsArray() throws {
        // Simulate FRC results.
        let reference1 = [
            makeChecksum(data: "a"),
            makeChecksum(data: "b")
        ]
        testFRC.test_fetchedObjects = reference1

        try startObservingAndWaitForInitialResults()

        XCTAssertEqual(observer.rawItems, reference1.compactMap(\.data))

        // Update the simulated fetch results.
        let reference2 = [makeChecksum(data: "c")]
        testFRC.test_fetchedObjects = reference2

        // Access items again — cached value is still reference1 until the relay fires.
        XCTAssertEqual(observer.rawItems, reference1.compactMap(\.data))

        // Manually drive the relay and verify the cache rebuilds.
        assertItemsAfterUpdate(reference2.compactMap(\.data))
    }

    // MARK: - startObserving

    func test_startObserving_startsFRC() throws {
        XCTAssertFalse(testFRC.test_performFetchCalled)
        try observer.startObserving()
        XCTAssertTrue(testFRC.test_performFetchCalled)
    }

    func test_startObservingMultipleTimes_startsFRCOnlyOnce() throws {
        XCTAssertFalse(testFRC.test_performFetchCalled)
        try observer.startObserving()
        XCTAssertTrue(testFRC.test_performFetchCalled)
        testFRC.test_performFetchCalled = false
        try observer.startObserving()
        XCTAssertFalse(testFRC.test_performFetchCalled)
    }

    // MARK: - Idempotent-write reporting

    func test_updateStillReported_whenSamePropertyAssigned() throws {
        // For this test we need a real NSFetchedResultsController, not the stub.
        observer = LazyDBObserver<String, ChecksumDTO>(
            context: context,
            fetchRequest: fetchRequest,
            itemCreator: { $0.data ?? "" }
        )

        try startObservingAndWaitForInitialResults()

        let onDidChange = expectation(description: "onDidChange fires twice")
        onDidChange.expectedFulfillmentCount = 2

        var receivedChanges: [DBChangeItem<String>] = []
        observer.onDidChange = { changes in
            receivedChanges.append(contentsOf: changes)
            onDidChange.fulfill()
        }

        // Insert.
        let testValue = UUID().uuidString
        var item: ChecksumDTO!
        try syncWrite { ctx in
            item = NSEntityDescription.insertNewObject(forEntityName: "ChecksumDTO", into: ctx) as? ChecksumDTO
            item.data = testValue
            item.attachmentTid = 1
        }

        // Re-assign the same value.
        try syncWrite { _ in
            item.data = testValue
        }

        wait(for: [onDidChange], timeout: defaultTimeout)

        XCTAssertEqual(receivedChanges.count, 2)
        guard case .insert = receivedChanges.first else {
            XCTFail("expected first change to be .insert, got \(String(describing: receivedChanges.first))")
            return
        }
        guard case .update = receivedChanges.last else {
            XCTFail("expected last change to be .update, got \(String(describing: receivedChanges.last))")
            return
        }
    }

    // MARK: - Race-condition coverage

    func test_accessingItemsBeforeInitialFetchHasEnded() throws {
        try syncWrite { ctx in
            let item = NSEntityDescription.insertNewObject(forEntityName: "ChecksumDTO", into: ctx) as! ChecksumDTO
            item.data = "1"
        }

        observer = LazyDBObserver<String, ChecksumDTO>(
            context: context,
            fetchRequest: fetchRequest,
            itemCreator: { $0.data ?? "" }
        )
        try observer.startObserving()

        XCTAssertEqual(["1"], observer.rawItems)
    }

    func test_accessingItemsConcurrentlyWhileInitialFetchIsRunning() throws {
        let expectedIds = (0..<5).map { "\($0)" }
        try syncWrite { ctx in
            for id in expectedIds {
                let item = NSEntityDescription.insertNewObject(forEntityName: "ChecksumDTO", into: ctx) as! ChecksumDTO
                item.data = id
            }
        }

        let initialFinished = XCTestExpectation(description: "Initial onDidChange")
        observer = LazyDBObserver<String, ChecksumDTO>(
            context: context,
            fetchRequest: fetchRequest,
            itemCreator: { $0.data ?? "" }
        )
        observer.onDidChange = { [initialFinished] _ in
            initialFinished.fulfill()
        }
        try observer.startObserving()

        DispatchQueue.concurrentPerform(iterations: 1000) { _ in
            XCTAssertEqual(expectedIds, observer.rawItems)
        }
        wait(for: [initialFinished], timeout: defaultTimeout)
        XCTAssertEqual(expectedIds, observer.rawItems)
    }

    func test_accessingItems_whenObservationStartsWithEmptyDBAndWriteHappens_thenWrittenDataIsReturned() throws {
        let initialFinished = XCTestExpectation(description: "Initial onDidChange")
        observer = LazyDBObserver<String, ChecksumDTO>(
            context: context,
            fetchRequest: fetchRequest,
            itemCreator: { $0.data ?? "" }
        )
        observer.onDidChange = { _ in initialFinished.fulfill() }
        try observer.startObserving()

        // Race the initial load against an immediate write.
        try syncWrite { ctx in
            let item = NSEntityDescription.insertNewObject(forEntityName: "ChecksumDTO", into: ctx) as! ChecksumDTO
            item.data = "1"
        }

        XCTAssertEqual(["1"], observer.rawItems)
        wait(for: [initialFinished], timeout: defaultTimeout)
        XCTAssertEqual(["1"], observer.rawItems)
    }

    // MARK: - Helpers

    @discardableResult
    private func makeChecksum(data: String) -> ChecksumDTO {
        let dto = NSEntityDescription.insertNewObject(forEntityName: "ChecksumDTO", into: context) as! ChecksumDTO
        dto.data = data
        return dto
    }

    /// Synchronously runs `block` on the observer's context queue and saves.
    private func syncWrite(_ block: (NSManagedObjectContext) throws -> Void) throws {
        var caught: Error?
        context.performAndWait {
            do {
                try block(context)
                try context.save()
            } catch {
                caught = error
            }
        }
        if let caught { throw caught }
    }

    private func startObservingAndWaitForInitialResults() throws {
        try waitForItemsUpdate {
            try observer.startObserving()
        }
    }

    private func assertItemsAfterUpdate(_ items: [String], file: StaticString = #file, line: UInt = #line) {
        try? waitForItemsUpdate {
            let relay = observer.frc.delegate as? ChangeRelay<ChecksumDTO, String>
            relay?.onDidChange?([])
        }
        XCTAssertEqual(observer.rawItems, items, file: file, line: line)
    }

    private func waitForItemsUpdate(block: () throws -> Void) throws {
        let exp = expectation(description: "onDidChange")
        observer.onDidChange = { _ in exp.fulfill() }
        try block()
        wait(for: [exp], timeout: defaultTimeout)
    }
}
