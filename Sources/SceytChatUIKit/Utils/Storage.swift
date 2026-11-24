//
//  Storage.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

public protocol StoringKey: AnyObject {

    func storingFilename(url: URL) -> String

    func storingPath(url: URL) -> String
    
    func removeStorageFolder()
    
    var storageFolderPath: String { get }
}

public extension StoringKey {

    func storingFileFullUrl(url: URL) -> URL {
        URL(fileURLWithPath: storingPath(url: url)).appendingPathComponent(storingFilename(url: url))
    }

    func storingFileFullUrl(filename: String) -> URL {
        URL(fileURLWithPath: storingPath(url: URL(fileURLWithPath: filename))).appendingPathComponent(filename)
    }
}

open class Storage: NSObject {

    public static var calculateChecksumMaxBytes = 3_000_000
    
    public static var storingKey: StoringKey = SceytChatStoringKey()

    open class func fileUrl(for originalUrl: URL) -> URL? {
        if FileManager.default.fileExists(atPath: originalUrl.path) {
            return originalUrl
        }
        let fileUrl = storingKey.storingFileFullUrl(url: originalUrl)
        if FileManager.default.fileExists(atPath: fileUrl.path) {
            return fileUrl
        }
        return nil
    }

    open class func filePath(for originalUrl: URL) -> String? {
        fileUrl(for: originalUrl)?.path
    }
    
    open class func filePath(for originalUrl: String) -> String? {
        guard let url = URL(string: originalUrl)
        else { return nil }
        return fileUrl(for: url)?.path
    }

    open class func filePath(filename: String) -> String? {
        let fileUrl = storingKey.storingFileFullUrl(filename: filename)
        return FileManager.default.fileExists(atPath: fileUrl.path) ? fileUrl.path : nil
    }
    
    open class func fileUrl(for attachment: ChatMessage.Attachment) -> URL? {
        if let path = filePath(for: attachment) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
    
    open class func filePath(for attachment: ChatMessage.Attachment) -> String? {
        if let filePath = attachment.filePath {
            return filePath
        }
        guard let originalUrl = attachment.url,
              let url = URL(string: originalUrl)
        else { return nil }
        return fileUrl(for: url)?.path
    }
    
    open class func createFilePath(filename: String) -> String {
        let fileUrl = storingKey.storingFileFullUrl(filename: filename)
        return fileUrl.path
    }

    @discardableResult
    open class func storeFile(originalUrl: URL, file srcUrl: URL, deleteFromSrc: Bool = false) -> URL? {
        let fileUrl = storingKey.storingFileFullUrl(url: originalUrl)
        guard srcUrl != fileUrl
        else { return fileUrl }
        do {
            try? FileManager.default.removeItem(at: fileUrl)
            try? FileManager.default.createDirectory(at: fileUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            if deleteFromSrc, FileManager.default.isDeletableFile(atPath: srcUrl.path) {
                try FileManager.default.moveItem(at: srcUrl, to: fileUrl)
            } else {
                try FileManager.default.copyItem(at: srcUrl, to: fileUrl)
            }
            return fileUrl
        } catch {
            logger.errorIfNotNil(error, "")
        }
        return nil
    }

    @discardableResult
    open class func storeData(_ data: Data, filename: String) -> URL? {
        let fileUrl = storingKey.storingFileFullUrl(filename: filename)
        return storeData(data, filePath: fileUrl.path)
    }
    
    @discardableResult
    open class func storeData(_ data: Data, filePath: String) -> URL? {
        let fileUrl = URL(fileURLWithPath: filePath)
        do {
            try? FileManager.default.removeItem(at: fileUrl)
            try? FileManager.default.createDirectory(at: fileUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try data.write(to: fileUrl)
            return fileUrl
        } catch {
            logger.errorIfNotNil(error, "")
        }
        return nil
    }
    
    @discardableResult
    open class func storeInTemporaryDirectory(data: Data, filename: String = UUID().uuidString, ext: String? = nil) -> URL? {
        do {
            var fileUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
            if let ext = ext {
                fileUrl.appendPathExtension(ext)
            }
            try? FileManager.default.removeItem(at: fileUrl)
            try data.write(to: fileUrl)
            return fileUrl
        } catch {
            logger.errorIfNotNil(error, "")
        }
        return nil
    }
    
