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
            log.verbose("[CHECKSUM] create checksum \(checksum) for file \(filePath)")
            self.database.read {
                ChecksumDTO.fetch(checksum: Int64(checksum), context: $0)?
                    .convert()
            } completion: { result in
                switch result {
                case .failure(let error):
                    log.errorIfNotNil(error, "Getting check sum result")
                    completion(nil)
                case .success(let checksum):
                    log.verbose("[CHECKSUM] read checksum \(checksum?.checksum ?? -1) for mTid: \(checksum?.messageTid ?? 0), aTid \(checksum?.attachmentTid ?? 0), data: \(checksum?.data ?? "")")
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
            log.verbose("[CHECKSUM] create checksum \(crc) for mTid: \(message.tid), aTid \(attachment.tid)")
            self.database.write {
                $0.createOrUpdate(checksum: checksum)
            } completion: { error in
                log.errorIfNotNil(error, "Creating check sum result")
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
                        database.read { checksum -> ChatMessage.Attachment? in
                            var dto = MessageDTO.fetch(tid: message.tid, context: checksum)
                            if dto == nil, message.id > 0 {
                                dto = MessageDTO.fetch(id: message.id, context: checksum)
                                log.debug("Found message by tid not found \(message.tid) is fetch by id \(message.id) \(dto != nil)")
                            }
                            if dto == nil {
                                log.debug("Found message by tid not found \(message.tid)  will insert new message")
                                dto = checksum.createOrUpdate(message: message.builder.build(), channelId: message.channelId)
                            }
                            return AttachmentDTO.fetch(url: link, context: checksum)?.convert()
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
                                    database.write { [weak self] context in
                                        guard let self else { return }
                                        var attachments = message.attachments ?? []
                                        if attachments.count > 1,
                                           let idx = attachments.firstIndex(where: { $0.id == attachmentId })
                                        {
                                            attachments[idx] = attachment
                                        }
                                        context.update(chatMessage: message, attachments: attachments)
                                    } completion: { [weak self] error in
                                        guard let self else { return }
                                        if let error {
                                            log.debug("Update Attachments error: \(error.localizedDescription)")
                                            completion(.failure(error))
                                        } else {
                                            completion(.success(link))
                                        }
                                    }
                                } else {
                                    completion(.success(nil))
                                }
                            case .failure(let error):
                                log.debug("Getting Attachment by url error: \(error.localizedDescription)")
                                completion(.failure(error))
                            }
                        }
                    } else {
                        createChecksum(
                            message: message,
                            attachment: attachment)
                        { [weak self] error in
                            guard let self else { return }
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
