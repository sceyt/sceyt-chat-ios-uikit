//
//  DatabaseObserver.swift
//  SceytChatUIKit
//

import Foundation
import CoreData

open class DatabaseObserver<DTO: NSManagedObject, Item>: NSObject, NSFetchedResultsControllerDelegate {
    
    public let request: NSFetchRequest<DTO>
    public let controller: NSFetchedResultsController<DTO>
    public let context: NSManagedObjectContext
    public let itemCreator: (DTO) -> Item
    public let eventQueue: DispatchQueue
    
    public var onWillChange: (() -> Void)?
    public var onChange: ((DBChangeItem<Item>) -> Void)?
    public var onDidChange: ((DBChangeItemPaths) -> Void)?
    
    public private(set) var changeItems = [DBChangeItem<Item>]()
    public private(set) var changeSections = [DBChangeSection]()
    private var cache = [NSManagedObjectID: Item]()
    
    public var items: [Item] {
        Array(cache.values)
    }
    
    private var relationshipKeyPathsObserver: RelationshipKeyPathsObserver<DTO>?
    
    public required init(request: NSFetchRequest<DTO>,
                         controller: NSFetchedResultsController<DTO>.Type = NSFetchedResultsController.self,
                         context: NSManagedObjectContext,
                         sectionNameKeyPath: String? = nil,
                         cacheName: String? = nil,
                         itemCreator: @escaping (DTO) -> Item,
                         eventQueue: DispatchQueue = DispatchQueue.main) {
        self.request = request
        self.context = context
        self.controller = controller.init(fetchRequest: request,
                                          managedObjectContext: context,
                                          sectionNameKeyPath: sectionNameKeyPath,
                                          cacheName: cacheName)
        self.itemCreator = itemCreator
        self.eventQueue = eventQueue
        if let keys = request.relationshipKeyPathsForRefreshing {
            relationshipKeyPathsObserver = RelationshipKeyPathsObserver(
                keyPaths: Set(keys),
                fetchedResultsController: self.controller
            )
        }
    }
    
    open var isEmpty: Bool {
        controller.fetchedObjects?.isEmpty == .some(true)
    }
    
    open var numberOfSection: Int {
        controller.sections?.count ?? 0
    }
    
    open func numberOfItems(in section: Int) -> Int {
        guard let sections = controller.sections,
                sections.indices.contains(section)
        else { return 0 }
        return sections[section].numberOfObjects
    }
    
    open var count: Int {
        (try? context.count(for: request)) ?? 0
    }
    
    open func item(at indexPath: IndexPath) -> Item? {
        guard canGetObject(at: indexPath)
        else { return nil }
        let object = controller.object(at: indexPath)
        if let item = cache[object.objectID] {
            return item
        } else {
            let item = itemCreator(object)
            cache[object.objectID] = item
            return item
        }
    }
    
    open func startObserver() throws {
        controller.delegate = self
        try updateFetchedObjects()
    }
    
    open func update(predicate: NSPredicate?) throws {
        if let cacheName = controller.cacheName {
            NSFetchedResultsController<DTO>.deleteCache(withName: cacheName)
        }
        controller.fetchRequest.predicate = predicate
        try updateFetchedObjects()
    }
    
    private func updateFetchedObjects() throws {
        changeItems.removeAll()
        changeSections.removeAll()
        cache.removeAll()
        try controller.performFetch()
        
        func perform()  {
            if let sections = controller.sections {
                for (index, section) in sections.enumerated() {
                    for (row, object) in (section.objects ?? []).enumerated() where object is DTO {
                        let dto = object as! DTO
                        let item = itemCreator(dto)
                        let indexPath = IndexPath(row: row, section: index)
                        cache[dto.objectID] = item
                        changeItems.append(.insert(item, indexPath))
                    }
                }
            }
            onDidChange?(.init(changeItems: changeItems))
        }
        
        controller.managedObjectContext.performAndWait {
            perform()
        }
    }
    
    private func canGetObject(at indexPath: IndexPath) -> Bool {
        if let sections = controller.sections,
           sections.indices.contains(indexPath.section) {
            if indexPath.row < sections[indexPath.section].numberOfObjects {
                return true
            }
        }
        return false
    }
    
