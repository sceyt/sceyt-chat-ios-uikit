//
//  AttachmentPreviewDataSource.swift
//  SceytChatUIKit
//

import UIKit

open class AttachmentPreviewDataSource: PreviewDataSource {

    private lazy var previewItems: [PreviewItem] = {
        getPreviewItems()
    }()
    private var ascending: Bool
    
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
                .sort(descriptors: [.init(keyPath: \AttachmentDTO.message?.id, ascending: ascending)])
                .fetch(predicate: predicate),
            context: Config.database.viewContext
        ) { $0.convert() }
    }()

    public var channel: ChatChannel
    public let attachmentTypes: [String]
    
    public init(
        channel: ChatChannel,
        attachmentTypes: [String] = ["image", "video"],
        ascending: Bool = false
    ) {
        self.channel = channel
        self.attachmentTypes = attachmentTypes
        self.ascending = ascending

        do {
            try attachmentObserver.startObserver()
        } catch {
            debugPrint("observer.startObserver", error)
        }

        attachmentObserver.onDidChange = {[weak self] in
            self?.onDidChangeEvent(items: $0)
        }
    }
    
    open func onDidChangeEvent(items: DBChangeItemPaths) {
        previewItems = getPreviewItems()
    }
    
    private func getPreviewItems() -> [PreviewItem] {
        let items: [ChatMessage.Attachment] = (0..<attachmentObserver.numberOfSection).flatMap { section in
            (0..<attachmentObserver.numberOfItems(in: section)).compactMap { row in
                attachmentObserver.item(at: IndexPath(row: row, section: section))
            }
        }

        return items.map { .attachment($0) }
    }

    public func numberOfImages() -> Int {
        previewItems.count
    }

    public func previewItem(at index: Int) -> PreviewItem {
        previewItems[index]
    }

    public func indexOfItem(_ item: PreviewItem) -> Int? {
        previewItems.firstIndex(of: item)
    }

    static func senderTitle(attachment: ChatMessage.Attachment) -> String {
        if me == attachment.userId {
            return L10n.User.current
        } else if let user = attachment.user {
            return Formatters.userDisplayName.format(user)
        } else {
            return ""
        }
    }
}
