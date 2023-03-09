//
//  UserSendMessage.swift
//  SceytChatUIKit
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
    open var attachments: [AttachmentView]?
    open var type = ChannelVM.MessageType.text
    
    open var linkAttachments: [AttachmentView] {
        Self.createLinkAttachmentsFrom(text: text)
    }
    
    public required init(sendText: NSAttributedString,
                         attachments: [AttachmentView]? = nil)
    {
        self.attachments = attachments
        text = sendText.string
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let nsString = text as NSString
        var users = [(id: UserId, displayName: String)]()
        var ranges = [UserId: MentionUserPos]()
        sendText
            .enumerateAttribute(.customKey,
                                in: NSRange(location: 0, length: sendText.length)) { obj, range, _ in
                if let id = obj as? UserId {
                    var displayName = nsString.substring(with: range)
                    if displayName.hasPrefix(Config.mentionSymbol) {
                        displayName.removeFirst()
                    }
                    users.append((id, displayName))
                    ranges[id] = .init(loc: range.location, len: range.length)
                }
            }
        if !ranges.isEmpty {
            if let json = try? JSONEncoder().encode(ranges),
               let jsonString = String(data: json, encoding: .utf8) {
                metadata = jsonString
                mentionUsers = users
            }
        }
    }
    
    open class func createLinkAttachmentsFrom(text: String) -> [AttachmentView] {
        LinkDetector.getLinks(text: text)
            .map { url in
                AttachmentView(link: url)
            }
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

public struct AttachmentView {
    public let url: URL
    public var resizedFileUrl: URL?
    public let thumbnail: UIImage
    public let name: String
    public var isLocalFile: Bool
    public var type: AttachmentType
    
    public var photoAsset: PHAsset? {
        didSet {
            if let photoAsset {
                imageWidth = photoAsset.pixelWidth
                imageHeight = photoAsset.pixelHeight
            }
        }
    }
    
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
        if url.isFileURL {
            builder = Attachment
                .Builder(filePath: url.path,
                         type: type.rawValue)
                .fileSize(fileSize)
        } else {
            builder = Attachment
                .Builder(url: url.absoluteString,
                         type: type.rawValue)
        }
        builder.name(name)
        if type == .image || type == .video {
            let tm = try? Components
                .imageBuilder.init(image: thumbnail)
                .resize(max: 10)
                .jpegBase64()
            
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
        }
        return builder
    }
    
    public var attachment: Attachment {
        attachmentBuilder
            .build()
    }
    
    public init(mediaUrl: URL, thumbnail: UIImage?, imageSize: CGSize? = nil, duration: Int? = nil) {
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
                self.thumbnail = Appearance.Images.file
            }
        }
        
        if needsCalculateVideoDuration {
            self.duration = Int(AVURLAsset(url: mediaUrl).duration.seconds)
        }
        
        isLocalFile = url.isFileURL
        type = AttachmentType(url: url)
        fileSize = Storage.sizeOfItem(at: url)
    }
    
    public init(fileUrl: URL) {
        url = fileUrl
        name = url.lastPathComponent
        isLocalFile = true
        type = .file
        thumbnail = Appearance.Images.file
        fileSize = Storage.sizeOfItem(at: url)
    }
    
    public init(voiceUrl: URL, metadata: ChatMessage.Attachment.Metadata<[Int]>) {
        url = voiceUrl
        name = url.lastPathComponent
        isLocalFile = true
        type = .voice
        thumbnail = Appearance.Images.file
        duration = metadata.duration
        thumb = metadata.thumbnail
        fileSize = Storage.sizeOfItem(at: url)
    }
    
    public init(link: URL) {
        url = link
        name = link.host ?? ""
        isLocalFile = false
        type = .link
        thumbnail = Appearance.Images.link
    }
    
    static func view(from asset: PHAsset, completion: @escaping (AttachmentView?) -> Void) {
        if asset.mediaType == .image {
            let options: PHContentEditingInputRequestOptions = .init()
            options.isNetworkAccessAllowed = true
            options.canHandleAdjustmentData = { (_: PHAdjustmentData) -> Bool in
                true
            }
            options.progressHandler = { pct, _ in
                print("asset progress", pct, asset.localIdentifier)
            }
            asset
                .requestContentEditingInput(
                    with: options,
                    completionHandler: { contentEditingInput, _ in
                        if let value = contentEditingInput, let fullSizeImageURL = value.fullSizeImageURL {
                            var imageUrl: URL?
                            if let jpeg = Components.imageBuilder.init(imageUrl: fullSizeImageURL)?.jpegData() {
                                let fileName = fullSizeImageURL
                                    .deletingPathExtension()
                                    .appendingPathExtension("jpg")
                                    .lastPathComponent
                                imageUrl = Storage.storeData(jpeg, filename: fileName)
                            }
                            if imageUrl == nil {
                                imageUrl = Storage.copyFile(fullSizeImageURL) ?? fullSizeImageURL
                            }
                            
                            var v = AttachmentView(
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
            let options: PHVideoRequestOptions = .init()
            options.isNetworkAccessAllowed = true
            options.version = .current
            options.deliveryMode = .mediumQualityFormat
            PHImageManager.default()
                .requestAVAsset(
                    forVideo: asset,
                    options: options,
                    resultHandler: { avAsset, _, _ in
                        if let urlAsset = avAsset as? AVURLAsset {
                            let videoAssetUrl = urlAsset.url
                            let videoUrl = Storage.copyFile(videoAssetUrl) ?? videoAssetUrl
                            var v = AttachmentView(
                                mediaUrl: videoUrl,
                                thumbnail: Components.videoProcessor.copyFrame(asset: avAsset!),
                                duration: Int(asset.duration)
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
        } else {
            completion(nil)
        }
    }
    
    public static func items(attachments: [ChatMessage.Attachment]) -> [AttachmentView] {
        attachments
            .compactMap { $0.originUrl }
            .compactMap { Storage.fileUrl(for: $0) }
            .compactMap { AttachmentView(mediaUrl: $0, thumbnail: nil) }
    }
}

public struct MentionUserPos: Codable {
    public var loc: Int
    public var len: Int
    
    public init(loc: Int, len: Int) {
        self.loc = loc
        self.len = len
    }
}
