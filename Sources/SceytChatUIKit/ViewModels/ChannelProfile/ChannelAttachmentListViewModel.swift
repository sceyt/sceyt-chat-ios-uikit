//
//  ChannelAttachmentListViewModel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Combine
import Foundation
import SceytChat
import UIKit

open class ChannelAttachmentListViewModel: NSObject {
    public let sectionNameKeyPath: String?
    public let channel: ChatChannel
    public let attachmentTypes: [String]
    public let provider: ChannelAttachmentProvider
    public lazy var messageProvider: ChannelMessageProvider = Components.channelMessageProvider
        .init(channelId: channel.id)
    public var appearance: MessageCell.Appearance
    @Published public var event: Event?
    private let downloadQueue = DispatchQueue(label: "com.sceytchat.uikit.attachments", qos: .userInitiated)

    public var thumbnailSize: CGSize = .init(width: 40, height: 40) {
        didSet {
            guard thumbnailSize != oldValue,
                  attachmentObserver.isObserverStarted else { return }
            thumbnailCache.removeAll()
            for section in 0..<attachmentObserver.numberOfSections {
                for row in 0..<attachmentObserver.numberOfItems(in: section) {
                    if let layout = attachmentObserver.item(at: IndexPath(row: row, section: section)) {
                        layout.thumbnailSize = thumbnailSize
                        layout.resetThumbnail()
                    }
                }
            }
        }
    }
    public var minAutoDownloadSize = 10_000_000

    /// False until the first server page has reported back. While false, an empty list
    /// means "not loaded yet" rather than "nothing here", and the view keeps its empty
    /// state hidden.
    public private(set) var hasLoadedInitialAttachments = false
    private var isInitialServerPageRequested = false

    private let thumbnailCache = {
        $0.countLimit = 20
        return $0
    }(Cache<AttachmentId, UIImage?>())

    public required init(
        channel: ChatChannel,
        attachmentTypes: [String],
        sectionNameKeyPath: String? = "createdYearMonth",
        appearance: MessageCell.Appearance
    ) {
        self.sectionNameKeyPath = sectionNameKeyPath
        self.channel = channel
        self.attachmentTypes = attachmentTypes
        self.appearance = appearance
        provider = Components.channelAttachmentProvider
            .init(channelId: channel.id, attachmentTypes: attachmentTypes)
        provider.queryLimit = 20
        super.init()
    }

