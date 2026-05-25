//
//  Database.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData

public protocol Database {

    func write(resultQueue: DispatchQueue,
               _ perform: @escaping (NSManagedObjectContext) throws -> Void,
               completion: ((Error?) -> Void)?)
    func performWriteTask(resultQueue: DispatchQueue,
                          _ perform: @escaping (NSManagedObjectContext) throws -> Void,
                          completion: ((Error?) -> Void)?)
    func syncWrite(_ perform: @escaping (NSManagedObjectContext) throws -> Void) throws
    func read<Fetch>(resultQueue: DispatchQueue,
                     _ perform: @escaping (NSManagedObjectContext) throws -> Fetch,
                     completion: ((Result<Fetch, Error>) -> Void)?)
    func read<Fetch>(_ perform: @escaping (NSManagedObjectContext) throws -> Fetch) -> Result<Fetch, Error>
    func performBgTask<Fetch>(resultQueue: DispatchQueue,
                     _ perform: @escaping (NSManagedObjectContext) throws -> Fetch,
                     completion: ((Result<Fetch, Error>) -> Void)?)
    
    var viewContext: NSManagedObjectContext { get }
    var backgroundPerformContext: NSManagedObjectContext { get }
    var backgroundReadOnlyContext: NSManagedObjectContext { get }
    var backgroundReadOnlyObservableContext: NSManagedObjectContext { get }
    
    func recreate(completion: @escaping ((Error?) -> Void))
    func deleteAll(completion: (() -> Void)?)
}

public extension Database {

    func write(_ perform: @escaping (NSManagedObjectContext) throws -> Void,
               completion: ((Error?) -> Void)?,
               file: StaticString = #file,
               line: UInt = #line,
               function: StaticString = #function) {
        let wrapped = DatabaseWriteWatchdog.wrap(perform, kind: "bgPerform", file: file, line: line, function: function)
        write(resultQueue: .main, wrapped, completion: completion)
    }

    func read<Fetch>(_ perform: @escaping (NSManagedObjectContext) throws -> Fetch,
                     completion: ((Result<Fetch, Error>) -> Void)?) {
        read(resultQueue: .main, perform, completion: completion)
    }

    func write(_ perform: @escaping (NSManagedObjectContext) throws -> Void,
               file: StaticString = #file,
               line: UInt = #line,
               function: StaticString = #function) {
        write(perform, completion: { _ in }, file: file, line: line, function: function)
    }

    func write(resultQueue: DispatchQueue,
               _ perform: @escaping (NSManagedObjectContext) throws -> Void,
               completion: ((Error?) -> Void)? = nil,
               file: StaticString = #file,
               line: UInt = #line,
               function: StaticString = #function) {
        let wrapped = DatabaseWriteWatchdog.wrap(perform, kind: "bgPerform", file: file, line: line, function: function)
        write(resultQueue: resultQueue, wrapped, completion: completion)
    }

    func performWriteTask(_ perform: @escaping (NSManagedObjectContext) throws -> Void,
                          completion: ((Error?) -> Void)?,
                          file: StaticString = #file,
                          line: UInt = #line,
                          function: StaticString = #function) {
        let wrapped = DatabaseWriteWatchdog.wrap(perform, kind: "newCtx", file: file, line: line, function: function)
        performWriteTask(resultQueue: .main, wrapped, completion: completion)
    }

    func performWriteTask(_ perform: @escaping (NSManagedObjectContext) throws -> Void,
                          file: StaticString = #file,
                          line: UInt = #line,
                          function: StaticString = #function) {
        performWriteTask(perform, completion: nil, file: file, line: line, function: function)
    }

    func performWriteTask(resultQueue: DispatchQueue,
                          _ perform: @escaping (NSManagedObjectContext) throws -> Void,
                          completion: ((Error?) -> Void)? = nil,
                          file: StaticString = #file,
                          line: UInt = #line,
                          function: StaticString = #function) {
        let wrapped = DatabaseWriteWatchdog.wrap(perform, kind: "newCtx", file: file, line: line, function: function)
        performWriteTask(resultQueue: resultQueue, wrapped, completion: completion)
    }

    func syncWrite(_ perform: @escaping (NSManagedObjectContext) throws -> Void,
                   file: StaticString = #file,
                   line: UInt = #line,
                   function: StaticString = #function) throws {
        let wrapped = DatabaseWriteWatchdog.wrap(perform, kind: "syncWrite", file: file, line: line, function: function)
        try syncWrite(wrapped)
    }
    
    func performBgTask<Fetch>(_ perform: @escaping (NSManagedObjectContext) throws -> Fetch,
                              completion: ((Result<Fetch, Error>) -> Void)?) {
        performBgTask(resultQueue: .main, perform, completion: completion)
    }
    
