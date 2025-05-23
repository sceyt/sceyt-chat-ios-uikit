//
//  LazyDatabaseObserver.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 14.03.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData

open class LazyDatabaseObserver<DTO: NSManagedObject, Item>: NSObject, NSFetchedResultsControllerDelegate {
    
    public typealias Cache = [[DTO]]
    public let context: NSManagedObjectContext
    public let sortDescriptors: [NSSortDescriptor]
    public let itemCreator: (DTO) -> Item
    public let eventQueue: DispatchQueue
    public private(set) var fetchOffset: Int = 0
    public private(set) var fetchLimit: Int = 0
    public private(set) var currentFetchOffset: Int = 0
    public private(set) var fetchPredicate: NSPredicate
    public let sectionNameKeyPath: String?
    
    public var onWillChange: ((Cache, ChangeItemPaths) -> Any?)?
    public var onDidChange: ((Bool, ChangeItemPaths, Any?) -> Void)?
    
    private let cacheQueue = DispatchQueue(label: "com.uikit.lazyDBO.access.cache", attributes: .concurrent)
    
    private struct Caches {
        @Atomic var mainCache = Cache()
        @Atomic var workingCache = Cache()
        @Atomic var prevCache: Cache?
        @Atomic var mapItems = [NSManagedObjectID: Item]()
        @Atomic var mapDeletedItems = [NSManagedObjectID: Item]()
        
        func copy() -> Caches {
            .init(
                mainCache: mainCache,
                workingCache: workingCache,
                prevCache: prevCache,
                mapItems: mapItems,
                mapDeletedItems: mapDeletedItems
            )
        }
    }
    
    @Atomic private var mainCaches = Caches()
    @Atomic private var tmpCaches = Caches()
    private var currentCaches: Caches {
        isObserverRestarting ? tmpCaches : mainCaches
    }
    
    public let keyPaths: Set<RelationshipKeyPath>
    @Atomic private var updatedObjectIDs: Set<NSManagedObjectID> = []
    
    @Atomic public private(set) var isObserverStarted = false
    @Atomic private var isObserverRestarting = false
    
    public var viewContext: NSManagedObjectContext {
        SceytChatUIKit.shared.database.viewContext
    }
    
    private var lockContext: NSManagedObjectContext {
        Thread.isMainThread ? viewContext : context
    }
    
    
    public init(context: NSManagedObjectContext,
                         sortDescriptors: [NSSortDescriptor],
                         sectionNameKeyPath: String? = nil,
                         fetchPredicate: NSPredicate,
                         relationshipKeyPathsObserver: [String]? = nil,
                         itemCreator: @escaping (DTO) -> Item,
                         eventQueue: DispatchQueue = DispatchQueue.main) {
        self.context = context
        self.sortDescriptors = sortDescriptors
        self.fetchPredicate = fetchPredicate
        self.sectionNameKeyPath = sectionNameKeyPath
        self.itemCreator = itemCreator
        self.eventQueue = eventQueue
        if let keyPath = relationshipKeyPathsObserver {
            keyPaths = Set(keyPath.compactMap { keyPath in
                RelationshipKeyPath(keyPath: keyPath, relationships: DTO.entity().relationshipsByName)
            })
        } else {
            keyPaths = .init()
        }
    }
    
    open func startObserver(
        fetchOffset: Int = 0,
        fetchLimit: Int = 0,
        fetchPredicate: NSPredicate? = nil,
        completion: (() -> Void)? = nil
    ) {
        logger.debug("[MESS] STARTED")
            self.fetchPredicate = fetchPredicate ?? self.fetchPredicate
            self.fetchOffset = max(0, fetchOffset)
            self.fetchLimit = max(0, fetchLimit)
            self.currentFetchOffset = self.fetchOffset
            if let request = DTO.fetchRequest() as? NSFetchRequest<DTO> {
                var changeItems = [ChangeItem]()
                var changeSections = [ChangeSection]()
                request.sortDescriptors = sortDescriptors
                request.predicate = fetchPredicate ?? self.fetchPredicate
                request.fetchLimit = self.fetchLimit
                request.fetchOffset = self.fetchOffset
                
                context.perform {
                    logger.debug("[MESS] STARTED PERFORM")
                    self.clearCache()
                    var insertCache = self.mainCaches.workingCache
                    self.fetchObjects(context: self.context,
                                      request: request,
                                      in: &insertCache,
                                      changeItems: &changeItems,
                                      changeSections: &changeSections)
                    self.isObserverStarted = true
                    self.mainCaches.workingCache = insertCache
                    let path = ChangeItemPaths(changeItems: changeItems, changeSections: changeSections)
                    let userInfo = self.onWillChange?(self.mainCaches.workingCache, path)
                    self.queue {
                        logger.debug("[MESS] STARTED EVENT")
                        self.mainCaches.mainCache = insertCache
                        self.isObserverRestarting = false
                        self.onDidChange?(true, path, userInfo)
                        completion?()
                    }
                }
                addObservers()
            }
        }
    
