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

/// Optional hook for data sources that need to inject context-specific
/// actions between "Save" and "Forward" in the preview share sheet.
public protocol PreviewShareActionProviding: AnyObject {
    func previewShareTopActions(previewItem: PreviewItem) -> [SheetAction]
}

open class SingleItemPreviewDataSource: PreviewDataSource {
    private let item: PreviewItem
    public weak var delegate: AttachmentPreviewDataSourceDelegate?

    public init(item: PreviewItem) {
        self.item = item
    }

    public var numberOfImages: Int { 1 }
    public var isLoading: Bool { false }

    public func previewItem(at index: Int) -> PreviewItem? {
        index == 0 ? item : nil
    }

    public func indexOfItem(_ item: PreviewItem) -> Int? {
        item == self.item ? 0 : nil
    }

    public func canShowPreviewer() -> Bool {
        delegate?.canShowPreviewer() ?? true
    }

    public func setOnLoading(_ callback: @escaping (Bool) -> Void) {}
    public func setOnReload(_ callback: @escaping () -> Void) {}
    public func observe(_ observable: PreviewDataSourceItemObservable) {}
}

open class AttachmentPreviewDataSource: PreviewDataSource {
    
    private var ascending: Bool
    public let provider: ChannelAttachmentProvider
    private let downloadQueue = DispatchQueue(label: "com.sceytchat.uikit.attachments", qos: .userInitiated)
    
    private var observersCache = [PreviewItem: PreviewDataSourceItemObservable]()
    
    /// The observer's scope: this channel, the requested attachment types, and never
    /// view-once media. Named and computed so refresh paths can re-apply it — clearing
    /// the predicate instead widens the previewer to every attachment in the database,
    /// across all channels.
    open var defaultFetchPredicate: NSPredicate {
        var subpredicates = [NSPredicate(format: "channelId == %lld", channel.id)]
        if !attachmentTypes.isEmpty {
            subpredicates.append(
                NSCompoundPredicate(orPredicateWithSubpredicates:
                    attachmentTypes.map { NSPredicate(format: "type = %@", $0) }
                )
            )
        }
        subpredicates.append(NSPredicate(format: "message.type != %@", ChatMessage.MessageType.viewOnce))
        return NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
    }

    open lazy var attachmentObserver: DatabaseObserver<AttachmentDTO, ChatMessage.Attachment> = {
        DatabaseObserver<AttachmentDTO, ChatMessage.Attachment>(
            request: AttachmentDTO.fetchRequest()
                .sort(descriptors: [.init(keyPath: \AttachmentDTO.createdAt, ascending: ascending),
                    .init(keyPath: \AttachmentDTO.id, ascending: ascending)])
                .fetch(predicate: defaultFetchPredicate)
                .fetch(batchSize: 10),
            context: SceytChatUIKit.shared.database.viewContext
        ) { $0.convert() }
    }()

    /// Re-runs the observer's fetch against `defaultFetchPredicate`. Needed after another
    /// process (share extension / notification service extension) writes attachments into
    /// the shared store: `NSPersistentStoreRemoteChange` is disabled, so the fetched-results
    /// controller never learns that the rows on disk changed.
    ///
    /// Never clear the predicate to force a refresh — the predicate is the only thing
    /// scoping the previewer to this channel, its types, and non-view-once media.
    open func refreshObserver() {
        do {
            try attachmentObserver.update(predicate: defaultFetchPredicate)
        } catch {
            logger.errorIfNotNil(error, "attachmentObserver.update(predicate:)")
        }
    }

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
        let count = attachmentObserver.numberOfItems(in: 0)

        // First pass: exact match (works once the server has assigned a real id)
        for index in 0..<count {
            if let attachment = attachmentObserver.item(at: IndexPath(row: index, section: 0)),
               attachment == item.attachment {
                return index
            }
        }

        // Second pass: the attachment was still pending (id == 0) when setupPreviewer()
        // stored it in the tap recognizer. By tap time the DB has the real id, so the
        // exact match above fails. Fall back to matching by URL so we open the correct media.
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

    static func senderTitle(attachment: ChatMessage.Attachment) -> String {
        if SceytChatUIKit.shared.currentUserId == attachment.userId {
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
            guard let chatMessage = try? DataProvider.database.read ({
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