    func performBgTask<Fetch>(_ perform: @escaping (NSManagedObjectContext) throws -> Fetch) {
        performBgTask(resultQueue: .main, perform, completion: nil)
    }
    
    func refreshAllObjects(
        resetStalenessInterval: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        logger.debug("[Ctx] refreshAll called")
        backgroundPerformContext.perform {
            logger.debug("[Ctx] refreshAll bgPerform")
            if resetStalenessInterval {
                self.backgroundPerformContext.stalenessInterval = 0
            }
            self.backgroundPerformContext.refreshAllObjects()
            if resetStalenessInterval {
                self.backgroundPerformContext.stalenessInterval = -1
            }
        }

        backgroundReadOnlyObservableContext.perform {
            logger.debug("[Ctx] refreshAll bgReadObs")
            if resetStalenessInterval {
                self.backgroundReadOnlyObservableContext.stalenessInterval = 0
            }
            self.backgroundReadOnlyObservableContext.refreshAllObjects()
            if resetStalenessInterval {
                self.backgroundReadOnlyObservableContext.stalenessInterval = -1
            }

            backgroundReadOnlyContext.perform {
                logger.debug("[Ctx] refreshAll bgRead")
                if resetStalenessInterval {
                    self.backgroundReadOnlyContext.stalenessInterval = 0
                }
                self.backgroundReadOnlyContext.refreshAllObjects()
                if resetStalenessInterval {
                    self.backgroundReadOnlyContext.stalenessInterval = -1
                }

                DispatchQueue.main.async {
                    logger.debug("[Ctx] refreshAll view")
                    if resetStalenessInterval {
                        self.viewContext.stalenessInterval = 0
                    }
                    self.viewContext.refreshAllObjects()
                    if resetStalenessInterval {
                        self.viewContext.stalenessInterval = -1
                    }
                    logger.debug("[Ctx] refreshAll done")
                    completion?()
                }
            }
        }
    }
    
    func deleteAll() {
        deleteAll(completion: nil)
    }
}

public final class PersistentContainer: NSPersistentContainer, Database {

    public required init(modelName: String = "SceytChatModel", bundle: Bundle? = nil, storeType: StoreType) {
        let modelBundle = bundle ?? Bundle.kit(for: PersistentContainer.self)
        guard let modelUrl = modelBundle.url(forResource: modelName, withExtension: "momd") else {
            fatalError("file \(modelName).momd font found")
        }
        guard let model = NSManagedObjectModel(contentsOf: modelUrl) else {
            fatalError("cant't create model for \(modelUrl)")
        }

        if case let .sqLite(storeURL) = storeType {
            do {
                try CoreDataMigrator.migrateStoreIfNeeded(
                    at: storeURL,
                    modelName: modelName,
                    bundle: modelBundle
                )
            } catch {
                logger.errorIfNotNil(error, "CoreData migration failed; falling back to recreate.")
            }
        }

        super.init(name: modelName, managedObjectModel: model)
        setPersistentStoreDescription(type: storeType)
        loadPersistentStores {[weak self] _, error in
            if let error = error {
                logger.errorIfNotNil(error, "")
                self?.tryRecreatePersistentStore(completion: { error in
                    if let error = error {
                        logger.errorIfNotNil(error, "")
                    }
                })
            } else {
                self?.purgePersistentHistory()
            }
        }
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        viewContext.automaticallyMergesChangesFromParent = true
        addObservers()
    }
    
    private func purgePersistentHistory() {
        let context = newBackgroundContext()
        context.perform {
            let request = NSPersistentHistoryChangeRequest.deleteHistory(before: Date())
            do {
                try context.execute(request)
            } catch {
                logger.errorIfNotNil(error, "Failed to purge persistent history")
            }
        }
    }

    private func tryRecreatePersistentStore(completion: @escaping ((Error?) -> Void)) {
        
        guard let storeDescription = persistentStoreDescriptions.first else {
            completion(NSError(reason: "Not found PersistentStoreDescriptions"))
            return
        }
        
        do {
            try persistentStoreCoordinator.persistentStores.forEach {
                try persistentStoreCoordinator.remove($0)
            }
            if let storeURL = storeDescription.url, !storeURL.absoluteString.hasSuffix("/dev/null") {
                try persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: storeDescription.type, options: nil)
            }
        } catch {
            completion(error)
            return
        }
        