    open func loadAttachments() {
        attachmentObserver.loadNext()
        // Only the first page decides whether the list is genuinely empty; every later
        // call is pagination and must not re-arm the flag.
        guard !isInitialServerPageRequested else {
            provider.loadPrevAttachment()
            return
        }
        isInitialServerPageRequested = true
        provider.loadPrevAttachment(pageCompletion: { [weak self] fetchedCount, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let fetchedCount else {
                    // Nothing was requested (a page was already in flight) — let the
                    // next loadAttachments() own the initial page.
                    self.isInitialServerPageRequested = false
                    return
                }
                self.markInitialAttachmentsLoaded(didFetchItems: fetchedCount > 0)
            }
        })
    }

    /// Counterpart of `ChannelViewModel.markInitialMessagesLoaded()`: until this has run
    /// the view cannot tell "empty" from "still loading", so it shows no empty state.
    ///
    /// A failed fetch also lands here — an attempt that came back, even empty-handed, is
    /// what the empty state is waiting for; leaving the tab blank offline would be worse.
    open func markInitialAttachmentsLoaded(didFetchItems: Bool) {
        guard !hasLoadedInitialAttachments else { return }
        hasLoadedInitialAttachments = true
        // Items came back: the database observer is about to deliver them and that event
        // re-evaluates the empty state on its own. Nudging here would race the merge and
        // flash the placeholder over a list that is about to fill. Nothing came back: no
        // database change is coming, so this is the only chance to reveal it.
        guard !didFetchItems else { return }
        event = .change(.init(changeItems: []))
    }

    public typealias ChangeItemPaths = LazyDatabaseObserver<AttachmentDTO, MessageLayoutModel.AttachmentLayout>.ChangeItemPaths

    open lazy var attachmentObserver: LazyDatabaseObserver<AttachmentDTO, MessageLayoutModel.AttachmentLayout> = {
        let predicate: NSPredicate
        if attachmentTypes.isEmpty {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
//                NSPredicate(format: "message != nil", channel.id, channel.id),
                NSPredicate(format: "channelId == %lld", channel.id),
                NSPredicate(format: "message.type != %@", ChatMessage.MessageType.viewOnce)
            ])
        } else {
            predicate =
                NSCompoundPredicate(andPredicateWithSubpredicates: [
//                NSPredicate(format: "message != nil", channel.id, channel.id),
                    NSPredicate(format: "channelId == %lld", channel.id),
                    NSCompoundPredicate(orPredicateWithSubpredicates:
                        attachmentTypes.map { NSPredicate(format: "type = %@", $0) }
                    ),
                    NSPredicate(format: "message.type != %@", ChatMessage.MessageType.viewOnce)
                ])
        }

        let channel = self.channel
        let appearance = self.appearance
        return LazyDatabaseObserver<AttachmentDTO, MessageLayoutModel.AttachmentLayout>(
            context: SceytChatUIKit.shared.database.backgroundReadOnlyObservableContext,
            sortDescriptors: [.init(keyPath: \AttachmentDTO.createdAt, ascending: false),
                              .init(keyPath: \AttachmentDTO.id, ascending: false)],
            sectionNameKeyPath: sectionNameKeyPath,
            fetchPredicate: predicate,
            relationshipKeyPathsObserver: []
        ) { [weak self] in
            let attachment = $0.convert()
            if let prevItem = self?.attachmentObserver.item(for: $0.objectID) {
                prevItem.update(attachment: attachment)
                if let message = $0.message?.convert() {
                    prevItem.updateMessageIfNeeded(ownerMessage: message)
                }
                return prevItem
            }
            return MessageLayoutModel
                .AttachmentLayout(
                    attachment: attachment,
                    ownerMessage: $0.message?.convert(),
                    ownerChannel: channel,
                    thumbnailSize: self?.thumbnailSize ?? CGSize(width: 40, height: 40),
                    onLoadThumbnail: { [weak self] in
                        self?.cacheThumbnail($0, for: attachment)
                    },
                    asyncLoadThumbnail: true,
                    appearance: appearance
                )
        }

    }()

    open func startDatabaseObserver() {
        attachmentObserver.onDidChange = { [weak self] _, paths, _ in
            self?.onDidChangeEvent(items: paths)
        }
        do {
            try attachmentObserver.startObserver(fetchLimit: Int(provider.queryLimit))
        } catch {
            logger.errorIfNotNil(error, "observer.startObserver")
        }
    }

    open func onDidChangeEvent(items: ChangeItemPaths) {
        event = .change(items)
    }

    open func attachmentLayout(at indexPath: IndexPath,
                               onLoadThumbnail: ((MessageLayoutModel.AttachmentLayout) -> Void)? = nil,
                               onLoadLinkMetadata: ((LinkMetadata?) -> Void)? = nil) -> MessageLayoutModel.AttachmentLayout?
    {
        let attachmentLayout = attachmentObserver.item(at: indexPath)
        if let attachmentLayout {
            let attachment = attachmentLayout.attachment
            if let onLoadThumbnail {
                attachmentLayout.onLoadThumbnail = { [weak self, weak attachmentLayout] image in
                    self?.cacheThumbnail(image, for: attachment)
                    guard let attachmentLayout else { return }
                    onLoadThumbnail(attachmentLayout)
                }
            }

            if let onLoadLinkMetadata,
               let urlStr = attachment.url,
               let url = URL(string: urlStr)?.normalizedURL {
                if let metadata = LinkMetadataProvider.default.metadata(for: url) {
                    logger.debug("[LONK LOAD] HAS META \(url)")
                    onLoadLinkMetadata(metadata)
                } else {
                    loadLinkMetadata(url: url, for: attachmentLayout, completion: onLoadLinkMetadata)
                }
            }
        }
        return attachmentLayout
    }

    /// Resolves link metadata from the local stores first (memory cache, then DB — no
    /// network); only on a full miss asks the backend and persists the result, so the
    /// next launch is served from the DB. Without the persist step, metadata resolved
    /// from this screen would be refetched over the network on every launch.
    open func loadLinkMetadata(url: URL,
                               for attachmentLayout: MessageLayoutModel.AttachmentLayout,
                               completion: @escaping (LinkMetadata?) -> Void) {
        LinkMetadataProvider.default.fetchFromCacheOrDB(url: url) { [weak self] metadata in
            if let metadata {
                completion(metadata)
                return
            }
            LinkMetadataProvider.default.fetch(url: url) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let metadata):
                        completion(metadata)
                        self?.storeLinkMetadata(metadata, for: attachmentLayout)
                    case .failure:
                        completion(nil)
                    }
                }
            }
        }
    }

    /// Persists network-resolved metadata (images to disk, fields to `LinkMetadataDTO`)
    /// attached to the owner message — the same mechanism `ChannelViewModel` uses when a
    /// preview resolves in a message cell.
    open func storeLinkMetadata(_ metadata: LinkMetadata, for layout: MessageLayoutModel.AttachmentLayout) {
        getMessage(layout) { [weak self] message in
            guard let self, let message else { return }
            self.messageProvider.storeLinkMetadata(metadata, to: message)
        }
    }

    open var numberOfSections: Int {
        attachmentObserver.numberOfSections
    }

    open func numberOfAttachments(in section: Int) -> Int {
        attachmentObserver.numberOfItems(in: section)
    }

    open func downloadAttachmentIfNeeded(
        _ layout: MessageLayoutModel.AttachmentLayout,
        completion: ((MessageLayoutModel.AttachmentLayout) -> Void)? = nil
    ) {
        let attachment = layout.attachment
        downloadQueue.async { [weak self] in
            guard let self
            else {
                DispatchQueue.main.async {
                    completion?(layout)
                }
                return
            }

            // The video poster is a separate, tiny fetch, so it runs ahead of the
            // auto-download gate below — a video that won't auto-download (over the
            // size limit, or a paused/failed transfer waiting for a tap) is exactly
            // the case where the grid would otherwise sit on the blurred thumbHash
            // indefinitely.
            self.downloadVideoThumbnailIfNeeded(layout)

            guard shouldAutoDownload(attachment),
                  // A stored `.done` is not proof the bytes are still there (cache
                  // eviction, restored backup), and a stored `.pending` is not proof
                  // they are missing. The file itself is the authority.
                  fileProvider.filePath(attachment: attachment) == nil
            else {
                DispatchQueue.main.async {
                    completion?(layout)
                }
                return
            }

            self.getMessage(layout) { message in
                if let message {
                    fileProvider
                        .downloadMessageAttachments(
                            message: message,
                            attachments: [attachment]
                        ) { message, error in
                            if let attachment = message?.attachments?.first(where: { $0.id == attachment.id }) {
                                layout.update(attachment: attachment)
                            } else if let error {
                                logger.errorIfNotNil(error, "Download Channel profile attachment")
                            }
                            DispatchQueue.main.async {
                                completion?(layout)
                            }
                        }
                }
            }
        }
    }

    /// Fetches the small "video_thumb" poster so a video that is not downloaded yet
    /// still previews sharply in the grid. Independent of the video transfer itself:
    /// it must happen even when the video won't be (or hasn't been) downloaded.
    ///
    /// The cheap `needsVideoThumbnailDownload` pre-check comes first because
    /// `getMessage` falls back to a database fetch when the layout carries no owner
    /// message — this runs for every bound cell, and for images and already-posted
    /// videos there is nothing to fetch.
    open func downloadVideoThumbnailIfNeeded(_ layout: MessageLayoutModel.AttachmentLayout) {
        let attachment = layout.attachment
        guard fileProvider.needsVideoThumbnailDownload(attachment: attachment)
        else { return }
        getMessage(layout) { message in
            guard let message else { return }
            fileProvider.downloadVideoThumbnailsIfNeeded(
                message: message,
                attachments: [attachment]
            )
        }
    }

    open func resumeDownload(_ layout: MessageLayoutModel.AttachmentLayout) {
        let attachment = layout.attachment
        guard attachment.type != "link"
        else { return }
        if fileProvider.filePath(attachment: attachment) != nil {
            let done = ChatMessage.Attachment.TransferStatus.done.rawValue
            DataProvider.database.write {
                // Skip the same-value write: Core Data would still mark the object
                // dirty and emit an update event for a no-op reconcile.
                guard let dto = AttachmentDTO.fetch(id: attachment.id, context: $0),
                      dto.status != done
                else { return }
                dto.status = done
            } completion: { error in
                logger.errorIfNotNil(error, "")
            }
            attachment.status = .done
            AttachmentTransferStatusRelay.default.post(attachment, status: .done)
            return
        }
        getMessage(layout) { message in
            if let message {
                fileProvider.resumeTransfer(message: message, attachment: attachment) {
                    if !$0 {
                        fileProvider
                            .downloadMessageAttachments(
                                message: message,
                                attachments: [attachment]
                            )
                    }
                }
            }
        }
    }

    open func pauseDownload(_ layout: MessageLayoutModel.AttachmentLayout) {
        let attachment = layout.attachment

        getMessage(layout) { message in
            if let message {
                fileProvider.stopTransfer(message: message, attachment: attachment) { stopped in
                    // stopTransfer persists the paused status itself whenever it had
                    // something to stop. False means there was no live task and the
                    // status is not a transfer state — e.g. the download already
                    // finished — and stamping `.pauseDownloading` over it would mark
                    // a completed attachment as paused.
                    guard stopped else { return }
                    DataProvider.database.write {
                        let attachmentDTO = AttachmentDTO.fetch(id: attachment.id, context: $0)
                        attachmentDTO?.status = ChatMessage.Attachment.TransferStatus.pauseDownloading.rawValue
                    } completion: { error in
                        logger.errorIfNotNil(error, "")
                    }
                }
            }
        }
    }
    
    open func getMessage(_ layout: MessageLayoutModel.AttachmentLayout, completion: @escaping ((ChatMessage?) -> Void)) {
        if let message = layout.ownerMessage {
            completion(message)
        } else {
            ChannelMessageProvider.fetchMessage(id: layout.attachment.messageId) { message in
                completion(message)
            }
        }
    }

    open func thumbnail(for attachment: ChatMessage.Attachment?) -> UIImage? {
        guard let attachment else { return nil }
        return thumbnailCache[attachment.id] ?? nil
    }

    open func cacheThumbnail(_ thumbnail: UIImage?, for attachment: ChatMessage.Attachment) {
        thumbnailCache[attachment.id] = thumbnail
    }
}

