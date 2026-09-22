//
//  CoreDataMigrator.swift
//  SceytChatUIKit
//

import Foundation
import CoreData

enum CoreDataMigratorError: Error {
    case missingMomd
    case missingDestinationModel
    case noCompatibleSourceModel
}

enum CoreDataMigrator {

    /// Migrates the persistent store at `storeURL` to the latest model version if needed.
    ///
    /// Runs an inferred mapping for all entities, then attaches `MemberDTOMigrationPolicy`
    /// to the `MemberDTO` mapping so the new `channel` relationship is populated atomically
    /// with the schema change.
    static func migrateStoreIfNeeded(
        at storeURL: URL,
        modelName: String,
        bundle: Bundle
    ) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { return }

        guard let momdURL = bundle.url(forResource: modelName, withExtension: "momd") else {
            throw CoreDataMigratorError.missingMomd
        }

        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )

        guard let destinationModel = NSManagedObjectModel(contentsOf: momdURL) else {
            throw CoreDataMigratorError.missingDestinationModel
        }

        if destinationModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
            return
        }

        let momURLs = bundle.urls(forResourcesWithExtension: "mom", subdirectory: momdURL.lastPathComponent) ?? []
        let candidateModels = momURLs.compactMap { NSManagedObjectModel(contentsOf: $0) }

        guard let sourceModel = candidateModels.first(where: {
            $0.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }) else {
            throw CoreDataMigratorError.noCompatibleSourceModel
        }

        let mappingModel = try NSMappingModel.inferredMappingModel(
            forSourceModel: sourceModel,
            destinationModel: destinationModel
        )

        if let entityMappings = mappingModel.entityMappings {
            for mapping in entityMappings where mapping.destinationEntityName == "MemberDTO" {
                mapping.entityMigrationPolicyClassName = NSStringFromClass(MemberDTOMigrationPolicy.self)
            }
        }

        let migrationManager = NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
        let tempStoreURL = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(storeURL.lastPathComponent).migration_tmp")

        if fm.fileExists(atPath: tempStoreURL.path) {
            try? fm.removeItem(at: tempStoreURL)
        }

        try migrationManager.migrateStore(
            from: storeURL,
            sourceType: NSSQLiteStoreType,
            options: nil,
            with: mappingModel,
            toDestinationURL: tempStoreURL,
            destinationType: NSSQLiteStoreType,
            destinationOptions: nil
        )

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: destinationModel)
        try coordinator.replacePersistentStore(
            at: storeURL,
            destinationOptions: nil,
            withPersistentStoreFrom: tempStoreURL,
            sourceOptions: nil,
            ofType: NSSQLiteStoreType
        )
        try coordinator.destroyPersistentStore(
            at: tempStoreURL,
            ofType: NSSQLiteStoreType,
            options: nil
        )
    }
}
