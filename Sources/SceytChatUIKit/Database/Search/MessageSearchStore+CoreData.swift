//
//  MessageSearchStore+CoreData.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData

public extension MessageSearchStore {

    /// Forwards `MessageDTO` inserts/updates/deletes from a Core Data
    /// `NSManagedObjectContextDidSave` notification into the FTS index.
    ///
    /// Must be called synchronously from the saving context's queue (i.e.,
    /// from inside a `didSave` notification handler) — managed objects in the
    /// notification are only valid on that queue.
    func sync(notification: Notification, on context: NSManagedObjectContext) {
        let info = notification.userInfo ?? [:]
        let inserted = (info[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? []
        let updated  = (info[NSUpdatedObjectsKey]  as? Set<NSManagedObject>) ?? []
        let deleted  = (info[NSDeletedObjectsKey]  as? Set<NSManagedObject>) ?? []

        let insertedMessages = inserted.compactMap { $0 as? MessageDTO }
        let updatedMessages  = updated.compactMap  { $0 as? MessageDTO }
        let deletedMessages  = deleted.compactMap  { $0 as? MessageDTO }
        if insertedMessages.isEmpty, updatedMessages.isEmpty, deletedMessages.isEmpty {
            return
        }

        var channelTypeCache: [Int64: String] = [:]
        func channelType(for channelId: Int64) -> String {
            if let cached = channelTypeCache[channelId] { return cached }
            let request = ChannelDTO.fetchRequest()
            request.predicate = NSPredicate(format: "id == %lld", channelId)
            request.fetchLimit = 1
            let type = (try? context.fetch(request))?.first?.type ?? ""
            channelTypeCache[channelId] = type
            return type
        }

        var indexRows: [Row] = []
        var deleteIds: [Int64] = []

        func makeRow(from dto: MessageDTO) -> Row? {
            guard dto.id > 0,
                  let userId = dto.user?.id, !userId.isEmpty,
                  Self.shouldIndex(state: dto.state, transient: dto.transient, body: dto.body)
            else { return nil }
            return Row(
                messageId: dto.id,
                channelId: dto.channelId,
                channelType: channelType(for: dto.channelId),
                userId: userId,
                createdAt: dto.createdAt.timeIntervalSince1970,
                body: dto.body
            )
        }

        for dto in insertedMessages {
            if let row = makeRow(from: dto) { indexRows.append(row) }
        }
        for dto in updatedMessages {
            guard dto.id > 0 else { continue }
            if let row = makeRow(from: dto) {
                indexRows.append(row)
            } else {
                // Either now soft-deleted, transient, or empty body —
                // remove if it was previously indexed.
                deleteIds.append(dto.id)
            }
        }
        for dto in deletedMessages where dto.id > 0 {
            deleteIds.append(dto.id)
        }

        if !indexRows.isEmpty { index(rows: indexRows) }
        if !deleteIds.isEmpty { delete(messageIds: deleteIds) }
    }
}