public extension ChannelAttachmentListViewModel {
    enum Event {
        case change(ChangeItemPaths)
    }
}

// MARK: - Protocol

public protocol ChannelAttachmentListViewModelProviding: AnyObject {
    var numberOfSections: Int { get }
    func numberOfAttachments(in section: Int) -> Int
    var thumbnailSize: CGSize { get set }
    var minAutoDownloadSize: Int { get }
    func startDatabaseObserver()
    func stopDatabaseObserver()
    func loadAttachments()
    func attachmentLayout(
        at indexPath: IndexPath,
        onLoadThumbnail: ((MessageLayoutModel.AttachmentLayout) -> Void)?,
        onLoadLinkMetadata: ((LinkMetadata?) -> Void)?
    ) -> MessageLayoutModel.AttachmentLayout?
    func downloadAttachmentIfNeeded(
        _ layout: MessageLayoutModel.AttachmentLayout,
        completion: ((MessageLayoutModel.AttachmentLayout) -> Void)?
    )
    /// Whether `downloadAttachmentIfNeeded` would start a transfer for this attachment,
    /// assuming its bytes are not already on disk (callers check that separately).
    func shouldAutoDownload(_ attachment: ChatMessage.Attachment) -> Bool
    func resumeDownload(_ layout: MessageLayoutModel.AttachmentLayout)
    func pauseDownload(_ layout: MessageLayoutModel.AttachmentLayout)
    var eventPublisher: AnyPublisher<ChannelAttachmentListViewModel.Event?, Never> { get }
    /// Filters the attachment list by text query and/or sender. Both filters are applied together when provided.
    /// - Parameters:
    ///   - query: Optional text to match against the owning message's body (case- and diacritic-insensitive).
    ///   - filterUser: When set, only attachments sent by this user are shown.
    func search(query: String?, filterUser: ChatUser?)
    /// Returns true when any filter (user or query) is currently active.
    var isFiltered: Bool { get }
    /// Returns false when the last load returned no new items (end of data reached).
    var hasMore: Bool { get }
    /// See `ChannelAttachmentListViewModel.hasLoadedInitialAttachments`. While false the
    /// view treats an empty list as "still loading" and keeps its empty state hidden.
    var hasLoadedInitialAttachments: Bool { get }
}

