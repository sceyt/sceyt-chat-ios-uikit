//
//  AttachmentMetadataEntries.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//
//  An attachment's metadata is a JSON object. UIKit owns the media keys of the typed
//  `Metadata` model; a `FileTransferProvider` adds its own entries (`prepareUpload`), which
//  UIKit merges in, keeps through every rewrite, and never reads.
//

import Foundation

public enum AttachmentMetadataError: Error {
    /// The attachment's metadata is not a JSON object, so entries cannot be added to it.
    case notAnObject
    /// The provider's entries could not be saved: the upload does not start, since the message
    /// would go out without them.
    case saveFailed(Error)
}

public extension ChatMessage.Attachment {

    /// The keys UIKit writes (the typed `Metadata` model). Every other key belongs to someone
    /// else (a `FileTransferProvider`, the server) and is kept as it is.
    static let ownedMetadataKeys: Set<String> = ["szw", "szh", "tmb", "dur", "dsc", "iur", "tur", "hld", "pvw", "video_thumb"]

    /// The metadata entries that have string values: what a provider's requests carry.
    var stringMetadataEntries: [String: String] {
        Self.stringEntries(inMetadata: metadata)
    }

    static func stringEntries(inMetadata metadata: String?) -> [String: String] {
        guard let object = metadataObject(metadata) else { return [:] }
        return object.compactMapValues { $0 as? String }
    }

    /// `metadata` with `entries` merged in: returned keys are added or overwritten, every other
    /// key is kept. Throws when `metadata` is not a JSON object, so an entry is never silently
    /// dropped.
    static func metadata(_ metadata: String?, merging entries: [String: String]) throws -> String {
        try self.metadata(metadata, merging: entries, json: .live)
    }

    internal static func metadata(_ metadata: String?, merging entries: [String: String], json: MetadataJSON) throws -> String {
        var object: [String: Any] = [:]
        if let metadata, !metadata.isEmpty {
            guard let existing = metadataObject(metadata) else {
                // The caller fails the upload and reports it.
                logger.debug("[Attachment] \(TransferLog.currentTag) cannot merge metadata entries: the metadata (\(metadata.count) chars) is not a JSON object")
                throw AttachmentMetadataError.notAnObject
            }
            object = existing
        }
        for (key, value) in entries {
            object[key] = value
        }
        let data = try json.serialize(object)
        guard let string = json.string(data) else {
            throw AttachmentMetadataError.notAnObject
        }
        return string
    }

    /// `metadata` with each of `keys` put back as `previousMetadata` had it: restored when it
    /// had the key, removed when it did not. Every other key is left as it is now, so a write
    /// that landed after `previousMetadata` was read is kept. Undoes a `metadata(_:merging:)`
    /// whose save failed.
    static func metadata(_ metadata: String?, restoringKeys keys: Set<String>, from previousMetadata: String?) -> String? {
        self.metadata(metadata, restoringKeys: keys, from: previousMetadata, json: .live)
    }

    internal static func metadata(_ metadata: String?, restoringKeys keys: Set<String>, from previousMetadata: String?, json: MetadataJSON) -> String? {
        guard !keys.isEmpty, var object = metadataObject(metadata) else { return metadata }
        let previous = metadataObject(previousMetadata) ?? [:]
        for key in keys {
            object[key] = previous[key]
        }
        if object.isEmpty, previous.isEmpty {
            // Nothing is left that the merge did not add: back to what it was (nil or empty).
            return previousMetadata
        }
        guard let data = try? json.serialize(object),
              let string = json.string(data)
        else {
            // Not expected (the merge serialized the same kind of object): the whole earlier
            // metadata is the closest safe state, since it never held the unsaved entries.
            logger.error("[Attachment] \(TransferLog.currentTag) metadata keys \(keys.sorted()) could not be rolled back key by key: restoring the earlier metadata")
            return previousMetadata
        }
        return string
    }

