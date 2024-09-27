//
//  UserSendMessage.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Photos
import SceytChat
import UIKit

open class UserSendMessage {
    public enum Action {
        case send
        case edit(ChatMessage)
        case reply(ChatMessage)
        case forward(ChatMessage)
    }

    open var action = Action.send
    open var text: String
    open var mentionUsers: [(id: UserId, displayName: String)]?
    open var metadata: String?
    open var bodyAttributes: [ChatMessage.BodyAttribute]?
    open var attachments: [AttachmentModel]?
    open var type = ChannelViewModel.MessageType.text
    open var linkMetadata: LinkMetadata?
    
    open var linkAttachments: [AttachmentModel] {
        Self.createLinkAttachmentsFrom(text: text, linkMetaData: linkMetadata)
    }
    
    public required init(sendText: NSAttributedString,
                         attachments: [AttachmentModel]? = nil,
                         linkMetadata: LinkMetadata? = nil
    ) {
        let sendText = sendText.trimWhitespacesAndNewlines().mutableCopy() as! NSMutableAttributedString
        self.attachments = attachments
        self.linkMetadata = linkMetadata
        
        let nsString = sendText.string as NSString
        var users = [(id: UserId, displayName: String)]()
        var bodyAttributes = [ChatMessage.BodyAttribute]()

        var mentions = [(range: NSRange, mention: String)]()
        sendText.enumerateAttribute(.mention, in: NSRange(location: 0, length: sendText.length)) { obj, range, _ in
            if let id = obj as? UserId {
                var displayName = nsString.substring(with: range)
                if displayName.hasPrefix(SceytChatUIKit.shared.config.mentionTriggerPrefix) {
                    displayName.removeFirst()
                }
                users.append((id, displayName))
                mentions.append((range, SceytChatUIKit.shared.config.mentionTriggerPrefix + String(id)))
            }
        }
        mentions.sorted(by: { $0.range.location > $1.range.location }).forEach {
            sendText.safeReplaceCharacters(in: $0.range, with: $0.mention)
        }
        sendText.enumerateAttribute(.mention, in: NSRange(location: 0, length: sendText.length)) { obj, range, _ in
            if let id = obj as? UserId {
                bodyAttributes.append(.init(offset: range.location, length: range.length, type: .mention, metadata: id))
            }
        }
        if !users.isEmpty {
            mentionUsers = users
        }
        text = sendText.string
        
        sendText.enumerateAttribute(.font, in: NSRange(location: 0, length: sendText.length)) { obj, range, _ in
            guard let font = obj as? UIFont else { return }
            if font.isBold {
                bodyAttributes.append(.init(offset: range.location, length: range.length, type: .bold, metadata: nil))
            }
            if font.isItalic {
                bodyAttributes.append(.init(offset: range.location, length: range.length, type: .italic, metadata: nil))
            }
            if font.isMonospace {
                bodyAttributes.append(.init(offset: range.location, length: range.length, type: .monospace, metadata: nil))
            }
        }
        sendText.enumerateAttribute(.underlineStyle, in: NSRange(location: 0, length: sendText.length)) { obj, range, _ in
            guard
                let value = obj as? Int,
                value == NSUnderlineStyle.single.rawValue
            else { return }
            bodyAttributes.append(.init(offset: range.location, length: range.length, type: .underline, metadata: nil))
        }
        sendText.enumerateAttribute(.strikethroughStyle, in: NSRange(location: 0, length: sendText.length)) { obj, range, _ in
            guard
                let value = obj as? Int,
                value == NSUnderlineStyle.single.rawValue
            else { return }
            bodyAttributes.append(.init(offset: range.location, length: range.length, type: .strikethrough, metadata: nil))
        }
        
        if !bodyAttributes.isEmpty {
            self.bodyAttributes = bodyAttributes
        }
    }
    
    open class func createLinkAttachmentsFrom(text: String, linkMetaData: LinkMetadata?) -> [AttachmentModel] {
        DataDetector.getLinks(text: text)
            .map { url in
                AttachmentModel(link: url, linkMetaData: linkMetaData, hideLinkDetails: linkMetaData == nil)
            }
    }
    
    var isEmptyContent: Bool {
        text.isEmpty && (attachments ?? []).isEmpty && linkAttachments.isEmpty
    }
}

public enum AttachmentType: String {
    case image
    case video
    case voice
    case file
    case link
    
    public init(url: URL) {
        if url.isImage {
            self = .image
        } else if url.isAudio {
            self = .voice
        } else if url.isVideo {
            self = .video
        } else if url.isFileURL {
            self = .file
        } else {
            self = .link
        }
    }
}

public struct AttachmentModel {
    public let url: URL
    public var resizedFileUrl: URL?
    public let thumbnail: UIImage
    public let name: String
    public var isLocalFile: Bool
    public var type: AttachmentType
    
    public var linkMetaData: LinkMetadata?
    public var hideLinkDetails: Bool = false
    
    public var photoAsset: PHAsset? {
        didSet {
            if let photoAsset {
                imageWidth = photoAsset.pixelWidth
                imageHeight = photoAsset.pixelHeight
            }
        }
    }
    