        loadPersistentStores {
            completion($1)
        }
    }
    
    private func setPersistentStoreDescription(type: StoreType) {
        let description = NSPersistentStoreDescription()
        
        switch type {
        case .sqLite(let fileUrl):
            description.url = fileUrl
            // Tracking must stay enabled once a store has used it — Core Data otherwise
            // forces the store into read-only mode (NSCocoaErrorDomain 513). The remote-
            // change notification is intentionally NOT requested: we don't run the
            // per-save fetch/purge cascade, which was the source of multi-second
            // backgroundPerformContext stalls.
            description.setOption(true as NSNumber,
                forKey: NSPersistentHistoryTrackingKey)
        case .binary(let fileUrl):
            description.url = fileUrl
        case .inMemory:
            // https://useyourloaf.com/blog/core-data-in-memory-store/
            if #available(iOS 13, *) {
                description.url = URL(fileURLWithPath: "/dev/null")
            } else {
                description.type = NSInMemoryStoreType
            }
        }
        logger.debug("Database file url \(description.url)")
        persistentStoreDescriptions = [description]
    }
    
    public lazy var backgroundPerformContext: NSManagedObjectContext = {
        let context = newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
   
    public lazy var backgroundReadOnlyContext: NSManagedObjectContext = {
        let context = newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
    
    public lazy var backgroundReadOnlyObservableContext: NSManagedObjectContext = {
        let context = newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        context.retainsRegisteredObjects = true
        return context
    }()
    
    public func createBackgroundContext() -> NSManagedObjectContext {
        let context = newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }
    
    public final func write(resultQueue: DispatchQueue,
                            _ perform: @escaping (NSManagedObjectContext) throws -> Void,
                            completion: ((Error?) -> Void)? = nil) {
        logger.debug("[Ctx] bgPerform write")
        backgroundPerformContext.perform {[weak self] in
            guard let self = self else { return }
            do {
                defer { resultQueue.async { completion?(nil) } }
                try perform(self.backgroundPerformContext)
                for object in self.backgroundPerformContext.updatedObjects {
                    if object.changedValues().isEmpty {
                        self.backgroundPerformContext.refresh(object, mergeChanges: false)
                    }
                }
                if self.backgroundPerformContext.hasChanges {
                    self.logUncommittedChanges(context: self.backgroundPerformContext)
                    try self.backgroundPerformContext.save()
                }
            } catch {
                resultQueue.async { completion?(error) }
            }
        }
    }
    
    func logUncommittedChanges(context: NSManagedObjectContext) {
    }
    
    public final func performWriteTask(resultQueue: DispatchQueue,
                                              _ perform: @escaping (NSManagedObjectContext) throws -> Void,
                                              completion: ((Error?) -> Void)? = nil) {
        let context = createBackgroundContext()
        logger.debug("[Ctx] newCtx write")
        context.perform {[weak self] in
            guard let self = self else { return }
            do {
                defer { resultQueue.async { completion?(nil) } }
                try perform(context)
                for object in context.updatedObjects {
                    if object.changedValues().isEmpty {
                        context.refresh(object, mergeChanges: false)
                    }
                }
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                context.rollback()
                resultQueue.async { completion?(error) }
            }
        }
    }
    
    public final func syncWrite(_ perform: @escaping (NSManagedObjectContext) throws -> Void) throws {
        var _error: Error?
        logger.debug("[Ctx] bgPerform syncWrite")
        backgroundPerformContext.performAndWait {
            do {
                try perform(self.backgroundPerformContext)
                self.backgroundPerformContext.updatedObjects.forEach {
                    guard $0.changedValues().isEmpty else {
                        return
                    }
                    self.backgroundPerformContext.refresh($0, mergeChanges: false)
                }
                guard self.backgroundPerformContext.hasChanges else { return }
                try self.backgroundPerformContext.save()
            } catch {
                _error = error
            }
        }
        if let _error {
            throw _error
        }
    }
    
    public final func read<Fetch>(resultQueue: DispatchQueue,
                                  _ perform: @escaping (NSManagedObjectContext) throws -> Fetch,
                                  completion: ((Result<Fetch, Error>) -> Void)?) {
        let context = backgroundReadOnlyContext
        logger.debug("[Ctx] bgRead read")
        context.perform {[weak self] in
            guard self != nil else { return }
            do {
                let fetch = try perform(context)
                resultQueue.async {
                    completion?(.success(fetch))
                }
            } catch {
                resultQueue.async {
                    completion?(.failure(error))
                }
            }
        }
    }
    
    public final func read<Fetch>(_ perform: @escaping (NSManagedObjectContext) throws -> Fetch) -> Result<Fetch, Error> {
        var result: Result<Fetch, Error>!
        let context = Thread.isMainThread ? viewContext : backgroundReadOnlyContext
        logger.debug("[Ctx] \(Thread.isMainThread ? "view" : "bgRead") read")
        context.performAndWait {
            do {
                let fetch = try perform(context)
                result = .success(fetch)
            } catch {
                result = .failure(error)
            }
        }
        return result
    }
    
    public final func performBgTask<Fetch>(resultQueue: DispatchQueue,
                                           _ perform: @escaping (NSManagedObjectContext) throws -> Fetch,
                                           completion: ((Result<Fetch, Error>) -> Void)? = nil) {
        let context = createBackgroundContext()
        logger.debug("[Ctx] newCtx bgTask")
        context.perform {
            guard self != nil else { return }
            do {
                let fetch = try perform(context)
                resultQueue.async {
                    completion?(.success(fetch))
                }
            } catch {
                resultQueue.async {
                    completion?(.failure(error))
                }
            }
        }
    }
    
    public func recreate(completion: @escaping ((Error?) -> Void)) {
        backgroundPerformContext.perform {
            self.tryRecreatePersistentStore(completion: completion)
        }
    }
    
    public func deleteAll(completion: (() -> Void)? = nil) {
        backgroundPerformContext.perform {
            for key in self.managedObjectModel.entitiesByName.keys {
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: key)
                try? self.backgroundPerformContext.batchDelete(fetchRequest: request)
            }
            completion?()
        }
    }
    
    deinit {
        NotificationCenter.default
            .removeObserver(
                self,
                name: .NSManagedObjectContextDidSave,
                object: backgroundPerformContext)
    }
}

