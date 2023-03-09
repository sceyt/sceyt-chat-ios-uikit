//
//  NSPredicate+Extension.swift
//  SceytChatUIKit
//

import Foundation

public extension NSCompoundPredicate {
    
    class func andPredicate(_ predicates: NSPredicate...) -> NSCompoundPredicate {
        NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}

public extension NSPredicate {
    
    func and(predicate: NSPredicate) -> NSPredicate {
        NSCompoundPredicate(andPredicateWithSubpredicates: [self, predicate])
    }
    
    func or(predicate: NSPredicate) -> NSPredicate {
        NSCompoundPredicate(orPredicateWithSubpredicates: [self, predicate])
    }
}
