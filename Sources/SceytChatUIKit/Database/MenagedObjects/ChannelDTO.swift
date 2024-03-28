//
//  ChannelDTO.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData
import SceytChat

@objc(ChannelDTO)
public class ChannelDTO: NSManagedObject {

    @NSManaged public var id: Int64
    @NSManaged public var parentChannelId: Int64
    @NSManaged public var type: String
    @NSManaged public var uri: String?
    @NSManaged public var subject: String?
    @NSManaged public var avatarUrl: String?
    @NSManaged public var metadata: String?
    
    @NSManaged public var createdAt: CDDate
    @NSManaged public var updatedAt: CDDate?
    @NSManaged public var messagesClearedAt: CDDate?
    @NSManaged public var pinnedAt: CDDate?
    @NSManaged public var messageRetentionPeriod: TimeInterval
    
    @NSManaged public var memberCount: Int64
    
    @NSManaged public var newMessageCount: Int64
    @NSManaged public var newMentionCount: Int64
    @NSManaged public var newReactionMessageCount: Int64
    @NSManaged public var lastDisplayedMessageId: Int64
    @NSManaged public var lastReceivedMessageId: Int64
    
    @NSManaged public var hidden: Bool
    @NSManaged public var archived: Bool
    @NSManaged public var unread: Bool
    @NSManaged public var muted: Bool
    @NSManaged public var muteTill: CDDate?
    
    @NSManaged public var lastMessage: MessageDTO?
    @NSManaged public var lastReaction: ReactionDTO?
    
    @NSManaged public var owner: MemberDTO?
    @NSManaged public var userRole: RoleDTO?
    
    @NSManaged public var unsubscribed: Bool
    
    @NSManaged public var createdBy: UserDTO?

    @NSManaged public var draft: NSAttributedString?
    @NSManaged public var draftDate: CDDate?
    @NSManaged public var sortingKey: CDDate?
    
    @NSManaged public var unsynched: Bool
    
    @NSManaged public var toggle: Bool

    @NSManaged public var isSelf: Bool

    public override func willSave() {
        super.willSave()
        let date: Date?
        let draftDate = draftDate?.bridgeDate
        
        if let last = lastMessage?.createdAt {
            date = last.bridgeDate
        } else {
            date = updatedAt != nil ? updatedAt?.bridgeDate : createdAt.bridgeDate
        }
        let sortingDate: Date?
        if let pinnedAt {
            sortingDate = pinnedAt.bridgeDate
        } else {
            switch (date, draftDate) {
            case (.some(let d), .none):
                sortingDate = d
            case (.none, .some(let d)):
                sortingDate = d
            case (.some(let d1), .some(let d2)):
                sortingDate = max(d1, d2)
            case (.none, .none):
                sortingDate = nil
            }
        }
        
        if sortingDate != sortingKey?.bridgeDate {
            sortingKey = sortingDate?.bridgeDate
        }
    }

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<ChannelDTO> {
        return NSFetchRequest<ChannelDTO>(entityName: entityName)
    }

    @nonobjc
    public static func predicate(query: ChannelListQuery) -> NSPredicate {
        let key: String
        switch query.filterKey {
        case .subject:
            key = "subject"
        case .URI:
            key = "uri"
        case .member:
            key = "peer"
        @unknown default:
            key = "subject"
        }

        let type: String
        switch query.searchOperator {
        case .begins:
            type = "BEGINSWITH"
        case .EQ:
            type = "=="
        default:
            type = "CONTAINS"
        }

        return NSPredicate(format: "\(key) \(type)[c] %@", query.query ?? "")
    }

