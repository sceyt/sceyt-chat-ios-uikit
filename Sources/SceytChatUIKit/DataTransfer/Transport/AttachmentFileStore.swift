//
//  AttachmentFileStore.swift
//  SceytChatUIKit
//
//  Where a data session keeps the files it transfers. A session is given one
//  (`TransportDataSession.fileStore`) instead of being subclassed to change it.
//

import Foundation

public protocol AttachmentFileStore: Sendable {
    /// Moves (or copies) the file at `path` into storage, under `transferId`, and returns where
    /// it is now. A store that fails returns `path` itself: callers check for that.
    func store(fileAt path: String, transferId: String, fileName: String?) -> String
    /// Removes a stored file. A file that is already gone is not a failure.
    func remove(fileAt path: String)
    /// Moves the thumbnails made for a file that was just stored under `transferId`.
    func updateThumbnailPath(transferId: String, filePath: String)
    /// Where a downloaded file stored under `transferId` goes.
    func downloadDestination(transferId: String, fileName: String?) -> URL
}

public extension AttachmentFileStore {
    /// The app's file storage, for a store that keeps downloads where `FileStorage` does.
    func downloadDestination(transferId: String, fileName: String?) -> URL {
        URL(fileURLWithPath: FileStorage.default.createPath(transferId: transferId, fileName: fileName))
    }
}

/// Why a store did not take a file.
public enum AttachmentFileStoreError: Error, Equatable {
    /// The store handed the source path back: its way of saying it failed.
    case sourceReturned
    /// The path it returned has no file.
    case nothingStored
}

/// Reads a store's answer (`store(fileAt:...)` reports a failure by returning the source path,
/// a convention kept for stores and `storeFile` overrides written against it) as a throw.
public enum AttachmentFileStoreResult {
    public static func check(_ stored: String, source: String) throws -> String {
        guard stored != source else { throw AttachmentFileStoreError.sourceReturned }
        guard FileManager.default.fileExists(atPath: stored) else { throw AttachmentFileStoreError.nothingStored }
        return stored
    }
}
