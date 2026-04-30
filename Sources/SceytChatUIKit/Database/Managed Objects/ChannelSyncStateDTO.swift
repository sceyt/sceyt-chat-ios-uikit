//
//  ChannelSyncStateDTO.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import CoreData
import Foundation
import SceytChat

@objc(ChannelSyncStateDTO)
public class ChannelSyncStateDTO: NSManagedObject {

    @NSManaged public var channelId: Int64
    @NSManaged public var lastSyncedMessageId: Int64

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<ChannelSyncStateDTO> {
        return NSFetchRequest<ChannelSyncStateDTO>(entityName: entityName)
    }

    public static func fetch(channelId: ChannelId, context: NSManagedObjectContext) -> ChannelSyncStateDTO? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "channelId == %lld", channelId)
        request.fetchLimit = 1
        return fetch(request: request, context: context).first
    }

    public static func fetchOrCreate(channelId: ChannelId, context: NSManagedObjectContext) -> ChannelSyncStateDTO {
        if let mo = fetch(channelId: channelId, context: context) {
            return mo
        }
        let mo = insertNewObject(into: context)
        mo.channelId = Int64(channelId)
        return mo
    }

    public static func delete(channelId: ChannelId, context: NSManagedObjectContext) {
        guard let mo = fetch(channelId: channelId, context: context) else { return }
        context.delete(mo)
    }

    public static func fetchAll(context: NSManagedObjectContext) -> [ChannelId: MessageId] {
        let request = NSFetchRequest<NSDictionary>(entityName: entityName)
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["channelId", "lastSyncedMessageId"]
        let results = ChannelSyncStateDTO.fetch(request: request, context: context)
        var items = [ChannelId: MessageId]()
        for result in results {
            guard let channelId = result["channelId"] as? ChannelId,
                  let lastSyncedMessageId = result["lastSyncedMessageId"] as? MessageId
            else { continue }
            items[channelId] = lastSyncedMessageId
        }
        return items
    }
}
