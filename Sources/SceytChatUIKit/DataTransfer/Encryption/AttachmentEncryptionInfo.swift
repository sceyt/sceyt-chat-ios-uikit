//
//  AttachmentEncryptionInfo.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import Security
import SceytChat

/// The `enc` object of an encrypted attachment's metadata. The file and each rendition (the
/// video poster under `video_thumb`) are encrypted by the Chat SDK, each with its own key:
///
/// ```json
/// "enc": { "v": 1, "alg": "tink-aes256-gcm-hkdf-64k+commit-v1",
///          "attachmentId": "t7qA7hJJlA8x9sgMjck7Qg", "key": "<32B b64url>",
///          "renditions": [{ "role": "thumbnail", "attachmentId": "…", "key": "…" }] }
/// ```
///
/// The keys travel inside the message: not end-to-end, anyone who can read the message can
/// decrypt the files. There is no size: the original size follows from the stored object's
/// (`plaintextSize(ciphertextSize:)`), and a truncated object fails authentication.
public struct AttachmentEncryption: Codable, Equatable {

    public static let version = 1
    public static let metadataKey = "enc"

    /// The encryption of one stored object.
    public struct Rendition: Codable, Equatable {
        public static let thumbnailRole = "thumbnail"

        public let role: String
        /// The unique id the object's encryption is bound to.
        public let attachmentId: String
        /// The 32-byte key, base64url without padding.
        public let key: String

        public init(role: String, attachmentId: String, key: String) {
            self.role = role
            self.attachmentId = attachmentId
            self.key = key
        }

        /// The rendition of `info`, e.g. of a prepared upload.
        public init(role: String, info: EncryptedFileInfo) {
            self.init(role: role, attachmentId: info.attachmentId, key: info.key)
        }
    }

    public let algorithm: String
    public let attachmentId: String
    public let key: String
    public let renditions: [Rendition]

    public init(algorithm: String, attachmentId: String, key: String, renditions: [Rendition] = []) {
        self.algorithm = algorithm
        self.attachmentId = attachmentId
        self.key = key
        self.renditions = renditions
    }

    /// The encryption of an uploaded file, and the renditions sent with it.
    public init(info: EncryptedFileInfo, renditions: [Rendition] = []) {
        self.init(algorithm: info.algorithm, attachmentId: info.attachmentId, key: info.key, renditions: renditions)
    }

    public var thumbnail: Rendition? {
        renditions.first { $0.role == Rendition.thumbnailRole }
    }

    /// The encryption of the file itself.
    public var fileInfo: EncryptedFileInfo {
        EncryptedFileInfo(algorithm: algorithm, attachmentId: attachmentId, key: key)
    }

    /// The encryption of `rendition`: its own id and key, the root algorithm.
    public func info(of rendition: Rendition) -> EncryptedFileInfo {
        EncryptedFileInfo(algorithm: algorithm, attachmentId: rendition.attachmentId, key: rendition.key)
    }

    /// What the SDK needs to decrypt the file, for a stored object of `ciphertextSize` bytes.
    func fileEncryptionInfo(ciphertextSize: UInt64) throws -> FileEncryptionInfo {
        guard let plainSize = Self.plaintextSize(ciphertextSize: ciphertextSize) else {
            throw AttachmentEncryptionError.invalidCiphertextSize(ciphertextSize)
        }
        return ChatSDKFileEncryption.sdkInfo(fileInfo, plaintextSize: plainSize)
    }

    /// Fills its buffer with random bytes. A test seam: `SecRandomCopyBytes` in production.
    static var randomBytes: (inout [UInt8]) -> OSStatus = { bytes in
        SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    }

    /// A new random attachment id: 16 bytes, base64url without padding.
    public static func newAttachmentId() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        let status = randomBytes(&bytes)
        if status != errSecSuccess {
            logger.warn("[Encryption] \(TransferLog.currentTag) SecRandomCopyBytes failed (\(status)), the SDK makes the attachment id")
            return StreamingAeadFileEncryptionProvider.newUniqueId()
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: Sizes

    // The layout of `StreamingAeadFileEncryptionProvider.format` (the native
    // `AesGcmHkdfStreaming`): a 32-byte key commitment, Tink's 40-byte header, then 64 KiB
    // segments that each end in a 16-byte tag. The SDK doesn't export the size function.
    private static let segmentSize: UInt64 = 64 * 1024
    private static let tagSize: UInt64 = 16
    private static let headerSize: UInt64 = 40
    private static let commitmentSize: UInt64 = 32

    /// The stored size of a file of `plaintextSize` bytes.
    static func ciphertextSize(plaintextSize: UInt64) -> UInt64 {
        let firstPlaintext = segmentSize - tagSize - headerSize
        let plaintext = segmentSize - tagSize
        var segments: UInt64 = 1
        if plaintextSize > firstPlaintext {
            segments += (plaintextSize - firstPlaintext + plaintext - 1) / plaintext
        }
        return commitmentSize + headerSize + plaintextSize + segments * tagSize
    }

    /// The original size of a stored object of `ciphertextSize` bytes, or nil if no file
    /// encrypts to that size.
    static func plaintextSize(ciphertextSize: UInt64) -> UInt64? {
        guard ciphertextSize >= commitmentSize + headerSize + tagSize else { return nil }
        let tinkSize = ciphertextSize - commitmentSize
        let segments = (tinkSize + segmentSize - 1) / segmentSize
        let overhead = headerSize + segments * tagSize
        guard overhead <= tinkSize else { return nil }
        let plaintextSize = tinkSize - overhead
        return self.ciphertextSize(plaintextSize: plaintextSize) == ciphertextSize ? plaintextSize : nil
    }

    // MARK: Codable

    enum CodingKeys: String, CodingKey {
        case version = "v"
        case algorithm = "alg"
        case attachmentId
        case key
        case renditions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)
        guard version == Self.version else {
            throw DecodingError.dataCorruptedError(forKey: .version, in: container, debugDescription: "unsupported enc version \(version)")
        }
        algorithm = try container.decode(String.self, forKey: .algorithm)
        attachmentId = try container.decode(String.self, forKey: .attachmentId)
        key = try container.decode(String.self, forKey: .key)
        renditions = try container.decodeIfPresent([Rendition].self, forKey: .renditions) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.version, forKey: .version)
        try container.encode(algorithm, forKey: .algorithm)
        try container.encode(attachmentId, forKey: .attachmentId)
        try container.encode(key, forKey: .key)
        if !renditions.isEmpty {
            try container.encode(renditions, forKey: .renditions)
        }
    }
}

