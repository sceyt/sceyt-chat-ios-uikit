//
//  NSManagedObject+Extension.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
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
            logger.debug("fetch failed for request \(request) error: \(error)")
        }
        return []
    }

    static func insertNewObject(into context: NSManagedObjectContext) -> Self {
        NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! Self
    }
}

public extension NSManagedObject {
    
    static func maxExpression(
        keyPaths: [String],
        predicate: NSPredicate,
        context: NSManagedObjectContext,
        resultType: NSFetchRequestResultType = .dictionaryResultType,
        expressionResultType: NSAttributeType = .integer64AttributeType
    ) -> [NSFetchRequestResult] {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        request.predicate = predicate
        request.resultType = resultType
        let maxExpression = NSExpression(forFunction: "max:", arguments: keyPaths.map { NSExpression(forKeyPath: $0) })
        
        let key = "max"
        let expressionDescription = NSExpressionDescription()
        expressionDescription.name = key
        expressionDescription.expression = maxExpression
        expressionDescription.expressionResultType = expressionResultType
        request.propertiesToFetch = [expressionDescription]
        return fetch(request: request, context: context)
    }
}
