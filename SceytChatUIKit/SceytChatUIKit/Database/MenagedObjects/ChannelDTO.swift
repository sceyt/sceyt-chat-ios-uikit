//
//  ChannelDTO.swift
//  
//
//
//

import Foundation
import CoreData
import SceytChat

@objc(ChannelDTO)
public class ChannelDTO: NSManagedObject {

    @NSManaged public var id: Int64
    @NSManaged public var type: Int16
    @NSManaged public var createdAt: CDDate
    @NSManaged public var updatedAt: CDDate?
    @NSManaged public var unreadMessageCount: Int64
    @NSManaged public var unreadMentionCount: Int64
    @NSManaged public var unreadReactionCount: Int64
    @NSManaged public var lastDisplayedMessageId: Int64
    @NSManaged public var lastReceivedMessageId: Int64
    @NSManaged public var memberCount: Int64
    @NSManaged public var markedAsUnread: Bool
    @NSManaged public var muted: Bool
    @NSManaged public var muteExpireDate: CDDate?
    @NSManaged public var subject: String?
    @NSManaged public var label: String?
    @NSManaged public var metadata: String?
    @NSManaged public var avatarUrl: URL?
    @NSManaged public var uri: String?
    @NSManaged public var unsubscribed: Bool

    @NSManaged public var lastMessage: MessageDTO?
    @NSManaged public var peer: UserDTO?
    @NSManaged public var owner: MemberDTO?
    @NSManaged public var currentUserRole: RoleDTO?
    @NSManaged public var members: Set<MemberDTO>?
    @NSManaged public var messages: Set<MessageDTO>?

    @NSManaged public var draft: NSAttributedString?
    @NSManaged public var sortingKey: CDDate?

    public override func willSave() {
        super.willSave()
        let date: Date?
        if let last = lastMessage?.createdAt {
            date = last.bridgeDate
        } else {
            date = updatedAt != nil ? updatedAt?.bridgeDate : createdAt.bridgeDate
        }

        if date != sortingKey?.bridgeDate {
            sortingKey = date?.bridgeDate
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
        case .label:
            key = "label"
        case .URI:
            key = "uri"
        case .member:
            key = "peer"
        @unknown default:
            key = "subject"
        }

        let type: String
        switch query.queryType {
        case .beginsWith:
            type = "BEGINSWITH"
        case .equal:
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
        createdAt = map.createdAt.bridgeDate
        updatedAt = map.updatedAt?.bridgeDate
        unreadMessageCount = Int64(map.unreadMessageCount)
        unreadMentionCount = Int64(map.unreadMentionCount)
        unreadReactionCount = Int64(map.unreadReactionCount)
        lastDisplayedMessageId = max(lastDisplayedMessageId, Int64(map.lastDisplayedMessageId))
        lastReceivedMessageId = max(lastReceivedMessageId, Int64(map.lastReceivedMessageId)) 
        memberCount = Int64(map.memberCount)
        markedAsUnread = map.markedAsUnread
        muted = map.muted
        muteExpireDate = map.muteExpireDate?.bridgeDate
        if let channel = map as? GroupChannel {
            subject = channel.subject
            label = channel.label
            metadata = channel.metadata
            avatarUrl = channel.avatarUrl
            if let channel = channel as? PublicChannel {
                uri = channel.uri
                type = ChatChannel.ChannelType.public.rawValue
            } else {
                type = ChatChannel.ChannelType.private.rawValue
            }
        } else {
            type = ChatChannel.ChannelType.direct.rawValue
        }
        if let channel = map as? PublicChannel, channel.role == nil {
            unsubscribed = true
        } else {
            unsubscribed = false
        }
        return self
    }

    public func convert() -> ChatChannel {
        .init(dto: self)
    }
}

extension ChannelDTO: Identifiable { }

//Helper:
extension ChannelDTO {
    
    public static func totalUnreadMessageCount(context: NSManagedObjectContext) -> Int {
        let expressionDescription = NSExpressionDescription()
        expressionDescription.name = "sumOfUnreadMessageCount"
        expressionDescription.expression = NSExpression(forFunction: "sum:",
                                                 arguments:[NSExpression(forKeyPath: "unreadMessageCount")])
        expressionDescription.expressionResultType = .doubleAttributeType
        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: ChannelDTO.entityName)
        fetchRequest.propertiesToFetch = [expressionDescription]
        fetchRequest.resultType = .dictionaryResultType
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first?.value(forKey: "sumOfUnreadMessageCount") as? Int ?? 0
        } catch {
            debugPrint(error)
        }
        return 0
    }
}