    public var avAssetUrl: URL?
    
    public var imageWidth: Int = 0
    public var imageHeight: Int = 0
    public var duration: Int = 0
    public var thumb: [Int] = []
    public var fileSize: UInt = 0
    
    private var needsToUploadInternally: Bool {
        Components.dataSession == nil && isLocalFile
    }
    
    public var attachmentBuilder: Attachment.Builder {
        let builder: Attachment.Builder
        if url.isFileURL || url.scheme == "local" {
            builder = Attachment
                .Builder(filePath: url.path,
                         type: type.rawValue)

                .size(fileSize)
        } else {
            builder = Attachment
                .Builder(url: url.absoluteString,
                         type: type.rawValue)
        }
        builder.name(name)
        if type == .image || type == .video {
            let tm = Components
                .imageBuilder.init(image: thumbnail)
                .thumbHashBase64()
            
            if let json = ChatMessage.Attachment.Metadata<String>(
                width: imageWidth,
                height: imageHeight,
                thumbnail: tm ?? "",
                duration: duration
            ).build() {
                builder.metadata(json)
            }
        } else if type == .voice {
            let targetCount = 50
            if let json = ChatMessage.Attachment.Metadata<[Int]>(
                thumbnail: thumb
                    .chunked(into: Int(ceil(Float(thumb.count) / Float(targetCount))))
                    .map { $0.reduce(0, +) / Int($0.count) },
                duration: duration
            ).build() {
                builder.metadata(json)
            }
        } else if type == .link {
            builder.name(linkMetaData?.title ?? name)
            var thumbnail = ""
            var width = 0
            var height = 0
            if let image = linkMetaData?.image {
                width = Int(image.size.width)
                height = Int(image.size.height)
                thumbnail = Components
                    .imageBuilder.init(image: image)
                    .thumbHashBase64() ?? ""
            }
            if let json = ChatMessage.Attachment.Metadata<String>(
                width: width,
                height: height,
                thumbnail: thumbnail,
                duration: 0,
                description: linkMetaData?.summary,
                imageUrl: linkMetaData?.imageUrl?.absoluteString,
                thumbnailUrl: linkMetaData?.iconUrl?.absoluteString,
                hideLinkDetails: hideLinkDetails
            ).build() {
                builder.metadata(json)
            }
        }
        return builder
    }
    
    public var attachment: Attachment {
        attachmentBuilder
            .build()
    }
    
    public init(
        mediaUrl: URL,
        thumbnail: UIImage?,
        imageSize: CGSize? = nil,
        duration: Int? = nil
    ) {
        url = mediaUrl
        name = url.lastPathComponent
        let needsCalculateImageSize: Bool
        if let imageSize {
            imageWidth = Int(imageSize.width)
            imageHeight = Int(imageSize.height)
            needsCalculateImageSize = false
        } else {
            needsCalculateImageSize = true
        }
        let needsCalculateVideoDuration: Bool
        if let duration {
            self.duration = duration
            needsCalculateVideoDuration = false
        } else {
            needsCalculateVideoDuration = true
        }
        
        if let thumbnail {
            self.thumbnail = thumbnail
            if needsCalculateImageSize,
               let image = UIImage(contentsOfFile: url.path)
            {
                imageWidth = Int(image.size.width)
                imageHeight = Int(image.size.height)
            }
        } else {
            if url.isImage, let image = UIImage(contentsOfFile: url.path) {
                if needsCalculateImageSize {
                    imageWidth = Int(image.size.width)
                    imageHeight = Int(image.size.height)
                }
                self.thumbnail = image
                type = .image
            } else if url.isVideo, let image = Components.videoProcessor.copyFrame(url: url) {
                if needsCalculateImageSize {
                    imageWidth = Int(image.size.width)
                    imageHeight = Int(image.size.height)
                }
                self.thumbnail = image
                type = .video
            } else {
                self.thumbnail = .messageFile
            }
        }
        
        if needsCalculateVideoDuration {
            self.duration = Int(AVURLAsset(url: mediaUrl).duration.seconds)
        }
        
        isLocalFile = url.isFileURL || url.scheme == "local"
        type = url.scheme == "local" ? .video : AttachmentType(url: url)
        fileSize = Components.storage.sizeOfItem(at: url)
    }
    
    public init(fileUrl: URL) {
        url = fileUrl
        name = url.lastPathComponent
        isLocalFile = true
        type = .file
        thumbnail = .messageFile
        fileSize = Components.storage.sizeOfItem(at: url)
    }
    
    public init(voiceUrl: URL, metadata: ChatMessage.Attachment.Metadata<[Int]>) {
        url = voiceUrl
        name = url.lastPathComponent
        isLocalFile = true
        type = .voice
        thumbnail = .messageFile
        duration = metadata.duration
        thumb = metadata.thumbnail
        fileSize = Components.storage.sizeOfItem(at: url)
    }
    
