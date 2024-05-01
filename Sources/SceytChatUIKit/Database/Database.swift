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
    
    func performBgTask<Fetch>(_ perform: @escaping (NSManagedObjectContext) throws -> Fetch,
                              completion: ((Result<Fetch, Error>) -> Void)?) {
        performBgTask(resultQueue: .main, perform, completion: completion)
    }
    
    func refreshAllObjects(
        resetStalenessInterval: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        
        if resetStalenessInterval {
            self.backgroundPerformContext.stalenessInterval = 0
        }
        self.backgroundPerformContext.refreshAllObjects()
        if resetStalenessInterval {
            self.backgroundPerformContext.stalenessInterval = -1
        }
        
        if resetStalenessInterval {
            self.backgroundReadOnlyObservableContext.stalenessInterval = 0
        }
        self.backgroundReadOnlyObservableContext.refreshAllObjects()
        if resetStalenessInterval {
            self.backgroundReadOnlyObservableContext.stalenessInterval = -1
        }
        
        if resetStalenessInterval {
            self.viewContext.stalenessInterval = 0
        }
        self.viewContext.refreshAllObjects()
        if resetStalenessInterval {
            self.viewContext.stalenessInterval = -1
        }
        completion?()
    }
    
    func deleteAll() {
        deleteAll(completion: nil)
    }
}

public final class PersistentContainer: NSPersistentContainer, Database {
    
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
    
    public lazy var backgroundReadOnlyObservableContext: NSManagedObjectContext = {
        let context = newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        context.retainsRegisteredObjects = true
        return context
    }()
    
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
                    try self.backgroundPerformContext.save()
                }
            } catch {
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
        let context = backgroundPerformContext
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
        let context = Thread.isMainThread ? viewContext : backgroundPerformContext
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
                                           completion: ((Result<Fetch, Error>) -> Void)?) {
        performBackgroundTask {[weak self] context in
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
            into: [self, Config.database.viewContext]
        )
    }
}
