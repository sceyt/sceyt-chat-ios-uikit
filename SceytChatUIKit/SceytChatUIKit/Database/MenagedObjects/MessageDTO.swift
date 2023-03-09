//
//  MessageDTO.swift
//  SceytChatUIKit
//
//

import Foundation
import CoreData
import SceytChat

@objc(MessageDTO)
public class MessageDTO: NSManagedObject {

    @NSManaged public var id: Int64
    @NSManaged public var tid: Int64
    @NSManaged public var channelId: Int64
    @NSManaged public var body: String
    @NSManaged public var type: String
    @NSManaged public var metadata: String?
    @NSManaged public var createdAt: CDDate
    @NSManaged public var updatedAt: CDDate?
    @NSManaged public var incoming: Bool
    @NSManaged public var transient: Bool
    @NSManaged public var silent: Bool
    @NSManaged public var state: Int16
    @NSManaged public var deliveryStatus: Int16
    @NSManaged public var repliedInThread: Bool
    @NSManaged public var replyCount: Int32
    @NSManaged public var displayCount: Int64

    @NSManaged public var markerCount: [String: Int]?
    @NSManaged public var reactionScores: [String: Int]?
    @NSManaged public var selfMarkerNames: Set<String>?
    @NSManaged public var pendingMarkerNames: Set<String>?
    
    @NSManaged public var attachments: Set<AttachmentDTO>?
    @NSManaged public var selfReactions: Set<ReactionDTO>?
    @NSManaged public var mentionedUsers: Set<UserDTO>?
    @NSManaged public var linkMetadatas: Set<LinkMetadataDTO>?
    @NSManaged public var user: UserDTO?
    @NSManaged public var changedBy: UserDTO?
    @NSManaged public var lastMessageChannel: ChannelDTO?
    @NSManaged public var ownerChannel: ChannelDTO?
    @NSManaged public var parent: MessageDTO?
    
    @NSManaged public var forwardMessageId: Int64
    @NSManaged public var forwardChannelId: Int64
    @NSManaged public var forwardHops: Int64
    @NSManaged public var forwardUser: UserDTO?
    
    
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
        var predicates = [NSPredicate]()
        if id != 0 {
            predicates.append(.init(format: "id == %lld", id))
        }
        if tid != 0 {
            predicates.append(.init(format: "tid == %lld", tid))
        }
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
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
        tid = Int64(map.tid)
        body = map.body
        type = map.type
        metadata = map.metadata
        if createdAt.bridgeDate < Date(timeIntervalSince1970: 60 * 60 * 24 * 2) {
            createdAt = map.createdAt.bridgeDate
        }
        updatedAt = map.updatedAt?.bridgeDate
        incoming = map.incoming
        transient = map.transient
        silent = map.silent
        state = Int16(map.state.rawValue)
        deliveryStatus = Int16(map.deliveryStatus.rawValue)
        replyCount = Int32(map.replyCount)
        repliedInThread = map.repliedInThread
        displayCount = Int64(map.displayCount)
        return self
    }

    public func convert() -> ChatMessage {
        .init(dto: self)
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