    open func stopObserver() {
        isObserverStarted = false
        clearCache()
        removeObservers()
    }
    
    open func restartObserver(
        fetchPredicate: NSPredicate,
        offset: Int? = nil,
        completion: (() -> Void)? = nil) {
            if isObserverRestarting {
                return
            }
            if isObserverStarted {
                tmpCaches = mainCaches.copy()
            }
            isObserverRestarting = true
            isObserverStarted = false
            removeObservers()
            self.fetchPredicate = fetchPredicate
            startObserver(
                fetchOffset: offset ?? fetchOffset,
                fetchLimit: fetchLimit,
                fetchPredicate: fetchPredicate,
                completion: completion
            )
        }
    
    open func update(predicate: NSPredicate, fetchOffset: Int = Int.max) {
        readCache {
            self.fetchPredicate = predicate
            self.currentFetchOffset = max(0, fetchOffset == Int.max ? self.currentFetchOffset : fetchOffset)
        }
    }
    
    open var isEmpty: Bool {
        (isObserverStarted || isObserverRestarting) ? currentCaches.mainCache.isEmpty : true
    }
    
    open var numberOfSections: Int {
        (isObserverStarted || isObserverRestarting) ? currentCaches.mainCache.count : 0
    }
    
    open func numberOfItems(in section: Int) -> Int {
        if (isObserverStarted || isObserverRestarting), currentCaches.mainCache.indices.contains(section) {
            return currentCaches.mainCache[section].count
        }
        return 0
    }
    
    open var count: Int {
        guard isObserverStarted || isObserverRestarting
        else { return 0 }
        var count = 0
        currentCaches.mainCache.forEach {
            count += $0.count
        }
        return count
    }
    
    
    public func totalCountOfItems(predicate: NSPredicate? = nil) -> Int {
        let fetchRequest = DTO.fetchRequest()
        fetchRequest.predicate = predicate ?? fetchPredicate
        fetchRequest.includesSubentities = false
        let count = (try? lockContext.count(for: fetchRequest)) ?? 0
        return count
    }
    
    open func item(at indexPath: IndexPath) -> Item? {
        guard isObserverStarted || isObserverRestarting
        else { return nil }
        let caches = currentCaches
        guard caches.mainCache.indices.contains(indexPath.section),
              caches.mainCache[indexPath.section].indices.contains(indexPath.row)
        else {
            return nil
        }
        let dto = caches.mainCache[indexPath.section][indexPath.row]
        
        if let item = _item(for: dto.objectID) {
            return item
        }
        let objectID = dto.objectID
        context.perform { [weak self] in
            guard let self, let obj = try? self.context.existingObject(with: objectID) as? DTO
            else { return }
            let item = self.itemCreator(obj)
            self.writeCache {
                caches.mapItems[dto.objectID] = item
                caches.mapDeletedItems[dto.objectID] = nil
            }
            
            logger.error("object did not find with id \(objectID.uriRepresentation()), found from context \(obj) ")
        }
        return nil
    }
    
    public var firstItem: Item? {
        let indexPath = IndexPath(row: 0, section: 0)
        return item(at: indexPath)
    }
    
    public var lastItem: Item? {
        let caches = currentCaches
        guard let lastSection = caches.mainCache.indices.last
        else { return nil }
        guard let lastRow = caches.mainCache.last?.indices.last
        else { return nil }
        let indexPath = IndexPath(row: lastRow, section: lastSection)
        return item(at: indexPath)
    }
    
    open func workingCacheItem(at indexPath: IndexPath) -> Item? {
        guard isObserverStarted || isObserverRestarting
        else { return nil }
        let caches = isObserverStarted ? mainCaches : tmpCaches
        guard caches.workingCache.indices.contains(indexPath.section),
              caches.workingCache[indexPath.section].indices.contains(indexPath.row)
        else {
            return nil
        }
        let dto = caches.workingCache[indexPath.section][indexPath.row]
        if let item = readCache({ caches.mapItems[dto.objectID] ?? caches.mapDeletedItems[dto.objectID] }) {
            return item
        }
        return nil
    }
    
