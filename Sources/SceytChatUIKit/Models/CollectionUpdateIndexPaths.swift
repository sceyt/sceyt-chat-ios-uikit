//
//  CollectionUpdateIndexPaths.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

public struct CollectionUpdateIndexPaths {
   
    public struct ContinuesOptions: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public static let top     = ContinuesOptions(rawValue: 1 << 0)
        public static let middle  = ContinuesOptions(rawValue: 1 << 1)
        public static let bottom  = ContinuesOptions(rawValue: 1 << 2)
        
        public static let all: ContinuesOptions = [.top, middle, bottom]
    }
    
    public var inserts: [IndexPath]
    public var reloads: [IndexPath]
    public var deletes: [IndexPath]
    public var moves: [(from: IndexPath, to: IndexPath)]
    
    public var sectionInserts: IndexSet
    public var sectionReloads: IndexSet
    public var sectionDeletes: IndexSet
    
    public var continuesOptions: ContinuesOptions = []
    
    public var isEmptyItems: Bool {
        inserts.isEmpty && reloads.isEmpty && deletes.isEmpty && moves.isEmpty
    }
    
    public var isEmptySections: Bool {
        sectionInserts.isEmpty && sectionReloads.isEmpty && sectionDeletes.isEmpty
    }
    
    public var isEmpty: Bool {
        isEmptyItems && isEmptySections
    }
    
    public var numberOfIndexPaths: Int {
        inserts.count + reloads.count + deletes.count + moves.count
    }
    
    public var numberOfSections: Int {
        sectionInserts.count + sectionReloads.count + sectionDeletes.count
    }
    
    public init(
        inserts: [IndexPath] = [],
        reloads: [IndexPath] = [],
        deletes: [IndexPath] = [],
        moves: [(from: IndexPath, to: IndexPath)] = [],
        sectionInserts: IndexSet = .init(),
        sectionReloads: IndexSet = .init(),
        sectionDeletes: IndexSet = .init()
    ) {
        self.inserts = inserts
        self.reloads = reloads
        self.deletes = deletes
        self.moves = moves
        self.sectionInserts = sectionInserts
        self.sectionReloads = sectionReloads
        self.sectionDeletes = sectionDeletes
    }
}
