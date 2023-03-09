//
//  NSManagedObject+Extension.swift
//  SceytChatUIKit
//

import Foundation
import CoreData

public extension NSManagedObject {

    @objc
    class var entityName: String {
        "\(self)"
    }

    @nonobjc
    static func fetch<T>(request: NSFetchRequest<T>, context: NSManagedObjectContext) -> [T] {
        do {
            return try context.fetch(request)
        } catch {
            debugPrint("fetch failed for request \(request) error: \(error)")
        }
        return []
    }

    static func insertNewObject(into context: NSManagedObjectContext) -> Self {
        NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! Self
    }
}
