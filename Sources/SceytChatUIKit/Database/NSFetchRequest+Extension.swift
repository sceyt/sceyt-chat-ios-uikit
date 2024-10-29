//
//  NSFetchRequest+Extension.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData

public extension NSFetchRequest {

    @objc
    var sortDescriptor: NSSortDescriptor? {
        set {
            if let newValue = newValue {
                sortDescriptors = [newValue]
            } else {
                sortDescriptors = nil
            }
        }
        get { sortDescriptors?.first }
    }
    
    @objc
    func sort(descriptors: [NSSortDescriptor]) -> Self {
        self.sortDescriptors = descriptors
        return self
    }
    
    @objc
    func fetch(predicate: NSPredicate) -> Self {
        self.predicate = predicate
        return self
    }
    
    @objc
    func fetch(limit: Int) -> Self {
        self.fetchLimit = limit
        return self
    }
    
    @objc
    func fetch(batchSize: Int) -> Self {
        self.fetchBatchSize = batchSize
        return self
    }
    
    @objc var relationshipKeyPathsForRefreshing: [String]? {
        get { refreshingValue }
        set { refreshingValue = newValue}
    }
    @objc
    func relationshipKeyPathsFor(refreshing: [String]) -> Self {
        relationshipKeyPathsForRefreshing = refreshing
        return self
    }
}

private var refreshingKey: UInt8 = 0
private extension NSFetchRequest {
    @objc
    var refreshingValue: [String]? {
        get { objc_getAssociatedObject(self, &refreshingKey) as? [String] }
        set { objc_setAssociatedObject(self, &refreshingKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}
