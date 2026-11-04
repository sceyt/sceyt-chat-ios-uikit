//
//  UploadPreparer.swift
//  SceytChatUIKit
//
//  Turns an attachment's file into the file its upload sends: the file an earlier attempt of
//  the operation staged, or a new one (an image resized, a video exported, a folder zipped).
//  Any other file is sent as it is, where it is.
//

import Foundation

struct UploadPreparer {
    let staging: UploadStaging
    let environment: TransferEnvironment
    /// An app extension resizes images with less memory.
    let isAppExtension: Bool

    func prepare(
        _ attachment: ChatMessage.Attachment,
        taskInfo: SCTDataSessionTaskInfo,
        operationId: String,
        videoProcessInfo: SCVideoProcessInfo
    ) async throws -> PreparedUploadFile {
        guard var filePath = attachment.filePath else {
            logger.debug("[Transfer] \(taskInfo.logTag) upload has no local file to prepare (missingSourceFile)")
            throw TransportDataSessionError.missingSourceFile
        }
        if !FileManager.default.fileExists(atPath: filePath) {
            // Not failed here: a Photos-library video (`/local/<id>`) has no file at this path,
            // its export reads it from Photos. Anything else that is missing fails once
            // preparation is over (`missingSourceFile`).
            logger.warn("[Transfer] \(taskInfo.logTag) upload source file is not on disk \(attachment.transferLogDescription)")
        }
        if attachment.kind == .image || attachment.kind == .video,
           let staged = staging.stagedFile(operationId: operationId) {
            // An export or resize would make different bytes than the ones already sent.
            logger.info("[Transfer] \(taskInfo.logTag) upload staging reused: sends the file an earlier attempt prepared (\(TransferLog.sizeText(staged)))")
            return PreparedUploadFile(file: staged, isStaged: true)
        }
        taskInfo.updateProgress(0.01)
        switch attachment.kind {
        case .video:
            switch await environment.videoProcessor().export(from: filePath, processInfo: videoProcessInfo) {
            case .success(let exported):
                try Task.checkCancellation()
                return PreparedUploadFile(file: try staging.stage(exported, operationId: operationId, fileName: exported.lastPathComponent, tag: taskInfo.logTag), isStaged: true)
            case .failure(let error):
                logger.warn("[Transfer] \(taskInfo.logTag) upload video export failed (\(TransferLog.describe(error))), uploading the original")
            }
        case .image:
            let config = environment.imageResizeConfig()
            var jpeg: Data?
            var reason = "the image could not be read"
            if isAppExtension {
                jpeg = environment.imageBuilder().lowMemory_resizeImage(fileUrl: URL(fileURLWithPath: filePath), maxPixelSize: config.dimensionThreshold)?
                    .jpegData(compressionQuality: config.compressionQuality)
            } else if let builder = environment.imageBuilder().init(imageUrl: URL(fileURLWithPath: filePath)),
                      !builder.imageSize.isNan {
                do {
                    jpeg = try builder.resize(max: config.dimensionThreshold).jpegData(compressionQuality: config.compressionQuality)
                    reason = "it could not be encoded as JPEG"
                } catch {
                    reason = "resize threw \(TransferLog.describe(error))"
                }
            }
            try Task.checkCancellation()
            if let jpeg,
               let resized = environment.storage().storeInTemporaryDirectory(data: jpeg, filename: attachment.name ?? UUID().uuidString) {
                return PreparedUploadFile(file: try staging.stage(resized, operationId: operationId, fileName: resized.lastPathComponent, tag: taskInfo.logTag), isStaged: true)
            }
            logger.warn("[Transfer] \(taskInfo.logTag) upload image resize \(jpeg == nil ? "failed (\(reason))" : "could not be stored"), uploading the original")
        case .file:
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory)
            if isDirectory.boolValue {
                let zip = try await environment.storage().makeUploadingUrl(directoryUrl: URL(fileURLWithPath: filePath))
                try Task.checkCancellation()
                logger.debug("[Transfer] \(taskInfo.logTag) upload folder zipped (\(TransferLog.sizeText(zip)))")
                taskInfo.updateLocalFileLocation(newLocation: zip)
                filePath = zip.path
            } else {
                // Sent in place: the attachment's own file stays where it is, and every
                // retry sends the same one.
                logger.debug("[Transfer] \(taskInfo.logTag) upload file sent in place (\(TransferLog.size(path: filePath)))")
            }
        default:
            break
        }
        return PreparedUploadFile(file: URL(fileURLWithPath: filePath), isStaged: false)
    }
}