    open func itemFromPrevCache(at indexPath: IndexPath) -> Item? {
        guard isObserverStarted || isObserverRestarting
        else { return nil }
        let caches = currentCaches
        guard let prevCache = caches.prevCache,
              prevCache.indices.contains(indexPath.section),
              prevCache[indexPath.section].indices.contains(indexPath.row)
        else { return nil }
        let dto = prevCache[indexPath.section][indexPath.row]
        if let item = readCache({caches.mapItems[dto.objectID]}) {
            return item
        }
        let objectID = dto.objectID
        context.perform {[weak self] in
            guard let self, let obj = try? self.context.existingObject(with: objectID) as? DTO
            else { return }
            let item = self.itemCreator(obj)
            self.writeCache {
                caches.mapItems[dto.objectID] = item
                caches.mapDeletedItems[dto.objectID] = nil
            }
            logger.error("object did not find from prev cache with id \(objectID.uriRepresentation()), found from context \(obj) ")
        }
        return nil
    }
    
    open func items(
        at indexPaths: [IndexPath],
        completion: @escaping (([IndexPath: Item]) -> Void)) {
            context.perform {[weak self] in
                guard let self else { return }
                var items = [IndexPath: Item]()
                for indexPath in indexPaths {
                    if let item = self.item(at: indexPath) ?? self.itemFromPrevCache(at: indexPath) {
                        items[indexPath] = item
                    }
                }
                DispatchQueue.global().async {
                    completion(items)
                }
            }
        }
    
    open func item(for objectID: NSManagedObjectID) -> Item? {
        readCache({self.currentCaches.mapItems[objectID]})
    }
    
    private func _item(for objectID: NSManagedObjectID) -> Item? {
        readCache({ self.currentCaches.mapItems[objectID] ?? self.currentCaches.mapDeletedItems[objectID] })
    }
    
    public func indexPath(_ body: (Item) throws -> Bool) rethrows -> IndexPath? {
        let caches = currentCaches
        let _mapItem = caches.mapItems
        for section in 0 ..< caches.mainCache.count {
            for row in 0 ..< caches.mainCache[section].count {
                let objectID = caches.mainCache[section][row].objectID
                if let item = _mapItem[objectID] {
                    if try body(item) {
                        logger.debug("[LDBO] indexPath found row: \(row) section: \(section)")
                        return IndexPath(row: row, section: section)
                    }
                }
            }
        }
        return nil
    }
    
    public func forEach(_ body: (IndexPath, Item) throws -> Bool) rethrows {
        let caches = currentCaches
        let _mapItem = caches.mapItems
        for section in 0 ..< caches.mainCache.count {
            for row in 0 ..< caches.mainCache[section].count {
                let objectID = caches.mainCache[section][row].objectID
                if let item = _mapItem[objectID] {
                    let ip = IndexPath(row: row, section: section)
                    if try body(ip, item) {
                        return
                    }
                }
            }
        }
    }
    
    open func loadNext(
        predicate: NSPredicate? = nil,
        done: (() -> Void)? = nil
    ) {
        guard isObserverStarted else {
            done?()
            return
        }
        willChangeCache()
        currentFetchOffset += fetchLimit
        fetchAndUpdate(
            predicate: predicate,
            offset: currentFetchOffset,
            limit: fetchLimit)
        { count in
//            if count == 0 {
//                self.currentFetchOffset -= self.fetchLimit
//            }
        } done: {
            done?()
        }
    }
    
    open func loadPrev(
        predicate: NSPredicate? = nil,
        done: (() -> Void)? = nil
    ) {
        guard isObserverStarted else {
            done?()
            return
        }
        willChangeCache()
        guard currentFetchOffset >= 0
        else {
            done?()
            return
        }
        currentFetchOffset = max(0, currentFetchOffset - fetchLimit)
        fetchAndUpdate(
            predicate: predicate,
            offset: currentFetchOffset,
            limit: fetchLimit)
        { count in
//            if count == 0 {
//                self.currentFetchOffset += self.fetchLimit
//            }
        } done: {
            done?()
        }
    }
    