    open func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        changeItems.removeAll()
        changeSections.removeAll()
        onWillChange?()
    }
    
    open func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                         didChange anObject: Any,
                         at indexPath: IndexPath?,
                         for type: NSFetchedResultsChangeType,
                         newIndexPath: IndexPath?) {
        guard let dto = anObject as? DTO else { return }
        let item = itemCreator(dto)
        cache[dto.objectID] = item
        switch type {
        case .insert:
            guard let indexPath = newIndexPath else { return }
            changeItems.append(.insert(item, indexPath))
        case .delete:
            guard let indexPath = indexPath else { return }
            cache[dto.objectID]  = nil
            changeItems.append(.delete(item, indexPath))
        case .update:
            guard let indexPath = indexPath else { return }
            changeItems.append(.update(item, indexPath))
        case .move:
            guard let indexPath = indexPath, let newIndexPath = newIndexPath else { return }
            changeItems.append(.move(item, indexPath, newIndexPath))
        @unknown default:
            fatalError()
        }
        onChange?(changeItems.last!)
    }
    
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                           didChange sectionInfo: NSFetchedResultsSectionInfo,
                           atSectionIndex sectionIndex: Int,
                           for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            changeSections.append(.insert(sectionIndex))
        case .delete:
            changeSections.append(.delete(sectionIndex))
        default:
            break
        }
    }
    
    open func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        changeItems = changeItems.compactMap {
            switch $0 {
            case let .move(item, indexPath, newIndexPath):
                guard indexPath != newIndexPath else {
                    return .update(item, indexPath)
                }
            default:
                break
            }
            return $0
        }
        let moveNewIndexPaths: [IndexPath] = changeItems.compactMap {
            if case .move(_, _, let newIndexPath) = $0 {
                return newIndexPath
            }
            return nil
        }
        if !moveNewIndexPaths.isEmpty {
            changeItems = changeItems.filter {
                if case .update(_, let indexPath) = $0 {
                    return !moveNewIndexPaths.contains(indexPath)
                }
                return true
            }
        }
        onDidChange?(.init(changeItems: changeItems, changeSections: changeSections))
    }
    
}

public enum DBChangeItem<Item>: Comparable {
    public static func < (lhs: DBChangeItem<Item>, rhs: DBChangeItem<Item>) -> Bool {
        lhs.indexPath < rhs.indexPath
    }
    
    public static func == (lhs: DBChangeItem<Item>, rhs: DBChangeItem<Item>) -> Bool {
        lhs.indexPath == rhs.indexPath
    }
    
    case insert(Item, IndexPath)
    case delete(Item, IndexPath)
    case move(Item, IndexPath, IndexPath)
    case update(Item, IndexPath)
    
    public var indexPath: IndexPath {
        switch self {
        case .insert(_, let indexPath),
                .delete(_, let indexPath),
                .move(_, let indexPath, _),
                .update(_, let indexPath):
            return indexPath
        }
    }
    
    public var item: Item {
        switch self {
        case .insert(let item, _),
                .delete(let item, _),
                .move(let item, _, _),
                .update(let item, _):
            return item
        }
    }
}

public enum DBChangeSection {
    case insert(Int)
    case delete(Int)
}

public struct DBChangeItemPaths {
    
    public var inserts = [IndexPath]()
    public var updates = [IndexPath]()
    public var deletes = [IndexPath]()
    public var moves = [(from: IndexPath, to: IndexPath)]()
    
    public var sectionInserts = IndexSet()
    public var sectionDeletes = IndexSet()
    
    private var objects = [IndexPath: Any]()
    
    public init<Item>(changeItems: [DBChangeItem<Item>], changeSections: [DBChangeSection] = []) {
        changeItems.forEach { item in
            switch item {
            case let .insert(item, indexPath):
                objects[indexPath] = item
                inserts.append(indexPath)
            case let .update(item, indexPath):
                objects[indexPath] = item
                updates.append(indexPath)
            case let .delete(item, indexPath):
                objects[indexPath] = item
                deletes.append(indexPath)
            case let .move(_, indexPath, newIndexPath):
                moves.append((indexPath, newIndexPath))
            }
        }
        changeSections.forEach { section in
            switch section {
            case let .insert(s):
                sectionInserts.insert(s)
            case let .delete(s):
                sectionDeletes.insert(s)
            }
        }
    }
    
    public init(
        inserts: [IndexPath] = [IndexPath](),
        updates: [IndexPath] = [IndexPath](),
        deletes: [IndexPath] = [IndexPath](),
        moves: [(from: IndexPath, to: IndexPath)] = [(from: IndexPath, to: IndexPath)](),
        sectionInserts: IndexSet = IndexSet(),
        sectionDeletes: IndexSet = IndexSet(),
        objects: [IndexPath : Any] = [IndexPath: Any]()
    ) {
        self.inserts = inserts
        self.updates = updates
        self.deletes = deletes
        self.moves = moves
        self.sectionInserts = sectionInserts
        self.sectionDeletes = sectionDeletes
        self.objects = objects
    }
    
    public func item<Item>(at indexPath: IndexPath) -> Item? {
        objects[indexPath] as? Item
    }
    
    public func items<Item>() -> [Item]? {
        objects.values.compactMap { $0 as? Item}
    }
}
