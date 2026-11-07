//
//  SCTSession.swift
//  DemoApp
//
//  Created by Hovsep Keropyan on 09.03.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import ImageIO
import SceytChat
import UIKit

/// The default data session: `TransportDataSession` over the Chat SDK's own transfers
/// (`DefaultFileTransferProvider`), storing files in `FileStorage`.
open class SCTSession: TransportDataSession, @unchecked Sendable {

    public static let `default` = SCTSession()

    public let fileStorage: FileStorage

    public init() {
        fileStorage = .init()
        super.init(provider: DefaultFileTransferProvider())
        fileStore = fileStorage
    }

    public override init(provider: FileTransferProvider) {
        fileStorage = .init()
        super.init(provider: provider)
        fileStore = fileStorage
    }

    /// With its own storage. A test seam.
    init(provider: FileTransferProvider, fileStorage: FileStorage) {
        self.fileStorage = fileStorage
        super.init(provider: provider)
        fileStore = fileStorage
    }

    open override func downloadDestination(for attachment: ChatMessage.Attachment) -> URL? {
        guard let string = attachment.url, let url = URL(string: string) else {
            // The download fails with invalidRequest, reported once by `AttachmentTransfer`.
            logger.debug("[Transfer] \(TransferLog.currentTag) no download destination: url missing or unparsable (\(TransferLog.redact(attachment.url))) \(attachment.transferLogDescription)")
            return nil
        }
        let transferId = url.deletingLastPathComponent().lastPathComponent
        return URL(fileURLWithPath: fileStorage.createPath(transferId: transferId, fileName: attachment.name))
    }

    open override func getFilePath(attachment: ChatMessage.Attachment) -> String? {
        if let filePath = attachment.filePath, FileManager.default.fileExists(atPath: filePath) {
            return filePath
        }
        if fileStorage.isFilePath(attachment.originUrl.path) {
            return attachment.originUrl.path
        }
        if let stringUrl = attachment.url,
           let url = URL(string: stringUrl)
        {
            let transferId = url.deletingLastPathComponent().lastPathComponent
            return fileStorage.path(transferId: transferId, fileName: attachment.name)
        }
        return nil
    }
    
    /// True when `path` holds an image whose data is complete and decodable, checked from the
    /// container's header rather than by decoding the pixels. Catches the truncated/partial
    /// JPEG that a cached thumbnail write could leave behind, at a fraction of the cost.
    static func isCompleteImageFile(at path: String) -> Bool {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, options),
              CGImageSourceGetCount(source) > 0
        else { return false }
        return CGImageSourceGetStatus(source) == .statusComplete
    }

    open override func thumbnailFile(for attachment: ChatMessage.Attachment, preferred size: CGSize) -> String? {
        let scale = DisplayScale.shared.value
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        func makeThumbnail(file path: String, thumbnailPath: String) -> String? {
            var image: UIImage?
            if attachment.kind == .image {
                image = UIImage(contentsOfFile: path)
            } else if attachment.kind == .video {
                image = environment.videoProcessor().copyFrame(url: URL(fileURLWithPath: path))
            } else if attachment.kind == .file {
                let fileURL = URL(fileURLWithPath: path)
                if fileURL.isImage {
                    image = UIImage(contentsOfFile: path)
                } else if fileURL.isVideo {
                    image = environment.videoProcessor().copyFrame(url: fileURL)
                }
            }
            if let image,
               let ib = try? environment.imageBuilder().init(image: image).resize(max: newSize.maxSide),
               let data = ib.jpegData(compressionQuality: environment.imageResizeConfig().compressionQuality)
            {
                // Atomic write: stage to a temp file then atomically replace the destination so a
                // concurrent reader (loadThumbnail / reloadThumbnailFromFile) never observes a
                // partially written JPEG. Several in-flight extractions of the same freshly
                // downloaded video each write a complete file and the last rename wins — this
                // removes the truncated-read `nil` that left the blurry placeholder in place.
                let destination = URL(fileURLWithPath: thumbnailPath)
                do {
                    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: destination, options: .atomic)
                    logger.debug("[Attachment] \(TransferLog.currentTag) thumbnail stored \((thumbnailPath as NSString).lastPathComponent)")
                    return thumbnailPath
                } catch {
                    logger.warn("[Attachment] \(TransferLog.currentTag) thumbnail atomic store failed, writing it directly: \(TransferLog.describe(error))")
                    return Storage.storeData(data, filePath: thumbnailPath)?.path
                }
            }
            return nil
        }

        if let path = getFilePath(attachment: attachment) {
            let thumbnailPath = fileStorage.thumbnailPath(filePath: path, imageSize: newSize)
            if fileStorage.isFilePath(thumbnailPath) {
                // Validate the cached thumbnail actually decodes. A legacy truncated/partial JPEG
                // would otherwise be handed back to every reader forever (and a retry just keeps
                // getting the same undecodable path) — evict it and fall through to regenerate.
                // Header-only via ImageIO: the caller decodes this file itself immediately after,
                // so fully decoding it here just to throw the pixels away doubled the cost of
                // every cached-thumbnail lookup — on the hot path of every file-cell bind.
                if Self.isCompleteImageFile(at: thumbnailPath) {
                    logger.verbose("[Attachment] \(TransferLog.currentTag) thumbnail cached \(attachment.transferLogDescription)")
                    return thumbnailPath
                }
                logger.debug("[Attachment] \(TransferLog.currentTag) cached thumbnail unreadable, regenerating \(attachment.transferLogDescription)")
                TransferLog.remove(URL(fileURLWithPath: thumbnailPath), what: "the unreadable thumbnail", context: "[Attachment] \(TransferLog.currentTag) thumbnail")
            }
            return makeThumbnail(file: path, thumbnailPath: thumbnailPath)
        } else if let path = attachment.filePath {
            let thumbnailPath = fileStorage.thumbnailPath(filePath: path, imageSize: newSize)
            return makeThumbnail(file: path, thumbnailPath: thumbnailPath)
        }
        return nil
    }
}

/// The screen's scale for work off the main thread: `UIScreen` may only be read on main, so it
/// is read there and cached. Until it is read, the largest scale (thumbnails at most a little
/// larger than needed, never blurry).
final class DisplayScale: @unchecked Sendable {
    static let shared = DisplayScale()

    private let lock = NSLock()
    private var _value: CGFloat = 3

    var value: CGFloat {
        lock.lock(); defer { lock.unlock() }
        return _value
    }

    private init() {
        if Thread.isMainThread {
            _value = MainActor.assumeIsolated { UIScreen.main.scale }
        } else {
            DispatchQueue.main.async { [self] in
                let scale = UIScreen.main.scale
                lock.lock(); _value = scale; lock.unlock()
            }
        }
    }
}
