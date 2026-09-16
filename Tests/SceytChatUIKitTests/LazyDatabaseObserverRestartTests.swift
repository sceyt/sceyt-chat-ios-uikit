//
//  LazyDatabaseObserverRestartTests.swift
//  SceytChatUIKitTests
//
//  A restart requested while one is in flight used to be dropped on the floor — no
//  retry, and its completion never fired. Two navigations racing (a reply jump and the
//  scroll-down return, say) then left the list on whichever window happened to start
//  first. The observer now queues the newest such request behind the in-flight restart.
//

@testable import SceytChatUIKit
import CoreData
import XCTest

final class LazyDatabaseObserverRestartTests: XCTestCase {

    private var database: MockDatabase!
    private var context: NSManagedObjectContext!
    private var observer: LazyDatabaseObserver<ChecksumDTO, String>!

    /// Predicates the observer is restarted onto, distinguishable by `fetchPredicate`.
    private let p1 = NSPredicate(format: "data == %@", "a")
    private let p2 = NSPredicate(format: "data == %@", "b")
    private let p3 = NSPredicate(format: "data == %@", "c")

    /// Every `isInitial` change event delivered so far, in order — one per (re)start
    /// that actually fetched. Recorded together with the predicate it was fetched with.
    private var landedPredicates: [NSPredicate] = []

    override func setUp() {
        super.setUp()
        database = MockDatabase()
        context = database.container.newBackgroundContext()
        seedRows()
        observer = LazyDatabaseObserver<ChecksumDTO, String>(
            context: context,
            sortDescriptors: [NSSortDescriptor(key: "data", ascending: true)],
            fetchPredicate: NSPredicate(value: true),
            itemCreator: { $0.data ?? "" }
        )
        observer.onDidChange = { [weak self] isInitial, _, _ in
            guard let self, isInitial else { return }
            self.landedPredicates.append(self.observer.fetchPredicate)
        }
    }

    override func tearDown() {
        observer?.stopObserver()
        observer = nil
        context = nil
        database = nil
        landedPredicates = []
        super.tearDown()
    }

    // MARK: - Tests

    func test_restartWhileRestarting_isQueuedAndRuns() {
        start()

        let c1 = expectation(description: "p1 completion")
        let c2 = expectation(description: "p2 completion")
        let startedNow = observer.restartObserver(fetchPredicate: p1) { c1.fulfill() }
        let queued = observer.restartObserver(fetchPredicate: p2) { c2.fulfill() }

        XCTAssertTrue(startedNow, "The first restart should start immediately")
        XCTAssertFalse(queued, "A restart while one is in flight should be queued, not started")
        wait(for: [c1, c2], timeout: 5, enforceOrder: true)

        XCTAssertEqual(observer.fetchPredicate, p2, "The queued restart should be the one the observer ends on")
        XCTAssertEqual(landedPredicates, [NSPredicate(value: true), p1, p2],
                       "start, p1, then the queued p2 — nothing dropped")
    }

    func test_restartWhileRestarting_latestWins_chainsSupersededCompletion() {
        start()

        let c1 = expectation(description: "p1 completion")
        let c2 = expectation(description: "p2 completion")
        let c3 = expectation(description: "p3 completion")
        observer.restartObserver(fetchPredicate: p1) { c1.fulfill() }
        observer.restartObserver(fetchPredicate: p2) { c2.fulfill() }
        observer.restartObserver(fetchPredicate: p3) { c3.fulfill() }

        wait(for: [c1, c2, c3], timeout: 5)

        XCTAssertEqual(observer.fetchPredicate, p3)
        XCTAssertEqual(landedPredicates, [NSPredicate(value: true), p1, p3],
                       "p2 was superseded by p3 before it could run and must never be fetched")
    }

    func test_restartIssuedFromCompletion_runsAfterPendingAndWins() {
        start()

        let c1 = expectation(description: "p1 completion")
        let c2 = expectation(description: "p2 completion")
        let c3 = expectation(description: "p3 completion")
        observer.restartObserver(fetchPredicate: p1) { [self] in
            c1.fulfill()
            // Re-entered while p2 is still queued: it must go behind the in-flight
            // restart too, replacing p2 and inheriting p2's completion.
            let startedNow = observer.restartObserver(fetchPredicate: p3) { c3.fulfill() }
            XCTAssertFalse(startedNow, "A restart issued from a completion joins the queue instead of racing the drain")
        }
        observer.restartObserver(fetchPredicate: p2) { c2.fulfill() }

        wait(for: [c1, c2, c3], timeout: 5)

        XCTAssertEqual(observer.fetchPredicate, p3)
        XCTAssertEqual(landedPredicates, [NSPredicate(value: true), p1, p3])
    }

    func test_stopObserver_clearsPendingRestart() {
        start()

        observer.restartObserver(fetchPredicate: p1)
        let c2 = expectation(description: "p2 completion must not fire after stop")
        c2.isInverted = true
        observer.restartObserver(fetchPredicate: p2) { c2.fulfill() }
        observer.stopObserver()

        wait(for: [c2], timeout: 1)
        XCTAssertFalse(landedPredicates.contains(p2), "A queued restart dies with the observer it was queued on")
        XCTAssertFalse(observer.isObserverRestarting, "stopObserver must not leave the observer marked as restarting")

        // A fresh restart after the stop starts immediately — nothing stale is queued.
        let c3 = expectation(description: "p3 completion")
        let startedNow = observer.restartObserver(fetchPredicate: p3) { c3.fulfill() }
        XCTAssertTrue(startedNow)
        wait(for: [c3], timeout: 5)
        XCTAssertEqual(observer.fetchPredicate, p3)
    }

    // MARK: - Helpers

    private func start() {
        let started = expectation(description: "initial start")
        observer.startObserver(completion: { started.fulfill() })
        wait(for: [started], timeout: 5)
        XCTAssertEqual(landedPredicates.count, 1)
    }

    private func seedRows() {
        context.performAndWait {
            for data in ["a", "b", "c"] {
                let dto = NSEntityDescription.insertNewObject(forEntityName: "ChecksumDTO", into: context) as! ChecksumDTO
                dto.data = data
            }
            try! context.save()
        }
    }
}