    open func loadNear(
        predicate: NSPredicate? = nil,
        done: (() -> Void)? = nil
    ) {
        guard isObserverStarted else {
            done?()
            return
        }
        willChangeCache()
        let minOffset = min(currentFetchOffset, fetchLimit / 2)
        currentFetchOffset = max(0, currentFetchOffset - minOffset)
        fetchAndUpdate(
            predicate: predicate,
            offset: currentFetchOffset,
            limit: fetchLimit,
            fetched: { count in
                
            },
            done: {
                done?()
            }
        )
    }
    
    open func load(
        from offset: Int,
        limit: Int,
        predicate: NSPredicate? = nil,
        done: (() -> Void)? = nil
    ) {
        willChangeCache()
        fetchAndUpdate(
            predicate: predicate,
            offset: offset,
            limit: limit
        ) { _ in
            
        } done: {
            done?()
        }
    }
    
    open func loadAll(
        from offset: Int,
        limit: Int,
        predicate: NSPredicate? = nil,
        done: (() -> Void)? = nil
    ) {
        guard isObserverStarted else {
            done?()
            return
        }
        currentFetchOffset = offset
        load(
            from: offset,
            limit: limit,
            predicate: predicate,
            done: done
        )
    }
    
    private func fetchAndUpdate(
        predicate: NSPredicate?,
        offset: Int,
        limit: Int,
        fetched: @escaping (Int) -> Void,
        done: (() -> Void)? = nil
    ) {
        func perform(context: NSManagedObjectContext) {
            if let request = DTO.fetchRequest() as? NSFetchRequest<DTO> {
                var insertCache = mainCaches.workingCache
                var changeItems = [ChangeItem]()
                var changeSections = [ChangeSection]()
                request.sortDescriptors = sortDescriptors
                request.predicate = predicate ?? fetchPredicate
                request.fetchLimit = limit
                request.fetchOffset = offset
                let count = fetchObjects(context: context,
                                         request: request,
                                         in: &insertCache,
                                         changeItems: &changeItems,
                                         changeSections: &changeSections).count
                fetched(count)
                didUpdate(
                    insertCache: insertCache,
                    paths: ChangeItemPaths(
                        changeItems: changeItems,
                        changeSections: changeSections),
                    done: done)
            }
        }
        
        self.perform {
            perform(context: self.context)
        }
    }
    
    @objc
    open func willSaveObjects(notification: Notification) {
        guard isObserverStarted else { return }
    }
    
    @objc
    open func didSaveObjects(notification: Notification) {
        guard isObserverStarted else { return }
        guard !updatedObjectIDs.isEmpty else { return }
        guard notification.userInfo != nil
        else { return }
        let objIDs = updatedObjectIDs
        updatedObjectIDs.removeAll()
        context.perform {[weak self] in
            guard let self else { return }
            for id in objIDs {
                if let obj = self.context.registeredObject(for: id) {
                    self.context.refresh(obj, mergeChanges: true)
                }
            }
        }
    }
    
    @objc
    open func didChangeObjects(notification: Notification) {
        guard isObserverStarted else { return }
        guard let userInfo = notification.userInfo
        else { return }
        if let currentContext = notification.object as? NSManagedObjectContext,
           (currentContext === context) {
            
            func perform() {
                logger.verbose("[MESSAGE SEND] didChangeObjects perform")
                readCache {}
                var sendEvent = false
                var changeItems = [ChangeItem]()
                var changeSections = [ChangeSection]()
                var insertCache = mainCaches.workingCache
                var shouldInsert: [DTO]?
                if let objs = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> {
                    let dtos = sorted(objs)
                    if !dtos.isEmpty {
                        willChangeCache()
                        insert(dtos: dtos, in: &insertCache, changeItems: &changeItems, changeSections: &changeSections)
                        sendEvent = true
                    }
                }
                if let objs = userInfo[NSRefreshedObjectsKey] as? Set<NSManagedObject> {
                    let dtos = sorted(objs)
                    if !dtos.isEmpty {
                        willChangeCache()
                        shouldInsert = reload(dtos: dtos, in: &insertCache, changeItems: &changeItems, changeSections: &changeSections)
                        sendEvent = true
                    }
                }
                
                if let objs = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> {
                    let dtos = sorted(objs)
                    if !dtos.isEmpty {
                        willChangeCache()
                        delete(dtos: dtos, in: &insertCache, changeItems: &changeItems, changeSections: &changeSections)
                        sendEvent = true
                    }
                }
                mainCaches.workingCache = insertCache
                if sendEvent {
                    didUpdate(
                        insertCache: insertCache,
                        paths: ChangeItemPaths(
                            changeItems: changeItems,
                            changeSections: changeSections),
                        done: nil)
                    
                    if let dtos = shouldInsert,
                       !dtos.isEmpty {
                        var changeItems = [ChangeItem]()
                        var changeSections = [ChangeSection]()
                        var insertCache = mainCaches.workingCache
                        if !dtos.isEmpty {
                            willChangeCache()
                            insert(dtos: dtos, in: &insertCache, changeItems: &changeItems, changeSections: &changeSections)
                            didUpdate(
                                insertCache: insertCache,
                                paths: ChangeItemPaths(
                                    changeItems: changeItems,
                                    changeSections: changeSections),
                                done: nil)
                        }
                    }
                }
            }
            
            currentContext.perform {
                perform()
            }
        }
        
        if let objs = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>,
           let updatedObjectIDs = objs.updatedObjectIDs(for: keyPaths),
           !updatedObjectIDs.isEmpty {
            self.updatedObjectIDs = self.updatedObjectIDs.union(updatedObjectIDs)
        }
    }
}

