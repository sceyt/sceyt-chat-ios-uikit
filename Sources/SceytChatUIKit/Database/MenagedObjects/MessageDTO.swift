//
//  MessageDTO.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData
import SceytChat

@objc(MessageDTO)
public class MessageDTO: NSManagedObject {

    @NSManaged public var id: Int64
    @NSManaged public var tid: Int64
    @NSManaged public var channelId: Int64
    @NSManaged public var type: String
    @NSManaged public var state: Int16
    @NSManaged public var deliveryStatus: Int16
    @NSManaged public var transient: Bool
    @NSManaged public var silent: Bool
    @NSManaged public var incoming: Bool
    
    @NSManaged public var body: String
    @NSManaged public var metadata: String?
    
    @NSManaged public var createdAt: CDDate
    @NSManaged public var updatedAt: CDDate?
    @NSManaged public var autoDeleteAt: CDDate?
   
    @NSManaged public var repliedInThread: Bool
    @NSManaged public var replyCount: Int32
    @NSManaged public var displayCount: Int64
    @NSManaged public var replied: Bool
    @NSManaged public var unlisted: Bool
    
    @NSManaged public var markerTotal: [String: Int]?
    @NSManaged public var reactionTotal: Set<ReactionTotalDTO>?
    @NSManaged public var userMarkers: Set<MarkerDTO>?
    @NSManaged public var pendingMarkerNames: Set<String>?
    
    @NSManaged public var user: UserDTO?
    @NSManaged public var attachments: Set<AttachmentDTO>?
    @NSManaged public var userReactions: Set<ReactionDTO>?
    @NSManaged public var pendingReactions: Set<ReactionDTO>?
    
    @NSManaged public var reactions: Set<ReactionDTO>?
    
    @NSManaged public var orderedMentionedUserIds: [UserId]?
    @NSManaged public var mentionedUsers: Set<UserDTO>?
    
    @NSManaged public var linkMetadatas: Set<LinkMetadataDTO>?
    
    @NSManaged public var changedBy: UserDTO?
    @NSManaged public var lastMessageChannel: ChannelDTO?
    @NSManaged public var parent: MessageDTO?
    
    @NSManaged public var forwardMessageId: Int64
    @NSManaged public var forwardChannelId: Int64
    @NSManaged public var forwardHops: Int64
    @NSManaged public var forwardUser: UserDTO?
    
    @NSManaged public var bodyAttributes: Set<BodyAttributeDTO>?
        
    public override func willSave() {
        super.willSave()
    }
    
    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<MessageDTO> {
        return NSFetchRequest<MessageDTO>(entityName: entityName)
    }

    public static func fetch(id: MessageId, context: NSManagedObjectContext) -> MessageDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.id, ascending: false)
        request.predicate = .init(format: "id == %lld", id)
        return fetch(request: request, context: context).first
    }

    public static func fetch(tid: Int64, context: NSManagedObjectContext) -> MessageDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.tid, ascending: false)
        request.predicate = .init(format: "tid == %lld", tid)
        return fetch(request: request, context: context).first
    }
    
    public static func fetch(predicate: NSPredicate, context: NSManagedObjectContext) -> [MessageDTO] {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.id, ascending: false)
        request.predicate = predicate
        return fetch(request: request, context: context)
    }

    public static func fetchOrCreate(id: MessageId, tid: Int64 = 0, context: NSManagedObjectContext) -> MessageDTO {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.id, ascending: false)
        if id != 0 {
            request.predicate = NSPredicate(format: "id == %lld", id)
            if let dto = fetch(request: request, context: context).first {
                dto.id = Int64(id)
                return dto
            }
        }
        if tid != 0 {
            request.predicate = NSPredicate(format: "tid == %lld", tid)
            if let dto = fetch(request: request, context: context).first {
                dto.id = Int64(id)
                return dto
            }
        }
        
        let mo = insertNewObject(into: context)
        mo.id = Int64(id)
        return mo
    }

    public func map(_ map: Message) -> MessageDTO {
        tid = (map.incoming || map.tid == 0) ? Int64(map.id) : Int64(map.tid)
        channelId = Int64(map.channelId)
        type = map.type
        state = Int16(map.state.rawValue)
        transient = map.transient
        silent = map.silent
        incoming = map.incoming
        body = map.body
        metadata = map.metadata
        
        if createdAt.bridgeDate < Date(timeIntervalSince1970: 60 * 60 * 24 * 2) {
            createdAt = map.createdAt.bridgeDate
        }
        updatedAt = map.updatedAt?.bridgeDate
        autoDeleteAt = map.autoDeleteAt?.bridgeDate
        repliedInThread = map.repliedInThread
        replyCount = Int32(map.replyCount)
        displayCount = Int64(map.displayCount)
        
        if deliveryStatus == MessageDeliveryStatus.pending.rawValue {
            deliveryStatus = Int16(map.deliveryStatus.rawValue)
        } else if deliveryStatus == MessageDeliveryStatus.failed.rawValue,
                  map.deliveryStatus != .pending {
            deliveryStatus = Int16(map.deliveryStatus.rawValue)
        } else if deliveryStatus < map.deliveryStatus.rawValue {
            deliveryStatus = Int16(map.deliveryStatus.rawValue)
        }
        return self
    }

    public func convert() -> ChatMessage {
        .init(dto: self)
    }
}

extension MessageDTO {
    
    func map(_ map: NotificationPayload.Message) -> MessageDTO {
        body = map.body
        type = map.type
        metadata = map.metadata
        transient = map.transient
        incoming = true
        silent = false
        state = 0
        replyCount = 0
        repliedInThread = false
        displayCount = 1
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
       
        if let date = dateFormatter.date(from: map.createdAt) {
            createdAt = date.bridgeDate
        }
        
        if let date = dateFormatter.date(from: map.updatedAt),
            date.timeIntervalSince1970 > 1_000 {
            updatedAt = date.bridgeDate
        }
        
        switch map.deliveryStatus {
        case "read":
            deliveryStatus = Int16(MessageDeliveryStatus.displayed.rawValue)
        case "delivered":
            deliveryStatus = Int16(MessageDeliveryStatus.received.rawValue)
        default:
            deliveryStatus = Int16(MessageDeliveryStatus.sent.rawValue)
        }
        return self
    }
}

extension MessageDTO: Identifiable { }

extension MessageDTO {
    
    @objc
    public var daySectionIdentifier: Int {
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = calendar.component(.year, from: createdAt.bridgeDate)
        dateComponents.month = calendar.component(.month, from: createdAt.bridgeDate)
        dateComponents.day = calendar.component(.day, from: createdAt.bridgeDate)
        dateComponents.hour = 0
        dateComponents.minute = 0
        if let date = calendar.date(from: dateComponents) {
            return Int(date.timeIntervalSince1970)
        }
        return 0
    }
}

public extension MessageDTO {
    
    static func lastMessage(predicate: NSPredicate, context: NSManagedObjectContext) -> MessageDTO? {
        let result = MessageDTO
            .maxExpression(
                keyPaths: ["createdAt"],
                predicate: predicate,
                context: context,
                resultType: .managedObjectIDResultType,
                expressionResultType: .objectIDAttributeType
            )
        if let result = result as? [NSManagedObjectID],
           let objectId = result.last {
            return context.object(with: objectId) as? MessageDTO
        }
        return nil
    }
}
