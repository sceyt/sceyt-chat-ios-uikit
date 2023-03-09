//
//  ChannelMediaListVM.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class ChannelAttachmentListVM: NSObject {

    public let channel: ChatChannel
    public let attachmentTypes: [String]
    public let provider: ChannelAttachmentProvider
    @Published open var event: Event?
    private let downloadQueue = DispatchQueue(label: "com.sceytchat.uikit.attachments", qos: .userInitiated)
    
    public required init(
        channel: ChatChannel,
        attachmentTypes: [String]) {
            self.channel = channel
            self.attachmentTypes = attachmentTypes
            provider = .init(channelId: channel.id, attachmentTypes: attachmentTypes)
            super.init()
        }
    
    open func loadAttachments() {
        provider.loadPrevAttachment()
    }

    open lazy var attachmentObserver: DatabaseObserver<AttachmentDTO, ChatMessage.Attachment> = {
        let predicate: NSPredicate
        if attachmentTypes.isEmpty {
            predicate = .init(format: "message.ownerChannel.id == %lld", channel.id)
        } else {
            predicate =
            NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "message.ownerChannel.id == %lld", channel.id),
                NSCompoundPredicate(orPredicateWithSubpredicates:
                                        attachmentTypes.map { NSPredicate(format: "type = %@", $0) }
                                   )
            ])
        }

        return DatabaseObserver<AttachmentDTO, ChatMessage.Attachment>(
            request: AttachmentDTO.fetchRequest()
                .sort(descriptors: [.init(keyPath: \AttachmentDTO.message?.id, ascending: false)])
                .fetch(predicate: predicate),
            context: Config.database.viewContext
        ) { $0.convert() }
    }()
   
    open func startDatabaseObserver() {
        attachmentObserver.onDidChange = {[weak self] in
            self?.onDidChangeEvent(items: $0)
        }
        do {
            try attachmentObserver.startObserver()
        } catch {
            debugPrint("observer.startObserver", error)
        }
    }

    open func onDidChangeEvent(items: DBChangeItemPaths) {
        event = .change(items)
    }

    open func attachment(at indexPath: IndexPath) -> ChatMessage.Attachment? {
        attachmentObserver.item(at: indexPath)
    }

    open var numberOfAttachments: Int {
        attachmentObserver.numberOfItems(in: 0)
    }
    
    open func downloadAttachmentIfNeeded(_ attachment: ChatMessage.Attachment) {
        guard attachment.status != .done,
                attachment.status != .failedDownloading,
                attachment.status != .failedUploading,
              fileProvider.filePath(attachment: attachment) == nil
        else { return }
        downloadQueue.async {
            guard let chatMessage = try? Provider.database.read ({
                try? MessageDTO.fetch(id: attachment.messageId, context: $0)?
                    .convert()
            }).get()
            else { return }
            
            fileProvider
                .downloadMessageAttachments(
                    message: chatMessage,
                    attachments: [attachment]
                )
        }
        
    }
}

public extension ChannelAttachmentListVM {

    enum Event {
        case change(DBChangeItemPaths)
    }
}
