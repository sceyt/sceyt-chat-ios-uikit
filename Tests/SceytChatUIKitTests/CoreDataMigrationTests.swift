//
//  CoreDataMigrationTests.swift
//  SceytChatUIKitTests
//
//  Guards the one class of mistake that silently destroys user data. `CoreDataMigrator` finds a
//  source model by hash-matching the store's metadata against the `.mom` files in the bundle; if
//  no model matches, `Database.tryRecreatePersistentStore` destroys and rebuilds the store —
//  every channel, message and draft gone, with nothing but a log line. Editing an already-shipped
//  model version in place, or forgetting to flip `.xccurrentversion`, causes exactly that.
//

@testable import SceytChatUIKit
import CoreData
import XCTest

final class CoreDataMigrationTests: XCTestCase {

    private var bundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle(for: PersistentContainer.self)
        #endif
    }

    private var momdURL: URL {
        guard let url = bundle.url(forResource: "SceytChatModel", withExtension: "momd") else {
            fatalError("compiled model not found — these tests need an xcodebuild run, not `swift test`")
        }
        return url
    }

    private func versionInfo() throws -> [String: Any] {
        let url = momdURL.appendingPathComponent("VersionInfo.plist")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return plist as? [String: Any] ?? [:]
    }

    private func model(named name: String) -> NSManagedObjectModel? {
        NSManagedObjectModel(contentsOf: momdURL.appendingPathComponent("\(name).mom"))
    }

    // MARK: - Frozen versions

    /// Superseded model versions are immutable records of what actually shipped. Changing one
    /// re-hashes it, so no device's store matches any model on disk and every existing install is
    /// wiped on next launch. If this fails, revert the edit and add a new version instead.
    func testShippedModelVersions_areFrozen() throws {
        let expected = [
            "SceytChatModel": "2ec9Pd/qk7HY4O+5N7Or7RdY9FzScGjC61UiodzwWLE=",
            "SceytChatModelV2": "2CK6Fi3k6bGBJys+deMGN80bRUjTgl8pccnAbIdlBSA=",
            "SceytChatModelV3": "qU4TwYYuTfM7y1OKmqCAx5oYrDqyNsd9T5K5m4SCCqQ="
        ]

        let checksums = try versionInfo()["NSManagedObjectModel_VersionChecksums"] as? [String: String] ?? [:]

        for (name, checksum) in expected {
            XCTAssertEqual(
                checksums[name], checksum,
                "\(name) has already shipped. Editing it wipes every existing store — add a new model version instead."
            )
        }
    }

    /// A new version that `.xccurrentversion` never points at is dead weight: the store keeps
    /// migrating to the old one and the new entities are simply absent at runtime.
    func testCurrentModelVersion_isTheNewestOne() throws {
        XCTAssertEqual(
            try versionInfo()["NSManagedObjectModel_CurrentVersionName"] as? String,
            "SceytChatModelV4",
            ".xccurrentversion must point at the newest model version"
        )
    }

    /// The draft side table is what the current version exists for.
    func testCurrentModel_hasTheDraftEntities() {
        guard let current = NSManagedObjectModel(contentsOf: momdURL) else {
            return XCTFail("could not load the current model")
        }

        let draft = current.entitiesByName["DraftMessageDTO"]
        XCTAssertNotNil(draft)
        XCTAssertEqual(
            draft?.uniquenessConstraints.first?.compactMap { $0 as? String }, ["channelId"],
            "one draft per channel"
        )
        XCTAssertNotNil(current.entitiesByName["DraftAttachmentDTO"])
        XCTAssertEqual(
            draft?.relationshipsByName["attachments"]?.deleteRule, .cascadeDeleteRule,
            "attachment rows must not outlive their draft"
        )
    }

    /// The draft deliberately has no relationship to `ChannelDTO` or `MessageDTO`: both are
    /// batch-deleted elsewhere, and `NSBatchDeleteRequest` ignores deletion rules, so such a
    /// relationship would leave dangling references and eventually trap on save.
    func testDraftEntities_holdNoRelationshipToVolatileEntities() {
        guard let current = NSManagedObjectModel(contentsOf: momdURL) else {
            return XCTFail("could not load the current model")
        }

        for name in ["DraftMessageDTO", "DraftAttachmentDTO"] {
            let destinations = (current.entitiesByName[name]?.relationshipsByName.values ?? [:].values)
                .compactMap { $0.destinationEntity?.name }
            XCTAssertFalse(
                destinations.contains("ChannelDTO") || destinations.contains("MessageDTO"),
                "\(name) must key volatile entities by id, not by relationship — batch deletes bypass deletion rules"
            )
        }
    }

    /// `ChannelDTO` gains only the denormalized `draftAttachmentType` the channel list previews
    /// from; the draft payload itself lives in its own entity. Keeping the change purely additive
    /// is what makes the V3→V4 hop inference-eligible and leaves `willSave`/`sortingKey` and every
    /// existing observer working unchanged.
    func testChannelDTO_changesOnlyAdditivelyBetweenV3AndV4() throws {
        guard let v3 = model(named: "SceytChatModelV3"),
              let v4 = model(named: "SceytChatModelV4"),
              let v3Channel = v3.entitiesByName["ChannelDTO"],
              let v4Channel = v4.entitiesByName["ChannelDTO"]
        else { return XCTFail("could not load both model versions") }

        let removed = Set(v3Channel.propertiesByName.keys).subtracting(v4Channel.propertiesByName.keys)
        XCTAssertTrue(removed.isEmpty, "ChannelDTO must not lose properties: \(removed.sorted())")

        let added = Set(v4Channel.propertiesByName.keys).subtracting(v3Channel.propertiesByName.keys)
        XCTAssertEqual(
            added, ["draftAttachmentType", "draftActionType"],
            "the draft payload belongs in DraftMessageDTO; only what the cell previews lives here"
        )
    }

    // MARK: - Real migration

    /// The end-to-end guarantee: an existing V3 store migrates rather than being destroyed, and
    /// the draft text already sitting on `ChannelDTO` comes through untouched.
    func testV3Store_migratesToCurrent_preservingChannelsAndDrafts() throws {
        guard let v3 = model(named: "SceytChatModelV3") else {
            return XCTFail("could not load SceytChatModelV3")
        }
        // The V3 entities would otherwise bind to the *compiled* DTO classes, which now declare
        // properties V3 does not have.
        v3.entities.forEach { $0.managedObjectClassName = NSStringFromClass(NSManagedObject.self) }

        let storeURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("migration-\(UUID().uuidString).sqlite")
        addTeardownBlock {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(
                    at: storeURL.deletingLastPathComponent()
                        .appendingPathComponent(storeURL.lastPathComponent + suffix)
                )
            }
        }

        // --- Write a genuine V3 store ---
        let v3Coordinator = NSPersistentStoreCoordinator(managedObjectModel: v3)
        try v3Coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
        let v3Context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        v3Context.persistentStoreCoordinator = v3Coordinator

        let channel = NSEntityDescription.insertNewObject(forEntityName: "ChannelDTO", into: v3Context)
        channel.setValue(Int64(7), forKey: "id")
        channel.setValue(Date(), forKey: "createdAt")
        channel.setValue("group", forKey: "type")
        channel.setValue(Date(), forKey: "sortingKey")
        channel.setValue(NSAttributedString(string: "draft from the old version"), forKey: "draft")
        channel.setValue(Date(), forKey: "draftDate")
        try v3Context.save()

        for store in v3Coordinator.persistentStores {
            try v3Coordinator.remove(store)
        }

        // --- Migrate ---
        try CoreDataMigrator.migrateStoreIfNeeded(at: storeURL, modelName: "SceytChatModel", bundle: bundle)

        // --- Reopen with the current model ---
        guard let current = NSManagedObjectModel(contentsOf: momdURL) else {
            return XCTFail("could not load the current model")
        }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: current)
        try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        let request = NSFetchRequest<NSManagedObject>(entityName: "ChannelDTO")
        let channels = try context.fetch(request)

        XCTAssertEqual(channels.count, 1, "the store must be migrated, not destroyed and rebuilt")
        XCTAssertEqual(channels.first?.value(forKey: "id") as? Int64, 7)
        XCTAssertEqual(
            (channels.first?.value(forKey: "draft") as? NSAttributedString)?.string,
            "draft from the old version",
            "an existing draft must survive the migration"
        )

        for column in ["draftAttachmentType", "draftActionType"] {
            XCTAssertNil(
                channels.first?.value(forKey: column),
                "\(column) must migrate in empty, not block the migration"
            )
        }

        let drafts = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "DraftMessageDTO"))
        XCTAssertTrue(drafts.isEmpty, "the new side table starts empty; no data migration is needed")
    }
}
