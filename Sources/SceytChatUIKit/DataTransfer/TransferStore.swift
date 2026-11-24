//
//  TransferStore.swift
//  SceytChatUIKit
//
//  Where `AttachmentTransfer` keeps what transfers change. Every write names the attachments
//  it owns: the rows of a message's other attachments belong to their own transfers, and a
//  write that carried them along would put back whatever this copy held (last write wins).
//

import Foundation

public protocol TransferStore: AnyObject {
    /// Saves `attachments` of `message` (only these rows).
    func save(
        _ attachments: [ChatMessage.Attachment],
        of message: ChatMessage,
        completion: ((Error?) -> Void)?
    )

    /// Saves the end of a transfer: `attachments` of `message`, and the checksum rows of the
    /// ones that have a url, so a later upload of the same bytes is deduplicated.
    /// - Parameter completion: the message as stored (nil when it is not), and the save's error.
    func saveEnd(
        of attachments: [ChatMessage.Attachment],
        of message: ChatMessage,
        completion: @escaping (ChatMessage?, Error?) -> Void
    )

    /// Saves `attachment`'s new local file; `previousPath` finds its row when it was stored
    /// under that path.
    func saveLocalFile(of attachment: ChatMessage.Attachment, previousPath: String?, of message: ChatMessage)

    /// Whether `message` is still stored (it may have been deleted while it uploaded).
    func messageExists(_ message: ChatMessage, completion: @escaping (Bool) -> Void)
}

public extension TransferStore {
    func save(_ attachments: [ChatMessage.Attachment], of message: ChatMessage) {
        save(attachments, of: message, completion: nil)
    }
}

/// The `TransferStore` on the UIKit's CoreData database, read at each call (it can be
/// replaced after this store is made).
public final class DatabaseTransferStore: TransferStore {
    private let database: () -> Database

    public init(database: @escaping () -> Database = { DataProvider.database }) {
        self.database = database
    }

    public func save(
        _ attachments: [ChatMessage.Attachment],
        of message: ChatMessage,
        completion: ((Error?) -> Void)?
    ) {
        database().write(resultQueue: .global()) {
            $0.update(chatMessage: message, attachments: attachments)
        } completion: { error in
            completion?(error)
        }
    }

    public func saveEnd(
        of attachments: [ChatMessage.Attachment],
        of message: ChatMessage,
        completion: @escaping (ChatMessage?, Error?) -> Void
    ) {
        var stored: ChatMessage?
        database().write(resultQueue: .global()) {
            stored = $0.update(chatMessage: message, attachments: attachments)?.convert()
            for attachment in attachments {
                if let url = attachment.url {
                    $0.updateChecksum(data: url, messageTid: message.tid, attachmentTid: attachment.tid)
                }
            }
        } completion: { error in
            completion(stored, error)
        }
    }

    public func saveLocalFile(of attachment: ChatMessage.Attachment, previousPath: String?, of message: ChatMessage) {
        database().write {
            if let previousPath {
                $0.updateAttachment(with: previousPath, chatMessage: message, attachment: attachment)
            } else {
                $0.update(chatMessage: message, attachments: [attachment])
            }
        }
    }

    public func messageExists(_ message: ChatMessage, completion: @escaping (Bool) -> Void) {
        database().read {
            var dto: MessageDTO?
            if message.id > 0 {
                dto = MessageDTO.fetch(id: message.id, context: $0)
            }
            if dto == nil {
                dto = MessageDTO.fetch(tid: message.tid, channelId: Int64(message.channelId), context: $0)
            }
            return dto != nil
        } completion: { result in
            completion(Self.exists(result, message: message))
        }
    }

    /// A read that failed says nothing about the message: it is taken as still there, so its
    /// upload's result is not dropped as if the message had been deleted.
    static func exists(_ result: Result<Bool, Error>, message: ChatMessage) -> Bool {
        switch result {
        case .success(let exists):
            return exists
        case .failure(let error):
            logger.error("[Attachment] \(TransferLog.currentTag) could not check that message \(message.id)/\(message.tid) still exists, taken as existing: \(TransferLog.describe(error))")
            return true
        }
    }
}
