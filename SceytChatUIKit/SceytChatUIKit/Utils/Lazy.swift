//
//  Lazy.swift
//  SceytChatUIKit
//

import Foundation
import CoreData

@propertyWrapper
public final class Lazy<T> {
    
    public var storage: T?
    
    var computeValue: (() -> T)!
    
    public init(wrappedValue computeValue: @autoclosure @escaping () -> T) {
        self.computeValue = computeValue
    }

    public var wrappedValue: T {
        if storage == nil {
            guard let computeValue = computeValue
            else { preconditionFailure() }
            storage = computeValue()
        }
        return storage!
    }

    public var projectedValue: (() -> T) {
        get {
            computeValue
        }
        set {
            computeValue = newValue
        }
    }
}

@propertyWrapper
public final class CoreDataLazy<T> {
    
    @Atomic public var storage: T?
    
    public var computeValue: (() -> T)!
    
    public weak var context: NSManagedObjectContext?
    public var viewContext: NSManagedObjectContext {
        Config.database.viewContext
    }
    
    public init(wrappedValue computeValue: @autoclosure @escaping () -> T) {
        self.computeValue = computeValue
    }

    public var wrappedValue: T {
        if storage == nil {
            guard computeValue != nil
            else { preconditionFailure() }
            let perform = {
                self.storage = self.computeValue()
            }
            if let context {
                (Thread.isMainThread ? viewContext : context).performAndWait { perform() }
            } else {
                perform()
            }
        }
        return storage!
    }

    public var projectedValue: (() -> T, NSManagedObjectContext?) {
        get {
            (computeValue, context)
        }
        set {
            computeValue = newValue.0
            context = newValue.1
        }
    }
}
