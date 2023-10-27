//
//  Cache.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

public final class Cache<Key: Hashable, Value> {

    private let _cache = NSCache<_Key, _Value>()

    public var name: String {
        _cache.name
    }

    public func value(forKey key: Key) -> Value? {
        _cache.object(forKey: .init(key: key))?.value
    }

    public func setValue(_ value: Value, forKey key: Key) {
        _cache.setObject(.init(value: value), forKey: .init(key: key))
    }

    public func setValue(_ value: Value, forKey key: Key, cost: Int) {
        _cache.setObject(.init(value: value), forKey: .init(key: key), cost: cost)
    }

    public func removeValue(forKey key: Key) {
        _cache.removeObject(forKey: .init(key: key))
    }

    public func removeAll() {
        _cache.removeAllObjects()
    }

    public var totalCostLimit: Int {
        get { _cache.totalCostLimit }
        set { _cache.totalCostLimit = newValue }
    }

    public var countLimit: Int {
        get { _cache.countLimit }
        set { _cache.countLimit = newValue }
    }
    
    subscript(key: Key) -> Value? {
        get {
            value(forKey: key)
        }
        set(newValue) {
            if let newValue = newValue {
                setValue(newValue, forKey: key)
            } else {
                removeValue(forKey: key)
            }
        }
    }
}

private extension Cache {

    class _Key: NSObject {

        let key: Key
        init(key: Key) {
            self.key = key
        }

        override var hash: Int {
            key.hashValue
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let keyType = object as? _Key else { return false }
            return key == keyType.key
        }
    }

    class _Value: NSObject {

        let value: Value
        init(value: Value) {
            self.value = value
        }
    }
}
