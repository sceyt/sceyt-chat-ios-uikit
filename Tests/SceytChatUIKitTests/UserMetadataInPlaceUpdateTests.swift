//
//  UserMetadataInPlaceUpdateTests.swift
//  SceytChatUIKitTests
//
//  `UserDTO.map(_:)` deleted every `UserMetadataDTO` of the user and inserted new ones on every
//  save, even when nothing changed. A 50-channel chat-list page re-saves each member and
//  last-message sender, so every page carried `ins == del == UserMetadataDTO` rows and marked
//  every user as changed, refreshing observers for nothing
//  (channel_save_performance_findings.md, section 5.3).
//
//  Metadata is now updated in place: changed values are set on the existing row, removed keys are
//  deleted, new keys are inserted, and an unchanged user is left untouched.
//

@testable import SceytChatUIKit
import CoreData
import XCTest

final class UserMetadataInPlaceUpdateTests: XCTestCase {

    private var mockDB: MockDatabase!
    private let userId = "u1"

    override func setUp() {
        super.setUp()
        mockDB = MockDatabase()
    }

    override func tearDown() {
        mockDB = nil
        super.tearDown()
    }

    private func user(_ metadata: [String: String]?) -> ChatUser {
        ChatUser(id: userId, firstName: "Ann", metadataDict: metadata)
    }

    /// Stores the user in its own save, as an earlier page would have.
    private func storeUser(_ metadata: [String: String]?) {
        let ctx = mockDB.backgroundPerformContext
        ctx.performAndWait {
            _ = UserDTO.fetchOrCreate(id: userId, context: ctx).map(user(metadata))
            try? ctx.save()
        }
    }

    private func storedMetadata() -> [String: String] {
        let ctx = mockDB.container.viewContext
        ctx.refreshAllObjects()
        let entries = UserDTO.fetch(id: userId, context: ctx)?.metadataEntries ?? []
        var result = [String: String]()
        for entry in entries where !entry.isDeleted { result[entry.key] = entry.value }
        return result
    }

    private func storedEntryIDs() -> [String: NSManagedObjectID] {
        let ctx = mockDB.container.viewContext
        ctx.refreshAllObjects()
        var result = [String: NSManagedObjectID]()
        for entry in UserDTO.fetch(id: userId, context: ctx)?.metadataEntries ?? [] {
            result[entry.key] = entry.objectID
        }
        return result
    }

    // MARK: - Fixed behaviour

    /// Re-saving a user whose metadata didn't change must not insert or delete anything.
    func testRemapUnchangedMetadata_insertsAndDeletesNothing() {
        storeUser(["status": "busy", "lang": "hy"])

        let ctx = mockDB.backgroundPerformContext
        var inserted = -1
        var deleted = -1
        ctx.performAndWait {
            _ = UserDTO.fetchOrCreate(id: userId, context: ctx).map(user(["status": "busy", "lang": "hy"]))
            inserted = ctx.insertedObjects.count
            deleted = ctx.deletedObjects.count
            ctx.rollback()
        }

        XCTAssertEqual(inserted, 0)
        XCTAssertEqual(deleted, 0)
    }

    /// A changed value is set on the existing row; a removed key is deleted; a new key is added.
    func testChangedMetadata_isUpdatedInPlace() {
        storeUser(["status": "busy", "lang": "hy"])
        let before = storedEntryIDs()

        storeUser(["status": "away", "city": "Yerevan"])

        XCTAssertEqual(storedMetadata(), ["status": "away", "city": "Yerevan"])
        XCTAssertEqual(storedEntryIDs()["status"], before["status"],
                       "the changed key must keep its row, not be deleted and re-inserted")
    }

    // MARK: - Guards (unchanged behaviour)

    func testNilMetadata_removesAllEntries() {
        storeUser(["status": "busy"])

        storeUser(nil)

        XCTAssertEqual(storedMetadata(), [:])
    }

    func testEmptyMetadata_removesAllEntries() {
        storeUser(["status": "busy"])

        storeUser([:])

        XCTAssertEqual(storedMetadata(), [:])
    }

    /// The same user saved many times in one write (once per channel of a chat-list page) ends up
    /// with one row per key.
    func testSameUserMappedRepeatedlyInOneWrite_keepsOneRowPerKey() {
        storeUser(["status": "busy"])

        let ctx = mockDB.backgroundPerformContext
        ctx.performAndWait {
            for _ in 0..<5 {
                _ = UserDTO.fetchOrCreate(id: userId, context: ctx).map(user(["status": "busy", "lang": "hy"]))
            }
            try? ctx.save()
        }

        XCTAssertEqual(storedMetadata(), ["status": "busy", "lang": "hy"])
        let request = UserMetadataDTO.fetchRequest()
        XCTAssertEqual((try? mockDB.container.viewContext.count(for: request)) ?? -1, 2)
    }

    func testNewUser_getsItsMetadata() {
        storeUser(["status": "busy"])

        XCTAssertEqual(storedMetadata(), ["status": "busy"])
    }
}