private extension LazyDatabaseObserver {
    
    func compareSectionObjects(lhs: Any, rhs: Any) -> ComparisonResult {
        
        func sort(lhs: Any, rhs: Any) -> ComparisonResult {
            if let l = lhs as? NSNumber,
               let r = rhs as? NSNumber {
                return l.compare(r)
            }
            
            if let l = lhs as? NSString,
               let r = rhs as? NSString {
                return l.compare(r as String)
            }
            logger.error("not implemented Comparison for \(lhs) and \(rhs)")
            return .orderedSame
        }
        for sortDescriptor in sortDescriptors {
            let result: ComparisonResult
            if sortDescriptor.ascending {
                result = sort(lhs: lhs, rhs: rhs)
            } else {
                result = sort(lhs: rhs, rhs: lhs)
            }
            if result == .orderedSame {
                continue
            } else {
                return result
            }
            
        }
        return .orderedSame
        
        
    }
    
    func insert(
        dto: DTO,
        section: Int,
        in cache: inout Cache,
        changeItems: inout [ChangeItem]
    ) {
        var sds = sortDescriptors
        var sort = sds.removeFirst()
        var foundIndex = 0
    exitLoop: for (index, element) in cache[section].enumerated() {
        var canContinue = false
        repeat {
            canContinue = false
            let compare = sort.compare(dto, to: element)
            switch compare {
            case .orderedAscending:
                foundIndex = index
                break exitLoop
            case .orderedDescending:
                foundIndex = index + 1
                continue
            case .orderedSame:
                if !sds.isEmpty {
                    sort = sds.removeFirst()
                    canContinue = true
                } else {
                    break exitLoop
                }
            }
        } while(canContinue)
        sds = sortDescriptors
        sort = sds.removeFirst()
    }
        let item = itemCreator(dto)
        cache[section].insert(dto, at: foundIndex)
        writeCache {
            self.mainCaches.mapItems[dto.objectID] = item
            self.mainCaches.mapDeletedItems[dto.objectID] = nil
        }
        changeItems.append(.insert(.init(row: foundIndex, section: section), item))
    }
    
    @discardableResult
    private func fetchObjects(
        context: NSManagedObjectContext,
        request: NSFetchRequest<DTO>,
        in cache: inout Cache,
        changeItems: inout [ChangeItem],
        changeSections: inout [ChangeSection]
    ) -> [DTO] {
        let startTime = CFAbsoluteTimeGetCurrent()
        let dtos = DTO.fetch(request: request, context: context)
        insert(dtos: dtos, in: &cache, changeItems: &changeItems, changeSections: &changeSections)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.verbose("[PERFORMANCE] fetch data time elapsed \(timeElapsed) s.")
        return dtos
    }
    
