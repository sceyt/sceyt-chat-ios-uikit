//
//  Database.swift
//  SceytChatUIKit
//

import Foundation
import CoreData
import Network

public protocol Database {

    func write(_ perform: @escaping (NSManagedObjectContext) throws -> Void,
                            completion: ((Error?) -> Void)?)
    func syncWrite(_ perform: @escaping (NSManagedObjectContext) throws -> Void) throws
    func read<Fetch>(_ perform: @escaping (NSManagedObjectContext) throws -> Fetch,
                           completion: ((Result<Fetch, Error>) -> Void)?)
    func read<Fetch>(_ perform: @escaping (NSManagedObjectContext) throws -> Fetch) -> Result<Fetch, Error>
    
    var viewContext: NSManagedObjectContext { get }
    var writableBackgroundContext: NSManagedObjectContext { get }
    var readOnlyBackgroundContext: NSManagedObjectContext { get }
    
    func recreate(completion: @escaping ((Error?) -> Void))
}

public extension Database {

    func write(_ perform: @escaping (NSManagedObjectContext) throws -> Void) {
        write(perform, completion: { _ in })
    }
}

public final class PersistentContainer: NSPersistentContainer, Database {

    public required init(modelName: String = "SceytChatModel", bundle: Bundle? = nil, storeType: StoreType) {
        let modelBundle = bundle ?? Bundle(for: PersistentContainer.self)
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
                debugPrint(error)
                self?.tryRecreatePersistentStore(completion: { error in
                    if let error = error {
                        debugPrint(error)
                    }
                })
            }
        }
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        viewContext.automaticallyMergesChangesFromParent = true
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
        debugPrint("Database file url", description.url as Any)
        persistentStoreDescriptions = [description]
    }

    public lazy var writableBackgroundContext: NSManagedObjectContext = {
       let context = newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }()

    public lazy var readOnlyBackgroundContext: NSManagedObjectContext = {
       let context = newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }()

    public final func write(_ perform: @escaping (NSManagedObjectContext) throws -> Void,
                            completion: ((Error?) -> Void)? = nil) {
        writableBackgroundContext.perform {[weak self] in
            guard let self = self else { return }
            do {
                defer { DispatchQueue.main.async { completion?(nil) } }
                try perform(self.writableBackgroundContext)
                self.writableBackgroundContext.updatedObjects.forEach {
//                    print("[CHECK MESSAGE] 1", type(of: $0), $0.changedValuesForCurrentEvent())
                    guard $0.changedValues().isEmpty else {
                        return
                    }
                    self.writableBackgroundContext.refresh($0, mergeChanges: false)
                }
                guard self.writableBackgroundContext.hasChanges else { return }
                try self.writableBackgroundContext.save()

            } catch {
                DispatchQueue.main.async { completion?(error) }
            }
        }
    }
    
    public final func syncWrite(_ perform: @escaping (NSManagedObjectContext) throws -> Void) throws {
        var _error: Error?
        writableBackgroundContext.performAndWait {
            do {
                try perform(self.writableBackgroundContext)
                self.writableBackgroundContext.updatedObjects.forEach {
                    guard $0.changedValues().isEmpty else {
                        return
                    }
                    self.writableBackgroundContext.refresh($0, mergeChanges: false)
                }
                guard self.writableBackgroundContext.hasChanges else { return }
                try self.writableBackgroundContext.save()

            } catch {
                _error = error
            }
        }
        if let _error {
            throw _error
        }
    }

    public final func read<Fetch>(_ perform: @escaping (NSManagedObjectContext) throws -> Fetch,
                     completion: ((Result<Fetch, Error>) -> Void)?) {
        readOnlyBackgroundContext.perform {[weak self] in
            guard let self = self else { return }
            do {
                let fetch = try perform(self.readOnlyBackgroundContext)
                DispatchQueue.global().async {
                    completion?(.success(fetch))
                }
            } catch {
                completion?(.failure(error))
            }
        }
    }
    
    public final func read<Fetch>(_ perform: @escaping (NSManagedObjectContext) throws -> Fetch) -> Result<Fetch, Error> {
        var result: Result<Fetch, Error>!
        let context = Thread.isMainThread ? viewContext : readOnlyBackgroundContext
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
    
    public func recreate(completion: @escaping ((Error?) -> Void)) {
        writableBackgroundContext.perform {
            self.tryRecreatePersistentStore(completion: completion)
        }
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

fileprivate extension NSError {

    convenience init(reason: String) {
        self.init(domain: "com.sceytchat.uikit.database", code: -1, userInfo: [NSLocalizedDescriptionKey: reason])
    }
}
