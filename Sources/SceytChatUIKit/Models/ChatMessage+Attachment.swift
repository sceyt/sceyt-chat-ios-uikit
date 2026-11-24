//
//  ChatMessage+Attachment.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 18.07.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import CoreData
import UIKit.UIImage

extension ChatMessage {
    
    public class Attachment {
        /// The type of a video's poster image sent as its own attachment (`pvw` names
        /// its url). Never shown as an item: `ChatMessage.previewAttachments`.
        public static let previewType = "preview"

        /// A video's poster image, not an item of the message.
        public var isVideoPreview: Bool { type == Self.previewType }

        public let id: AttachmentId
        public let tid: Int64
        public let messageId: MessageId
        public let userId: UserId
        public let type: String
        public let createdAt: Date

        /// What a transfer changes. One attachment object is shared by the transfer layer
        /// (writing on its queues) and the UI (reading on main), so every field goes through
        /// `lock`: a read never sees half a write (TSan reported `status` racing this way).
        private struct MutableState {
            var url: String?
            var filePath: String?
            var name: String?
            var metadata: String?
            var uploadedFileSize: UInt
            var status: TransferStatus
            var transferProgress: Double
            var imageDecodedMetadata: Metadata<String>?
            var voiceDecodedMetadata: Metadata<[Int]>?
            var assetFilePath: String?
        }

        private let lock = NSLock()
        private var state: MutableState

        private func read<T>(_ value: (MutableState) -> T) -> T {
            lock.lock(); defer { lock.unlock() }
            return value(state)
        }

        private func write(_ change: (inout MutableState) -> Void) {
            lock.lock(); defer { lock.unlock() }
            change(&state)
        }

        public var url: String? {
            get { read { $0.url } }
            set { write { $0.url = newValue } }
        }
        public var filePath: String? {
            get { read { $0.filePath } }
            set { write { $0.filePath = newValue } }
        }
        public var name: String? {
            get { read { $0.name } }
            set { write { $0.name = newValue } }
        }
        public var metadata: String? {
            get { read { $0.metadata } }
            set { write { $0.metadata = newValue } }
        }
        public var uploadedFileSize: UInt {
            get { read { $0.uploadedFileSize } }
            set { write { $0.uploadedFileSize = newValue } }
        }
        public var status: TransferStatus {
            get { read { $0.status } }
            set { write { $0.status = newValue } }
        }
        public var transferProgress: Double {
            get { read { $0.transferProgress } }
            set { write { $0.transferProgress = newValue } }
        }
        public private(set) var imageDecodedMetadata: Metadata<String>? {
            get { read { $0.imageDecodedMetadata } }
            set { write { $0.imageDecodedMetadata = newValue } }
        }
        public private(set) var voiceDecodedMetadata: Metadata<[Int]>? {
            get { read { $0.voiceDecodedMetadata } }
            set { write { $0.voiceDecodedMetadata = newValue } }
        }
        
        @Lazy public var user: ChatUser?
        
        public var originUrl: URL {
            if let filePath {
                return URL(fileURLWithPath: filePath)
            }
            if let url, let _url = URL(string: url) {
                return _url
            }
            //should not be happen
            return URL(fileURLWithPath: "/")
        }
        
        public var fileUrl: URL? {
            if let filePath = Components.dataSession?.getFilePath(attachment: self) {
                if #available(iOS 16.0, *) {
                    return URL(filePath: filePath)
                } else {
                    return URL(fileURLWithPath: filePath)
                }
            }
            return nil
        }
        
        public var assetFilePath: String? {
            get { read { $0.assetFilePath } }
            set { write { $0.assetFilePath = newValue } }
        }

        /// True while this attachment's bytes have never left the device: it has a local
        /// source file and no remote url yet.
        ///
        /// Only an outgoing attachment can be in this state — anything received carries the
        /// url it was (or will be) downloaded from. It is the discriminator every
        /// "the file is on disk, so the transfer must be over" rule needs: for a download the
        /// local file is the *result*, for an upload it is the *source*, so a `.pending`
        /// upload must not be reconciled to `.done` just because its file exists.
        public var isPendingUpload: Bool {
            (url ?? "").isEmpty && !(filePath ?? "").isEmpty
        }

        /// Replaces the metadata JSON and re-runs the eager decode so
        /// `imageDecodedMetadata`/`voiceDecodedMetadata` stay in sync — they are
        /// otherwise only decoded in `init`.
        public func updateMetadata(_ metadata: String?) {
            // Decoded outside the lock, then stored with the JSON in one step: a reader never
            // sees new JSON next to the old decoded values.
            let isVoice = type == "voice"
            let image = metadata.flatMap { isVoice ? nil : try? Metadata<String>.decode($0) }
            let voice = metadata.flatMap { isVoice ? try? Metadata<[Int]>.decode($0) : nil }
            write {
                $0.metadata = metadata
                guard metadata != nil else { return }
                if isVoice {
                    $0.voiceDecodedMetadata = voice
                } else {
                    $0.imageDecodedMetadata = image
                }
            }
        }
        
