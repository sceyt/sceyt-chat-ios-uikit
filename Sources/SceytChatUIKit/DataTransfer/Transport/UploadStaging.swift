//
//  UploadStaging.swift
//  SceytChatUIKit
//

import Foundation

/// The prepared files of uploads (a resized image, an exported video), kept until the upload
/// lands so every attempt of one operation sends the same bytes: one folder per operation
/// under `directory`.
struct UploadStaging {
    /// How long a staged file nobody uploaded or abandoned is kept.
    static let staleAge: TimeInterval = 7 * 24 * 60 * 60

    let directory: URL

    /// The staged file of `operationId`, when an earlier attempt prepared one.
    func stagedFile(operationId: String) -> URL? {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder(operationId: operationId),
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        )) ?? []
        return files.first { (TransportDataSession.fileSize($0) ?? 0) > 0 }
    }

    /// Moves `file` in as the staged file of `operationId`, replacing an earlier one.
    func stage(_ file: URL, operationId: String, fileName: String, tag: String) throws -> URL {
        let fileManager = FileManager.default
        let folder = folder(operationId: operationId)
        TransferLog.remove(folder, what: "the old staging folder", context: "[Transfer] \(tag) upload")
        let staged = folder.appendingPathComponent(fileName.isEmpty ? "file" : fileName)
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            try fileManager.moveItem(at: file, to: staged)
        } catch {
            logger.debug("[Transfer] \(tag) upload staging failed: \(TransferLog.describe(error))")
            throw error
        }
        logger.debug("[Transfer] \(tag) upload staging created (\(TransferLog.sizeText(staged)))")
        return staged
    }

    /// Removes what `operationId` staged: its upload landed, or was abandoned.
    func discard(operationId: String) {
        let folder = folder(operationId: operationId)
        guard FileManager.default.fileExists(atPath: folder.path) else { return }
        if TransferLog.remove(folder, what: "the staging folder", context: "[Transfer] xfer=\(operationId) upload") {
            logger.debug("[Transfer] xfer=\(operationId) upload staging cleaned up")
        }
    }

    /// Removes folders older than `staleAge`: uploads nobody finished or abandoned.
    func purgeStale(now: Date = Date()) {
        let fileManager = FileManager.default
        let cutoff = now.addingTimeInterval(-Self.staleAge)
        let folders = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        var purged = 0
        for folder in folders {
            let modified = (try? folder.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff,
               TransferLog.remove(folder, what: "a stale staging folder", context: "[Transfer] staging purge") {
                purged += 1
            }
        }
        if purged > 0 {
            logger.info("[Transfer] staging purge removed \(purged) of \(folders.count) folder(s) older than \(Int(Self.staleAge / 86_400)) days")
        }
    }

    private func folder(operationId: String) -> URL {
        directory.appendingPathComponent(Self.folderName(operationId), isDirectory: true)
    }

    /// `operationId` percent-encoded outside the ASCII alphanumerics: what
    /// `addingPercentEncoding(withAllowedCharacters: .alphanumerics)` makes (it escapes every
    /// non-ASCII scalar too, as its UTF-8 bytes, `%XX`), without its optional, which a Swift
    /// string never makes nil.
    static func folderName(_ operationId: String) -> String {
        var name = ""
        for scalar in operationId.unicodeScalars {
            if scalar.isASCII, CharacterSet.alphanumerics.contains(scalar) {
                name.unicodeScalars.append(scalar)
            } else {
                for byte in String(scalar).utf8 {
                    name += String(format: "%%%02X", byte)
                }
            }
        }
        return name
    }
}
