//
//  BatchDeleteDatabaseSession.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData

public protocol BatchDeleteDatabaseSession {

    func batchDelete(fetchRequest: NSFetchRequest<NSFetchRequestResult>) throws
}

extension NSManagedObjectContext: BatchDeleteDatabaseSession {

    public func batchDelete(fetchRequest: NSFetchRequest<NSFetchRequestResult>) throws {

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        let batchDelete = try execute(deleteRequest) as? NSBatchDeleteResult

        guard let deleteResult = batchDelete?.result as? [NSManagedObjectID]
        else { return }
        let deletedObjects: [AnyHashable: Any] = [
            NSDeletedObjectsKey: deleteResult
        ]
        mergeChangesWithViewContext(fromRemoteContextSave: deletedObjects)
    }
    
    public func batchDelete(ids: [NSManagedObjectID]) throws {

        let deleteRequest = NSBatchDeleteRequest(objectIDs: ids)
        deleteRequest.resultType = .resultTypeObjectIDs
        let batchDelete = try execute(deleteRequest) as? NSBatchDeleteResult

        guard let deleteResult = batchDelete?.result as? [NSManagedObjectID]
        else { return }
        let deletedObjects: [AnyHashable: Any] = [
            NSDeletedObjectsKey: deleteResult
        ]
        mergeChangesWithViewContext(fromRemoteContextSave: deletedObjects)
    }
}
