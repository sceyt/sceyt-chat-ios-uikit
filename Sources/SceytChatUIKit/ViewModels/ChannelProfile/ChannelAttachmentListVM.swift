//
//  ChannelAttachmentListVM.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Combine
import Foundation
import SceytChat
import UIKit

open class ChannelAttachmentListVM: NSObject {
    public let sectionNameKeyPath: String?
    public let channel: ChatChannel
    public let attachmentTypes: [String]
    public let provider: ChannelAttachmentProvider
    @Published public var event: Event?
    private let downloadQueue = DispatchQueue(label: "com.sceytchat.uikit.attachments", qos: .userInitiated)

    public var thumbnailSize: CGSize = .init(width: 40, height: 40)
    private let thumbnailCache = {
        $0.countLimit = 20
        return $0
    }(Cache<AttachmentId, UIImage?>())

    public required init(
        channel: ChatChannel,
        attachmentTypes: [String],
        sectionNameKeyPath: String? = "createdYearMonth"
    ) {
        self.sectionNameKeyPath = sectionNameKeyPath
        self.channel = channel
        self.attachmentTypes = attachmentTypes
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
                NSPredicate(format: "channelId == %lld", channel.id)
            ])
        } else {
            predicate =
                NSCompoundPredicate(andPredicateWithSubpredicates: [
//                NSPredicate(format: "message != nil", channel.id, channel.id),
                    NSPredicate(format: "channelId == %lld", channel.id),
                    NSCompoundPredicate(orPredicateWithSubpredicates:
                        attachmentTypes.map { NSPredicate(format: "type = %@", $0) }
                    )
                ])
        }

        return LazyDatabaseObserver<AttachmentDTO, MessageLayoutModel.AttachmentLayout>(
            context: Config.database.backgroundReadOnlyObservableContext,
            sortDescriptors: [.init(keyPath: \AttachmentDTO.createdAt, ascending: false),
                              .init(keyPath: \AttachmentDTO.id, ascending: false)],
            sectionNameKeyPath: sectionNameKeyPath,
            fetchPredicate: predicate,
            relationshipKeyPathsObserver: []
        ) { [weak self] in
            let attachment = $0.convert()
            if let self, let prevItem = self.attachmentObserver.item(for: $0.objectID) {
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
                    ownerChannel: self?.channel,
                    thumbnailSize: self?.thumbnailSize,
                    onLoadThumbnail: { [weak self] in
                        self?.cacheThumbnail($0, for: attachment)
                    },
                    asyncLoadThumbnail: true
                )
        }

    }()

    open func startDatabaseObserver() {
        attachmentObserver.onDidChange = { [weak self] paths, _ in
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
                    Task {
                        switch await LinkMetadataProvider.default.fetch(url: url) {
                        case .success(let metadata):
                            logger.debug("[LONK LOAD] HAS META fetch \(url)")
                            await MainActor.run {
                                onLoadLinkMetadata(metadata)
                            }
                        case .failure(let error):
                            await MainActor.run {
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
                  Config.minAutoDownloadSize <= 0 || attachment.uploadedFileSize <= Config.minAutoDownloadSize,
                  attachment.status != .done,
                  attachment.status != .failedDownloading,
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
        guard attachment.status == .downloading,
              fileProvider.filePath(attachment: attachment) == nil
        else { return }
        
        getMessage(layout) { message in
            if let message {
                fileProvider.stopTransfer(message: message, attachment: attachment) {
                    if $0 {
                        Provider.database.write {
                            let attachmentDTO = AttachmentDTO.fetch(id: attachment.id, context: $0)
                            attachmentDTO?.status = ChatMessage.Attachment.TransferStatus.pauseDownloading.rawValue
                        } completion: { error in
                            logger.errorIfNotNil(error, "")
                        }
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

public extension ChannelAttachmentListVM {
    enum Event {
        case change(ChangeItemPaths)
    }
}
