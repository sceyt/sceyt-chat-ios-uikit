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
}
