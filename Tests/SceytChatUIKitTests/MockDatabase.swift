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

    /// Non-nil when built with `sharesObservableContext: true`.
    private let sharedObservableContext: NSManagedObjectContext?

    /// - Parameter sharesObservableContext: `true` hands out one `backgroundReadOnlyObservableContext`
    ///   for every caller, as `PersistentContainer` does in production (a `lazy var`). The default
    ///   (`false`) keeps the historical behaviour of a fresh context per access, which existing
    ///   suites rely on.
    init(sharesObservableContext: Bool = false) {
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
        // Use SQLite-backed in-memory store (same as production) so that
        // fetch indexes and SQLite query optimizations are exercised.
        desc.url = URL(fileURLWithPath: "/dev/null")
        container.persistentStoreDescriptions = [desc]
        container.loadPersistentStores { _, error in
            if let error { fatalError("MockDatabase: store load failed: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        // Created here, not lazily: Swift `lazy` is not thread-safe, and transfer
        // callbacks reach the first write from several threads at once.
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        backgroundPerformContext = context
        if sharesObservableContext {
            let observable = container.newBackgroundContext()
            observable.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            observable.automaticallyMergesChangesFromParent = true
            observable.retainsRegisteredObjects = true
            sharedObservableContext = observable
        } else {
            sharedObservableContext = nil
        }
    }

    // MARK: - Database protocol

    var viewContext: NSManagedObjectContext { container.viewContext }

    /// One serial context for every write, mirroring `PersistentContainer`. A fresh context
    /// per write let concurrent writes land out of order and conflict on save (the default
    /// `NSErrorMergePolicy`), so a sequence like "persist the downloaded file, then persist the
    /// completion" could commit in either order or not at all — a race the production code does
    /// not have.
    let backgroundPerformContext: NSManagedObjectContext

    var backgroundReadOnlyContext: NSManagedObjectContext { container.newBackgroundContext() }

    var backgroundReadOnlyObservableContext: NSManagedObjectContext {
        sharedObservableContext ?? container.newBackgroundContext()
    }

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
        let ctx = backgroundPerformContext
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