public extension ChannelAttachmentListViewModelProviding {
    /// The cell binding asks this the moment a cell is dequeued, to decide whether to
    /// put the progress ring up *before* the transfer produces its first byte. Keeping
    /// it as the one predicate both the view and `downloadAttachmentIfNeeded` consult
    /// is what stops the two from disagreeing — a cell that auto-downloads with no
    /// overlay, or an overlay spinning on an attachment nobody is fetching.
    func shouldAutoDownload(_ attachment: ChatMessage.Attachment) -> Bool {
        guard attachment.type != "link",
              minAutoDownloadSize <= 0 || attachment.uploadedFileSize <= minAutoDownloadSize
        else { return false }
        switch attachment.status {
        case .pauseDownloading, .failedDownloading, .failedUploading:
            // Paused and failed transfers wait for an explicit tap.
            return false
        default:
            return true
        }
    }

    var hasMore: Bool { true }
    /// View models that serve the database only have nothing to wait for, so their empty
    /// state is meaningful from the start.
    var hasLoadedInitialAttachments: Bool { true }
    func search(query: String?, filterUser: ChatUser?) {}
    func stopDatabaseObserver() {}
    var isFiltered: Bool { false }
    func attachmentLayout(at indexPath: IndexPath) -> MessageLayoutModel.AttachmentLayout? {
        attachmentLayout(at: indexPath, onLoadThumbnail: nil, onLoadLinkMetadata: nil)
    }
    func attachmentLayout(
        at indexPath: IndexPath,
        onLoadThumbnail: ((MessageLayoutModel.AttachmentLayout) -> Void)?
    ) -> MessageLayoutModel.AttachmentLayout? {
        attachmentLayout(at: indexPath, onLoadThumbnail: onLoadThumbnail, onLoadLinkMetadata: nil)
    }
    func attachmentLayout(
        at indexPath: IndexPath,
        onLoadLinkMetadata: ((LinkMetadata?) -> Void)?
    ) -> MessageLayoutModel.AttachmentLayout? {
        attachmentLayout(at: indexPath, onLoadThumbnail: nil, onLoadLinkMetadata: onLoadLinkMetadata)
    }
    func downloadAttachmentIfNeeded(_ layout: MessageLayoutModel.AttachmentLayout) {
        downloadAttachmentIfNeeded(layout, completion: nil)
    }
}

