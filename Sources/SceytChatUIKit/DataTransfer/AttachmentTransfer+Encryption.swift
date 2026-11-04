//
//  AttachmentTransfer+Encryption.swift
//  SceytChatUIKit
//
//  Which transfers are encrypted, with what, and the gate that fails closed when a transfer
//  would store or send plaintext it must not.
//

import Foundation
import SceytChat

extension AttachmentTransfer {

    /// What `…Encryption` found for one attachment that must be encrypted.
    struct EncryptionSetup {
        /// The received attachment's `enc`; nil for an upload.
        var download: AttachmentEncryption?
        /// Why it cannot be transferred, e.g. a malformed encryption field.
        var error: Error?
    }

    /// The attachments the key provider says must be encrypted. Their keys are made by the
    /// transport's `FileEncryption` session, once UIKit hands it the prepared file
    /// (`FileUploadType.encrypted`).
    func uploadEncryption(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment]
    ) -> [ObjectIdentifier: EncryptionSetup] {
        let provider = environment.keyProvider()
        var setups = [ObjectIdentifier: EncryptionSetup]()
        for attachment in attachments where attachment.filePath != nil
            && provider.requirement(for: attachment, in: message) == .required {
            setups[ObjectIdentifier(attachment)] = EncryptionSetup()
        }
        logger.debug("[Encryption] \(TransferLog.currentTag) upload of message tid=\(message.tid): \(setups.count) of \(attachments.count) attachment(s) must be encrypted (provider \(type(of: provider)))")
        return setups
    }

    /// The received attachments that carry `enc`. A malformed one, or one of a version or
    /// algorithm this build cannot read, fails before anything is fetched.
    func downloadEncryption(attachments: [ChatMessage.Attachment]) -> [ObjectIdentifier: EncryptionSetup] {
        var setups = [ObjectIdentifier: EncryptionSetup]()
        for attachment in attachments where attachment.isEncrypted {
            guard let encryption = attachment.encryption,
                  encryption.algorithm == StreamingAeadFileEncryptionProvider.format
            else {
                // The task fails with it and reports it.
                logger.debug("[Encryption] \(TransferLog.currentTag) download rejected: \(attachment.encryption.map { "unsupported algorithm \($0.algorithm)" } ?? "malformed enc or unsupported version") \(attachment.transferLogDescription)")
                setups[ObjectIdentifier(attachment)] = EncryptionSetup(error: AttachmentEncryptionError.invalidEncryptionInfo)
                continue
            }
            // Ids and algorithm only: the keys are never logged.
            logger.debug("[Encryption] \(TransferLog.currentTag) download enc \(attachment.transferLogDescription) alg=\(encryption.algorithm) attachmentId=\(encryption.attachmentId) thumbnailAttachmentId=\(encryption.thumbnail?.attachmentId ?? "-")")
            setups[ObjectIdentifier(attachment)] = EncryptionSetup(download: encryption)
        }
        return setups
    }

    /// Marks `taskInfo` as an encrypted transfer. Returns the error to fail it with when it
    /// cannot run encrypted (fail-closed rule 1, malformed encryption field).
    static func apply(_ setup: EncryptionSetup, to taskInfo: SCTDataSessionTaskInfo, dataSession: SCTDataSession) -> Error? {
        taskInfo.encryption = .required
        taskInfo.downloadEncryption = setup.download
        guard dataSession.supportsAttachmentEncryption else {
            return AttachmentEncryptionError.encryptionUnsupportedBySession
        }
        return setup.error
    }

    /// Fail-closed rules 2 and 4: an encrypted upload succeeds only with the encryption its
    /// transport returned (or a dedupe hit that reused an encrypted object together with its
    /// key); an encrypted download only with the plaintext its transport verified.
    static func encryptionGateError(taskInfo: SCTDataSessionTaskInfo, attachment: ChatMessage.Attachment) -> Error? {
        guard taskInfo.encryption == .required else { return nil }
        switch taskInfo.transferType {
        case .upload:
            guard taskInfo.uploadedEncryption != nil || attachment.encryption != nil else {
                return AttachmentEncryptionError.encryptionBypassed
            }
        case .download:
            guard taskInfo.didDecryptDownload else {
                return AttachmentEncryptionError.encryptionBypassed
            }
        }
        return nil
    }
}
