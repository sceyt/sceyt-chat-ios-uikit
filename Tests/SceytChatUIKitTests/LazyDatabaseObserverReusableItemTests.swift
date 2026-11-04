//
//  LazyDatabaseObserverReusableItemTests.swift
//  SceytChatUIKitTests
//
//  `reload(dto:)` parks a changed row's item in `mapDeletedItems` before it calls
//  `itemCreator`, so an item creator that looked its previous instance up with
//  `item(for:)` never found it and built a fresh one on every update. The Channel Info
//  media grid kept the old instance bound — a sent image stayed a pending (id 0, no url)
//  attachment there, the previewer couldn't match it, and tapping it opened a different
//  item. `reusableItem(for:)` sees the parked instance.
//

@testable import SceytChatUIKit
import CoreData
import XCTest

final class LazyDatabaseObserverReusableItemTests: XCTestCase {

    /// Reference-type item, like `MessageLayoutModel.AttachmentLayout`.
    private final class Box {
        var checksum: Int64
        init(checksum: Int64) { self.checksum = checksum }
    }

    private var database: MockDatabase!
    private var context: NSManagedObjectContext!
    private var observer: LazyDatabaseObserver<ChecksumDTO, Box>!
    private var onUpdate: (() -> Void)?

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
        observer = LazyDatabaseObserver<ChecksumDTO, Box>(
            context: context,
            sortDescriptors: [NSSortDescriptor(key: "data", ascending: true)],
            fetchPredicate: NSPredicate(value: true),
            itemCreator: { [weak self] dto in
                // Same shape as `ChannelAttachmentListViewModel`'s creator.
                if let previous = self?.observer.reusableItem(for: dto.objectID) {
                    previous.checksum = dto.checksum
                    return previous
                }
                return Box(checksum: dto.checksum)
            }
        )
        observer.onDidChange = { [weak self] isInitial, paths, _ in
            guard !isInitial, !paths.updates.isEmpty else { return }
            self?.onUpdate?()
        }
    }

    override func tearDown() {
        observer?.stopObserver()
        observer = nil
        context = nil
        database = nil
        onUpdate = nil
        super.tearDown()
    }

    func test_updatedRow_keepsItsItemInstance() {
        let started = expectation(description: "initial start")
        observer.startObserver(completion: { started.fulfill() })
        wait(for: [started], timeout: 5)

        let indexPath = IndexPath(row: 1, section: 0)
        let before = try! XCTUnwrap(observer.item(at: indexPath))

        let updated = expectation(description: "update event")
        onUpdate = { updated.fulfill() }
        let writer = database.container.newBackgroundContext()
        writer.performAndWait {
            let request = ChecksumDTO.fetchRequest()
            request.predicate = NSPredicate(format: "data == %@", "b")
            let dto = try! writer.fetch(request).first as! ChecksumDTO
            dto.checksum = 42
            try! writer.save()
        }
        wait(for: [updated], timeout: 5)

        let after = try! XCTUnwrap(observer.item(at: indexPath))
        XCTAssertTrue(after === before,
                      "An update must reach the instance views already hold, not replace it with a fresh one")
        XCTAssertEqual(before.checksum, 42, "The held instance must carry the updated values")
    }
}
