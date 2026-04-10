//
//  GlobalSearchMediaPreviewDataSource.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit on 09.04.26
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import UIKit

/// `PreviewDataSource` for the global-search Media tab initial state.
/// Observes all image/video attachments across every channel — no channelId filter.
open class GlobalSearchMediaPreviewDataSource: PreviewDataSource {

    public let attachmentTypes: [String]
    private let ascending: Bool
    private let downloadQueue = DispatchQueue(
        label: "com.sceytchat.uikit.globalSearchMediaPreview",
        qos: .userInitiated
    )
    private var observersCache = [PreviewItem: PreviewDataSourceItemObservable]()
    private var onLoading: ((Bool) -> Void)?
    private var onReload: (() -> Void)?

    open lazy var attachmentObserver: DatabaseObserver<AttachmentDTO, ChatMessage.Attachment> = {
        let predicate: NSPredicate
        if attachmentTypes.isEmpty {
            predicate = NSPredicate(
                format: "message.type != %@",
                ChatMessage.MessageType.viewOnce
            )
        } else {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSCompoundPredicate(orPredicateWithSubpredicates:
                    attachmentTypes.map { NSPredicate(format: "type = %@", $0) }
                ),
                NSPredicate(format: "message.type != %@", ChatMessage.MessageType.viewOnce)
            ])
        }

        return DatabaseObserver<AttachmentDTO, ChatMessage.Attachment>(
            request: AttachmentDTO.fetchRequest()
                .sort(descriptors: [
                    .init(keyPath: \AttachmentDTO.createdAt, ascending: ascending),
                    .init(keyPath: \AttachmentDTO.id,        ascending: ascending)
                ])
                .fetch(predicate: predicate)
                .fetch(batchSize: 20),
            context: SceytChatUIKit.shared.database.viewContext
        ) { $0.convert() }
    }()

    public required init(
        attachmentTypes: [String] = ["image", "video"],
        ascending: Bool = false
    ) {
        self.attachmentTypes = attachmentTypes
        self.ascending = ascending
        do {
            try attachmentObserver.startObserver(fetchedAllObjects: false)
        } catch {
            logger.errorIfNotNil(error, "GlobalSearchMediaPreviewDataSource observer.startObserver")
        }
        attachmentObserver.onDidChange = { [weak self] in
            self?.onDidChangeEvent(items: $0)
        }
    }

    open func onDidChangeEvent(items: DBChangeItemPaths) {
        for indexPath in items.updates {
            if let attachment = attachmentObserver.item(at: indexPath) {
                let item = PreviewItem.attachment(attachment)
                if let observer = observersCache[item] {
                    observer.didUpdate(previewItem: item)
                }
            }
        }
        if !items.inserts.isEmpty {
            onReload?()
        }
    }

    // MARK: - PreviewDataSource

    public var numberOfImages: Int {
        attachmentObserver.numberOfItems(in: 0)
    }

    public var isLoading: Bool { false }

    public func previewItem(at index: Int) -> PreviewItem? {
        guard let attachment = attachmentObserver.item(at: IndexPath(row: index, section: 0)) else {
            return nil
        }
        return .attachment(attachment)
    }

    public func indexOfItem(_ item: PreviewItem) -> Int? {
        let count = attachmentObserver.numberOfItems(in: 0)

        for index in 0..<count {
            if let attachment = attachmentObserver.item(at: IndexPath(row: index, section: 0)),
               attachment == item.attachment {
                return index
            }
        }

        // Fallback: pending attachment matched by URL
        if item.attachment.id == 0, let itemUrl = item.attachment.url, !itemUrl.isEmpty {
            for index in 0..<count {
                if let attachment = attachmentObserver.item(at: IndexPath(row: index, section: 0)),
                   attachment.url == itemUrl {
                    return index
                }
            }
        }

        return nil
    }

    public func canShowPreviewer() -> Bool {
        numberOfImages != 0
    }

    public func setOnLoading(_ callback: @escaping (Bool) -> Void) {
        onLoading = callback
    }

    public func setOnReload(_ callback: @escaping () -> Void) {
        onReload = callback
    }

    public func observe(_ observable: PreviewDataSourceItemObservable) {
        observersCache[observable.previewItem] = observable
        downloadAttachmentIfNeeded(observable.previewItem.attachment)
    }

    open func downloadAttachmentIfNeeded(_ attachment: ChatMessage.Attachment) {
        guard attachment.type != "link",
              attachment.status != .done,
              attachment.status != .failedDownloading,
              attachment.status != .failedUploading,
              fileProvider.filePath(attachment: attachment) == nil
        else { return }
        downloadQueue.async {
            guard let chatMessage = try? DataProvider.database.read({
                MessageDTO.fetch(id: attachment.messageId, context: $0)?.convert()
            }).get() else { return }
            fileProvider.downloadMessageAttachments(
                message: chatMessage,
                attachments: [attachment]
            )
        }
    }
}