extension ChannelAttachmentListViewModel: ChannelAttachmentListViewModelProviding {
    public var eventPublisher: AnyPublisher<Event?, Never> { $event.eraseToAnyPublisher() }
}

// MARK: - Empty default

public extension ChannelAttachmentListViewModel {
    final class Empty: NSObject, ChannelAttachmentListViewModelProviding {
        public var numberOfSections: Int { 0 }
        public func numberOfAttachments(in section: Int) -> Int { 0 }
        public var thumbnailSize: CGSize = .zero
        public var minAutoDownloadSize: Int = 0
        public func startDatabaseObserver() {}
        public func loadAttachments() {}
        public func attachmentLayout(
            at indexPath: IndexPath,
            onLoadThumbnail: ((MessageLayoutModel.AttachmentLayout) -> Void)?,
            onLoadLinkMetadata: ((LinkMetadata?) -> Void)?
        ) -> MessageLayoutModel.AttachmentLayout? { nil }
        public func downloadAttachmentIfNeeded(
            _ layout: MessageLayoutModel.AttachmentLayout,
            completion: ((MessageLayoutModel.AttachmentLayout) -> Void)?
        ) {}
        public func resumeDownload(_ layout: MessageLayoutModel.AttachmentLayout) {}
        public func pauseDownload(_ layout: MessageLayoutModel.AttachmentLayout) {}

        private let eventSubject = PassthroughSubject<ChannelAttachmentListViewModel.Event?, Never>()
        public var eventPublisher: AnyPublisher<ChannelAttachmentListViewModel.Event?, Never> {
            eventSubject.eraseToAnyPublisher()
        }
    }
}
