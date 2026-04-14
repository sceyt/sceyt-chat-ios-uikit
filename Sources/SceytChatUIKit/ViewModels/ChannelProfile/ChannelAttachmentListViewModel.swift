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
    public var minAutoDownloadSize = 3_000_000
    
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
        provider.loadPrevAttachment()
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
                attachmentLayout.onLoadThumbnail = { [weak self] in
                    self?.cacheThumbnail($0, for: attachment)
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
                    LinkMetadataProvider.default.fetch(url: url) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let metadata):
                                logger.debug("[LONK LOAD] HAS META fetch \(url)")
                                onLoadLinkMetadata(metadata)
                            case .failure:
                                onLoadLinkMetadata(nil)
                            }
                        }
                    }
                }
            }
        }
        return attachmentLayout
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
            guard let self,
                  attachment.type != "link",
                  minAutoDownloadSize <= 0 || attachment.uploadedFileSize <= minAutoDownloadSize,
                  attachment.status != .done,
                  attachment.status != .failedDownloading,
                  attachment.status != .pauseDownloading,
                  attachment.status != .failedUploading
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

    open func resumeDownload(_ layout: MessageLayoutModel.AttachmentLayout) {
        let attachment = layout.attachment
        guard attachment.type != "link"
        else { return }
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
                fileProvider.stopTransfer(message: message, attachment: attachment) { _ in
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
}

public extension ChannelAttachmentListViewModelProviding {
    func search(query: String?, filterUser: ChatUser?) {}
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
