//
//  PinnedMessage.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

/// Context-free snapshot of a `PinnedMessageDTO`, safe to pass between queues.
///
/// Everything needed to render a pinned message is denormalized onto the row, so the
/// pinned banner and the pinned list keep working with no network **and** when the
/// `MessageDTO` the pin points at was never fetched or has been swept by a
/// batch delete. See `PinnedMessageDTO` for why that snapshot exists.
public struct PinnedMessage {

    /// Who a pin is visible to. Local-only today — the SceytChat SDK has no
    /// message-pin API — but persisted so the server flip needs no migration.
    public enum Scope {
        case forMe
        case forAll
    }

    /// The pinned message's first attachment, flattened. Mirrors the fields the
    /// preview needs; not a full `ChatMessage.Attachment`.
    public struct AttachmentPreview {
        public let type: String
        public let name: String?
        public let filePath: String?
        public let url: String?
        public let metadata: String?
    }

    public let channelId: ChannelId
    /// 0 while the pinned message is still a pending send.
    public let messageId: MessageId
    public let messageTid: Int64
    public let scope: Scope
    public let pinnedAt: Date?
    /// When the pin lapses. `Date.distantFuture` for an indefinite pin.
    public let pinnedUntil: Date?
    public let pinnedByUserId: UserId?
    /// The pinned message's own `createdAt`, denormalized because it is the sort key
    /// and must survive the `MessageDTO` row being deleted.
    public let messageCreatedAt: Date?

    public let body: String
    public let messageType: String
    public let messageState: ChatMessage.State
    /// Rebuilt from the snapshot columns, so the existing `UserFormatting`
    /// formatters work on it unchanged.
    public let sender: ChatUser?
    public let attachment: AttachmentPreview?

    public let syncState: PinnedMessageDTO.StoredSyncState
    public let retryCount: Int
    public let lastAttemptAt: Int64

    /// The pinned message has no server id yet.
    public var isPending: Bool { messageId == 0 }

    /// The snapshot rebuilt as a `ChatMessage`, so the existing message formatters can run
    /// on it unchanged.
    ///
    /// This is what makes the banner work offline: it is built from the pin row's own
    /// columns, never from a `MessageDTO`, so it still renders after the message has been
    /// evicted or was never fetched.
    public var previewMessage: ChatMessage {
        ChatMessage(
            id: messageId,
            tid: messageTid,
            channelId: channelId,
            body: body,
            type: messageType,
            createdAt: messageCreatedAt ?? Date(),
            state: messageState,
            attachments: attachment.map {
                [ChatMessage.Attachment(
                    id: 0,
                    tid: messageTid,
                    messageId: messageId,
                    userId: sender?.id ?? "",
                    url: $0.url,
                    filePath: $0.filePath,
                    type: $0.type,
                    name: $0.name,
                    metadata: $0.metadata,
                    uploadedFileSize: 0,
                    createdAt: messageCreatedAt ?? Date()
                )]
            },
            user: sender
        )
    }

    /// The pin has lapsed and should no longer be shown.
    public var isExpired: Bool {
        guard let pinnedUntil else { return false }
        return pinnedUntil <= Date()
    }
}

// MARK: - init with DTO

extension PinnedMessage {
    init(dto: PinnedMessageDTO) {
        channelId = ChannelId(dto.channelId)
        messageId = MessageId(dto.messageId)
        messageTid = dto.messageTid
        scope = dto.scope
        pinnedAt = dto.pinnedAt?.bridgeDate
        pinnedUntil = dto.pinnedUntil?.bridgeDate
        pinnedByUserId = dto.pinnedByUserId
        messageCreatedAt = dto.messageCreatedAt?.bridgeDate

        body = dto.body
        messageType = dto.messageType ?? "text"
        messageState = ChatMessage.State(rawValue: Int(dto.messageState)) ?? .none

        if let senderId = dto.senderId {
            sender = ChatUser(
                id: senderId,
                firstName: dto.senderFirstName,
                lastName: dto.senderLastName,
                username: dto.senderUsername,
                avatarUrl: dto.senderAvatarUrl
            )
        } else {
            sender = nil
        }

        if let type = dto.attachmentType {
            attachment = AttachmentPreview(
                type: type,
                name: dto.attachmentName,
                filePath: dto.attachmentFilePath,
                url: dto.attachmentUrl,
                metadata: dto.attachmentMetadata
            )
        } else {
            attachment = nil
        }

        syncState = PinnedMessageDTO.StoredSyncState(rawValue: dto.syncState) ?? .unspecified
        retryCount = Int(dto.retryCount)
        lastAttemptAt = dto.lastAttemptAt
    }
}
