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
               completion: ((Error?) -> Void)?) {
        write(resultQueue: .main, perform, completion: completion)
    }
    
    func read<Fetch>(_ perform: @escaping (NSManagedObjectContext) throws -> Fetch,
                     completion: ((Result<Fetch, Error>) -> Void)?) {
        read(resultQueue: .main, perform, completion: completion)
    }
    
    func write(_ perform: @escaping (NSManagedObjectContext) throws -> Void) {
        write(perform, completion: { _ in })
    }
    
    func performWriteTask(_ perform: @escaping (NSManagedObjectContext) throws -> Void, completion: ((Error?) -> Void)?) {
        performWriteTask(resultQueue: .main, perform, completion: completion)
    }
    
    func performWriteTask(_ perform: @escaping (NSManagedObjectContext) throws -> Void) {
        performWriteTask(resultQueue: .main, perform, completion: nil)
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
        backgroundPerformContext.perform {
            if resetStalenessInterval {
                self.backgroundPerformContext.stalenessInterval = 0
            }
            self.backgroundPerformContext.refreshAllObjects()
            if resetStalenessInterval {
                self.backgroundPerformContext.stalenessInterval = -1
            }
        }

        backgroundReadOnlyObservableContext.perform {
            if resetStalenessInterval {
                self.backgroundReadOnlyObservableContext.stalenessInterval = 0
            }
            self.backgroundReadOnlyObservableContext.refreshAllObjects()
            if resetStalenessInterval {
                self.backgroundReadOnlyObservableContext.stalenessInterval = -1
            }
            
            backgroundReadOnlyContext.perform {
                if resetStalenessInterval {
                    self.backgroundReadOnlyContext.stalenessInterval = 0
                }
                self.backgroundReadOnlyContext.refreshAllObjects()
                if resetStalenessInterval {
                    self.backgroundReadOnlyContext.stalenessInterval = -1
                }
                
                DispatchQueue.main.async {
                    if resetStalenessInterval {
                        self.viewContext.stalenessInterval = 0
                    }
                    self.viewContext.refreshAllObjects()
                    if resetStalenessInterval {
                        self.viewContext.stalenessInterval = -1
                    }
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

    // Accessed only on the main queue — guards against reacting to same-process saves.
    private var lastHistoryToken: NSPersistentHistoryToken?

    private lazy var observersQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    public required init(modelName: String = "SceytChatModel", bundle: Bundle? = nil, storeType: StoreType) {
        let modelBundle = bundle ?? Bundle.kit(for: PersistentContainer.self)
        guard let modelUrl = modelBundle.url(forResource: modelName, withExtension: "momd") else {
            fatalError("file \(modelName).momd font found")
        }
        guard let model = NSManagedObjectModel(contentsOf: modelUrl) else {
            fatalError("cant't create model for \(modelUrl)")
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
            }
        }
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        viewContext.automaticallyMergesChangesFromParent = true
        addObservers()
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
            description.setOption(true as NSNumber,
                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
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
        context.transactionAuthor = Bundle.main.bundleIdentifier
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
        NotificationCenter.default.removeObserver(
            self,
            name: .NSPersistentStoreRemoteChange,
            object: persistentStoreCoordinator)
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
        notificationCenter.addObserver(self,
            selector: #selector(storeDidChangeExternally(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: persistentStoreCoordinator)
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

    @objc
    func storeDidChangeExternally(_ notification: Notification) {
        // NSPersistentStoreRemoteChange fires for ALL saves — including same-process ones.
        // Fetch persistent history to check whether any transaction was authored by a
        // different process (NSE / Share Extension). Only then refresh contexts and
        // notify observers, so that normal in-app writes don't trigger a cascade.
        let currentAuthor = Bundle.main.bundleIdentifier
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let tokenSnapshot = self.lastHistoryToken
            let historyContext = self.newBackgroundContext()
            historyContext.perform {
                let fetchRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: tokenSnapshot)
                guard let result = try? historyContext.execute(fetchRequest) as? NSPersistentHistoryResult,
                      let transactions = result.result as? [NSPersistentHistoryTransaction],
                      !transactions.isEmpty else { return }

                let lastToken = transactions.last?.token
                let hasExternalChanges = transactions.contains { $0.author != currentAuthor }

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.lastHistoryToken = lastToken

                    // Purge processed history to prevent unbounded table growth.
                    if let purgeToken = lastToken {
                        let purgeContext = self.newBackgroundContext()
                        purgeContext.perform {
                            let purgeRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: purgeToken)
                            try? purgeContext.execute(purgeRequest)
                        }
                    }

                    guard hasExternalChanges else { return }

                    self.refreshAllObjects {
                        NotificationCenter.default.post(
                            name: .persistentStoreDidChangeExternally,
                            object: self)
                    }
                }
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
