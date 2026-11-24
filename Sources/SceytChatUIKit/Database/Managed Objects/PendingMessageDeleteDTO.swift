//
//  PendingMessageDeleteDTO.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import CoreData
import Foundation
import SceytChat

/// A durable "delete this message on the server" intent.
///
/// Created in the same transaction that removes (or, for a sent message, hides or tombstones)
/// the message row, so the intent survives a failed request, a lost connection and an app
/// restart. `SyncService` replays the surviving records until the server confirms the delete.
///
/// Keyed by `messageTid` for our own messages. Incoming messages have no tid of ours, so their
/// records carry `messageTid == 0` and are keyed by `messageId`.
@objc(PendingMessageDeleteDTO)
public class PendingMessageDeleteDTO: NSManagedObject {

    @NSManaged public var messageTid: Int64
    @NSManaged public var channelId: Int64
    /// The server id, known only after a send ack arrived for an already deleted message. 0 otherwise.
    @NSManaged public var messageId: Int64
    /// `StoredType` raw value — never `DeleteMessageType.rawValue`, see `StoredType`.
    @NSManaged public var deleteType: Int16
    @NSManaged public var createdAt: Int64
    /// 0 until the first attempt is made.
    @NSManaged public var lastAttemptAt: Int64
    @NSManaged public var retryCount: Int16

    /// `DeleteMessageType.deleteHard.rawValue` is 0, which is also Core Data's default for a
    /// missing value, so a decoding accident would turn into the most destructive delete.
    /// This shifted encoding keeps 0 meaning "unspecified" and maps it to `.deleteForMe`.
    public enum StoredType: Int16 {
        case unspecified = 0
        case deleteForMe = 1
        case deleteForEveryone = 2
        case deleteHard = 3

        public init(_ type: DeleteMessageType) {
            switch type {
            case .deleteForMe: self = .deleteForMe
            case .deleteForEveryone: self = .deleteForEveryone
            case .deleteHard: self = .deleteHard
            @unknown default: self = .deleteForMe
            }
        }

        public var deleteMessageType: DeleteMessageType {
            switch self {
            case .deleteForEveryone: return .deleteForEveryone
            case .deleteHard: return .deleteHard
            case .deleteForMe, .unspecified: return .deleteForMe
            }
        }
    }

    public var type: DeleteMessageType {
        get { (StoredType(rawValue: deleteType) ?? .deleteForMe).deleteMessageType }
        set { deleteType = StoredType(newValue).rawValue }
    }

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<PendingMessageDeleteDTO> {
        return NSFetchRequest<PendingMessageDeleteDTO>(entityName: entityName)
    }

    public static func fetch(
        messageTid: Int64,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) -> PendingMessageDeleteDTO? {
        fetchAll(messageTid: messageTid, channelId: channelId, context: context).first
    }

    public static func fetchAll(context: NSManagedObjectContext) -> [PendingMessageDeleteDTO] {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \PendingMessageDeleteDTO.createdAt, ascending: true)
        return fetch(request: request, context: context)
    }

    public static func fetchAll(
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) -> [PendingMessageDeleteDTO] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "channelId == %lld", channelId)
        request.sortDescriptor = NSSortDescriptor(keyPath: \PendingMessageDeleteDTO.createdAt, ascending: true)
        return fetch(request: request, context: context)
    }

    /// Looks up a record by server id. Used for incoming messages, which have no tid of ours.
    public static func fetch(
        messageId: MessageId,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) -> PendingMessageDeleteDTO? {
        guard messageId > 0 else { return nil }
        return fetchAll(messageId: messageId, channelId: channelId, context: context).first
    }

    /// - Parameter messageId: keys the record when `messageTid` is 0 (an incoming message);
    ///   otherwise records are keyed by tid and the id is only stored by the caller.
    public static func fetchOrCreate(
        messageTid: Int64,
        messageId: MessageId = 0,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) -> PendingMessageDeleteDTO {
        let existing = messageTid == 0 && messageId > 0
            ? fetchAll(messageId: messageId, channelId: channelId, context: context)
            : fetchAll(messageTid: messageTid, channelId: channelId, context: context)
        if let mo = existing.first {
            // Two write contexts can insert concurrently; keep the oldest record.
            if existing.count > 1 {
                existing.dropFirst().forEach { context.delete($0) }
            }
            return mo
        }

        let mo = insertNewObject(into: context)
        mo.messageTid = messageTid
        mo.messageId = Int64(messageId)
        mo.channelId = Int64(channelId)
        mo.createdAt = Int64(Date().timeIntervalSince1970 * 1000)
        return mo
    }

    public static func delete(
        messageTid: Int64,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) {
        fetchAll(messageTid: messageTid, channelId: channelId, context: context)
            .forEach { context.delete($0) }
    }

    public static func delete(
        messageId: MessageId,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) {
        guard messageId > 0 else { return }
        fetchAll(messageId: messageId, channelId: channelId, context: context)
            .forEach { context.delete($0) }
    }

    public static func deleteAll(channelId: ChannelId, context: NSManagedObjectContext) {
        fetchAll(channelId: channelId, context: context)
            .forEach { context.delete($0) }
    }

    private static func fetchAll(
        messageTid: Int64,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) -> [PendingMessageDeleteDTO] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "messageTid == %lld AND channelId == %lld", messageTid, channelId)
        request.sortDescriptor = NSSortDescriptor(keyPath: \PendingMessageDeleteDTO.createdAt, ascending: true)
        return fetch(request: request, context: context)
    }

    /// Only records without a tid: a tid keyed record that later learned its id is found by tid.
    private static func fetchAll(
        messageId: MessageId,
        channelId: ChannelId,
        context: NSManagedObjectContext
    ) -> [PendingMessageDeleteDTO] {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "messageTid == 0 AND messageId == %lld AND channelId == %lld",
            Int64(messageId), Int64(channelId)
        )
        request.sortDescriptor = NSSortDescriptor(keyPath: \PendingMessageDeleteDTO.createdAt, ascending: true)
        return fetch(request: request, context: context)
    }

    public func convert() -> PendingMessageDelete {
        .init(dto: self)
    }
}

extension PendingMessageDeleteDTO: Identifiable { }
