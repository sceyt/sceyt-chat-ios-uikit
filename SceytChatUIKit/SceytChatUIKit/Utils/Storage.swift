//
//  Storage.swift
//  SceytChatUIKit
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
    
    open class func filePath(for attachment: ChatMessage.Attachment) -> String? {
        if let filePath = attachment.filePath {
            return filePath
        }
        guard let originalUrl = attachment.url,
              let url = URL(string: originalUrl)
        else { return nil }
        return fileUrl(for: url)?.path
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
            debugPrint(#function, error)
        }
        return nil
    }

    @discardableResult
    open class func storeData(_ data: Data, filename: String) -> URL? {
        let fileUrl = storingKey.storingFileFullUrl(filename: filename)
        do {
            try? FileManager.default.removeItem(at: fileUrl)
            try? FileManager.default.createDirectory(at: fileUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try data.write(to: fileUrl)
            return fileUrl
        } catch {
            debugPrint(#function, error)
        }
        return nil
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
            debugPrint(#function, error)
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
            debugPrint(#function, error)
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
            debugPrint(#function, error)
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
            debugPrint(#function, error)
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
            debugPrint(#function, error)
        }
        return nil
    }
    
    open class func makeUploadingUrl(directoryUrl: URL, completion:(URL?, Error?) -> Void) {
        let coordinator = NSFileCoordinator()
        var error: NSError?
        coordinator.coordinate(
            readingItemAt: directoryUrl,
            options: [.forUploading],
            error: &error) { zipUrl in
            
            do {
                let tmpUrl = try FileManager.default.url(
                    for: .itemReplacementDirectory,
                    in: .userDomainMask,
                    appropriateFor: zipUrl,
                    create: true
                ).appendingPathComponent(directoryUrl.lastPathComponent + ".zip", isDirectory: false)
                try FileManager.default.copyItem(at: zipUrl, to: tmpUrl)
                completion(tmpUrl, nil)
            } catch {
                completion(nil, error)
            }
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
    
    static func subPath(filePath: String) -> String {
        if filePath.hasPrefix(storingKey.storageFolderPath) {
            return String(filePath.dropFirst(storingKey.storageFolderPath.count))
        }
        return filePath
    }
    
    static func fullPath(filePath: String) -> String {
        if !filePath.hasPrefix(storingKey.storageFolderPath) {
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
        ChatClient.shared.apiUrl?.host ?? ""
    }

    public static let storageFolder = "SceytChatFiles"

    public required init() {}

    open var storageFolderPath: String = Config.storageDirectory?.path ?? NSTemporaryDirectory()

    open func storingFilename(url: URL) -> String {
        let key = url.lastPathComponent
        guard url.host?.contains(Self.sceytChatStorageHost) == true else { return key }
        let lastTwo = url.pathComponents.suffix(2)
        guard lastTwo.count == 2 else { return key }
        return lastTwo.first! + "_" + lastTwo.last!
    }

    open func storingPath(url: URL) -> String {
        storageFolderPath
    }

    open func removeStorageFolder() {
        do {
            try FileManager.default.removeItem(atPath: storageFolderPath)
        } catch {
            debugPrint(#function, error)
        }
    }
}