    public static func fetch(id: ChannelId, context: NSManagedObjectContext) -> ChannelDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \ChannelDTO.id, ascending: false)
        request.predicate = .init(format: "id == %lld", id)
        return fetch(request: request, context: context).first
    }

    public static func fetchOrCreate(id: ChannelId, context: NSManagedObjectContext) -> ChannelDTO {
        if let mo = fetch(id: id, context: context) {
            return mo
        }
        
        let mo = insertNewObject(into: context)
        mo.id = Int64(id)
        return mo
    }

    public func map(_ map: Channel) -> ChannelDTO {
        parentChannelId = Int64(map.parentChannelId)
        uri = map.uri
        type = map.type
        subject = map.subject
        avatarUrl = map.avatarUrl
        metadata = map.metadata
        createdAt = map.createdAt.bridgeDate
        updatedAt = map.updatedAt?.bridgeDate
        messagesClearedAt = map.messagesClearedAt?.bridgeDate
        memberCount = Int64(map.memberCount)
        unread = map.unread
        hidden = map.hidden
        archived = map.archived
        newMessageCount = Int64(map.newMessageCount)
        newMentionCount = Int64(map.newMentionCount)
        newReactionMessageCount = Int64(map.newReactionMessageCount)
        
        muted = map.muted
        muteTill = map.muteTill?.bridgeDate
        pinnedAt = map.pinnedAt?.bridgeDate
        
        lastDisplayedMessageId = max(lastDisplayedMessageId, Int64(map.lastDisplayedMessageId))
        lastReceivedMessageId = max(lastReceivedMessageId, Int64(map.lastReceivedMessageId))
        
        if map.userRole == nil {
            unsubscribed = true
        } else {
            unsubscribed = false
        }
        unsynched = false

        if let metadata = map.metadata, let decodedMetadata = try? ChatChannel.Metadata.decode(metadata) {
            let isSelf = Bool(truncating: decodedMetadata.isSelf as NSNumber)
            if self.isSelf != isSelf {
                self.isSelf = isSelf
            }
        }
        return self
    }
    
    public func map(_ map: ChatChannel) -> ChannelDTO {
        parentChannelId = 0
        uri = map.uri
        type = map.type
        subject = map.subject
        avatarUrl = map.avatarUrl
        metadata = map.metadata
        createdAt = map.createdAt.bridgeDate
        updatedAt = map.updatedAt?.bridgeDate
        messagesClearedAt = nil
        memberCount = Int64(map.memberCount)
        unread = map.unread
        hidden = map.hidden
        archived = map.archived
        newMessageCount = Int64(map.newMessageCount)
        newMentionCount = Int64(map.newMentionCount)
        newReactionMessageCount = Int64(map.newReactionMessageCount)
        
        muted = map.muted
        muteTill = map.muteTill?.bridgeDate
        pinnedAt = map.pinnedAt?.bridgeDate
        
        lastDisplayedMessageId = max(lastDisplayedMessageId, Int64(map.lastDisplayedMessageId))
        lastReceivedMessageId = max(lastReceivedMessageId, Int64(map.lastReceivedMessageId))
        
        if map.userRole == nil {
            unsubscribed = true
        } else {
            unsubscribed = false
        }
        isSelf = map.isSelfChannel

        return self
    }

    public func convert() -> ChatChannel {
        .init(dto: self)
    }
}

extension ChannelDTO {
    
    func map(_ map: NotificationPayload.Channel) -> ChannelDTO {
        uri = map.uri
        subject = map.subject
        metadata = map.metadata
        memberCount = map.membersCount
        type = map.type
        return self
    }
}

extension ChannelDTO: Identifiable { }


extension ChannelDTO {
    
    @objc
    public var pinSectionIdentifier: Int {
        if pinnedAt == nil {
            return 0
        }
        return 1
    }
}

//Helper:
extension ChannelDTO {
    
    public static func totalUnreadMessageCount(context: NSManagedObjectContext) -> Int {
        let expressionDescription = NSExpressionDescription()
        expressionDescription.name = "sumOfUnreadMessageCount"
        expressionDescription.expression = NSExpression(forFunction: "sum:",
                                                 arguments:[NSExpression(forKeyPath: "newMessageCount")])
        expressionDescription.expressionResultType = .doubleAttributeType
        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: ChannelDTO.entityName)
        fetchRequest.propertiesToFetch = [expressionDescription]
        fetchRequest.resultType = .dictionaryResultType
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first?.value(forKey: "sumOfUnreadMessageCount") as? Int ?? 0
        } catch {
            logger.errorIfNotNil(error, "")
        }
        return 0
    }
}