    @discardableResult
    open class func removeFile(filename: String) -> URL?  {
        let fileUrl = storingKey.storingFileFullUrl(filename: filename)
        do {
            try FileManager.default.removeItem(at: fileUrl)
            return fileUrl
        } catch {
            logger.errorIfNotNil(error, "")
        }
        return nil
    }
    
    @discardableResult
    open class func removeFile(originalUrl: URL) -> URL?  {
        let fileUrl = storingKey.storingFileFullUrl(url: originalUrl)
        do {
            try FileManager.default.removeItem(at: fileUrl)
            return fileUrl
        } catch {
            logger.errorIfNotNil(error, "")
        }
        return nil
    }
    
    @discardableResult
    open class func copyFile(_ url: URL, filename: String? = nil, overwrite: Bool = false) -> URL? {
        let name = filename ?? url.lastPathComponent
        var fileUrl = storingKey.storingFileFullUrl(filename: name)
        guard url != fileUrl
        else { return fileUrl }
        do {
            if overwrite {
                try? FileManager.default.removeItem(at: fileUrl)
            } else {
                let ext = (name as NSString).pathExtension
                let fname = (name as NSString).deletingPathExtension
                var index = 2
                while FileManager.default.fileExists(atPath: fileUrl.path) {
                    let newFileName = fname + "-\(index)." + ext
                    fileUrl = storingKey.storingFileFullUrl(filename: newFileName)
                    index += 1
                }
            }
            
            try? FileManager.default.createDirectory(at: fileUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.copyItem(at: url, to: fileUrl)
            return fileUrl
        } catch {
            logger.errorIfNotNil(error, "")
        }
        return nil
    }
    
    /// Copies the zipped item out of the coordinator's temporary location. A test seam:
    /// `FileManager.copyItem` in production.
    static var copyZippedItem: (URL, URL) throws -> Void = { try FileManager.default.copyItem(at: $0, to: $1) }

    open class func makeUploadingUrl(directoryUrl: URL, completion:(URL?, Error?) -> Void) {
        let coordinator = NSFileCoordinator()
        var error: NSError?
        var accessed = false
        coordinator.coordinate(
            readingItemAt: directoryUrl,
            options: [.forUploading],
            error: &error) { zipUrl in
            accessed = true
            do {
                let tmpUrl = try FileManager.default.url(
                    for: .itemReplacementDirectory,
                    in: .userDomainMask,
                    appropriateFor: zipUrl,
                    create: true
                ).appendingPathComponent(directoryUrl.lastPathComponent + ".zip", isDirectory: false)
                try copyZippedItem(zipUrl, tmpUrl)
                completion(tmpUrl, nil)
            } catch {
                completion(nil, error)
            }
        }
        // A coordination that fails (the item is gone) never runs the accessor: without this
        // the caller waited forever.
        if !accessed {
            completion(nil, error ?? CocoaError(.fileReadUnknown))
        }
    }
    
    open class func makeUploadingUrl(directoryUrl: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            makeUploadingUrl(directoryUrl: directoryUrl) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error!)
                }
            }
        }
        
    }
    
    open class func readFile(at url: URL, upToCount count: Int = 0, seek toOffset: UInt64 = 0) throws -> Data? {
        let handle = try FileHandle(forReadingFrom: url)
        let data: Data?
        // iOS 15 is the minimum: the pre-13.4 InputStream fallback could never run.
        if count > 0 {
            try handle.seek(toOffset: toOffset)
            data = try handle.read(upToCount: count)
        } else {
            data = try handle.readToEnd()
        }
        try handle.close()
        return data
    }
    
    /// The CRC32 of sampled bytes of the file at `filePath` (all of it up to
    /// `calculateChecksumMaxBytes`, else its start, middle and end). 0 for an empty or
    /// unreadable file, so 0 never identifies a file: dedupe with `dedupeChecksum(filePath:)`.
    open class func checksum(filePath: String) -> Int {
        let fileUrl = URL(fileURLWithPath: filePath)
        return sampledCRC32(fileUrl: fileUrl, fileSize: sizeOfItem(at: fileUrl)).map { Int($0) } ?? 0
    }

