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

    /// In-memory FTS store paired with this database. Saves through the container
    /// are mirrored into the store via the `didSave` observer below.
    let messageSearchStore: MessageSearchStore

    private var didSaveObserver: NSObjectProtocol?

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
        // Use SQLite-backed in-memory store (same as production) so that
        // fetch indexes and SQLite query optimizations are exercised.
        desc.url = URL(fileURLWithPath: "/dev/null")
        container.persistentStoreDescriptions = [desc]
        container.loadPersistentStores { _, error in
            if let error { fatalError("MockDatabase: store load failed: \(error)") }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        messageSearchStore = MessageSearchStore.inMemory()
        messageSearchStore.open()

        installFTSObserver()
    }

    deinit {
        if let didSaveObserver {
            NotificationCenter.default.removeObserver(didSaveObserver)
        }
        messageSearchStore.close()
    }

    /// Toggles automatic FTS sync on Core Data saves. Disable during heavy
    /// bulk seeding (e.g. perf tests) so the per-save observer doesn't add
    /// thousands of synchronous FTS round-trips on the saving context's queue.
    /// Caller is expected to re-enable and bulk-index manually after seeding.
    func setFTSSyncEnabled(_ enabled: Bool) {
        if enabled, didSaveObserver == nil {
            installFTSObserver()
        } else if !enabled, let observer = didSaveObserver {
            NotificationCenter.default.removeObserver(observer)
            didSaveObserver = nil
        }
    }

    private func installFTSObserver() {
        let store = messageSearchStore
        let coordinator = container.persistentStoreCoordinator
        didSaveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil
        ) { notification in
            // Filter to saves that came from a context backed by this container's
            // store coordinator. Without this, saves from other tests could leak
            // through the shared NotificationCenter into our FTS store.
            guard let savingContext = notification.object as? NSManagedObjectContext,
                  savingContext.persistentStoreCoordinator === coordinator
            else { return }
            // The notification's userInfo references managed objects that are only
            // valid on the saving context's queue, so we hop onto it before syncing.
            savingContext.performAndWait {
                store.sync(notification: notification, on: savingContext)
            }
        }
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
