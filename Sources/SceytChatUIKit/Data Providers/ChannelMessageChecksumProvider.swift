//
//  ChannelMessageChecksumProvider.swift
//  SceytChatUIKit
//
//  Created by Duc on 28/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

/// The checksum table: an upload first asks it for an object already stored for the same file.
///
/// A file is matched on `Storage.dedupeChecksum(filePath:)`, its sampled CRC32 together with
/// its size, and the stored attachment's size is compared again where it is the file's own (a
/// file sent as is). An empty or unreadable file is never matched or recorded. Rows written
/// before the size was part of the key hold a bare CRC32 and are never matched again: such an
/// upload is simply not deduped, nothing needs migrating.
open class ChannelMessageChecksumProvider: DataProvider {

    override public required init() {
        super.init()
    }

    /// The checksum row matching `attachment`'s file, or nil (no row, nothing to checksum, an
    /// empty or unreadable file).
    open func checksum(
        attachment: ChatMessage.Attachment,
        completion: @escaping (ChatMessage.Attachment.Checksum?) -> Void)
    {
        let tag = TransferLog.currentTag
        guard attachment.type != "link", attachment.filePath != nil
        else {
            completion(nil)
            return
        }

        attachment.assetFilePath { filePath in
            guard let filePath
            else {
                completion(nil)
                return
            }
            guard let checksum = Components.storage.dedupeChecksum(filePath: filePath) else {
                logger.info("[CHECKSUM] \(tag) no checksum: the file is empty or unreadable (\(TransferLog.size(path: filePath))), never deduped \(attachment.transferLogDescription)")
                completion(nil)
                return
            }
            logger.verbose("[CHECKSUM] \(tag) checksum \(checksum) size=\(TransferLog.size(path: filePath)) \(attachment.transferLogDescription)")
            self.database.read {
                ChecksumDTO.fetch(checksum: checksum, context: $0)?
                    .convert()
            } completion: { result in
                switch result {
                case .failure(let error):
                    logger.warn("[CHECKSUM] \(tag) lookup failed, treated as a miss: \(TransferLog.describe(error)) \(attachment.transferLogDescription)")
                    completion(nil)
                case .success(let checksum):
                    logger.verbose("[CHECKSUM] \(tag) read checksum \(checksum?.checksum ?? -1) for mTid: \(checksum?.messageTid ?? 0), aTid \(checksum?.attachmentTid ?? 0), data: \(TransferLog.redact(checksum?.data))")
                    completion(checksum)
                }
            }
        }
    }

    /// Records `attachment`'s file under its checksum; its url is filled in once it is uploaded.
    /// Nothing is recorded for an empty or unreadable file.
    open func createChecksum(
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        completion: ((Error?) -> Void)? = nil)
    {
        let tag = TransferLog.currentTag
        guard attachment.type != "link", attachment.filePath != nil
        else {
            completion?(nil)
            return
        }
        attachment.assetFilePath { filePath in
            guard let filePath,
                  let key = Components.storage.dedupeChecksum(filePath: filePath)
            else {
                completion?(nil)
                return
            }
            let checksum = ChatMessage.Attachment.Checksum(
                checksum: key,
                messageTid: message.tid,
                attachmentTid: attachment.tid,
                data: nil)
            logger.verbose("[CHECKSUM] \(tag) create checksum \(key) for mTid: \(message.tid), aTid \(attachment.tid)")
            self.database.performWriteTask {
                $0.createOrUpdate(checksum: checksum)
            } completion: { error in
                if let error {
                    // The upload fails with it and reports it.
                    logger.debug("[CHECKSUM] \(tag) create failed for mTid: \(message.tid), aTid \(attachment.tid): \(TransferLog.describe(error))")
                }
                completion?(error)
            }
        }
    }

    /// Whether the stored attachment can stand for `attachment`'s file: the same size, where
    /// its size is the file's own. An image or a video is resized or exported before it is
    /// sent, so its stored size is not its source's; the size in the key covers those.
    static func sizesMatch(stored: ChatMessage.Attachment, attachment: ChatMessage.Attachment, localSize: UInt) -> Bool {
        guard attachment.type != "image", attachment.type != "video", stored.uploadedFileSize > 0 else { return true }
        return stored.uploadedFileSize == localSize
    }

