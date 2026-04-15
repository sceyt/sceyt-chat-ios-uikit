//
//  GlobalSearchAllLinksViewModel.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit on 10.04.26
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Combine
import Foundation
import SceytChat
import UIKit

/// Loads all link attachments across every channel for the global-search Links tab.
/// - `allLinksObserver`: always-on, no text/user filter, paginated – drives the table view.
/// - `searchObserver`: restarted on each `search(query:filterUser:)` call – drives filtered results.
open class GlobalSearchAllLinksViewModel: NSObject {

    public let attachmentTypes: [String]
    public let sectionNameKeyPath: String?
    public var appearance: MessageCell.Appearance

    @Published public var event: ChannelAttachmentListViewModel.Event?

    private let downloadQueue = DispatchQueue(
        label: "com.sceytchat.uikit.globalSearchAllLinks",
        qos: .userInitiated
    )

    public var thumbnailSize: CGSize = .init(width: 40, height: 40) {
        didSet {
            guard thumbnailSize != oldValue else { return }
            thumbnailCache.removeAll()
            for observer in [allLinksObserver, searchObserver] {
                guard observer.isObserverStarted else { continue }
                for section in 0..<observer.numberOfSections {
                    for row in 0..<observer.numberOfItems(in: section) {
                        if let layout = observer.item(at: IndexPath(row: row, section: section)) {
                            layout.thumbnailSize = thumbnailSize
                            layout.resetThumbnail()
                        }
                    }
                }
            }
        }
    }

    public var minAutoDownloadSize = 3_000_000

    private let thumbnailCache = {
        $0.countLimit = 20
        return $0
    }(Cache<AttachmentId, UIImage?>())

    /// When set, only attachments sent by this user are included in search results.
    open var filterUser: ChatUser?
    /// Text query used for message-body matching in search results.
    open var query: String?

    public var isFiltered: Bool {
        filterUser != nil || !(query?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
    }

    private var isLoadingNext = false
    public private(set) var hasMore = true
    private var countBeforeLoad = 0

    public required init(
        attachmentTypes: [String],
        sectionNameKeyPath: String? = "createdYearMonth",
        appearance: MessageCell.Appearance
    ) {
        self.attachmentTypes = attachmentTypes
        self.sectionNameKeyPath = sectionNameKeyPath
        self.appearance = appearance
        super.init()
    }

    public typealias ChangeItemPaths = LazyDatabaseObserver<AttachmentDTO, MessageLayoutModel.AttachmentLayout>.ChangeItemPaths

    // MARK: - Base predicate (type filter only, no text/user) — used by allLinksObserver

    open func buildBasePredicate() -> NSPredicate {
        var predicates: [NSPredicate] = []
        if attachmentTypes.isEmpty {
            predicates.append(NSPredicate(format: "message.type != %@", ChatMessage.MessageType.viewOnce))
        } else {
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates:
                attachmentTypes.map { NSPredicate(format: "type = %@", $0) }
            ))
            predicates.append(NSPredicate(format: "message.type != %@", ChatMessage.MessageType.viewOnce))
        }
        return predicates.count == 1
            ? predicates[0]
            : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    // MARK: - Search predicate (includes text and user filters) — used by searchObserver