        init(
            id: AttachmentId,
            tid: Int64,
            messageId: MessageId,
            userId: UserId,
            url: String?,
            filePath: String?,
            type: String,
            name: String? = nil,
            metadata: String? = nil,
            uploadedFileSize: UInt,
            createdAt: Date,
            status: TransferStatus = .pending,
            transferProgress: Double = 0
        ) {
            self.id = id
            self.tid = tid
            self.messageId = messageId
            self.userId = userId
            self.type = type
            self.createdAt = createdAt
            // Metadata is decoded eagerly, so no thread ever decodes it lazily.
            state = MutableState(
                url: url,
                filePath: filePath,
                name: name,
                metadata: metadata,
                uploadedFileSize: uploadedFileSize,
                status: status,
                transferProgress: transferProgress,
                imageDecodedMetadata: metadata.flatMap { type != "voice" ? try? Metadata<String>.decode($0) : nil },
                voiceDecodedMetadata: metadata.flatMap { type == "voice" ? try? Metadata<[Int]>.decode($0) : nil },
                assetFilePath: nil
            )
            $user = {
                try? DataProvider.database.read {
                     UserDTO.fetch(id: userId, context: $0)?.convert()
                }.get()
            }
        }
        
        public convenience init(dto: AttachmentDTO) {
            self.init(
                id: AttachmentId(dto.id),
                tid: dto.tid,
                messageId: MessageId(dto.message?.id ?? 0),
                userId: dto.userId,
                url: dto.url,
                filePath: dto.fullFilePath,
                type: dto.type,
                name: dto.name,
                metadata: dto.metadata,
                uploadedFileSize: UInt(dto.uploadedFileSize),
                createdAt: dto.createdAt?.bridgeDate ?? .init(),
                status: TransferStatus(rawValue: dto.status) ?? .done,
                transferProgress: dto.transferProgress
            )
        }
        
        public convenience init(attachment: SceytChat.Attachment) {
            self.init(
                id: attachment.id,
                tid: Int64(attachment.tid),
                messageId: attachment.messageId,
                userId: attachment.userId,
                url: attachment.url,
                filePath: attachment.filePath,
                type: attachment.type,
                name: attachment.name,
                metadata: attachment.metadata,
                uploadedFileSize: attachment.size, //MARK: db RENAME
                createdAt: attachment.createdAt
            )
        }
        
        public enum TransferStatus: Int16, Sendable {
            case pending
            case uploading
            case downloading
            case pauseUploading
            case pauseDownloading
            case failedUploading
            case failedDownloading
            case done
        }
        
        public struct Metadata<T: Codable>: Codable {
            
            public var width: Int
            public var height: Int
            public var thumbnail: T
            public var duration: Int
            public var description: String?
            public var thumbnailImage: UIImage?
            public var imageUrl: String?
            public var thumbnailUrl: String?
            public var hideLinkDetails: Bool?
            public var videoThumbnail: String?

            enum CodingKeys: String, CodingKey {
                case width = "szw"
                case height = "szh"
                case thumbnail = "tmb"
                case duration = "dur"
                case description = "dsc"
                case imageUrl = "iur"
                case thumbnailUrl = "tur"
                case hideLinkDetails = "hld"
                case videoThumbnail = "pvw"
            }

            /// The key `videoThumbnail` was stored under before it became `pvw`; still read
            /// so videos sent by older builds keep their poster. Never written.
            private enum LegacyCodingKeys: String, CodingKey {
                case videoThumbnail = "video_thumb"
            }

            public init(
                width: Int = 0,
                height: Int = 0,
                thumbnail: T,
                duration: Int = 0,
                description: String? = nil,
                imageUrl: String? = nil,
                thumbnailUrl: String? = nil,
                hideLinkDetails: Bool? = nil,
                videoThumbnail: String? = nil
            ) {
                self.width = width
                self.height = height
                self.thumbnail = thumbnail
                self.duration = duration
                self.description = description
                self.imageUrl = imageUrl
                self.thumbnailUrl = thumbnailUrl
                self.hideLinkDetails = hideLinkDetails
                self.videoThumbnail = videoThumbnail
            }
            
            func build() -> String? {
                try? jsonString()
            }
            
