//
//  DraftMessage.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import Photos
import SceytChat
import UIKit

/// Everything the message input bar was holding when the user left a channel.
///
/// Mirrors the Android SDK's `DraftMessage`. `attachments` carries `AttachmentModel` directly so
/// the input bar's media strip can be handed over in both directions without an extra hop.
public struct DraftMessage {

    /// The reply/edit target. A single optional plus a flag, rather than an action enum, because
    /// the two states are mutually exclusive and only meaningful with a message attached.
    public struct Target {
        public let message: ChatMessage
        public let isReply: Bool

        public init(message: ChatMessage, isReply: Bool) {
            self.message = message
            self.isReply = isReply
        }
    }

    public let channelId: ChannelId
    /// The next *new* message being composed.
    public var body: NSAttributedString?
    /// The in-progress text of a message being edited. Kept apart from `body` so a pending edit
    /// never becomes the channel list's "Draft:" preview, and so cancelling a restored edit falls
    /// back to `body`.
    public var editBody: NSAttributedString?
    public var createdAt: Date?
    public var target: Target?
    public var attachments: [AttachmentModel]
    /// A recorded-but-unsent voice message. A separate slot from `attachments` because the input
    /// bar keeps it in its own play/send preview, not in the media strip.
    public var voiceRecording: AttachmentModel?
    public var viewOnce: Bool

    public init(
        channelId: ChannelId,
        body: NSAttributedString? = nil,
        editBody: NSAttributedString? = nil,
        createdAt: Date? = nil,
        target: Target? = nil,
        attachments: [AttachmentModel] = [],
        voiceRecording: AttachmentModel? = nil,
        viewOnce: Bool = false
    ) {
        self.channelId = channelId
        self.body = body
        self.editBody = editBody
        self.createdAt = createdAt
        self.target = target
        self.attachments = attachments
        self.voiceRecording = voiceRecording
        self.viewOnce = viewOnce
    }

    /// Whether anything is worth keeping. A bare reply/edit target counts — tapping Reply and
    /// leaving without typing is still intent. Matches Android's `DraftMessage.hasContent()`.
    public var hasContent: Bool {
        !bodyIsBlank || !attachments.isEmpty || voiceRecording != nil || target != nil
    }

    /// The composed new message, blank normalized away. This is what is stored and restored — in
    /// edit mode it is the draft parked behind the edit, which cancelling falls back to.
    public var normalizedBody: NSAttributedString? {
        Self.nonBlank(body)
    }

    /// The text the channel list previews.
    ///
    /// While a message is being edited that is the edit itself, not the draft parked behind it:
    /// the cell should show what the user is actually working on. The parked draft is still kept
    /// in `body` — it is just not what the list shows.
    public var channelListBody: NSAttributedString? {
        if let target, !target.isReply {
            return Self.nonBlank(editBody)
        }
        return normalizedBody
    }

    private var bodyIsBlank: Bool {
        Self.nonBlank(body) == nil
    }

    private static func nonBlank(_ value: NSAttributedString?) -> NSAttributedString? {
        guard let value,
              !value.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return value
    }
}
