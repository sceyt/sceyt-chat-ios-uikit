//
//  LinkMetadataDTO.swift
//  SceytChatUIKit
//

import Foundation
import CoreData

@objc(LinkMetadataDTO)
public class LinkMetadataDTO: NSManagedObject {

    @NSManaged public var url: URL
    @NSManaged public var title: String?
    @NSManaged public var summary: String?
    @NSManaged public var creator: String?
    @NSManaged public var iconUrl: URL?
    @NSManaged public var imageUrl: URL?

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<LinkMetadataDTO> {
        return NSFetchRequest<LinkMetadataDTO>(entityName: entityName)
    }

    public static func create(context: NSManagedObjectContext) -> LinkMetadataDTO {
        insertNewObject(into: context)
    }

    public static func fetch(url: URL, context: NSManagedObjectContext) -> LinkMetadataDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \LinkMetadataDTO.url, ascending: false)
        request.predicate = .init(format: "url == %@", url as CVarArg)
        return fetch(request: request, context: context).first
    }

    public static func fetchOrCreate(url: URL, context: NSManagedObjectContext) -> LinkMetadataDTO {
        if let mo = fetch(url: url, context: context) {
            return mo
        }

        let mo = insertNewObject(into: context)
        mo.url = url
        return mo
    }

    public func map(_ map: LinkMetadata) -> LinkMetadataDTO {
        url = map.url
        title = map.title
        summary = map.summary
        creator = map.creator
        iconUrl = map.iconUrl
        imageUrl = map.imageUrl
        return self
    }
}

extension LinkMetadataDTO: Identifiable { }
