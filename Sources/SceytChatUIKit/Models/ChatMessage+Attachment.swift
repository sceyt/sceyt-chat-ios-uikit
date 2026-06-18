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
        public let id: AttachmentId
        public let tid: Int64
        public let messageId: MessageId
        public let userId: UserId
        public var url: String?
        public var filePath: String?
        public let type: String
        public var name: String?
        public var metadata: String?
        public var uploadedFileSize: UInt
        public let createdAt: Date
        public var status: TransferStatus
        public var transferProgress: Double
        
        public private(set) var imageDecodedMetadata: Metadata<String>?
        public private(set) var voiceDecodedMetadata: Metadata<[Int]>?
        
        @Lazy public var user: ChatUser?
        
        public var originUrl: URL {
            if let filePath {
                logger.verbose("[Attachment] originUrl filePath \(filePath)")
                return URL(fileURLWithPath: filePath)
            }
            if let url, let _url = URL(string: url) {
                logger.verbose("[Attachment] originUrl url \(url)")
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
        
        public var assetFilePath: String?
        
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
            self.url = url
            self.filePath = filePath
            self.type = type
            self.name = name
            self.metadata = metadata
            self.uploadedFileSize = uploadedFileSize
            self.createdAt = createdAt
            self.status = status
            self.transferProgress = transferProgress
            // Decode metadata eagerly so the properties are immutable by the time any
            // thread reads them — lazy var on a class is not thread-safe.
            if let metadata, type != "voice" {
                imageDecodedMetadata = try? Metadata<String>.decode(metadata)
            }
            if let metadata, type == "voice" {
                voiceDecodedMetadata = try? Metadata<[Int]>.decode(metadata)
            }
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
        
        public enum TransferStatus: Int16 {
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
            
            enum CodingKeys: String, CodingKey {
                case width = "szw"
                case height = "szh"
                case thumbnail = "tmb"
                case duration = "dur"
                case description = "dsc"
                case imageUrl = "iur"
                case thumbnailUrl = "tur"
                case hideLinkDetails = "hld"
                
            }
            
            public init(
                width: Int = 0,
                height: Int = 0,
                thumbnail: T,
                duration: Int = 0,
                description: String? = nil,
                imageUrl: String? = nil,
                thumbnailUrl: String? = nil,
                hideLinkDetails: Bool? = nil
            ) {
                self.width = width
                self.height = height
                self.thumbnail = thumbnail
                self.duration = duration
                self.description = description
                self.imageUrl = imageUrl
                self.thumbnailUrl = thumbnailUrl
                self.hideLinkDetails = hideLinkDetails
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
