//
//  RelationshipKeyPathsObserver.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData


public struct RelationshipKeyPath: Hashable {
    
    public let sourcePropertyName: String
    public let destinationEntityName: String
    public let destinationPropertyName: String
    public let inverseRelationshipKeyPath: String
    
    public init?(keyPath: String, relationships: [String: NSRelationshipDescription]) {
        let splitted = keyPath.split(separator: ".")
        guard !splitted.isEmpty else { return nil }
        
        sourcePropertyName = String(splitted.first!)
        destinationPropertyName = String(splitted.last!)
        
        guard let relationship = relationships[sourcePropertyName],
                let destinationEntityName = relationship.destinationEntity?.name,
              let inverseRelationshipName = relationship.inverseRelationship?.name
        else { return nil }
        self.destinationEntityName = destinationEntityName
        self.inverseRelationshipKeyPath = inverseRelationshipName
        if [sourcePropertyName, self.destinationEntityName, destinationPropertyName].contains("") {
            log.error("RelationshipKeyPath: Key path is empty")
            return nil
        }
    }
}

public final class RelationshipKeyPathsObserver<ResultType: NSManagedObject>: NSObject {
    
    public let keyPaths: Set<RelationshipKeyPath>
    
    public let fetchedResultsController: NSFetchedResultsController<ResultType>
    
    private var updatedObjectIDs: Set<NSManagedObjectID> = []
    
    public init?(keyPaths: Set<String>, fetchedResultsController: NSFetchedResultsController<ResultType>) {
        guard !keyPaths.isEmpty,
              let relationshipsByName = fetchedResultsController.fetchRequest.entity?.relationshipsByName
        else { return nil }
        
        self.keyPaths = Set(keyPaths.compactMap { keyPath in
            RelationshipKeyPath(keyPath: keyPath, relationships: relationshipsByName)
        })
        self.fetchedResultsController = fetchedResultsController
        
        super.init()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contextDidChangeNotification(_:)),
                                               name: .NSManagedObjectContextObjectsDidChange,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contextDidSaveNotification(_:)),
                                               name: .NSManagedObjectContextDidSave,
                                               object: nil)
    }
    
    @objc
    private func contextDidChangeNotification(_ notification: NSNotification) {
//        fetchedResultsController.managedObjectContext.perform {
            guard let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>
            else { return }
            guard let updatedObjectIDs = updatedObjects.updatedObjectIDs(for: self.keyPaths),
                    !updatedObjectIDs.isEmpty
            else { return }
            self.updatedObjectIDs = self.updatedObjectIDs.union(updatedObjectIDs)
//        }
    }
    
    @objc
    private func contextDidSaveNotification(_ notification: NSNotification) {
        fetchedResultsController.managedObjectContext.perform {
            guard !self.updatedObjectIDs.isEmpty else { return }
            guard let fetchedObjects = self.fetchedResultsController.fetchedObjects,
                    !fetchedObjects.isEmpty
            else { return }
            
            fetchedObjects.forEach { object in
                guard self.updatedObjectIDs.contains(object.objectID) else { return }
                self.fetchedResultsController.managedObjectContext.refresh(object, mergeChanges: true)
            }
            self.updatedObjectIDs.removeAll()
        }
    }
}

extension Set where Element: NSManagedObject {
   
    func updatedObjectIDs(for keyPaths: Set<RelationshipKeyPath>) -> Set<NSManagedObjectID>? {
        reduce(into: Set<NSManagedObjectID>()) { partialResult, object in
            guard let changedRelationshipKeyPath = object.changedKeyPath(from: keyPaths)
            else { return }
            
            let value = object.value(forKey: changedRelationshipKeyPath.inverseRelationshipKeyPath)
            if let objects = value as? Set<NSManagedObject> {
                objects.forEach {
                    partialResult.insert($0.objectID)
                }
            } else if let object = value as? NSManagedObject {
                partialResult.insert(object.objectID)
            } else {
                return
            }
        }
    }
}

extension NSManagedObject {
    
    func changedKeyPath(from keyPaths: Set<RelationshipKeyPath>) -> RelationshipKeyPath? {
        keyPaths.first { keyPath in
            guard keyPath.destinationEntityName == entity.name ||
                    keyPath.destinationEntityName == entity.superentity?.name
            else { return false }
            return changedValues().keys.contains(keyPath.destinationPropertyName)
        }
    }
}
