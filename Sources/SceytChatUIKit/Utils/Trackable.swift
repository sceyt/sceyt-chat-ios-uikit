//
//  Trackable.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 07.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

@propertyWrapper
public final class Trackable<R, V> {
    private var hasSet = false
    private var referencePath: KeyPath<R, V>!
    private var reference: R!
    private var value: V!
    
    public init(reference: R, referencePath: KeyPath<R, V>) {
        self.referencePath = referencePath
        self.reference = reference
    }
    
    public init(value: V) {
        hasSet = true
        self.value = value
    }
    
    public var wrappedValue: V {
        get {
            if hasSet {
                value!
            } else {
                reference[keyPath: referencePath]
            }
        }
        set {
            hasSet = true
            value = newValue
        }
    }
}
