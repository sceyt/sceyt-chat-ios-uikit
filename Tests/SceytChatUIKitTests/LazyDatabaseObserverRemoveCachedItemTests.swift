//
//  LazyDatabaseObserverRemoveCachedItemTests.swift
//  SceytChatUIKitTests
//
//  A shown row that a refresh moves outside the fetch predicate is reloaded in place,
//  because the predicate also bounds the loaded window. A delete for me hides the row
//  (`unlisted = true`) and relied on that refresh to take it off screen, so the message
//  stayed visible until the server confirmed the delete and the row was really deleted.
//  `shouldRemoveCachedItem(_:)` lets a subclass say such a row has left the list.
//

@testable import SceytChatUIKit
import CoreData
import XCTest

final class LazyDatabaseObserverRemoveCachedItemTests: XCTestCase {

    /// Treats `checksum == 1` the way `LazyMessagesObserver` treats `unlisted`.
    private final class HidingObserver: LazyDatabaseObserver<ChecksumDTO, String> {
        override func shouldRemoveCachedItem(_ dto: ChecksumDTO) -> Bool {
            dto.checksum == 1
        }
    }

    private var database: MockDatabase!
    private var context: NSManagedObjectContext!
    private var observer: LazyDatabaseObserver<ChecksumDTO, String>!

    override func setUp() {
        super.setUp()
        database = MockDatabase()
        context = database.container.newBackgroundContext()
        // Like the production observable context: the observer only sees changes that
        // are merged into its own context.
        context.automaticallyMergesChangesFromParent = true
        context.performAndWait {
            for data in ["a", "b", "c"] {
                let dto = NSEntityDescription.insertNewObject(forEntityName: "ChecksumDTO", into: context) as! ChecksumDTO
                dto.data = data
            }
            try! context.save()
        }
    }

    override func tearDown() {
        observer?.stopObserver()
        observer = nil
        context = nil
        database = nil
        super.tearDown()
    }

    func test_rowThatLeftTheList_isRemovedOnRefresh() {
        observer = makeObserver(hiding: true)
        start()

        hideRow("b")

        XCTAssertEqual(shownRows(), ["a", "c"], "A hidden row must leave the list as soon as it is hidden")
    }

    func test_rowOutsideWindow_isKeptByDefault() {
        observer = makeObserver(hiding: false)
        start()

        hideRow("b")

        XCTAssertEqual(shownRows(), ["a", "b", "c"],
                       "Without the override a row outside the predicate is only outside the window and stays")
    }

    // MARK: - Helpers

    private func makeObserver(hiding: Bool) -> LazyDatabaseObserver<ChecksumDTO, String> {
        let sortDescriptors = [NSSortDescriptor(key: "data", ascending: true)]
        let predicate = NSPredicate(format: "checksum == 0")
        let itemCreator: (ChecksumDTO) -> String = { $0.data ?? "" }
        if hiding {
            return HidingObserver(
                context: context,
                sortDescriptors: sortDescriptors,
                fetchPredicate: predicate,
                itemCreator: itemCreator
            )
        }
        return LazyDatabaseObserver<ChecksumDTO, String>(
            context: context,
            sortDescriptors: sortDescriptors,
            fetchPredicate: predicate,
            itemCreator: itemCreator
        )
    }

    private func start() {
        let started = expectation(description: "initial start")
        observer.startObserver(completion: { started.fulfill() })
        wait(for: [started], timeout: 5)
        XCTAssertEqual(shownRows(), ["a", "b", "c"])
    }

    /// Hides `data` from another context and waits for the observer to process the merge.
    private func hideRow(_ data: String) {
        let changed = expectation(description: "change event")
        changed.assertForOverFulfill = false
        observer.onDidChange = { isInitial, _, _ in
            if !isInitial { changed.fulfill() }
        }
        let writer = database.container.newBackgroundContext()
        writer.performAndWait {
            let request = ChecksumDTO.fetchRequest()
            request.predicate = NSPredicate(format: "data == %@", data)
            let dto = try! writer.fetch(request).first as! ChecksumDTO
            dto.checksum = 1
            try! writer.save()
        }
        wait(for: [changed], timeout: 5)
    }

    private func shownRows() -> [String] {
        var rows = [String]()
        observer.forEach { _, item in
            rows.append(item)
            return false
        }
        return rows
    }
}
