//
//  GlobalSearchAllMediaViewModel.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit on 09.04.26
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Combine
import Foundation
import SceytChat
import UIKit

/// Loads all image/video attachments across every channel for the
/// global-search Media tab.
/// - `allAttachmentsObserver`: always-on, no search filter, paginated – drives the collection view.
/// - `searchObserver`: restarted on each `search(query:filterUser:)` call with text/user predicates – drives the search table view.
open class GlobalSearchAllMediaViewModel: NSObject {

    public let attachmentTypes: [String]
    public let sectionNameKeyPath: String?
    public var appearance: MessageCell.Appearance

    @Published public var event: ChannelAttachmentListViewModel.Event?

    private let downloadQueue = DispatchQueue(
        label: "com.sceytchat.uikit.globalSearchAllMedia",
        qos: .userInitiated
    )

    public var thumbnailSize: CGSize = .init(width: 40, height: 40) {
        didSet {
            guard thumbnailSize != oldValue else { return }
            thumbnailCache.removeAll()
            for observer in [allAttachmentsObserver, searchObserver] {
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
        if filterUser != nil { return true }
        let trimmed = (query ?? "").trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 1
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

    // MARK: - Base predicate (type filter only, no text/user) — used by allAttachmentsObserver

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
        predicates.append(NSPredicate(format: "message.unlisted == false"))
        // Drop attachments whose parent message has been soft-deleted remotely.
        predicates.append(NSPredicate(format: "message.state != %d", MessageState.deleted.rawValue))
        predicates.append(buildRoleQualifiedChannelPredicate())
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
        predicates.append(NSPredicate(format: "message.unlisted == false"))
        // Drop attachments whose parent message has been soft-deleted remotely.
        predicates.append(NSPredicate(format: "message.state != %d", MessageState.deleted.rawValue))
        predicates.append(buildRoleQualifiedChannelPredicate())

        if let userId = filterUser?.id {
            predicates.append(NSPredicate(format: "userId == %@", userId))
        }

        let trimmed = (query ?? "").trimmingCharacters(in: .whitespaces)
        let tokens = trimmed
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        let shouldApplyTextFilter: Bool = {
            if filterUser != nil {
                return !tokens.isEmpty
            }
            return trimmed.count >= 1 && !tokens.isEmpty
        }()
        if shouldApplyTextFilter {
            predicates.append(contentsOf: tokens.map { token in
                let escaped = NSRegularExpression.escapedPattern(for: token)
                let pattern = "(?i)(?s).*\\b\(escaped).*"
                return NSPredicate(format: "message.body MATCHES %@", pattern)
            })
        }

        return predicates.count == 1
            ? predicates[0]
            : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    // MARK: - All attachments observer (no search filter, paginated) — drives collection view

    open lazy var allAttachmentsObserver: LazyDatabaseObserver<AttachmentDTO, MessageLayoutModel.AttachmentLayout> = {
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
            // Watch message.state so FRC re-evaluates when a parent message is soft-deleted.
            relationshipKeyPathsObserver: [#keyPath(AttachmentDTO.message.state)]
        ) { [weak self] dto in
            let attachment = dto.convert()
            if let prevItem = self?.allAttachmentsObserver.item(for: dto.objectID) {
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

    // MARK: - Search observer (text/user filter) — drives search table view

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
            // Watch message.state so FRC re-evaluates when a parent message is soft-deleted.
            relationshipKeyPathsObserver: [#keyPath(AttachmentDTO.message.state)]
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

    private var isLoadingNext = false

    /// Watches messages transitioning into `.deleted` so on-screen attachment cells drop
    /// immediately when the parent message is removed remotely. The FRC-level relationship
    /// observation on `searchObserver` sometimes surfaces a stale cell (body cleared but
    /// cell kept), so this observer performs an explicit restart when a deletion impacts
    /// the currently-shown rows. Mirrors the pattern used by GlobalSearchMessagesViewModel.
    private var deletedMessageObserver: DatabaseObserver<MessageDTO, ChatMessage>?

    /// Initial `onDidChange` replays every historically-deleted message as an insert;
    /// skip that snapshot so we don't restart the observers on first fetch.
    private var didReceiveInitialDeletionSnapshot = false

    /// Tracks channels currently visible to the user (`userRole != nil`).
    private var roleQualifiedChannelIds = Set<ChannelId>()
    private var didLoadRoleQualifiedChannelIds = false
    private var channelRoleObserver: DatabaseObserver<ChannelDTO, ChannelId>?

    /// Initial role observer callback replays existing channels. We pre-load
    /// `roleQualifiedChannelIds` before starting the observer, so skip that snapshot.
    private var didReceiveInitialChannelRoleSnapshot = false

    open func stopDatabaseObserver() {
        allAttachmentsObserver.stopObserver()
        searchObserver.stopObserver()
        deletedMessageObserver?.stopObserver()
        deletedMessageObserver = nil
        didReceiveInitialDeletionSnapshot = false
        channelRoleObserver?.stopObserver()
        channelRoleObserver = nil
        didReceiveInitialChannelRoleSnapshot = false
    }

    open func startDatabaseObserver() {
        _ = refreshRoleQualifiedChannelIds()
        allAttachmentsObserver.onDidChange = { [weak self] _, paths, _ in
            guard let self, !self.isFiltered else { return }
            self.isLoadingNext = false
            self.onDidChangeEvent(items: paths)
        }
        searchObserver.onDidChange = { [weak self] _, paths, _ in
            guard let self, self.isFiltered else { return }
            self.isLoadingNext = false
            self.onDidChangeEvent(items: paths)
        }
        do {
            try allAttachmentsObserver.startObserver(fetchLimit: 20)
        } catch {
            logger.errorIfNotNil(error, "GlobalSearchAllMediaViewModel allAttachmentsObserver.startObserver")
        }
        do {
            try searchObserver.startObserver(fetchLimit: 0)
        } catch {
            logger.errorIfNotNil(error, "GlobalSearchAllMediaViewModel searchObserver.startObserver")
        }
        startDeletedMessageObserver()
        startChannelRoleObserver()
    }

    /// Starts a lightweight observer on MessageDTOs with `state == deleted`. When a
    /// message transitions into the deleted state and any of our visible rows references
    /// it, we restart the affected attachment observer so the predicate re-runs and the
    /// stale row drops out.
    private func startDeletedMessageObserver() {
        guard deletedMessageObserver == nil else { return }
        let request = MessageDTO.fetchRequest()
            .sort(descriptors: [.init(keyPath: \MessageDTO.id, ascending: false)])
            .fetch(predicate: NSPredicate(format: "state == %d", MessageState.deleted.rawValue))
        let observer = DatabaseObserver<MessageDTO, ChatMessage>(
            request: request,
            context: SceytChatUIKit.shared.database.backgroundReadOnlyObservableContext,
            itemCreator: { $0.convert() }
        )
        observer.onDidChange = { [weak self] paths in
            guard let self else { return }
            // Skip the initial historical snapshot – nothing is on screen yet.
            guard didReceiveInitialDeletionSnapshot else {
                didReceiveInitialDeletionSnapshot = true
                return
            }
            var deletedIds = Set<MessageId>()
            for ip in paths.inserts {
                if let m: ChatMessage = paths.item(at: ip) { deletedIds.insert(m.id) }
            }
            for ip in paths.updates {
                if let m: ChatMessage = paths.item(at: ip) { deletedIds.insert(m.id) }
            }
            guard !deletedIds.isEmpty else { return }
            DispatchQueue.main.async { [weak self] in
                self?.restartObserversIfNeeded(forDeletedMessageIds: deletedIds)
            }
        }
        deletedMessageObserver = observer
        do {
            try observer.startObserver()
        } catch {
            logger.errorIfNotNil(error, "GlobalSearchAllMediaViewModel deletedMessageObserver.startObserver")
        }
    }

    /// Starts an observer on channels and reloads attachment observers when
    /// `userRole` visibility changes.
    private func startChannelRoleObserver() {
        guard channelRoleObserver == nil else { return }
        let request = ChannelDTO.fetchRequest()
            .sort(descriptors: [.init(keyPath: \ChannelDTO.id, ascending: false)])
            .fetch(predicate: NSPredicate(value: true))
            .relationshipKeyPathsFor(refreshing: [#keyPath(ChannelDTO.userRole)])
        let observer = DatabaseObserver<ChannelDTO, ChannelId>(
            request: request,
            context: SceytChatUIKit.shared.database.backgroundReadOnlyObservableContext,
            itemCreator: { ChannelId($0.id) }
        )
        observer.onDidChange = { [weak self] _ in
            guard let self else { return }
            guard didReceiveInitialChannelRoleSnapshot else {
                didReceiveInitialChannelRoleSnapshot = true
                return
            }
            guard refreshRoleQualifiedChannelIds() else { return }
            DispatchQueue.main.async { [weak self] in
                self?.restartAttachmentObserversForRoleChange()
            }
        }
        channelRoleObserver = observer
        do {
            try observer.startObserver()
        } catch {
            logger.errorIfNotNil(error, "GlobalSearchAllMediaViewModel channelRoleObserver.startObserver")
        }
    }

    private func restartAttachmentObserversForRoleChange() {
        if searchObserver.isObserverStarted {
            searchObserver.restartObserver(fetchPredicate: buildPredicate())
        }
        if allAttachmentsObserver.isObserverStarted {
            allAttachmentsObserver.restartObserver(fetchPredicate: buildBasePredicate())
        }
    }

    open func loadRoleQualifiedChannelIds() -> Set<ChannelId> {
        let context = SceytChatUIKit.shared.database.backgroundReadOnlyObservableContext
        var channelIds = Set<ChannelId>()
        context.performAndWait {
            let request = ChannelDTO.fetchRequest()
                .sort(descriptors: [.init(keyPath: \ChannelDTO.id, ascending: false)])
                .fetch(predicate: NSPredicate(format: "userRole != nil"))
            let channels = ChannelDTO.fetch(request: request, context: context)
            channelIds = Set(channels.map { ChannelId($0.id) })
        }
        return channelIds
    }

    @discardableResult
    private func refreshRoleQualifiedChannelIds() -> Bool {
        let newValue = loadRoleQualifiedChannelIds()
        let didChange = newValue != roleQualifiedChannelIds
        roleQualifiedChannelIds = newValue
        didLoadRoleQualifiedChannelIds = true
        return didChange
    }

    private func effectiveRoleQualifiedChannelIds() -> Set<ChannelId> {
        guard didLoadRoleQualifiedChannelIds else {
            let loaded = loadRoleQualifiedChannelIds()
            roleQualifiedChannelIds = loaded
            didLoadRoleQualifiedChannelIds = true
            return loaded
        }
        return roleQualifiedChannelIds
    }

    private func buildRoleQualifiedChannelPredicate() -> NSPredicate {
        let channelIds = Array(effectiveRoleQualifiedChannelIds())
        guard !channelIds.isEmpty else {
            return NSPredicate(value: false)
        }
        return NSPredicate(format: "channelId IN %@", channelIds)
    }

    /// Checks each observer's currently-cached rows for attachments whose owner message
    /// was just deleted and restarts that observer to re-apply the current fetch predicate.
    private func restartObserversIfNeeded(forDeletedMessageIds deletedIds: Set<MessageId>) {
        if observerContainsDeletedMessage(observer: searchObserver, deletedIds: deletedIds) {
            searchObserver.restartObserver(fetchPredicate: buildPredicate())
        }
        if observerContainsDeletedMessage(observer: allAttachmentsObserver, deletedIds: deletedIds) {
            allAttachmentsObserver.restartObserver(fetchPredicate: buildBasePredicate())
        }
    }

    private func observerContainsDeletedMessage(
        observer: LazyDatabaseObserver<AttachmentDTO, MessageLayoutModel.AttachmentLayout>,
        deletedIds: Set<MessageId>
    ) -> Bool {
        for section in 0..<observer.numberOfSections {
            for row in 0..<observer.numberOfItems(in: section) {
                if let layout = observer.item(at: IndexPath(row: row, section: section)),
                   let msgId = layout.ownerMessage?.id,
                   deletedIds.contains(msgId) {
                    return true
                }
            }
        }
        return false
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
        let predicate = buildPredicate()
        searchObserver.restartObserver(fetchPredicate: predicate) { [weak self] in
            guard let self else { return }
        }
    }

    open func loadAttachments() {
        guard !isLoadingNext else { return }
        isLoadingNext = true
        if isFiltered {
            searchObserver.loadNext()
        } else {
            allAttachmentsObserver.loadNext()
        }
    }

    open var numberOfSections: Int {
        isFiltered ? searchObserver.numberOfSections : allAttachmentsObserver.numberOfSections
    }

    open func numberOfAttachments(in section: Int) -> Int {
        isFiltered
            ? searchObserver.numberOfItems(in: section)
            : allAttachmentsObserver.numberOfItems(in: section)
    }

    open func attachmentLayout(
        at indexPath: IndexPath,
        onLoadThumbnail: ((MessageLayoutModel.AttachmentLayout) -> Void)? = nil,
        onLoadLinkMetadata: ((LinkMetadata?) -> Void)? = nil
    ) -> MessageLayoutModel.AttachmentLayout? {
        let observer = isFiltered ? searchObserver : allAttachmentsObserver
        let layout = observer.item(at: indexPath)
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
                            logger.errorIfNotNil(error, "Download global search media attachment")
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
        if fileProvider.filePath(attachment: attachment) != nil {
            DataProvider.database.write {
                let dto = AttachmentDTO.fetch(id: attachment.id, context: $0)
                dto?.status = ChatMessage.Attachment.TransferStatus.done.rawValue
            } completion: { error in
                logger.errorIfNotNil(error, "")
            }
            return
        }
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
        completion(layout.ownerMessage)
    }

    open func cacheThumbnail(_ thumbnail: UIImage?, for attachment: ChatMessage.Attachment) {
        thumbnailCache[attachment.id] = thumbnail
    }
}

extension GlobalSearchAllMediaViewModel: ChannelAttachmentListViewModelProviding {
    public var eventPublisher: AnyPublisher<ChannelAttachmentListViewModel.Event?, Never> {
        $event.eraseToAnyPublisher()
    }
}

