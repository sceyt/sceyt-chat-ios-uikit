//
//  RoleDTO+CoreDataProperties.swift
//  
//
//
//

import Foundation
import CoreData

@objc(RoleDTO)
public class RoleDTO: NSManagedObject {

    @NSManaged public var name: String?
    @NSManaged public var members: Set<MemberDTO>?

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<RoleDTO> {
        return NSFetchRequest<RoleDTO>(entityName: entityName)
    }

    public static func fetch(name: String, context: NSManagedObjectContext) -> RoleDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \RoleDTO.name, ascending: false)
        request.predicate = .init(format: "name == %@", name)
        return fetch(request: request, context: context).first
    }

    public static func fetchOrCreate(name: String, context: NSManagedObjectContext) -> RoleDTO {
        if let mo = fetch(name: name, context: context) {
            return mo
        }

        let mo = insertNewObject(into: context)
        mo.name = name
        return mo
    }

    public func map(_ map: RoleDTO) -> RoleDTO {
        return self
    }
}