    /// Marks a key made by `dedupeChecksum`: older rows hold a bare CRC32 (below 2^32), so they
    /// never match one, and an upload made before it is simply not deduped again.
    static let dedupeChecksumVersionBit: Int64 = 1 << 62

    /// What the checksum table matches a file on: its sampled CRC32 together with its size
    /// (bits 32..61, modulo 2^30), so two files of different sizes never share a key. Nil for an
    /// empty file or one that cannot be read in full: nothing dedupes on it, since every such
    /// file would share one key and a hit would deliver another file's object.
    open class func dedupeChecksum(filePath: String) -> Int64? {
        let fileUrl = URL(fileURLWithPath: filePath)
        let fileSize = sizeOfItem(at: fileUrl)
        guard fileSize > 0, let crc = sampledCRC32(fileUrl: fileUrl, fileSize: fileSize) else { return nil }
        let size = Int64(fileSize & 0x3FFF_FFFF)
        return dedupeChecksumVersionBit | (size << 32) | Int64(crc & 0xFFFF_FFFF)
    }

    /// Nil when the file is empty or any sampled read fails or comes back short.
    private class func sampledCRC32(fileUrl: URL, fileSize: UInt) -> UInt? {
        let upToCount = calculateChecksumMaxBytes
        guard fileSize > 0 else { return nil }
        if fileSize <= upToCount || upToCount <= 3/*byte*/ {
            guard let data = try? Storage.readFile(at: fileUrl), data.count == Int(fileSize) else { return nil }
            return ChecksumAlg.crc32(data: data)
        }
        let part = upToCount / 3
        var buff = Data()
        for offset in [0, UInt64(fileSize) / 2, UInt64(fileSize) - UInt64(part) - 1] {
            guard let data = try? Storage.readFile(at: fileUrl, upToCount: part, seek: offset), data.count == part else { return nil }
            buff.append(data)
        }
        return ChecksumAlg.crc32(data: buff)
    }

    open class func deleteAll() {
        storingKey.removeStorageFolder()
    }
    
    static func subPath(filePath: String) -> String {
        if filePath.hasPrefix(storingKey.storageFolderPath) {
            return String(filePath.dropFirst(storingKey.storageFolderPath.count))
        }
        return filePath
    }
    
    static func fullPath(filePath: String) -> String {
        if !filePath.hasPrefix(storingKey.storageFolderPath),
           !filePath.hasPrefix("/local/") {
            return (storingKey.storageFolderPath as NSString).appendingPathComponent(filePath)
        }
        return filePath
    }
}

extension Storage {
    
    static public func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
    
    static public func fileExists(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
    
    static public func attributesOfItem(at path: String) -> [FileAttributeKey: Any] {
        (try? FileManager.default.attributesOfItem(atPath: path)) ?? [:]
    }
    
    static public func attributesOfItem(at url: URL) -> [FileAttributeKey: Any] {
        attributesOfItem(at: url.path)
    }
    
    static public func sizeOfItem(at path: String) -> UInt {
        (attributesOfItem(at: path)[.size] as? UInt) ?? 0
    }
    
    static public func sizeOfItem(at url: URL) -> UInt {
        sizeOfItem(at: url.path)
    }
}

open class SceytChatStoringKey: StoringKey {

    public static var sceytChatStorageHost: String {
        SceytChatUIKit.shared.chatClient.apiUrl?.host ?? ""
    }

    public static let storageFolder = "SceytChatFiles"

    public required init() {}

    open var storageFolderPath: String = SceytChatUIKit.shared.config.storageConfig.storageDirectory?.path ?? NSTemporaryDirectory()

    open func storingFilename(url: URL) -> String {
        url.encoded
//        let key = url.lastPathComponent
//        guard url.host?.contains(Self.sceytChatStorageHost) == true else { return key }
//        let lastTwo = url.pathComponents.suffix(2)
//        guard lastTwo.count == 2 else { return key }
//        return lastTwo.first! + "_" + lastTwo.last!
    }

    open func storingPath(url: URL) -> String {
        storageFolderPath
    }

    open func removeStorageFolder() {
        do {
            try FileManager.default.removeItem(atPath: storageFolderPath)
        } catch {
            logger.errorIfNotNil(error, "")
        }
    }
}

internal extension URL {
    var encoded: String {
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".:-%").inverted)
        return self.absoluteString.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? ""
    }
}
