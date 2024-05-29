//
//  ChannelMessageChecksumProvider.swift
//  SceytChatUIKit
//
//  Created by Duc on 28/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class ChannelMessageChecksumProvider: Provider {
    
    override public required init() {
        super.init()
    }
    
    open func checksum(
        attachment: ChatMessage.Attachment,
        completion: @escaping (ChatMessage.Attachment.Checksum?) -> Void)
    {
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
            let checksum = Components.storage.checksum(filePath: filePath)
            logger.verbose("[CHECKSUM] create checksum \(checksum) for file \(filePath)")
            self.database.read {
                ChecksumDTO.fetch(checksum: Int64(checksum), context: $0)?
                    .convert()
            } completion: { result in
                switch result {
                case .failure(let error):
                    logger.errorIfNotNil(error, "Getting check sum result")
                    completion(nil)
                case .success(let checksum):
                    logger.verbose("[CHECKSUM] read checksum \(checksum?.checksum ?? -1) for mTid: \(checksum?.messageTid ?? 0), aTid \(checksum?.attachmentTid ?? 0), data: \(checksum?.data ?? "")")
                    completion(checksum)
                }
            }
        }
    }
    
    open func createChecksum(
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        completion: ((Error?) -> Void)? = nil)
    {
        guard attachment.type != "link", attachment.filePath != nil
        else {
            completion?(nil)
            return
        }
        attachment.assetFilePath { filePath in
            guard let filePath
            else {
                completion?(nil)
                return
            }
                
            let crc = Components.storage.checksum(filePath: filePath)
            let checksum = ChatMessage.Attachment.Checksum(
                checksum: Int64(crc),
                messageTid: message.tid,
                attachmentTid: attachment.tid,
                data: nil)
            logger.verbose("[CHECKSUM] create checksum \(crc) for mTid: \(message.tid), aTid \(attachment.tid)")
            self.database.performWriteTask {
                $0.createOrUpdate(checksum: checksum)
            } completion: { error in
                logger.errorIfNotNil(error, "Creating check sum result")
                completion?(error)
            }
        }
    }
    
    open func startChecksum(
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        completion: @escaping ((Result<String?, Error>) -> Void))
    {
        if attachment.type != "link" && attachment.filePath != nil {
            let attachmentId = attachment.id
            let message = message
            checksum(
                attachment: attachment,
                completion: { [weak self] checksum in
                    guard let self else { return }
                    if let checksum, let link = checksum.data {
                        self.database.read { context -> ChatMessage.Attachment? in
                            var dto = MessageDTO.fetch(tid: message.tid, context: context)
                            if dto == nil, message.id > 0 {
                                dto = MessageDTO.fetch(id: message.id, context: context)
                                logger.debug("Found message by tid not found \(message.tid) is fetch by id \(message.id) \(dto != nil)")
                            }
                            if dto == nil {
                                logger.debug("Found message by tid not found \(message.tid)  will insert new message")
                                dto = context.createOrUpdate(message: message.builder.build(), channelId: message.channelId)
                            }
                            return AttachmentDTO.fetch(url: link, context: context)?.convert()
                        } completion: { [weak self] result in
                            guard let self else { return }
                            switch result {
                            case .success(let stored):
                                if let stored {
                                    attachment.filePath = stored.filePath
                                    attachment.name = stored.name
                                    attachment.metadata = stored.metadata
                                    attachment.uploadedFileSize = stored.uploadedFileSize
                                    attachment.status = .done
                                    self.database.performWriteTask { [weak self] context in
                                        guard let self else { return }
                                        var attachments = message.attachments ?? []
                                        if attachments.count > 1,
                                           let idx = attachments.firstIndex(where: { $0.id == attachmentId })
                                        {
                                            attachments[idx] = attachment
                                        }
                                        context.update(chatMessage: message, attachments: attachments)
                                    } completion: { [weak self] error in
                                        if let error {
                                            logger.errorIfNotNil(error, "Update Attachments")
                                            completion(.failure(error))
                                        } else {
                                            completion(.success(link))
                                        }
                                    }
                                } else {
                                    self.createChecksum(
                                        message: message,
                                        attachment: attachment)
                                    { [weak self] error in
                                        if let error {
                                            completion(.failure(error))
                                        } else {
                                            completion(.success(nil))
                                        }
                                    }
//                                    completion(.success(nil))
                                }
                            case .failure(let error):
                                logger.errorIfNotNil(error, "Getting Attachment by url")
                                completion(.failure(error))
                            }
                        }
                    } else {
                        self.createChecksum(
                            message: message,
                            attachment: attachment)
                        { [weak self] error in
                            if let error {
                                completion(.failure(error))
                            } else {
                                completion(.success(nil))
                            }
                        }
                    }
                })
        } else {
            completion(.success(nil))
        }
    }
}