    public init(link: URL, linkMetaData: LinkMetadata? = nil, hideLinkDetails: Bool = false) {
        url = link
        name = link.host ?? ""
        isLocalFile = false
        type = .link
        thumbnail = Appearance.Images.link
        self.linkMetaData = linkMetaData
        self.hideLinkDetails = hideLinkDetails
    }
    
    static func view(from asset: PHAsset, completion: @escaping (AttachmentModel?) -> Void, progressHandler: ((Float) -> Void)? = nil) {
        if asset.mediaType == .image {
            let options: PHContentEditingInputRequestOptions = .init()
            options.isNetworkAccessAllowed = true
            options.canHandleAdjustmentData = { (_: PHAdjustmentData) -> Bool in
                false
            }
            options.progressHandler = { pct, _ in
                logger.debug("asset progress \(pct) \(asset.localIdentifier)")
            }
            asset
                .requestContentEditingInput(
                    with: options,
                    completionHandler: { contentEditingInput, _ in
                        if let value = contentEditingInput, let fullSizeImageURL = value.fullSizeImageURL {
                            let fileUrl = Components.storage.copyFile(fullSizeImageURL) ?? fullSizeImageURL
                            var imageUrl: URL?
                            if let jpeg = Components.imageBuilder.init(imageUrl: fileUrl)?.jpegData(compressionQuality: SceytChatUIKit.shared.config.imageAttachmentResizeConfig.compressionQuality) {
                                let fileName = fileUrl
                                    .deletingPathExtension()
                                    .appendingPathExtension("jpg")
                                    .lastPathComponent
                                imageUrl = Components.storage.storeData(jpeg, filename: fileName)
                            }
                            if imageUrl == nil {
                                imageUrl = fileUrl
                            }
                            var v = AttachmentModel(
                                mediaUrl: imageUrl ?? fullSizeImageURL,
                                thumbnail: value.displaySizeImage
                            )
                            v.photoAsset = asset
                            DispatchQueue.main.async {
                                completion(v)
                            }
                        } else {
                            DispatchQueue.main.async {
                                completion(nil)
                            }
                        }
                    }
                )
        } else if asset.mediaType == .video {
            logger.verbose("[ATTACHMENT] Creating Attachment view")
            let maxDimen = 848.0
            let targetSize = VideoProcessor.calculateSizeWith(
                maxDimen: maxDimen,
                originalSize: CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
            )
            logger.verbose("[ATTACHMENT] Creating Attachment view targetSize\(targetSize)")
            let imageOptions = PHImageRequestOptions()
            imageOptions.deliveryMode = .highQualityFormat
            imageOptions.resizeMode = .fast
            imageOptions.isSynchronous = true
            imageOptions.isNetworkAccessAllowed = true
            let manager = PHImageManager.default()
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: imageOptions
            ) { image, info in
                logger.verbose("[ATTACHMENT] requestImage received with size \(String(describing: image?.size)), info: \(String(describing: info))")
                if let image {
                    logger.verbose("[ATTACHMENT] requestImage receives requestAVAsset")
                    let viedeoOptions: PHVideoRequestOptions = .init()
                    viedeoOptions.isNetworkAccessAllowed = true
                    viedeoOptions.version = .current
                    viedeoOptions.deliveryMode = .highQualityFormat
                    manager.requestAVAsset(forVideo: asset, options: viedeoOptions) { avAsset, _, _ in
                        logger.verbose("[ATTACHMENT] requestAVAsset receives \(avAsset != nil)")
                        guard let avAsset else { return completion(nil) }
                        
                        var duration = Int(asset.duration)
                        if avAsset.isSlowMotionVideo, let slowMoDuration = (avAsset as? AVComposition)?.slowMoDuration {
                            logger.verbose("[ATTACHMENT] requestAVAsset receives is slowMoDuration \(slowMoDuration)")
                            duration = Int(slowMoDuration)
                        }
                        
                        var v = AttachmentModel(
                            mediaUrl: URL(string: "local:///local/\(asset.localIdentifier)")!,
                            thumbnail: image,
                            imageSize: image.size,
                            duration: duration
                        )
                        v.photoAsset = asset
                        v.avAssetUrl = (avAsset as? AVURLAsset)?.url
                        DispatchQueue.main.async {
                            logger.verbose("[ATTACHMENT] Created Attachment with \(v.name)")
                            completion(v)
                        }
                    }
                } else {
                    logger.verbose("[ATTACHMENT] image size != target size targetSize = \(targetSize), imageSize = \(image?.size)")
                    completion(nil)
                }
            }
        } else {
            completion(nil)
        }
    }
    
    public static func items(attachments: [ChatMessage.Attachment]) -> [AttachmentModel] {
        attachments
            .compactMap { Components.storage.fileUrl(for: $0) }
            .compactMap { AttachmentModel(mediaUrl: $0, thumbnail: nil) }
    }
}

public struct MentionUserPos: Codable {
    public var id: UserId
    public var loc: Int
    public var len: Int
    
    public init(
        userId: UserId,
        loc: Int,
        len: Int
    ) {
        id = userId
        self.loc = loc
        self.len = len
    }
}
