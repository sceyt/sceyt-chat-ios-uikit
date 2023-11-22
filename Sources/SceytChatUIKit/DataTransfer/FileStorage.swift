//
//  FileStorage.swift
//  LiveChat
//
//  Created by Hovsep Keropyan on 01.09.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class FileStorage: Storage {
    public static let `default` = FileStorage()
    
    var fileManager: FileManager { FileManager.default }
    
    public static var documentDirectory: URL? = {
        if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            return URL(fileURLWithPath: path)
        }
        return nil
    }()
    
    public lazy var storagePath: String = {
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
            return tmp
        }
    }()
    
    public lazy var thumbnailPath: String = {
        let path = URL(fileURLWithPath: storagePath).appendingPathComponent("thumbnails").path
        if fileManager.fileExists(atPath: path) {
            return path
        }
        do {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
        } catch {}
        return path
    }()
    
    open func store(transferId: String, fileName: String?, file path: String) -> String {
        var newPath = filePath(transferId: transferId)
        if let fileName {
            do {
                try fileManager.createDirectory(at: URL(fileURLWithPath: newPath), withIntermediateDirectories: true, attributes: nil)
                newPath = (newPath as NSString).appendingPathComponent(fileName)
            } catch {
                logger.errorIfNotNil(error, "store")
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
            logger.errorIfNotNil(error, "")
            if (error as NSError).code == NSFileWriteFileExistsError {
                return newPath
            }
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
                logger.errorIfNotNil(error, "store")
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
            logger.errorIfNotNil(error, "thumbnailPath")
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
        try? fileManager.contentsOfDirectory(atPath: thumbnailPath)
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
                        try? fileManager.createDirectory(at: newTmpUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                        try fileManager.copyItem(at: tmpUrl, to: newTmpUrl)
                        try fileManager.removeItem(at: tmpUrl)
                    } catch {
                        logger.errorIfNotNil(error, "")
                    }
                }
            }
    }
    
    open func remove(path: String) {
        try? fileManager.removeItem(atPath: path)
    }
    
    open func filePath(transferId: String) -> String {
        (storagePath as NSString).appendingPathComponent(transferId)
    }
    
    open func isFilePath(_ path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }
}
