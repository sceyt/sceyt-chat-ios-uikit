//
//  AttachmentDTO.swift
//  SceytChatUIKit
//
//

import Foundation
import CoreData
import SceytChat

@objc(AttachmentDTO)
public class AttachmentDTO: NSManagedObject {
    @NSManaged public var id: Int64
    @NSManaged public var messageId: Int64
    @NSManaged public var userId: String
    @NSManaged public var localId: String
    @NSManaged public var url: String?
    @NSManaged public var filePath: String?
    @NSManaged public var type: String
    @NSManaged public var name: String?
    @NSManaged public var metadata: String?
    @NSManaged public var uploadedFileSize: Int64
    @NSManaged public var status: Int16
    @NSManaged public var transferProgress: Double
    @NSManaged public var createdAt: CDDate?
    @NSManaged public var message: MessageDTO?
    
    public override func willSave() {
        super.willSave()
        if let filePath {
            let subPath = Storage.subPath(filePath: filePath)
            if filePath != subPath {
                self.filePath = subPath
            }
        }
    }
    
    public override func awakeFromFetch() {
        super.awakeFromFetch()
        if let filePath {
            let fullPath = Storage.fullPath(filePath: filePath)
            if filePath != fullPath {
                self.filePath = fullPath
            }
        }
    }

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<AttachmentDTO> {
        return NSFetchRequest<AttachmentDTO>(entityName: entityName)
    }

    public static func create(context: NSManagedObjectContext) -> AttachmentDTO {
        insertNewObject(into: context)
    }
    
    public static func fetch(id: AttachmentId, context: NSManagedObjectContext) -> AttachmentDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \AttachmentDTO.id, ascending: false)
        request.predicate = .init(format: "id == %lld", id)
        return fetch(request: request, context: context).first
    }
    
    public static func fetchOrCreate(id: AttachmentId, context: NSManagedObjectContext) -> AttachmentDTO {
        if let mo = fetch(id: id, context: context) {
            return mo
        }

        let mo = insertNewObject(into: context)
        mo.id = Int64(id)
        return mo
    }
    
    public static func fetchOrCreate(url: String, message: MessageDTO, context: NSManagedObjectContext) -> AttachmentDTO {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \AttachmentDTO.createdAt, ascending: false)
        request.predicate = NSPredicate(format: "url == %@ AND message == %@", url, message)
        if let dto = fetch(request: request, context: context).first {
            dto.url = url
            return dto
        }
        let dto = insertNewObject(into: context)
        dto.url = url
        dto.localId = UUID().uuidString
        return dto
    }
    
    public static func fetchOrCreate(filePath: String, message: MessageDTO, context: NSManagedObjectContext) -> AttachmentDTO {
        let subPath = Storage.subPath(filePath: filePath)
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \AttachmentDTO.createdAt, ascending: false)
        request.predicate = NSPredicate(format: "filePath == %@ AND message == %@", subPath, message)
        if let dto = fetch(request: request, context: context).first {
            dto.filePath = filePath
            return dto
        }
        let dto = insertNewObject(into: context)
        dto.filePath = filePath
        dto.localId = UUID().uuidString
        return dto
    }
    
    public static func fetch(localId: String, context: NSManagedObjectContext) -> AttachmentDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \AttachmentDTO.createdAt, ascending: false)
        request.predicate = NSPredicate(format: "localId == %@", localId)
        return fetch(request: request, context: context).first
    }

    public func map(_ map: Attachment) -> AttachmentDTO {
        id = Int64(map.id)
        messageId = Int64(map.messageId)
        userId = map.userId
        url = map.url
        filePath = map.filePath ?? filePath
        type = map.type
        name = map.name
        metadata = map.metadata
        createdAt = map.createdAt.bridgeDate
        uploadedFileSize = Int64(map.fileSize)
        return self
    }

    public func convert() -> ChatMessage.Attachment {
        .init(dto: self)
    }
}

extension AttachmentDTO: Identifiable { }
