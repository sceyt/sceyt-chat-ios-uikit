//
//  CollectionUpdateIndexPaths.swift
//  SceytChatUIKit
//

import Foundation

public struct CollectionUpdateIndexPaths {
    
    public var inserts: [IndexPath]
    public var reloads: [IndexPath]
    public var deletes: [IndexPath]
    public var moves: [(from: IndexPath, to: IndexPath)]
    
    public var sectionInserts: IndexSet
    public var sectionReloads: IndexSet
    public var sectionDeletes: IndexSet
    
    public var isEmptyItems: Bool {
        inserts.isEmpty && reloads.isEmpty && deletes.isEmpty && moves.isEmpty
    }
    
    public var isEmptySections: Bool {
        sectionInserts.isEmpty && sectionReloads.isEmpty && sectionDeletes.isEmpty
    }
    
    public var isEmpty: Bool {
        isEmptyItems && isEmptySections
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
