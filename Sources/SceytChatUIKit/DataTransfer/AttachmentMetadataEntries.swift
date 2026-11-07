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
    static let ownedMetadataKeys: Set<String> = ["szw", "szh", "tmb", "dur", "dsc", "iur", "tur", "hld", "video_thumb"]

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
