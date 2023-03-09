//
//  MessageAttachmentUploadInfo.swift
//  SceytChatUIKit
//  Copyright © 2022 Varmtech LLC. All rights reserved.
//

import SceytChat

public final class MessageAttachmentUploadInfo {

    public typealias AttachmentIndex = Int
    public typealias Key = Int
    public typealias ProgressBlock = ((Key, AttachmentIndex, Double) -> Void)
    public typealias CompletionBlock = ((Key, AttachmentIndex, URL?, Bool) -> Void)

    public static let `default` = MessageAttachmentUploadInfo()

    public final class Item: Hashable {

        public var onProgress: ProgressBlock?
        public var onCompletion: CompletionBlock?
        public let key: Key

        public init(key: Key) {
            self.key = key
        }

        public var hashValue: Int {
            Int(key)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        public static func == (lhs: MessageAttachmentUploadInfo.Item,
                               rhs: MessageAttachmentUploadInfo.Item) -> Bool {
            lhs.key == rhs.key
        }
    }

    private(set) var items = [Item]()

    public func item(key: Key) -> Item? {
        items.first { $0.key == key }
    }

    public func create(key: Key) {
        items.append(Item(key: key))
    }

    public func remove(key: Key) {
        items.removeAll { $0.key == key }
    }

    public func progress(key: Key) -> Item? {
        item(key: key)
    }

    public func set(key: Key, attachment index: AttachmentIndex, progress: Double) {
        print("[ATTACHMENT]", "Key", key, "index", index, "progress", progress, "item", item(key: key) != nil)
        item(key: key)?.onProgress?(key, index, progress)
    }

    public func set(key: Key, attachment index: AttachmentIndex, localFileUrl: URL?, complete: Bool) {
        item(key: key)?.onCompletion?(key, index, localFileUrl, complete)
    }
}
