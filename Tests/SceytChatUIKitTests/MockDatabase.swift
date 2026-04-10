//
//  MockDatabase.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import CoreData
import XCTest

/// An in-memory `Database` implementation for use in unit tests.
/// Set up via `NSInMemoryStoreType` so no disk I/O occurs.
final class MockDatabase: Database {

    let container: NSPersistentContainer

    init() {
        let bundle: Bundle
        #if SWIFT_PACKAGE
        bundle = Bundle.module
        #else
        bundle = Bundle(for: PersistentContainer.self)
        #endif

        guard let modelURL = bundle.url(forResource: "SceytChatModel", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL)
        else { fatalError("MockDatabase: failed to load SceytChatModel") }

        container = NSPersistentContainer(name: "SceytChatModel", managedObjectModel: model)
        let desc = NSPersistentStoreDescription()
        desc.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [desc]
        container.loadPersistentStores { _, error in
            if let error { fatalError("MockDatabase: store load failed: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: - Database protocol

    var viewContext: NSManagedObjectContext { container.viewContext }

    var backgroundPerformContext: NSManagedObjectContext { container.newBackgroundContext() }

    var backgroundReadOnlyContext: NSManagedObjectContext { container.newBackgroundContext() }

    var backgroundReadOnlyObservableContext: NSManagedObjectContext { container.newBackgroundContext() }

    func read<Fetch>(resultQueue: DispatchQueue,
                     _ perform: @escaping (NSManagedObjectContext) throws -> Fetch,
                     completion: ((Result<Fetch, Error>) -> Void)?) {
        let ctx = container.newBackgroundContext()
        ctx.perform {
            let result = Result { try perform(ctx) }
            if let completion {
                resultQueue.async { completion(result) }
            }
        }
    }

    func read<Fetch>(_ perform: @escaping (NSManagedObjectContext) throws -> Fetch) -> Result<Fetch, Error> {
        Result { try perform(container.viewContext) }
    }

    func performBgTask<Fetch>(resultQueue: DispatchQueue,
                               _ perform: @escaping (NSManagedObjectContext) throws -> Fetch,
                               completion: ((Result<Fetch, Error>) -> Void)?) {
        read(resultQueue: resultQueue, perform, completion: completion)
    }

    func write(resultQueue: DispatchQueue,
               _ perform: @escaping (NSManagedObjectContext) throws -> Void,
               completion: ((Error?) -> Void)?) {
        let ctx = container.newBackgroundContext()
        ctx.perform {
            do {
                try perform(ctx)
                try ctx.save()
                if let completion { resultQueue.async { completion(nil) } }
            } catch {
                if let completion { resultQueue.async { completion(error) } }
            }
        }
    }

    func performWriteTask(resultQueue: DispatchQueue,
                          _ perform: @escaping (NSManagedObjectContext) throws -> Void,
                          completion: ((Error?) -> Void)?) {
        write(resultQueue: resultQueue, perform, completion: completion)
    }

    func syncWrite(_ perform: @escaping (NSManagedObjectContext) throws -> Void) throws {
        try perform(container.viewContext)
        try container.viewContext.save()
    }

    func recreate(completion: @escaping ((Error?) -> Void)) { completion(nil) }

    func deleteAll(completion: (() -> Void)?) { completion?() }
}
