//
//  Lazy.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
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