public extension PersistentContainer {
    
    enum StoreType {
        case sqLite(databaseFileUrl: URL)
        case binary(fileUrl: URL)
        case inMemory
        
        public var rawValue: String {
            switch self {
            case .sqLite:
                return NSSQLiteStoreType
            case .binary:
                return NSBinaryStoreType
            case .inMemory:
                return NSInMemoryStoreType
            }
        }
    }
}

private extension PersistentContainer {
    
    func addObservers() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(didSave(notification: )), name: .NSManagedObjectContextDidSave, object: backgroundPerformContext)
    }
    
    func removeObservers() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: .NSManagedObjectContextDidSave, object: nil)
    }
    
    @objc
    func didSave(notification: Notification) {
        if (notification.object as? NSManagedObjectContext) === backgroundPerformContext {
            backgroundReadOnlyObservableContext.perform {
                self.backgroundReadOnlyObservableContext.mergeChanges(fromContextDidSave: notification)
            }
        }
    }
}

fileprivate extension NSError {
    
    convenience init(reason: String) {
        self.init(domain: "com.sceytchat.uikit.database", code: -1, userInfo: [NSLocalizedDescriptionKey: reason])
    }
}


public extension NSManagedObjectContext {

    func mergeChangesWithViewContext(fromRemoteContextSave: [AnyHashable: Any]) {
        NSManagedObjectContext.mergeChanges(
            fromRemoteContextSave: fromRemoteContextSave,
            into: [self, SceytChatUIKit.shared.database.viewContext]
        )
    }
}

public extension Notification.Name {
    static let persistentStoreDidChangeExternally =
        Notification.Name("SceytChatUIKit.persistentStoreDidChangeExternally")
}

enum DatabaseWriteWatchdog {

    static var stuckThreshold: TimeInterval = 5

    static func wrap(
        _ perform: @escaping (NSManagedObjectContext) throws -> Void,
        kind: String,
        file: StaticString,
        line: UInt,
        function: StaticString
    ) -> (NSManagedObjectContext) throws -> Void {
        let id = String(UUID().uuidString.prefix(8))
        let callsite = "\(("\(file)" as NSString).lastPathComponent):\(line) \(function)"
        let enqueuedAt = CFAbsoluteTimeGetCurrent()
        logger.debug("[Ctx] \(kind) ENQUEUE id=\(id) by=\(callsite)")
        let enqueueWatchdog = DispatchWorkItem {
            logger.error("[Ctx] \(kind) WATCHDOG id=\(id) >\(Int(stuckThreshold))s NOT STARTED by=\(callsite)")
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + stuckThreshold, execute: enqueueWatchdog)
        return { ctx in
            enqueueWatchdog.cancel()
            let waited = CFAbsoluteTimeGetCurrent() - enqueuedAt
            let started = CFAbsoluteTimeGetCurrent()
            logger.debug("[Ctx] \(kind) START id=\(id) waited=\(Int(waited*1000))ms by=\(callsite)")
            let runWatchdog = DispatchWorkItem {
                logger.error("[Ctx] \(kind) WATCHDOG id=\(id) >\(Int(stuckThreshold))s STILL RUNNING by=\(callsite)")
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + stuckThreshold, execute: runWatchdog)
            defer {
                runWatchdog.cancel()
                let dur = CFAbsoluteTimeGetCurrent() - started
                logger.debug("[Ctx] \(kind) END id=\(id) duration=\(Int(dur*1000))ms by=\(callsite)")
            }
            try perform(ctx)
        }
    }
}