    private func insert(
        dtos: [DTO],
        in cache: inout Cache,
        changeItems: inout [ChangeItem],
        changeSections: inout [ChangeSection]
    ) {
        var valueCache = [NSManagedObjectID: Any]()
        for dto in dtos {
            guard readCache({self.mainCaches.mapItems[dto.objectID]}) == nil
            else { continue }
            if cache.isEmpty {
                cache.append([dto])
                let item = itemCreator(dto)
                writeCache {
                    self.mainCaches.mapItems[dto.objectID] = item
                    self.mainCaches.mapDeletedItems[dto.objectID] = nil
                }
                changeSections.append(.insert(0))
                changeItems.append(.insert(.init(row: 0, section: 0), item))
            } else if let sectionNameKeyPath {
                var found = false
                let _nv = dto.value(forKey: sectionNameKeyPath)
            exitLoop: for (index, elements) in cache.enumerated() {
                if let first = elements.first {
                    if let fv = valueCache[first.objectID] ?? first.value(forKey: sectionNameKeyPath),
                       let nv = _nv {
                        valueCache[first.objectID] = fv
                        switch compareSectionObjects(lhs: fv, rhs: nv) {
                        case .orderedSame:
                            insert(dto: dto, section: index, in: &cache, changeItems: &changeItems)
                            found = true
                            break exitLoop
                        case .orderedDescending:
                            let item = itemCreator(dto)
                            writeCache {
                                self.mainCaches.mapItems[dto.objectID] = item
                                self.mainCaches.mapDeletedItems[dto.objectID] = nil
                            }
                            cache.insert([dto], at: index)
                            for (row, changeItem) in changeItems.enumerated() where changeItem.indexPath.section >= index {
                                var indexPath = changeItem.indexPath
                                indexPath.section += 1
                                switch changeItem {
                                case let .insert(ip, item):
                                    changeItems[row] = .insert(IndexPath(row: ip.row, section: ip.section + 1), item)
                                case let .delete(ip):
                                    changeItems[row] = .delete(IndexPath(row: ip.row, section: ip.section + 1))
                                case let .update(ip, item):
                                    changeItems[row] = .update(IndexPath(row: ip.row, section: ip.section + 1), item)
                                case let .move(fip, tip, item):
                                    changeItems[row] = .move(IndexPath(row: fip.row, section: fip.section + 1),
                                                             IndexPath(row: tip.row, section: tip.section + 1), item)
                                }
                            }
                            changeSections.append(.insert(index))
                            changeItems.append(.insert(.init(row: 0, section: index), item))
                            found = true
                            break exitLoop
                        case .orderedAscending:
                            continue
                        }
                    }
                }
            }
                if !found {
                    cache.append([dto])
                    let item = itemCreator(dto)
                    writeCache {
                        self.mainCaches.mapItems[dto.objectID] = item
                        self.mainCaches.mapDeletedItems[dto.objectID] = nil
                    }
                    changeSections.append(.insert(cache.count - 1))
                    changeItems.append(.insert(.init(row: 0, section: cache.count - 1), item))
                }
            } else {
                insert(dto: dto, section: 0, in: &cache, changeItems: &changeItems)
            }
        }
    }
    
    func reload(
        dtos: [DTO],
        in cache: inout Cache,
        changeItems: inout [ChangeItem],
        changeSections: inout [ChangeSection]
    ) -> [DTO] {
        var shouldInsert = [DTO]()
        for dto in dtos {
            if !reload(dto: dto, in: &cache, changeItems: &changeItems, changeSections: &changeSections) {
                shouldInsert.append(dto)
            }
        }
        return shouldInsert
    }
    
    func reload(
        dto: DTO,
        in cache: inout Cache,
        changeItems: inout [ChangeItem],
        changeSections: inout [ChangeSection]
    ) -> Bool {
        
        var foundIndexPath: IndexPath?
        
        for (section, objects) in cache.enumerated() {
            if foundIndexPath != nil {
                break
            }
            for (row, item) in objects.enumerated() {
                if item.objectID == dto.objectID {
                    foundIndexPath = IndexPath(row: row, section: section)
                    break
                }
            }
        }
        var isRemovedSection = false
        
        if let foundIndexPath {
            let beforeCount = cache.count
            cache[foundIndexPath.section].remove(at: foundIndexPath.row)
            if cache[foundIndexPath.section].isEmpty {
                cache.remove(at: foundIndexPath.section)
                isRemovedSection = true
            }
            writeCache {
                self.mainCaches.mapDeletedItems[dto.objectID] = self.mainCaches.mapItems[dto.objectID]
                self.mainCaches.mapItems[dto.objectID] = nil
                
            }
            var _changeItems = [ChangeItem]()
            var _changeSections = [ChangeSection]()
            
            insert(dtos: [dto], in: &cache, changeItems: &_changeItems, changeSections: &_changeSections)
            
            let item = _changeItems.last!
            if cache.count == beforeCount {
                if isRemovedSection {
                    if item.indexPath.section == foundIndexPath.section {
                        if item.indexPath.row == foundIndexPath.row {
                            changeItems.append(.update(item.indexPath, item.item!))
                        } else {
                            changeItems.append(.move(foundIndexPath, item.indexPath, item.item!))
                        }
                    } else {
                        changeSections.append(.delete(foundIndexPath.section))
                        changeSections.append(.insert(item.indexPath.section))
                        changeItems.append(.move(foundIndexPath, item.indexPath, item.item!))
                    }
                } else {
                    if item.indexPath.section == foundIndexPath.section {
                        if item.indexPath.row == foundIndexPath.row {
                            changeItems.append(.update(item.indexPath, item.item!))
                        } else {
                            changeItems.append(.move(foundIndexPath, item.indexPath, item.item!))
                        }
                    } else {
                        changeItems.append(.move(foundIndexPath, item.indexPath, item.item!))
                    }
                }
            } else if cache.count > beforeCount {
                if cache[item.indexPath.section].count == 1 {
                    changeItems.append(.move(foundIndexPath, item.indexPath, item.item!))
                    changeSections.append(.insert(item.indexPath.section))
                } else {
                    logger.error("something wrong on reload item from index \(foundIndexPath) to index \(item.indexPath) isRemovedSection \(isRemovedSection) ")
                }
            } else { //if cache.count < beforeCount
                changeSections.append(.delete(foundIndexPath.section))
                changeItems.append(.move(foundIndexPath, item.indexPath, item.item!))
            }
        }
        return foundIndexPath != nil
    }
    
