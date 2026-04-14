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

/// Loads all link attachments across every channel for the
/// global-search Links tab initial state (no query active).
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

    public var minAutoDownloadSize = 3_000_000

    private let thumbnailCache = {
        $0.countLimit = 20
        return $0
    }(Cache<AttachmentId, UIImage?>())

    /// When set, only attachments sent by this user are included in results.
    open var filterUser: ChatUser?
    /// When non-empty, only attachments whose owning message body contains this text are included.
    open var query: String?

    public var isFiltered: Bool {
        filterUser != nil || !(query?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
    }

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

    /// Builds the fetch predicate based on `attachmentTypes`, `filterUser`, and `query`.
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

    open lazy var attachmentObserver: LazyDatabaseObserver<AttachmentDTO, MessageLayoutModel.AttachmentLayout> = {
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
            if let prevItem = self?.attachmentObserver.item(for: dto.objectID) {
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
        attachmentObserver.onDidChange = { [weak self] _, paths, _ in
            self?.onDidChangeEvent(items: paths)
        }
        do {
            try attachmentObserver.startObserver(fetchLimit: 20)
        } catch {
            logger.errorIfNotNil(error, "GlobalSearchAllLinksViewModel observer.startObserver")
        }
    }

    open func onDidChangeEvent(items: ChangeItemPaths) {
        event = .change(items)
    }

    /// Filters displayed attachments by sender and/or message body text.
    /// Calling with both nil clears all filters and shows every attachment.
    open func search(query: String?, filterUser: ChatUser?) {
        self.filterUser = filterUser
        self.query = query
        attachmentObserver.restartObserver(fetchPredicate: buildPredicate())
    }

    open func loadAttachments() {
        attachmentObserver.loadNext()
    }

    open var numberOfSections: Int {
        attachmentObserver.numberOfSections
    }

    open func numberOfAttachments(in section: Int) -> Int {
        attachmentObserver.numberOfItems(in: section)
    }

    open func attachmentLayout(
        at indexPath: IndexPath,
        onLoadThumbnail: ((MessageLayoutModel.AttachmentLayout) -> Void)? = nil,
        onLoadLinkMetadata: ((LinkMetadata?) -> Void)? = nil
    ) -> MessageLayoutModel.AttachmentLayout? {
        let layout = attachmentObserver.item(at: indexPath)
        if let layout, let onLoadThumbnail {
            let attachment = layout.attachment
            layout.onLoadThumbnail = { [weak self] in
                self?.cacheThumbnail($0, for: attachment)
                onLoadThumbnail(layout)
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
