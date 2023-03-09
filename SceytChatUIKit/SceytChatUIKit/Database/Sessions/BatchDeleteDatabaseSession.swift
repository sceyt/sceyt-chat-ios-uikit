//
//  BatchDeleteDatabaseSession.swift
//  SceytChatUIKit
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
        NSManagedObjectContext.mergeChanges(
            fromRemoteContextSave: deletedObjects,
            into: [self]
        )
    }
}