    open func buildPredicate() -> NSPredicate {
        var predicates: [NSPredicate] = []
        if attachmentTypes.isEmpty {
            predicates.append(NSPredicate(format: "message.type != %@", ChatMessage.MessageType.viewOnce))
        } else {
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates:
                attachmentTypes.map { NSPredicate(format: "type = %@", $0) }
            ))
            predicates.append(NSPredicate(format: "message.type != %@", ChatMessage.MessageType.viewOnce))
        }
        if let userId = filterUser?.id {
            predicates.append(NSPredicate(format: "userId == %@", userId))
        }
        if let trimmed = query?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty {
            predicates.append(NSPredicate(format: "message.body CONTAINS[cd] %@", trimmed))
        }
        return predicates.count == 1
            ? predicates[0]
            : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    // MARK: - All links observer (no search filter, paginated) — drives table view

    open lazy var allLinksObserver: LazyDatabaseObserver<AttachmentDTO, MessageLayoutModel.AttachmentLayout> = {
        let predicate = buildBasePredicate()
        let appearance = self.appearance
        return LazyDatabaseObserver<AttachmentDTO, MessageLayoutModel.AttachmentLayout>(
            context: SceytChatUIKit.shared.database.backgroundReadOnlyObservableContext,
            sortDescriptors: [
                .init(keyPath: \AttachmentDTO.createdAt, ascending: false),
                .init(keyPath: \AttachmentDTO.id, ascending: false)
            ],
            sectionNameKeyPath: sectionNameKeyPath,
            fetchPredicate: predicate,
            relationshipKeyPathsObserver: []
        ) { [weak self] dto in
            let attachment = dto.convert()
            if let prevItem = self?.allLinksObserver.item(for: dto.objectID) {
                prevItem.update(attachment: attachment)
                if let message = dto.message?.convert() {
                    prevItem.updateMessageIfNeeded(ownerMessage: message)
                }
                return prevItem
            }
            return MessageLayoutModel.AttachmentLayout(
                attachment: attachment,
                ownerMessage: dto.message?.convert(),
                ownerChannel: nil,
                thumbnailSize: self?.thumbnailSize ?? CGSize(width: 40, height: 40),
                onLoadThumbnail: { [weak self] in
                    self?.cacheThumbnail($0, for: attachment)
                },
                asyncLoadThumbnail: true,
                appearance: appearance
            )
        }
    }()

    // MARK: - Search observer (text/user filter) — drives filtered results

    open lazy var searchObserver: LazyDatabaseObserver<AttachmentDTO, MessageLayoutModel.AttachmentLayout> = {
        let predicate = buildPredicate()
        let appearance = self.appearance
        return LazyDatabaseObserver<AttachmentDTO, MessageLayoutModel.AttachmentLayout>(
            context: SceytChatUIKit.shared.database.backgroundReadOnlyObservableContext,
            sortDescriptors: [
                .init(keyPath: \AttachmentDTO.createdAt, ascending: false),
                .init(keyPath: \AttachmentDTO.id, ascending: false)
            ],
            sectionNameKeyPath: sectionNameKeyPath,
            fetchPredicate: predicate,
            relationshipKeyPathsObserver: []
        ) { [weak self] dto in
            let attachment = dto.convert()
            if let prevItem = self?.searchObserver.item(for: dto.objectID) {
                prevItem.update(attachment: attachment)
                if let message = dto.message?.convert() {
                    prevItem.updateMessageIfNeeded(ownerMessage: message)
                }
                return prevItem
            }
            return MessageLayoutModel.AttachmentLayout(
                attachment: attachment,
                ownerMessage: dto.message?.convert(),
                ownerChannel: nil,
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
        allLinksObserver.onDidChange = { [weak self] _, paths, _ in
            guard let self else { return }
            let newCount = (0..<allLinksObserver.numberOfSections)
                .reduce(0) { $0 + self.allLinksObserver.numberOfItems(in: $1) }
            hasMore = newCount > countBeforeLoad
            isLoadingNext = false
            onDidChangeEvent(items: paths)
        }
        searchObserver.onDidChange = { [weak self] _, paths, _ in
            self?.isLoadingNext = false
            self?.onDidChangeEvent(items: paths)
        }
        do {
            try allLinksObserver.startObserver(fetchLimit: 20)
        } catch {
            logger.errorIfNotNil(error, "GlobalSearchAllLinksViewModel allLinksObserver.startObserver")
        }
        do {
            try searchObserver.startObserver(fetchLimit: 0)
        } catch {
            logger.errorIfNotNil(error, "GlobalSearchAllLinksViewModel searchObserver.startObserver")
        }
    }

    open func onDidChangeEvent(items: ChangeItemPaths) {
        event = .change(items)
    }

    /// Filters search results by sender and/or message body text.
    /// Calling with both nil clears all filters.
    open func search(query: String?, filterUser: ChatUser?) {
        guard query != self.query || filterUser?.id != self.filterUser?.id else { return }
        self.filterUser = filterUser
        self.query = query
        isLoadingNext = false
        hasMore = true
        countBeforeLoad = 0
        searchObserver.restartObserver(fetchPredicate: buildPredicate())
    }

    open func loadAttachments() {
        guard !isLoadingNext else { return }
        isLoadingNext = true
        if isFiltered {
            searchObserver.loadNext()
        } else {
            countBeforeLoad = (0..<allLinksObserver.numberOfSections)
                .reduce(0) { $0 + allLinksObserver.numberOfItems(in: $1) }
            allLinksObserver.loadNext()
        }
    }

    open var numberOfSections: Int {
        isFiltered ? searchObserver.numberOfSections : allLinksObserver.numberOfSections
    }

    open func numberOfAttachments(in section: Int) -> Int {
        isFiltered
            ? searchObserver.numberOfItems(in: section)
            : allLinksObserver.numberOfItems(in: section)
    }

    open func attachmentLayout(
        at indexPath: IndexPath,
        onLoadThumbnail: ((MessageLayoutModel.AttachmentLayout) -> Void)? = nil,
        onLoadLinkMetadata: ((LinkMetadata?) -> Void)? = nil
    ) -> MessageLayoutModel.AttachmentLayout? {
        let observer = isFiltered ? searchObserver : allLinksObserver
        let layout = observer.item(at: indexPath)
        if let layout {
            let attachment = layout.attachment
            if let onLoadThumbnail {
                layout.onLoadThumbnail = { [weak self] in
                    self?.cacheThumbnail($0, for: attachment)
                    onLoadThumbnail(layout)
                }
            }
            if let onLoadLinkMetadata,
               let urlStr = attachment.url,
               let url = URL(string: urlStr)?.normalizedURL {
                if let cached = layout.linkMetadata {
                    onLoadLinkMetadata(cached)
                } else if let metadata = LinkMetadataProvider.default.metadata(for: url) {
                    layout.linkMetadata = metadata
                    onLoadLinkMetadata(metadata)
                } else {
                    LinkMetadataProvider.default.fetchFromCacheOrDB(url: url) { [weak layout] metadata in
                        layout?.linkMetadata = metadata ?? LinkMetadata(url: url)
                        onLoadLinkMetadata(metadata)
                    }
                }
            }
        }
        return layout
    }

    open func downloadAttachmentIfNeeded(
        _ layout: MessageLayoutModel.AttachmentLayout,
        completion: ((MessageLayoutModel.AttachmentLayout) -> Void)? = nil
    ) {
        let attachment = layout.attachment
        downloadQueue.async { [weak self] in
            guard let self,
                  attachment.type != "link",
                  minAutoDownloadSize <= 0 || attachment.uploadedFileSize <= minAutoDownloadSize,
                  attachment.status != .done,
                  attachment.status != .failedDownloading,
                  attachment.status != .pauseDownloading,
                  attachment.status != .failedUploading
            else {
                DispatchQueue.main.async { completion?(layout) }
                return
            }
            getMessage(layout) { message in
                if let message {
                    fileProvider.downloadMessageAttachments(
                        message: message,
                        attachments: [attachment]
                    ) { message, error in
                        if let attachment = message?.attachments?.first(where: { $0.id == attachment.id }) {
                            layout.update(attachment: attachment)
                        } else if let error {
                            logger.errorIfNotNil(error, "Download global search link attachment")
                        }
                        DispatchQueue.main.async { completion?(layout) }
                    }
                }
            }
        }
    }

    open func resumeDownload(_ layout: MessageLayoutModel.AttachmentLayout) {
        let attachment = layout.attachment
        guard attachment.type != "link" else { return }
        getMessage(layout) { message in
            if let message {
                fileProvider.resumeTransfer(message: message, attachment: attachment) {
                    if !$0 {
                        fileProvider.downloadMessageAttachments(message: message, attachments: [attachment])
                    }
                }
            }
        }
    }

    open func pauseDownload(_ layout: MessageLayoutModel.AttachmentLayout) {
        let attachment = layout.attachment
        getMessage(layout) { message in
            if let message {
                fileProvider.stopTransfer(message: message, attachment: attachment) { _ in
                    DataProvider.database.write {
                        let dto = AttachmentDTO.fetch(id: attachment.id, context: $0)
                        dto?.status = ChatMessage.Attachment.TransferStatus.pauseDownloading.rawValue
                    } completion: { error in
                        logger.errorIfNotNil(error, "")
                    }
                }
            }
        }
    }

    open func getMessage(_ layout: MessageLayoutModel.AttachmentLayout, completion: @escaping (ChatMessage?) -> Void) {
        if let message = layout.ownerMessage {
            completion(message)
        } else {
            ChannelMessageProvider.fetchMessage(id: layout.attachment.messageId) { message in
                completion(message)
            }
        }
    }

    open func cacheThumbnail(_ thumbnail: UIImage?, for attachment: ChatMessage.Attachment) {
        thumbnailCache[attachment.id] = thumbnail
    }
}

extension GlobalSearchAllLinksViewModel: ChannelAttachmentListViewModelProviding {
    public var eventPublisher: AnyPublisher<ChannelAttachmentListViewModel.Event?, Never> {
        $event.eraseToAnyPublisher()
    }
}
