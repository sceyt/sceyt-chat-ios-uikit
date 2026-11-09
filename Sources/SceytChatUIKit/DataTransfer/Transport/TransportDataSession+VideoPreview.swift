//
//  TransportDataSession+VideoPreview.swift
//  SceytChatUIKit
//
//  A video's poster as its own "preview" attachment, through the session's provider: prepared
//  (encrypted, if the provider does) and uploaded like any file, and downloaded (decrypted)
//  like one. Not queued: it runs inside its video's upload attempt, before the video's bytes.
//

import Foundation

extension TransportDataSession {

    /// The operation of `video`'s preview upload: the video's own, with "-thumbnail".
    public func videoPreviewOperationId(for video: ChatMessage.Attachment) -> String {
        "\(uploadOperationId(for: video))-thumbnail"
    }

    public func uploadVideoPreview(_ file: URL, of video: ChatMessage.Attachment, message: ChatMessage) async throws -> VideoPreviewUpload {
        let operationId = videoPreviewOperationId(for: video)
        var request = FileUploadRequest(
            operationId: operationId,
            sourceFile: file,
            fileName: file.lastPathComponent,
            mimeType: "image/jpeg",
            context: AttachmentTransferContext(message: message, attachment: video),
            // Inside the video's attempt and slot: part of the video's upload, not a file of its own.
            parentOperationId: uploadOperationId(for: video)
        )
        let entries = try await provider.prepareUpload(request) ?? [:]
        request = request.merging(metadata: entries)
        // Keys only: a provider's values may carry keys.
        logger.debug("[Transfer] xfer=\(operationId) preview upload start size=\(TransferLog.sizeText(file)) providerEntries=[\(entries.keys.sorted().joined(separator: ","))]")
        // The video's attempt waits on this upload: a pause or cancel of it (which cancels the
        // attempt's task) stops this one too.
        let provider = self.provider
        let result = await withTaskCancellationHandler {
            await provider.upload(request, progress: { _ in })
        } onCancel: {
            provider.cancel(operationId: operationId)
        }
        switch result {
        case .success(let uploaded):
            logger.debug("[Transfer] xfer=\(operationId) preview upload finished ref=\(TransferLog.redact(uploaded.url))")
            return VideoPreviewUpload(url: uploaded.url, metadata: entries)
        case .failure(let error):
            // Not kept for a later attempt: a retry prepares a new preview (a new key), so
            // what this one left would only stay open.
            logger.debug("[Transfer] xfer=\(operationId) preview upload failed, abandoning it: \(TransferLog.describe(error))")
            provider.cancel(operationId: operationId)
            throw error
        case .interrupted(let error):
            logger.debug("[Transfer] xfer=\(operationId) preview upload interrupted, abandoning it: \(TransferLog.describe(error))")
            provider.cancel(operationId: operationId)
            throw VideoPreviewInterrupted(underlying: error)
        }
    }

    public func abandonVideoPreview(of video: ChatMessage.Attachment) {
        let operationId = videoPreviewOperationId(for: video)
        logger.debug("[Transfer] xfer=\(operationId) preview abandoned")
        provider.cancel(operationId: operationId)
    }

    public func downloadVideoPreview(_ preview: ChatMessage.Attachment, message: ChatMessage, to destination: URL) async throws {
        guard let url = preview.url, !url.isEmpty else { throw FileTransferError.invalidRequest }
        let request = FileDownloadRequest(
            operationId: "download-preview-\(TransferLog.shortHash(url))",
            url: url,
            destinationFile: destination,
            context: AttachmentTransferContext(message: message, attachment: preview),
            headers: downloadHeaders(for: preview, message: message),
            metadata: preview.stringMetadataEntries
        )
        switch await provider.download(request, progress: { _ in }) {
        case .success:
            return
        case .failure(let error), .interrupted(let error):
            logger.debug("[Transfer] xfer=\(request.operationId) preview download failed: \(TransferLog.describe(error)) url=\(TransferLog.redact(url))")
            throw error
        }
    }
}
