//
//  EmojiViewModel.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import Foundation

public struct EmojiViewModel {

    public init() {}

    public let emojis = EmojiViewModel.loadEmojis()

    public func code(at indexPath: IndexPath) -> String? {
        guard emojis.indices.contains(indexPath.section),
              emojis[indexPath.section].items.indices.contains(indexPath.row)
        else { return nil }
        return emojis[indexPath.section].items[indexPath.row].code
    }

    public var numberOfSections: Int {
        emojis.count
    }

    public func numberOfRows(at section: Int) -> Int {
        guard emojis.indices.contains(section) else { return 0 }
        return emojis[section].items.count
    }

    public func groupTitle(at section: Int) -> String? {
        guard emojis.indices.contains(section) else { return nil }
        return emojis[section].group
    }
}

public extension EmojiViewModel {

    struct Emoji {
        public struct Item {
            public let code: String
        }

        public let group: String
        public let items: [Item]
    }
}

fileprivate extension EmojiViewModel {

    private typealias EmojiList = [[String: [[String: [String]]]]]

    class BundleClass: NSObject { }

    static func loadEmojis() -> [Emoji] {
        guard let path = Bundle(for: BundleClass.self).path(forResource: "emojis12", ofType: "plist") else { return [] }
        let url = URL(fileURLWithPath: path)
        do {
            let data = try Data(contentsOf: url)
            guard let plist = try PropertyListSerialization
                    .propertyList(from: data,
                                  options: .mutableContainers,
                                  format: nil)
                    as? EmojiList else { return [] }
            var emojis = [Emoji]()
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
            debugPrint(error)
        }
        return []
    }
}
