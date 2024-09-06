//
//  AttachmentPreviewDataSource.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public protocol AttachmentPreviewDataSourceDelegate: AnyObject {
    func canShowPreviewer() -> Bool
}

public protocol PreviewDataSource: AnyObject {
    var numberOfImages: Int { get }
    var isLoading: Bool { get }
    func previewItem(at index: Int) -> PreviewItem?
    func indexOfItem(_ item: PreviewItem) -> Int?
    func canShowPreviewer() -> Bool
    func setOnLoading(_ callback: @escaping (Bool) -> Void)
    func setOnReload(_ callback: @escaping () -> Void)
    func observe(_ observable: PreviewDataSourceItemObservable)
}

public protocol PreviewDataSourceItemObservable: AnyObject {
    
    var previewItem: PreviewItem { get }
    
    func didUpdate(previewItem: PreviewItem)
}

open class AttachmentPreviewDataSource: PreviewDataSource {
    
    private var ascending: Bool
    public let provider: ChannelAttachmentProvider
    private let downloadQueue = DispatchQueue(label: "com.sceytchat.uikit.attachments", qos: .userInitiated)
    
    private var observersCache = [PreviewItem: PreviewDataSourceItemObservable]()
    
    open lazy var attachmentObserver: DatabaseObserver<AttachmentDTO, ChatMessage.Attachment> = {
        let predicate: NSPredicate
        if attachmentTypes.isEmpty {
            predicate = .init(format: "channelId == %lld", channel.id)
        } else {
            predicate =
                NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "channelId == %lld", channel.id),
                    NSCompoundPredicate(orPredicateWithSubpredicates:
                        attachmentTypes.map { NSPredicate(format: "type = %@", $0) }
                    )
                ])
        }

        return DatabaseObserver<AttachmentDTO, ChatMessage.Attachment>(
            request: AttachmentDTO.fetchRequest()
                .sort(descriptors: [.init(keyPath: \AttachmentDTO.createdAt, ascending: ascending),
                    .init(keyPath: \AttachmentDTO.id, ascending: ascending)])
                .fetch(predicate: predicate)
                .fetch(batchSize: 10),
            context: SceytChatUIKit.shared.config.database.viewContext
        ) { $0.convert() }
    }()

    public var channel: ChatChannel
    public let attachmentTypes: [String]
    public weak var delegate: AttachmentPreviewDataSourceDelegate?
    private var onLoading: ((Bool) -> Void)?
    private var onReload: (() -> Void)?
    
    public init(
        channel: ChatChannel,
        attachmentTypes: [String] = ["image", "video"],
        ascending: Bool = false
    ) {
        self.channel = channel
        self.attachmentTypes = attachmentTypes
        self.ascending = ascending
        provider = Components.channelAttachmentProvider
            .init(channelId: channel.id, attachmentTypes: attachmentTypes)
        provider.queryLimit = 30
        do {
            try attachmentObserver.startObserver(fetchedAllObjects: false)
        } catch {
            logger.errorIfNotNil(error, "observer.startObserver")
        }

        attachmentObserver.onDidChange = { [weak self] in
            self?.onDidChangeEvent(items: $0)
        }
//        loadAttachments()
    }

    open func onDidChangeEvent(items: DBChangeItemPaths) {
        for indexPath in items.updates {
            if let attachment = attachmentObserver.item(at: indexPath) {
                let item = PreviewItem.attachment(attachment)
                if let value = observersCache[item] {
                    value.didUpdate(previewItem: item)
                }
            }
        }
        
        if !items.inserts.isEmpty {
            onReload?()
        }
    }
    
    open func loadAttachments() {
        provider.loadPrevAttachment {[weak self] error in
            if let self {
                self.onLoading?(error == nil)
            }
        }
    }

    public func canShowPreviewer() -> Bool {
        delegate?.canShowPreviewer() ?? (numberOfImages != 0)
    }

    public var numberOfImages: Int {
        attachmentObserver.numberOfItems(in: 0)
    }
    
    public var isLoading: Bool {
        provider.defaultQuery.loading
    }
    
    public func setOnLoading(_ callback: @escaping (Bool) -> Void) {
        onLoading = callback
    }
    
    public func setOnReload(_ callback: @escaping () -> Void) {
        onReload = callback
        loadAttachments()
    }

    public func previewItem(at index: Int) -> PreviewItem? {
        if index < 3 || index > numberOfImages - 3, !isLoading, provider.defaultQuery.hasNext {
            loadAttachments()
        }
        if let item = attachmentObserver.item(at: IndexPath(row: index, section: 0)) {
            return .attachment(item)
        }
        return nil
    }

    public func indexOfItem(_ item: PreviewItem) -> Int? {
        for index in 0 ..< attachmentObserver.numberOfItems(in: 0) {
            if let attachment = attachmentObserver.item(at: IndexPath(row: index, section: 0)),
               attachment == item.attachment {
                return index
            }
        }
        return nil
    }

    static func senderTitle(attachment: ChatMessage.Attachment) -> String {
        if me == attachment.userId {
            return L10n.User.current
        } else if let user = attachment.user {
            return SceytChatUIKit.shared.formatters.userNameFormatter.format(user)
        } else {
            return ""
        }
    }
    
    open func observe(_ observable: PreviewDataSourceItemObservable) {
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
            guard let chatMessage = try? Provider.database.read ({
                MessageDTO.fetch(id: attachment.messageId, context: $0)?
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
