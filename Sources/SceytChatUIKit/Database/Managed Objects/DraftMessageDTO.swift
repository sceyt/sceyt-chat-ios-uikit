//
//  DraftMessageDTO.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import CoreData
import Foundation
import Photos
import UIKit
import SceytChat

/// The full message-input state for one channel, so reopening a channel restores the bar the
/// user left behind — not just the typed text.
///
/// A channel-scoped side table keyed by a plain `channelId`, the same shape as
/// `ChannelSyncStateDTO` / `PendingMessageDeleteDTO` / `LoadRangeDTO`. There is deliberately no
/// relationship to `ChannelDTO` or `MessageDTO`: both are batch-deleted elsewhere
/// (`DeleteChannelsOperation`, `MessageDatabaseSession.deleteAllMessages`) and
/// `NSBatchDeleteRequest` does not honour deletion rules, so a relationship would leave dangling
/// references — the crash documented in `ChannelDatabaseSession.deleteMembers`.
///
/// `ChannelDTO.draft`/`draftDate` stay as the denormalized projection the channel list reads and
/// sorts by; this row is read only when the channel screen opens.
@objc(DraftMessageDTO)
public class DraftMessageDTO: NSManagedObject {

    @NSManaged public var channelId: Int64
    /// The next *new* message being composed. Mirrored into `ChannelDTO.draft`.
    @NSManaged public var body: NSAttributedString?
    /// The in-progress text of a message being edited. `body` keeps holding the pre-edit draft —
    /// the persisted twin of `MessageInputViewController.cachedMessage` — so cancelling a restored
    /// edit falls back to it.
    @NSManaged public var editBody: NSAttributedString?
    @NSManaged public var createdAt: CDDate?
    /// `true` reply, `false` edit. Only meaningful when a target is set.
    @NSManaged public var isReply: Bool
    /// `0` means no action. Resolved against the store on restore, so a deleted target simply
    /// drops the action.
    @NSManaged public var targetMessageId: Int64
    /// Addresses a pending target, which has `id == 0` and is reachable only by tid.
    @NSManaged public var targetMessageTid: Int64
    @NSManaged public var viewOnce: Bool

    @NSManaged public var attachments: Set<DraftAttachmentDTO>?

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<DraftMessageDTO> {
        return NSFetchRequest<DraftMessageDTO>(entityName: entityName)
    }

    public static func fetch(channelId: ChannelId, context: NSManagedObjectContext) -> DraftMessageDTO? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "channelId == %lld", channelId)
        request.fetchLimit = 1
        return fetch(request: request, context: context).first
    }

    public static func fetchOrCreate(channelId: ChannelId, context: NSManagedObjectContext) -> DraftMessageDTO {
        if let mo = fetch(channelId: channelId, context: context) {
            return mo
        }
        let mo = insertNewObject(into: context)
        mo.channelId = Int64(channelId)
        return mo
    }

    public static func delete(channelId: ChannelId, context: NSManagedObjectContext) {
        // Delete through the context so the Cascade rule clears the attachment rows.
        guard let mo = fetch(channelId: channelId, context: context) else { return }
        context.delete(mo)
    }

    /// Moves a draft when a locally created channel is assigned its server id. Newest
    /// `createdAt` wins, matching the Android SDK's `MigratePendingChannelToRealChannelUseCase`.
    public static func move(
        fromChannelId oldChannelId: ChannelId,
        toChannelId newChannelId: ChannelId,
        context: NSManagedObjectContext
    ) {
        guard oldChannelId != newChannelId,
              let source = fetch(channelId: oldChannelId, context: context)
        else { return }

        if let destination = fetch(channelId: newChannelId, context: context) {
            let sourceDate = source.createdAt?.bridgeDate ?? .distantPast
            let destinationDate = destination.createdAt?.bridgeDate ?? .distantPast
            guard sourceDate >= destinationDate else {
                context.delete(source)
                return
            }
            context.delete(destination)
        }

        source.channelId = Int64(newChannelId)
        source.attachments?.forEach { $0.channelId = Int64(newChannelId) }
    }

    /// Clears the reply/edit target while keeping the composed text — used when a channel's
    /// messages are wiped, so the target can no longer exist.
    public static func clearTarget(channelId: ChannelId, context: NSManagedObjectContext) {
        guard let mo = fetch(channelId: channelId, context: context) else { return }
        mo.targetMessageId = 0
        mo.targetMessageTid = 0
        mo.isReply = false
    }
}

extension DraftMessageDTO {