            static func decode(_ value: String) throws -> Metadata {
                try JSONDecoder()
                    .decode(
                        Metadata.self,
                        from: value.data(using: .utf8) ?? Data()
                    )
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                width = (try? container.decode(Int.self, forKey: CodingKeys.width)) ?? 0
                height = (try? container.decode(Int.self, forKey: CodingKeys.height)) ?? 0
                thumbnail = (try container.decode(T.self, forKey: CodingKeys.thumbnail))
                duration = (try? container.decode(Int.self, forKey: CodingKeys.duration)) ?? 0
                description = (try? container.decode(String.self, forKey: CodingKeys.description))
                imageUrl = (try? container.decode(String.self, forKey: CodingKeys.imageUrl))
                thumbnailUrl = (try? container.decode(String.self, forKey: CodingKeys.thumbnailUrl))
                hideLinkDetails = (try? container.decode(Bool.self, forKey: CodingKeys.hideLinkDetails))
                videoThumbnail = (try? container.decode(String.self, forKey: CodingKeys.videoThumbnail))
                    ?? (try? decoder.container(keyedBy: LegacyCodingKeys.self)
                        .decode(String.self, forKey: .videoThumbnail))
                if let base64 = thumbnail as? String, !base64.isEmpty {
                    thumbnailImage = Components.imageBuilder.image(thumbHash: base64)
                    if thumbnailImage == nil,
                        let thumbnailData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) {
                        thumbnailImage = UIImage(data: thumbnailData)
                    }
                }
            }
        }
    }
}

extension ChatMessage.Attachment: Hashable {

    private var identityKey: AnyHashable {
        if id != 0 { return AnyHashable(id) }
        if tid != 0 { return AnyHashable(tid) }

        if let url {
            return AnyHashable(url)
        }

        // Match your equality logic: lastPathComponent lowercased
        let last = (filePath as? NSString)?
            .lastPathComponent
            .lowercased()

        // Include the same normalized fields you compare in ==
        return AnyHashable([
            (last ?? ""),
            type.lowercased(),
            (name ?? "").lowercased()
        ])
    }
    
    public static func == (lhs: ChatMessage.Attachment, rhs: ChatMessage.Attachment) -> Bool {
        lhs.identityKey == rhs.identityKey
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identityKey)
    }
}

public extension ChatMessage.Attachment {
    
    var builder: Attachment.Builder {
        let b = url != nil ? Attachment.Builder(url: url!, type: type) :
        Attachment.Builder(filePath: filePath ?? "", type: type)
        if let name {
            b.name(name)
        }
        if let metadata {
            b.metadata(metadata)
        }
        if uploadedFileSize > 0 {
            b.size(uploadedFileSize)
        }
        return b
    }
}

extension ChatMessage.Attachment: CustomStringConvertible {
    
    public var description: String {
        " id: \(id), tid: \(tid), url: \(String(describing: url)), type: \(type), name: \(String(describing: name)), filePath: \(String(describing: filePath))"
    }
}

extension Attachment {
    public override var description: String {
        " id: \(id), tid: \(tid), url: \(String(describing: url)), type: \(type), name: \(String(describing: name)), filePath: \(String(describing: filePath))"
    }
}

public extension ChatMessage.Attachment {
    
    struct Checksum {
        public let checksum: Int64
        public let messageTid: Int64
        public let attachmentTid: Int64
        public let data: String?
        
        public init(
            checksum: Int64,
            messageTid: Int64,
            attachmentTid: Int64,
            data: String?) {
            self.checksum = checksum
            self.messageTid = messageTid
            self.attachmentTid = attachmentTid
            self.data = data
        }
        
        public init(dto: ChecksumDTO) {
            self.init(
                    checksum: dto.checksum,
                    messageTid: dto.messageTid,
                    attachmentTid: dto.attachmentTid,
                    data: dto.data)
        }
    }
    
}


public extension ChatMessage.Attachment {
    
    func assetFilePath(handler: @escaping (String?) -> Void) {
        guard let filePath
        else {
            handler(nil)
            return
        }
        if let assetFilePath {
            handler(assetFilePath)
            return
        }
        if type == "video" {
            Components.videoProcessor
            .assetUrl(localIdentifier: filePath) {[weak self] url in
                self?.assetFilePath = url?.path
                handler(url?.path)
            }
        } else {
            self.assetFilePath = filePath
            handler(filePath)
        }
    }

    /// Returns a unique identifier for attachment used for audio player tracking.
    /// Uses tid if available (non-zero), otherwise falls back to messageId.
    var playerId: Int64 {
        tid != 0 ? tid : Int64(messageId)
    }
}

/// Every field a transfer changes is behind the attachment's lock; the rest are constants.
extension ChatMessage.Attachment: @unchecked Sendable {}
