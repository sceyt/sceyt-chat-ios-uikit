//
//  ChecksumDTO.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 15.08.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//


import Foundation
import CoreData

@objc(ChecksumDTO)
public class ChecksumDTO: NSManagedObject {

    @NSManaged public var checksum: Int64
    @NSManaged public var attachmentTid: Int64
    @NSManaged public var messageTid: Int64
    @NSManaged public var data: String?
    
    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<ChecksumDTO> {
        return NSFetchRequest<ChecksumDTO>(entityName: entityName)
    }

    public static func fetch(checksum: Int64, context: NSManagedObjectContext) -> ChecksumDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \ChecksumDTO.checksum, ascending: false)
        request.predicate = .init(format: "checksum == %lld", checksum)
        return fetch(request: request, context: context).first
    }
    
    public static func fetch(message tid: Int64, context: NSManagedObjectContext) -> [ChecksumDTO] {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \ChecksumDTO.checksum, ascending: false)
        request.predicate = .init(format: "messageTid == %lld", tid)
        return fetch(request: request, context: context)
    }
    
    public static func fetch(message tid: Int64, attachmentTid: Int64, context: NSManagedObjectContext) -> ChecksumDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \ChecksumDTO.checksum, ascending: false)
        request.predicate = .init(format: "messageTid == %lld AND attachmentTid == %lld", tid, attachmentTid)
        return fetch(request: request, context: context).first
    }

    public static func fetchOrCreate(message tid: Int64, attachmentTid: Int64, context: NSManagedObjectContext) -> ChecksumDTO {
        if let mo = fetch(message: tid, attachmentTid: attachmentTid, context: context) {
            return mo
        }

        let mo = insertNewObject(into: context)
        mo.messageTid = tid
        mo.attachmentTid = attachmentTid
        return mo
    }
    
    public static func fetchOrCreate(checksum: Int64, context: NSManagedObjectContext) -> ChecksumDTO {
        if let mo = fetch(checksum: checksum, context: context) {
            return mo
        }

        let mo = insertNewObject(into: context)
        return mo
    }
    
    public func convert() -> ChatMessage.Attachment.Checksum {
        .init(dto: self)
    }
    
    public func map(_ map: ChatMessage.Attachment.Checksum) -> ChecksumDTO {
        messageTid = map.messageTid
        attachmentTid = map.attachmentTid
        checksum = map.checksum
        data = map.data
        return self
    }
}
