//
//  DraftAttachmentDTO.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import CoreData
import Foundation
import SceytChat

/// One chip of the message input's media strip, kept across channel opens.
///
/// Deliberately not `AttachmentDTO`: that entity is keyed to a `MessageDTO`, and its
/// `willSave`/`awakeFromFetch` rewrite `filePath` relative to `Components.storage.storageFolderPath`
/// — which would mangle both the synthetic `local:///local/<PHAsset id>` URLs the picker uses for
/// library videos and the temp-directory paths a fresh voice recording lives at.
@objc(DraftAttachmentDTO)
public class DraftAttachmentDTO: NSManagedObject {

    @NSManaged public var channelId: Int64
    /// Position in the strip. `selectedMediaView.items` is an ordered array, so the order has
    /// to be restored, not just the set.
    @NSManaged public var order: Int16
    /// Absolute URL string, including the `local:///local/<localIdentifier>` form.
    @NSManaged public var url: String?
    /// `AttachmentType` raw value.
    @NSManaged public var type: String?
    @NSManaged public var name: String?
    @NSManaged public var fileSize: Int64
    @NSManaged public var imageWidth: Int64
    @NSManaged public var imageHeight: Int64
    @NSManaged public var duration: Int64
    /// `ChatMessage.Attachment.Metadata<[Int]>.build()` JSON — this is where voice amplitudes
    /// live, mirroring `AttachmentDTO.metadata` for sent voice messages. A raw amplitude array
    /// is ~100 samples/second, so it does not belong in a column.
    @NSManaged public var metadata: String?
    @NSManaged public var photoAssetLocalIdentifier: String?
    /// `true` for a recorded-but-unsent voice message, which belongs in the recorder's play/send
    /// preview rather than the media strip. The two are separate slots in the input bar, so they
    /// have to stay separate here — the same split Android models as `draft_voice_attachment`.
    @NSManaged public var isVoiceRecording: Bool

    @NSManaged public var draft: DraftMessageDTO?

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<DraftAttachmentDTO> {
        return NSFetchRequest<DraftAttachmentDTO>(entityName: entityName)
    }

    public static func fetch(channelId: ChannelId, context: NSManagedObjectContext) -> [DraftAttachmentDTO] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "channelId == %lld", channelId)
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(DraftAttachmentDTO.order), ascending: true)]
        return fetch(request: request, context: context)
    }

    public static func deleteAll(channelId: ChannelId, context: NSManagedObjectContext) {
        fetch(channelId: channelId, context: context).forEach { context.delete($0) }
    }
}
