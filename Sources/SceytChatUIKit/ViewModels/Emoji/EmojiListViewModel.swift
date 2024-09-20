//
//  EmojiListViewModel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import Foundation
import UIKit

open class EmojiListViewModel {

    required public init() {}

    private var emojis: [Emoji] {
        Self.emojis
    }
    
    public static let recentReactionsKey = "recent-reactions"
    public static var recentReactionsLimit = 30
    public static var recentRowLimit = 2

    open func code(at indexPath: IndexPath) -> String? {
        guard emojis.indices.contains(indexPath.section),
              emojis[indexPath.section].items.indices.contains(indexPath.row)
        else { return nil }
        return emojis[indexPath.section].items[indexPath.row].code
    }

    open var numberOfSections: Int {
        emojis.count
    }

    open func numberOfRows(at section: Int) -> Int {
        guard emojis.indices.contains(section) else { return 0 }
        return emojis[section].items.count
    }

    open func groupTitle(at section: Int) -> String? {
        guard emojis.indices.contains(section) else { return nil }
        return emojis[section].group.uppercased()
    }

    open var recentEmojis: Emoji? {
        let decoder = JSONDecoder()
        if let recentEmojisData = SceytChatUIKit.shared.config.storageConfig.userDefaults.data(forKey: Self.recentReactionsKey),
           let recentEmojis = try? decoder.decode(Emoji.self, from: recentEmojisData) {
            return recentEmojis
        }
        return nil
    }

    open var shouldShowRecentSections: Bool {
        return recentEmojis?.items.isEmpty == false
    }

    open func didSelect(at indexPath: IndexPath) {
        guard let code = code(at: indexPath) else {
            return
        }
        let codeItem = Emoji.Item(code: code)
        let recentEmojisToEncode: Emoji
        if var recentEmojis = recentEmojis {
            if let removeIndex = recentEmojis.items.firstIndex(where: { $0.code == code }) {
                recentEmojis.items.remove(at: removeIndex)
            }
            recentEmojis.items.insert(codeItem, at: 0)
            if recentEmojis.items.count > Self.recentReactionsLimit {
                recentEmojis.items = Array(recentEmojis.items.prefix(Self.recentReactionsLimit))
            }
            recentEmojisToEncode = recentEmojis
        } else {
            recentEmojisToEncode = Emoji(group: L10n.Emoji.recent, items: [codeItem])
        }
        let encoder = JSONEncoder()
        if let encodeData = try? encoder.encode(recentEmojisToEncode) {
            SceytChatUIKit.shared.config.storageConfig.userDefaults.setValue(encodeData, forKey: Self.recentReactionsKey)
        }
    }
}

public extension EmojiListViewModel {
    
    static var emojis: [Emoji] = EmojiListViewModel.loadEmojis()
}

public extension EmojiListViewModel {

    static var itemSize: CGSize = .init(width: 32, height: 32)
    static var interItemSpacing: CGFloat = 10
    static var sectionInset: UIEdgeInsets = .init(top: 0, left: 12, bottom: 8, right: 12)

    static var numberOfColumnsInRowVisible: Int {
        var count = 0
        var accumWidth: CGFloat = .zero
        let width = UIScreen.main.bounds.width - sectionInset.left - sectionInset.right
        
        repeat {
            accumWidth += itemSize.width + interItemSpacing
            if accumWidth < width {
                count += 1
            }
        } while accumWidth < width
        
        accumWidth -= interItemSpacing
        if accumWidth <= width {
            count += 1
        }
        return count
    }
    
    struct Emoji: Codable {
        public struct Item: Codable {
            public let code: String
        }

        public let group: String
        public var items: [Item]
    }

}

fileprivate extension EmojiListViewModel {

    private typealias EmojiList = [[String: [[String: [String]]]]]

    class BundleClass: NSObject { }

    static func loadEmojis() -> [Emoji] {
        guard let path = Bundle.kit(for: BundleClass.self).path(forResource: "emojis12", ofType: "plist") else { return [] }
        let url = URL(fileURLWithPath: path)
        do {
            let data = try Data(contentsOf: url)
            guard let plist = try PropertyListSerialization
                    .propertyList(from: data,
                                  options: .mutableContainers,
                                  format: nil)
                    as? EmojiList else { return [] }
            
            var emojis = [Emoji]()
            
            if let recentEmojisData = SceytChatUIKit.shared.config.storageConfig.userDefaults.data(forKey: recentReactionsKey) {
                let decoder = JSONDecoder()
                var recentEmojis = try decoder.decode(Emoji.self, from: recentEmojisData)
                recentEmojis.items = Array(recentEmojis.items.prefix(numberOfColumnsInRowVisible * recentRowLimit))
                emojis.append(recentEmojis)
            }
            
            for item in plist {
                guard let group = item.keys.first, let objs = item[group] else { continue }
                var items = [Emoji.Item]()
                for obj in objs {
                    for key in obj.keys {
                        for code in obj[key]! {
                            items.append(.init(code: code))
                        }
                    }
                }
                emojis.append(Emoji(group: group, items: items))
            }
            return emojis
        } catch {
            logger.errorIfNotNil(error, "")
        }
        return []
    }
}
