//
//  AttachmentDTO.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData
import SceytChat

@objc(AttachmentDTO)
public class AttachmentDTO: NSManagedObject {
    @NSManaged public var id: Int64
    @NSManaged public var tid: Int64
    @NSManaged public var messageId: Int64
    @NSManaged public var channelId: Int64
    @NSManaged public var userId: String
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
    
    public var fullFilePath: String? {
        if let filePath {
            let fullPath = Components.storage.fullPath(filePath: filePath)
            return fullPath
        }
        return nil
    }
    
    public override func willSave() {
        super.willSave()
        if let filePath {
            let subPath = Components.storage.subPath(filePath: filePath)
            if filePath != subPath {
                self.filePath = subPath
            }
        }
    }
    
    public override func awakeFromFetch() {
        super.awakeFromFetch()
        if let filePath {
            let fullPath = Components.storage.fullPath(filePath: filePath)
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
    
    public static func fetch(tid: Int64, message: MessageDTO, context: NSManagedObjectContext) -> AttachmentDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \AttachmentDTO.tid, ascending: false)
        request.predicate = .init(format: "tid == %lld AND message == %@", tid, message)
        return fetch(request: request, context: context).first
    }
    
    public static func fetch(url: String, message: MessageDTO? = nil, context: NSManagedObjectContext) -> AttachmentDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \AttachmentDTO.tid, ascending: false)
        if let message {
            request.predicate = .init(format: "url == %@ AND message == %@", url, message)
        } else {
            request.predicate = .init(format: "url == %@", url)
        }
        
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
        return dto
    }
    
    public static func fetchOrCreate(filePath: String, message: MessageDTO, context: NSManagedObjectContext) -> AttachmentDTO {
        let subPath = Components.storage.subPath(filePath: filePath)
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \AttachmentDTO.createdAt, ascending: false)
        request.predicate = NSPredicate(format: "filePath == %@ AND message == %@", subPath, message)
        if let dto = fetch(request: request, context: context).first {
            dto.filePath = filePath
            return dto
        }
        let dto = insertNewObject(into: context)
        dto.filePath = filePath
        return dto
    }
    
    public static func fetch(filePath: String, message: MessageDTO, context: NSManagedObjectContext) -> [AttachmentDTO] {
        let subPath = Components.storage.subPath(filePath: filePath)
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \AttachmentDTO.createdAt, ascending: false)
        request.predicate = NSPredicate(format: "filePath == %@ AND message == %@", subPath, message)
        return fetch(request: request, context: context)
    }

    public func map(_ map: Attachment) -> AttachmentDTO {
        id = Int64(map.id)
        tid = Int64(map.tid)
        messageId = Int64(map.messageId)
        userId = map.userId
        url = map.url
        filePath = map.filePath ?? filePath
        type = map.type
        name = map.name
        metadata = map.metadata
        createdAt = map.createdAt.bridgeDate
        uploadedFileSize = Int64(map.size)
        if let message {
            createdAt = message.createdAt.bridgeDate.bridgeDate
        }
        return self
    }

    public func convert() -> ChatMessage.Attachment {
        .init(dto: self)
    }
}

extension AttachmentDTO {
    
    func map(_ map: NotificationPayload.Message.Attachment, dto: MessageDTO) -> AttachmentDTO {
        self.messageId = dto.id
        userId = dto.user?.id ?? ""
        
        url = map.data
        type = map.type
        name = map.name
        metadata = map.metadata
        createdAt = dto.createdAt
        uploadedFileSize = Int64(map.size ?? 0)
        if let message {
            createdAt = message.createdAt.bridgeDate.bridgeDate
        }
        return self
    }
}

extension AttachmentDTO: Identifiable { }

extension AttachmentDTO {
    @objc public var createdYearMonth: Int {
        let calendar = Calendar.current
        let createdAt = createdAt?.bridgeDate ?? Date()
        var dateComponents = DateComponents()
        dateComponents.year = calendar.component(.year, from: createdAt)
        dateComponents.month = calendar.component(.month, from: createdAt)
        dateComponents.day = 0
        dateComponents.hour = 0
        dateComponents.minute = 0
        if let date = calendar.date(from: dateComponents) {
            return Int(date.timeIntervalSince1970)
        }
        return 0
    }
}
