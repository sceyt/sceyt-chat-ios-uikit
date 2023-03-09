//
//  ChannelCollectionViewLayout+Attributes.swift
//  SceytChatUIKit
//

import UIKit

public final class ChannelCollectionViewLayoutAttributes: UICollectionViewLayoutAttributes {
    
    private(set) var id = UUID()
    
    public override func copy(with zone: NSZone? = nil) -> Any {
        guard let copiedAttributes = super.copy(with: zone) as? ChannelCollectionViewLayoutAttributes
        else { return super.copy(with: zone) }
        copiedAttributes.id = id
        return copiedAttributes
    }
    
    public func updateFromDeletedAttributes(_ attributes: ChannelCollectionViewLayoutAttributes) {
        self.id = attributes.id
    }
}

extension ChannelCollectionViewLayout.Attributes {
    
    subscript(_ indexPath: IndexPath) -> ChannelCollectionViewLayoutAttributes {
        guard self.contains(indexPath)
        else {
            fatalError("subscript \(indexPath)")
        }
        return self[indexPath.section][indexPath.row]
    }
}

extension ChannelCollectionViewLayout.Attributes {
    
    var last: ChannelCollectionViewLayoutAttributes? {
        self.last?.last
    }
    
    var first: ChannelCollectionViewLayoutAttributes? {
        self.first?.first
    }
    
    var size: Int {
        self.reduce(0) { partialResult, item in
            partialResult + item.count
        }
    }
    
    mutating func append(_ newElement: ChannelCollectionViewLayoutAttributes) {
        if !self.indices.contains(newElement.indexPath.section) {
            self.insert([], at: newElement.indexPath.section)
        }
        self[newElement.indexPath.section].append(newElement)
    }
    
    mutating func insert(_ newElement: ChannelCollectionViewLayoutAttributes) {
        if self.indices.contains(newElement.indexPath.section) {
            self[newElement.indexPath.section].insert(newElement, at: newElement.indexPath.row)
            for index in newElement.indexPath.row + 1 ..< self[newElement.indexPath.section].count {
                self[newElement.indexPath.section][index].indexPath.row += 1
            }
        } else if count == newElement.indexPath.section {
            self.append([newElement])
        } else {
            fatalError("insert: \(newElement.indexPath)")
        }
    }
    
    mutating func insert(section: Int) {
        insert([], at: section)
        if self.indices.contains(section + 1) {
            for index in section + 1 ..< count {
                for item in self[index] {
                    item.indexPath.section += 1
                }
            }
        }
    }
    
    mutating func remove(at indexPath: IndexPath) -> ChannelCollectionViewLayoutAttributes {
        let attribute = self[indexPath.section].remove(at: indexPath.row)
        for index in indexPath.row ..< self[indexPath.section].count {
            self[indexPath.section][index].indexPath.row -= 1
        }
        return attribute
    }
    
    func contains(_ indexPath: IndexPath) -> Bool {
        guard self.indices.contains(indexPath.section) else { return false }
        return self[indexPath.section].indices.contains(indexPath.row)
    }
    
    func attributes(id: UUID) -> ChannelCollectionViewLayoutAttributes? {
        for section in self {
            if let item = section.first(where: { $0.id == id }) {
                return item
            }
        }
        return nil
    }
    
    func attributes(at indexPath: IndexPath) -> ChannelCollectionViewLayoutAttributes? {
        guard contains(indexPath) else { return nil }
        return self[indexPath.section][indexPath.row]
    }
    
    func attributes(after indexPath: IndexPath) -> ChannelCollectionViewLayoutAttributes? {
        guard self.indices.contains(indexPath.section) else { return nil }
        if indexPath.row + 1 < self[indexPath.section].count {
            return self[indexPath.section][indexPath.row + 1]
        } else if indexPath.section + 1 < self.count {
            for section in indexPath.section + 1 ..< self.count {
                if !self[section].isEmpty {
                    return self[section].first
                }
            }
        }
        return nil
    }
    
    func suffix(section: Int, row: Int) -> [(section: Int, attributes: [ChannelCollectionViewLayoutAttributes])] {
        guard self.indices.contains(section)
        else { return [] }
        
        var items = [(Int, [ChannelCollectionViewLayoutAttributes])]()
        items.append((section, self[section].suffix(from: row).map { $0 }))
        for s in section + 1 ..< self.count {
            items.append((s, self[s]))
        }
        return items
    }
    
    func prefixAttribute(for indexPath: IndexPath) -> ChannelCollectionViewLayoutAttributes? {
        var prev = indexPath
        if prev.row > 0 {
            prev.row -= 1
        } else if prev.section > 0 {
            prev.section -= 1
            if indices.contains(prev.section) {
                prev.row = [prev.section].count
            }
        }
        if contains(prev) {
            return self[prev]
        }
        return nil
    }
}