// MARK: - Attachment metadata

public extension ChatMessage.Attachment {

    /// The `enc` object of this attachment, or nil for a plaintext (legacy) attachment or one
    /// whose `enc` cannot be read (see `isEncrypted`).
    var encryption: AttachmentEncryption? {
        Self.encryption(inMetadata: metadata)
    }

    /// Whether the metadata carries an `enc` object at all, even one this build cannot read.
    /// Such an attachment must never be shown as if it were plaintext.
    var isEncrypted: Bool {
        Self.metadataObject(metadata)?[AttachmentEncryption.metadataKey] != nil
    }

    static func encryption(inMetadata metadata: String?) -> AttachmentEncryption? {
        guard let enc = metadataObject(metadata)?[AttachmentEncryption.metadataKey] else { return nil }
        guard JSONSerialization.isValidJSONObject(enc),
              let data = try? JSONSerialization.data(withJSONObject: enc)
        else {
            // Never the value: it would carry the key.
            logger.debug("[Encryption] \(TransferLog.currentTag) enc is not a JSON object (\(Swift.type(of: enc))), unreadable")
            return nil
        }
        do {
            return try JSONDecoder().decode(AttachmentEncryption.self, from: data)
        } catch {
            // The coding path and kind only, never a value.
            logger.debug("[Encryption] \(TransferLog.currentTag) enc unreadable: \(TransferLog.describe(error))")
            return nil
        }
    }

    /// `metadata` with its `enc` object set to `encryption`; every other key is kept as is.
    /// Throws when `metadata` is not a JSON object, so `enc` is never silently dropped.
    static func metadata(_ metadata: String?, settingEncryption encryption: AttachmentEncryption) throws -> String {
        var object: [String: Any] = [:]
        if let metadata, !metadata.isEmpty {
            guard let existing = metadataObject(metadata) else {
                // The caller fails the upload with metadataFailed and reports it.
                logger.debug("[Encryption] \(TransferLog.currentTag) cannot add enc: the attachment metadata (\(metadata.count) chars) is not a JSON object")
                throw AttachmentEncryptionError.metadataNotAnObject
            }
            object = existing
        }
        object[AttachmentEncryption.metadataKey] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(encryption))
        let data = try MetadataJSON.serialize(object)
        guard let string = MetadataJSON.string(data) else {
            throw AttachmentEncryptionError.metadataNotAnObject
        }
        return string
    }

    /// `newMetadata` with the `enc` object of `oldMetadata` carried over. The typed
    /// `Metadata` model only knows the media keys, so any code that rebuilds metadata from
    /// it (dimensions after a resize, the video poster) would otherwise drop the keys.
    static func metadata(_ newMetadata: String?, preservingEncryptionFrom oldMetadata: String?) -> String? {
        let field = AttachmentEncryption.metadataKey
        guard let encryption = metadataObject(oldMetadata)?[field] else { return newMetadata }
        if let newMetadata, !newMetadata.isEmpty, metadataObject(newMetadata) == nil {
            // Not handled: the rebuilt metadata is replaced by an object holding only `enc`.
            logger.warn("[Encryption] \(TransferLog.currentTag) carrying enc over: the new metadata is not a JSON object, its other keys are dropped")
        }
        var object = metadataObject(newMetadata) ?? [:]
        guard object[field] == nil else { return newMetadata }
        object[field] = encryption
        guard let data = try? MetadataJSON.serialize(object),
              let string = MetadataJSON.string(data)
        else {
            // Not handled: the file's key is lost from the metadata.
            logger.error("[Encryption] \(TransferLog.currentTag) enc could not be carried over to the rebuilt metadata: it is dropped")
            return newMetadata
        }
        return string
    }

    private static func metadataObject(_ metadata: String?) -> [String: Any]? {
        guard let data = metadata?.data(using: .utf8), !data.isEmpty else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

/// How attachment metadata is written back. Test seams: `JSONSerialization` and UTF-8 never
/// fail on an object parsed from JSON, so only a test can make them.
enum MetadataJSON {
    static var serialize: (Any) throws -> Data = { try JSONSerialization.data(withJSONObject: $0) }
    static var string: (Data) -> String? = { String(data: $0, encoding: .utf8) }
}