    func delete(
        dtos: [DTO],
        in cache: inout Cache,
        changeItems: inout [ChangeItem],
        changeSections: inout [ChangeSection]
    ) {
        var group = Dictionary(uniqueKeysWithValues: dtos.map{($0.objectID, $0) })
        for (section, objects) in cache.enumerated().reversed() {
            for (row, item) in objects.enumerated().reversed() {
                if group[item.objectID] != nil,
                   readCache({self.mainCaches.mapItems[item.objectID]}) != nil {
                    cache[section].remove(at: row)
                    writeCache {
                        self.mainCaches.mapDeletedItems[item.objectID] = self.mainCaches.mapItems[item.objectID]
                        self.mainCaches.mapItems[item.objectID] = nil
                    }
                    
                    changeItems.append(.delete(.init(row: row, section: section)))
                    if cache[section].isEmpty {
                        cache.remove(at: section)
                        changeSections.append(.delete(section))
                    }
                    group[item.objectID] = nil
                } else if group.isEmpty {
                    return
                }
            }
        }
    }
    
    func addObservers() {
        let notificationCenter = NotificationCenter.default
        notificationCenter
            .addObserver(self,
                         selector: #selector(willSaveObjects(notification:)),
                         name: NSNotification.Name.NSManagedObjectContextWillSave,
                         object: nil)
        notificationCenter
            .addObserver(self,
                         selector: #selector(didSaveObjects(notification:)),
                         name: NSNotification.Name.NSManagedObjectContextDidSave,
                         object: nil)
        notificationCenter
            .addObserver(self,
                         selector: #selector(didChangeObjects(notification:)),
                         name: NSNotification.Name.NSManagedObjectContextObjectsDidChange,
                         object: nil)
    }
    
    func removeObservers() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: NSNotification.Name.NSManagedObjectContextWillSave, object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name.NSManagedObjectContextDidSave, object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: nil)
    }
    
    func sorted(_ set: Set<NSManagedObject>) -> [DTO] {
        NSArray(array: set.compactMap { $0 as? DTO})
            .ns_filtered(using: fetchPredicate)
            .sortedArray(using: sortDescriptors)
            .compactMap { $0 as? DTO }
    }
    
    func clearCache() {
        readCache {
            self.mainCaches.mapItems.removeAll(keepingCapacity: true)
            self.mainCaches.mapDeletedItems.removeAll()
        }
        mainCaches.mainCache.removeAll(keepingCapacity: true)
        mainCaches.workingCache.removeAll(keepingCapacity: true)
        mainCaches.prevCache?.removeAll(keepingCapacity: true)
    }
    
    func willChangeCache() {
        mainCaches.prevCache = mainCaches.mainCache
    }
    
    func queue( _ block: @escaping () -> Void) {
        if Thread.isMainThread {
            if eventQueue.label == "com.apple.main-thread" {
                block()
                return
            }
        }
        eventQueue.async {
            block()
        }
    }
    
    func perform( _ block: @escaping () -> Void) {
        if Thread.isMainThread {
            if context === viewContext {
                context.performAndWait {
                    block()
                }
                return
            }
        }
        context.perform {
            block()
        }
    }
    
    private func didUpdate(
        insertCache: Cache,
        paths: ChangeItemPaths,
        done: (() -> Void)?
    ) {
        guard isObserverStarted else { return }
        self.mainCaches.workingCache = insertCache
        let userInfo = self.onWillChange?(self.mainCaches.workingCache, paths)
        self.queue {[weak self] in
            guard let self else { return }
            guard self.isObserverStarted || self.isObserverRestarting
            else {
                self.clearCache()
                return
            }
            self.mainCaches.mainCache = insertCache
            self.onDidChange?(false, paths, userInfo)
            done?()
        }
    }
    
    func writeCache( _ block: @escaping () -> Void) {
        cacheQueue.async(flags: .barrier) {
            block()
        }
    }
    
    func readCache<T>( _ block: @escaping () -> T) -> T {
        cacheQueue.sync {
            block()
        }
    }
}

