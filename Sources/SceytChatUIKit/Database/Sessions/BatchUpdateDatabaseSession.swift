//
//  BatchUpdateDatabaseSession.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 20.11.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData

public protocol BatchUpdateDatabaseSession {

    func batchUpdate(object: NSManagedObject.Type, predicate: NSPredicate, propertiesToUpdate: [AnyHashable : Any]?) throws
}

extension NSManagedObjectContext: BatchUpdateDatabaseSession {

    public func batchUpdate(object: NSManagedObject.Type, predicate: NSPredicate, propertiesToUpdate: [AnyHashable : Any]?) throws {
        
        let batchUpdateRequest = NSBatchUpdateRequest(entity: object.entity())
        batchUpdateRequest.resultType = .updatedObjectIDsResultType
        batchUpdateRequest.predicate = predicate
        batchUpdateRequest.propertiesToUpdate = propertiesToUpdate
        let result = try execute(batchUpdateRequest) as? NSBatchUpdateResult
        guard let updateResult = result?.result as? [NSManagedObjectID]
        else { return }
        
        let updatedObjects: [AnyHashable: Any] = [
            NSUpdatedObjectsKey: updateResult
        ]
        mergeChangesWithViewContext(fromRemoteContextSave: updatedObjects)
    }
}