    /// `newMetadata` with every key of `oldMetadata` that UIKit does not own carried over. The
    /// typed `Metadata` model only knows the media keys, so any code that rebuilds metadata
    /// from it (dimensions after a resize, the video poster) would otherwise drop a provider's
    /// entries, and the recipients could never open the file.
    static func metadata(_ newMetadata: String?, preservingUnownedKeysFrom oldMetadata: String?) -> String? {
        metadata(newMetadata, preservingUnownedKeysFrom: oldMetadata, json: .live)
    }

    internal static func metadata(_ newMetadata: String?, preservingUnownedKeysFrom oldMetadata: String?, json: MetadataJSON) -> String? {
        guard let old = metadataObject(oldMetadata) else { return newMetadata }
        let unowned = old.filter { !ownedMetadataKeys.contains($0.key) }
        guard !unowned.isEmpty else { return newMetadata }
        if let newMetadata, !newMetadata.isEmpty, metadataObject(newMetadata) == nil {
            // Not handled: the rebuilt metadata is replaced by an object of the kept keys.
            logger.warn("[Attachment] \(TransferLog.currentTag) keeping metadata keys: the new metadata is not a JSON object, its own keys are dropped")
        }
        var object = metadataObject(newMetadata) ?? [:]
        var added = false
        for (key, value) in unowned where object[key] == nil {
            object[key] = value
            added = true
        }
        guard added else { return newMetadata }
        guard let data = try? json.serialize(object),
              let string = json.string(data)
        else {
            // Not handled: the provider's entries are lost from the metadata.
            logger.error("[Attachment] \(TransferLog.currentTag) metadata keys \(unowned.keys.sorted()) could not be carried over to the rebuilt metadata: they are dropped")
            return newMetadata
        }
        return string
    }

    /// The metadata of an attachment that reuses an already uploaded object (a checksum hit):
    /// `storedMetadata`, with every key UIKit owns taken from `ownMetadata` where it has one.
    /// The stored object's other keys (the key a provider encrypted it with) must go with the
    /// object, but the media keys describe this attachment: the same file sent earlier as a
    /// plain file has no duration, dimensions or poster, and taking its metadata whole sent
    /// the video as 00:00. A media key this attachment lacks is still taken from the stored one.
    static func metadata(reusing storedMetadata: String?, keepingOwnedKeysFrom ownMetadata: String?) -> String? {
        metadata(reusing: storedMetadata, keepingOwnedKeysFrom: ownMetadata, json: .live)
    }

    internal static func metadata(reusing storedMetadata: String?, keepingOwnedKeysFrom ownMetadata: String?, json: MetadataJSON) -> String? {
        guard let own = metadataObject(ownMetadata)?.filter({ ownedMetadataKeys.contains($0.key) }),
              !own.isEmpty
        else { return storedMetadata }
        if let storedMetadata, !storedMetadata.isEmpty, metadataObject(storedMetadata) == nil {
            // Not handled: the stored metadata is not an object, so only the media keys remain.
            logger.warn("[Attachment] \(TransferLog.currentTag) reused metadata is not a JSON object: only this attachment's media keys are kept")
        }
        var object = metadataObject(storedMetadata) ?? [:]
        object.merge(own) { _, mine in mine }
        guard let data = try? json.serialize(object),
              let string = json.string(data)
        else {
            // Not expected (both are JSON objects): the stored metadata keeps the object readable.
            logger.error("[Attachment] \(TransferLog.currentTag) media keys \(own.keys.sorted()) could not be merged into the reused metadata: it is taken whole")
            return storedMetadata
        }
        return string
    }

    internal static func metadataObject(_ metadata: String?) -> [String: Any]? {
        guard let data = metadata?.data(using: .utf8), !data.isEmpty else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

/// Writes a metadata object as JSON text. Neither step fails for the objects UIKit builds;
/// tests pass failing ones to reach those branches.
struct MetadataJSON: Sendable {
    var serialize: @Sendable (Any) throws -> Data
    var string: @Sendable (Data) -> String?

    static let live = MetadataJSON(
        serialize: { try JSONSerialization.data(withJSONObject: $0) },
        string: { String(data: $0, encoding: .utf8) }
    )
}
