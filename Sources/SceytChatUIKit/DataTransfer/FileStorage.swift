//
//  FileStorage.swift
//  LiveChat
//
//  Created by Hovsep Keropyan on 01.09.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import CryptoKit

/// Safe to share: it holds no state of its own, only paths derived from constants.
open class FileStorage: Storage, @unchecked Sendable {
    nonisolated(unsafe) public static let `default` = FileStorage()
    
    var fileManager: FileManager { FileManager.default }
    
    nonisolated(unsafe) public static var documentDirectory: URL? = {
        if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            return URL(fileURLWithPath: path)
        }
        return nil
    }()
    
    // Backed by `static let` (initialized once, thread-safe via swift_once): these
    // are read from background queues (e.g. concurrent thumbnail loads), and the
    // former `lazy var` initialization was not thread-safe — racing first reads
    // double-released the backing String and corrupted the heap.
    private static let resolvedStoragePath = makeStoragePath()
    private static let resolvedThumbnailPath = makeThumbnailPath(storagePath: resolvedStoragePath)

    open var storagePath: String { Self.resolvedStoragePath }
    open var thumbnailPath: String { Self.resolvedThumbnailPath }

    private static func makeStoragePath() -> String {
        let fileManager = FileManager.default
        let tmp = NSTemporaryDirectory()
        guard let documentDirectory = Self.documentDirectory
        else { return tmp }
        let cachePath = documentDirectory.appendingPathComponent("app_files").path
        if fileManager.fileExists(atPath: cachePath) {
            return cachePath
        }
        do {
            try fileManager.createDirectory(atPath: cachePath, withIntermediateDirectories: false, attributes: nil)
            return cachePath
        } catch {
            // Files kept in the temporary directory can be purged by the system.
            logger.error("[Transfer] storage folder app_files could not be created, using the temporary directory: \(TransferLog.describe(error))")
            return tmp
        }
    }

    private static func makeThumbnailPath(storagePath: String) -> String {
        let fileManager = FileManager.default
        let path = URL(fileURLWithPath: storagePath).appendingPathComponent("thumbnails").path
        if fileManager.fileExists(atPath: path) {
            return path
        }
        do {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
        } catch {
            // Every thumbnail write below it fails until a later call creates it.
            logger.error("[Transfer] thumbnail folder could not be created: \(TransferLog.describe(error))")
        }
        return path
    }

    open func store(transferId: String, fileName: String?, file path: String) -> String {
        var newPath = filePath(transferId: transferId)
        if let fileName {
            do {
                try fileManager.createDirectory(at: URL(fileURLWithPath: newPath), withIntermediateDirectories: true, attributes: nil)
                newPath = (newPath as NSString).appendingPathComponent(fileName)
            } catch {
                Self.logFailure("store: folder for \(fileName)", error)
            }
        }
        do {
            guard path != newPath
            else { return path }
            if fileManager.isDeletableFile(atPath: path) {
                try fileManager.moveItem(atPath: path, toPath: newPath)
            } else {
                try fileManager.copyItem(atPath: path, toPath: newPath)
            }
        } catch {
            if (error as NSError).code == NSFileWriteFileExistsError {
                logger.debug("[Transfer] \(TransferLog.currentTag) store: \(newPath.lastPathComponentOfPath) already stored, kept")
                return newPath
            }
            // The source path comes back: callers check for it (`TransportDataSession.adopt`).
            Self.logFailure("store: move of \(path.lastPathComponentOfPath)", error)
            return path
        }
        return newPath
    }
    
    open func path(transferId: String, fileName: String?) -> String? {
        var path = filePath(transferId: transferId)
        if let fileName {
            path = (path as NSString).appendingPathComponent(fileName)
        }
        if fileManager.fileExists(atPath: path) {
            return path
        }
        return nil
    }
    
    open func createPath(transferId: String, fileName: String?) -> String {
        var path = filePath(transferId: transferId)
        if let fileName {
            do {
                try fileManager.createDirectory(at: URL(fileURLWithPath: path), withIntermediateDirectories: true, attributes: nil)
                path = (path as NSString).appendingPathComponent(fileName)
                if fileManager.fileExists(atPath: path) {
                    try fileManager.removeItem(atPath: path)
                }
            } catch {
                Self.logFailure("createPath: \(fileName)", error)
            }
        }
        return path
    }
    
    open func thumbnailPath(filePath: String, imageSize: CGSize) -> String {
        var tmPath = filePath
        if filePath.hasPrefix(storagePath) {
            tmPath = String(filePath.dropFirst(storagePath.count))
            if tmPath.hasPrefix("/") {
                tmPath = String(tmPath.dropFirst(1))
            }
        }
        let folder = "\(Int(imageSize.width))x\(Int(imageSize.height))"
        let tmUrl = URL(fileURLWithPath: thumbnailPath).appendingPathComponent(folder).appendingPathComponent(tmPath)
        do {
            try fileManager.createDirectory(at: tmUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        } catch {
            Self.logFailure("thumbnail folder \(folder)", error)
        }
        return tmUrl.path
    }
    
    open func updateThumbnailPath(transferId: String, filePath: String) {
        var tmPath = filePath
        if filePath.hasPrefix(storagePath) {
            tmPath = String(filePath.dropFirst(storagePath.count))
            if tmPath.hasPrefix("/") {
                tmPath = String(tmPath.dropFirst(1))
            }
        }
        let sizes: [String]
        do {
            sizes = try fileManager.contentsOfDirectory(atPath: thumbnailPath)
        } catch {
            Self.logFailure("updateThumbnailPath: listing thumbnails", error)
            return
        }
        sizes
            .forEach { path in
                var isDir: ObjCBool = false
                let subDir = URL(fileURLWithPath: thumbnailPath).appendingPathComponent(path)
                guard fileManager.fileExists(atPath: subDir.path, isDirectory: &isDir), isDir.boolValue
                else { return }
                let tmpUrl = URL(fileURLWithPath: thumbnailPath)
                    .appendingPathComponent(path)
                    .appendingPathComponent(tmPath)
                if fileManager.fileExists(atPath: tmpUrl.path) {
                    let newTmpUrl = URL(fileURLWithPath: thumbnailPath)
                        .appendingPathComponent(path)
                        .appendingPathComponent(transferId)
                        .appendingPathComponent(tmPath)
                    do {
                        try fileManager.createDirectory(at: newTmpUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                        try fileManager.copyItem(at: tmpUrl, to: newTmpUrl)
                        try fileManager.removeItem(at: tmpUrl)
                    } catch {
                        Self.logFailure("updateThumbnailPath: moving the \(path) thumbnail", error)
                    }
                }
            }
    }
    
    /// Cache location for a downloaded "video_thumb" poster image, keyed by the
    /// opaque origin from the attachment metadata (hashed — origins may be URLs
    /// containing path separators). Creates the cache directory on demand.
    open func videoThumbnailCachePath(origin: String) -> String {
        let dir = URL(fileURLWithPath: storagePath).appendingPathComponent("video_thumbs")
        if !fileManager.fileExists(atPath: dir.path) {
            do {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                // The poster's store then fails and is logged by its caller with this reason.
                Self.logFailure("video_thumbs folder", error)
            }
        }
        let digest = SHA256.hash(data: Data(origin.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return dir.appendingPathComponent(name).appendingPathExtension("jpg").path
    }

    open func remove(path: String) {
        do {
            try fileManager.removeItem(atPath: path)
        } catch where TransferLog.isNotFound(error) {
            // Already gone: nothing to remove.
        } catch {
            Self.logFailure("remove \(path.lastPathComponentOfPath)", error, level: .debug)
        }
    }

    /// One line per storage failure, with the transfer it belongs to.
    static func logFailure(_ action: String, _ error: Error, level: SceytChatUIKit.Logger.LogLevel = .error) {
        let line = "[Transfer] \(TransferLog.currentTag) storage \(action) failed: \(TransferLog.describe(error))"
        if level == .debug {
            logger.debug(line)
        } else {
            logger.error(line)
        }
    }
    
    open func filePath(transferId: String) -> String {
        (storagePath as NSString).appendingPathComponent(transferId)
    }
    
    open func isFilePath(_ path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }
}

private extension String {
    var lastPathComponentOfPath: String { (self as NSString).lastPathComponent }
}

// MARK: - AttachmentFileStore

extension FileStorage: AttachmentFileStore {
    public func store(fileAt path: String, transferId: String, fileName: String?) -> String {
        store(transferId: transferId, fileName: fileName, file: path)
    }

    public func remove(fileAt path: String) {
        remove(path: path)
    }

    public func downloadDestination(transferId: String, fileName: String?) -> URL {
        URL(fileURLWithPath: createPath(transferId: transferId, fileName: fileName))
    }
}
