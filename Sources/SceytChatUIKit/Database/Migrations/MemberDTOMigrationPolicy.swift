//
//  MemberDTOMigrationPolicy.swift
//  SceytChatUIKit
//

import Foundation
import CoreData

@objc(MemberDTOMigrationPolicy)
public final class MemberDTOMigrationPolicy: NSEntityMigrationPolicy {

    public override func createRelationships(
        forDestination dInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createRelationships(forDestination: dInstance, in: mapping, manager: manager)

        let channelId = (dInstance.value(forKey: "channelId") as? Int64) ?? 0
        guard channelId != 0 else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "ChannelDTO")
        request.predicate = NSPredicate(format: "id == %lld", channelId)
        request.fetchLimit = 1

        let matches = try manager.destinationContext.fetch(request)
        if let channel = matches.first {
            dInstance.setValue(channel, forKey: "channel")
        }
    }
}