    /// Rebuilds the input-bar state, resolving the reply/edit target and the media strip against
    /// the same context — one DB hop for the whole draft.
    ///
    /// A target that no longer exists (or was deleted) yields a draft with no target rather than
    /// no draft: the typed text is never thrown away over a missing message. Attachments whose
    /// backing file has gone are skipped the same way; the stale rows are pruned by the next save,
    /// which rewrites the whole set.
    public func convert(context: NSManagedObjectContext) -> DraftMessage {
        DraftMessage(
            channelId: ChannelId(channelId),
            body: body,
            editBody: editBody,
            createdAt: createdAt?.bridgeDate,
            target: resolveTarget(context: context),
            attachments: resolveAttachments(),
            voiceRecording: resolveVoiceRecording(),
            viewOnce: viewOnce
        )
    }

    private func resolveTarget(context: NSManagedObjectContext) -> DraftMessage.Target? {
        let dto: MessageDTO?
        if targetMessageId != 0 {
            dto = MessageDTO.fetch(id: MessageId(targetMessageId), context: context)
        } else if targetMessageTid != 0 {
            dto = MessageDTO.fetch(tid: targetMessageTid, channelId: channelId, context: context)
        } else {
            return nil
        }
        guard let dto else { return nil }
        let message = dto.convert()
        guard message.state != .deleted else { return nil }
        return .init(message: message, isReply: isReply)
    }

    private func resolveAttachments() -> [AttachmentModel] {
        (attachments ?? [])
            .filter { !$0.isVoiceRecording }
            .sorted { $0.order < $1.order }
            .compactMap { $0.convert() }
    }

    /// `nil` when the recording's file is gone — it lives in the temp directory until it is sent,
    /// so iOS may have purged it since the draft was saved.
    private func resolveVoiceRecording() -> AttachmentModel? {
        (attachments ?? []).first { $0.isVoiceRecording }?.convert()
    }
}

extension DraftAttachmentDTO {

    /// `nil` when the backing file is gone — a purged temp recording, a document-picker URL that
    /// did not outlive the launch, or a deleted photo-library asset.
    public func convert() -> AttachmentModel? {
        guard let urlString = url, let url = URL(string: urlString) else { return nil }

        let asset = photoAssetLocalIdentifier.flatMap {
            PHAsset.fetchAssets(withLocalIdentifiers: [$0], options: nil).firstObject
        }

        if url.scheme == "local" {
            // Photo-library video, referenced by asset rather than copied to disk.
            guard let asset else { return nil }
            var model = AttachmentModel(
                mediaUrl: url,
                thumbnail: nil,
                imageSize: CGSize(width: Int(imageWidth), height: Int(imageHeight)),
                duration: Int(duration)
            )
            model.photoAsset = asset
            return model
        }

        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        switch type.map(AttachmentType.init(rawValue:)) ?? nil {
        case .voice:
            let metadata: ChatMessage.Attachment.Metadata<[Int]>
            if let raw = self.metadata,
               let decoded = try? ChatMessage.Attachment.Metadata<[Int]>.decode(raw)
            {
                metadata = decoded
            } else {
                metadata = .init(thumbnail: [], duration: Int(duration))
            }
            return AttachmentModel(voiceUrl: url, metadata: metadata)
        case .file:
            return AttachmentModel(fileUrl: url)
        default:
            var model = AttachmentModel(
                mediaUrl: url,
                thumbnail: nil,
                imageSize: CGSize(width: Int(imageWidth), height: Int(imageHeight)),
                duration: Int(duration)
            )
            model.photoAsset = asset
            return model
        }
    }

    /// Stores everything `AttachmentModel` cannot re-derive from the file itself. Voice amplitudes
    /// ride along in the metadata JSON, exactly as they do for a sent voice attachment.
    public func map(
        _ model: AttachmentModel,
        channelId: ChannelId,
        order: Int,
        isVoiceRecording: Bool = false
    ) {
        self.channelId = Int64(channelId)
        self.order = Int16(order)
        self.isVoiceRecording = isVoiceRecording
        url = model.url.absoluteString
        type = model.type.rawValue
        name = model.name
        fileSize = Int64(model.fileSize)
        imageWidth = Int64(model.imageWidth)
        imageHeight = Int64(model.imageHeight)
        duration = Int64(model.duration)
        photoAssetLocalIdentifier = model.photoAsset?.localIdentifier
        metadata = model.type == .voice
            ? ChatMessage.Attachment.Metadata(thumbnail: model.thumb, duration: model.duration).build()
            : nil
    }
}