public extension LazyDatabaseObserver {
    
    enum ChangeItem: Comparable {
        
        public static func < (lhs: ChangeItem, rhs: ChangeItem) -> Bool {
            lhs.indexPath < rhs.indexPath
        }
        
        public static func == (lhs: ChangeItem, rhs: ChangeItem) -> Bool {
            lhs.indexPath == rhs.indexPath
        }
        
        case insert(IndexPath, Item)
        case delete(IndexPath)
        case move(IndexPath, IndexPath, Item)
        case update(IndexPath, Item)
        
        public var indexPath: IndexPath {
            switch self {
            case .insert(let indexPath, _),
                    .delete(let indexPath),
                    .move(let indexPath, _, _),
                    .update(let indexPath, _):
                return indexPath
            }
        }
        
        public var item: Item? {
            switch self {
            case .insert(_, let item),
                    .move(_, _, let item),
                    .update(_, let item):
                return item
            default:
                return nil
            }
        }
    }
    
    enum ChangeSection {
        case insert(Int)
        case delete(Int)
        
        var section: Int {
            switch self {
            case .insert( let section ), .delete( let section ):
                return section
            }
        }
    }
    
    struct ChangeItemPaths {
        
        public var inserts = [IndexPath]()
        public var updates = [IndexPath]()
        public var deletes = [IndexPath]()
        public var moves = [(from: IndexPath, to: IndexPath)]()
        
        public var sectionInserts = IndexSet()
        public var sectionDeletes = IndexSet()
        
        public let changeItems: [ChangeItem]
        public let changeSections: [ChangeSection]
        
        public var isEmpty: Bool {
            inserts.isEmpty &&
            updates.isEmpty &&
            deletes.isEmpty &&
            moves.isEmpty &&
            sectionInserts.isEmpty &&
            sectionDeletes.isEmpty
        }
        
        public var numberOfChangedItems: Int {
            changeItems.count + changeSections.count
        }
        
        public init(changeItems: [ChangeItem],
                    changeSections: [ChangeSection] = []) {
            self.changeItems = changeItems
            self.changeSections = changeSections
            var toDelete = [IndexPath: Bool]()
            changeItems.forEach { item in
                switch item {
                case let .insert(indexPath, _):
                    inserts.append(indexPath)
                case let .update(indexPath, _):
                    updates.append(indexPath)
                case let .delete(indexPath):
                    deletes.append(indexPath)
                    toDelete[indexPath] = true
                case let .move(indexPath, newIndexPath, _):
                    moves.append((indexPath, newIndexPath))
                    toDelete[indexPath] = true
                }
            }
           
            let updatesCount = updates.count
            updates = updates.filter({ indexPath in
                toDelete[indexPath] == nil
            })
            
            changeSections.forEach { section in
                switch section {
                case let .insert(s):
                    var ns = s
                    while sectionInserts.contains(ns) {
                        ns += 1
                    }
                    sectionInserts.insert(ns)
                case let .delete(s):
                    var ns = s
                    while sectionDeletes.contains(ns) {
                        ns += 1
                    }
                    sectionDeletes.insert(ns)
                }
            }
        }
    }
    
}

private extension NSArray {
    func ns_filtered(using predicate: NSPredicate) -> NSArray {
        filtered(using: predicate) as NSArray
    }
}

internal extension LazyDatabaseObserver.ChangeItemPaths {
    
    var description: String {
        "[ChangeItemPaths]: INSERTS: \(inserts), UPDATES: \(updates), DELETES: \(deletes), MOVES: \(moves), SEC_INS \(sectionInserts), SEC_DEL \(sectionDeletes)"
    }
}