    /// On a hit the stored attachment's url is reused together with its whole metadata, so a
    /// provider's entries (the key that object was encrypted with, say) go with it.
    open func startChecksum(
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        completion: @escaping ((Result<String?, Error>) -> Void))
    {
        let context = TransferLog.current
        let tag = TransferLog.currentTag
        if attachment.type != "link" && attachment.filePath != nil {
            let attachmentId = attachment.id
            let message = message
            checksum(
                attachment: attachment,
                completion: { [weak self] checksum in
                    guard let self else { return }
                    let createChecksum = {
                        TransferLog.with(context) {
                            self.createChecksum(message: message, attachment: attachment) { error in
                                if let error {
                                    completion(.failure(error))
                                } else {
                                    completion(.success(nil))
                                }
                            }
                        }
                    }
                    guard let checksum, checksum.checksum != 0, let link = checksum.data else {
                        logger.debug("[CHECKSUM] \(tag) miss: \(checksum == nil ? "no row" : "row without an uploaded url")")
                        createChecksum()
                        return
                    }
                    self.database.read { context -> ChatMessage.Attachment? in
                        var dto = MessageDTO.fetch(tid: message.tid, channelId: Int64(message.channelId), context: context)
                        if dto == nil, message.id > 0 {
                            dto = MessageDTO.fetch(id: message.id, context: context)
                            logger.debug("[CHECKSUM] \(tag) message not found by tid, fetched by id: \(dto != nil)")
                        }
                        if dto == nil {
                            logger.debug("[CHECKSUM] \(tag) message not found by tid, inserting it")
                            dto = context.createOrUpdate(message: message.builder.build(), channelId: message.channelId)
                        }
                        return AttachmentDTO.fetch(url: link, context: context)?.convert()
                    } completion: { [weak self] result in
                        guard let self else { return }
                        switch result {
                        case .success(let stored):
                            let localPath = attachment.assetFilePath ?? attachment.filePath
                            let localSize = localPath.map { Storage.sizeOfItem(at: $0) } ?? 0
                            guard let stored else {
                                logger.info("[CHECKSUM] \(tag) miss: checksum \(checksum.checksum) points at \(TransferLog.redact(link)) but no attachment has it, uploading")
                                createChecksum()
                                return
                            }
                            guard Self.sizesMatch(stored: stored, attachment: attachment, localSize: localSize) else {
                                logger.info("[CHECKSUM] \(tag) miss: checksum \(checksum.checksum) matches but the stored object is \(stored.uploadedFileSize) B and this file \(localSize) B, uploading")
                                createChecksum()
                                return
                            }
                            logger.info("[CHECKSUM] \(tag) hit: checksum \(checksum.checksum) reuses \(TransferLog.redact(link)) storedSize=\(stored.uploadedFileSize) size=\(localSize) from \(stored.transferLogDescription)")
                            attachment.filePath = stored.filePath
                            attachment.name = stored.name
                            attachment.metadata = stored.metadata
                            attachment.uploadedFileSize = stored.uploadedFileSize
                            attachment.status = .done
                            self.database.performWriteTask { context in
                                var attachments = message.attachments ?? []
                                if attachments.count > 1,
                                   let idx = attachments.firstIndex(where: { $0.id == attachmentId })
                                {
                                    attachments[idx] = attachment
                                }
                                context.update(chatMessage: message, attachments: attachments)
                            } completion: { error in
                                if let error {
                                    // The upload fails with it and reports it.
                                    logger.debug("[CHECKSUM] \(tag) hit could not be persisted, the upload fails: \(TransferLog.describe(error))")
                                    completion(.failure(error))
                                } else {
                                    completion(.success(link))
                                }
                            }
                        case .failure(let error):
                            logger.debug("[CHECKSUM] \(tag) lookup of the stored attachment failed, the upload fails: \(TransferLog.describe(error))")
                            completion(.failure(error))
                        }
                    }
                })
        } else {
            completion(.success(nil))
        }
    }
}
