//
//  GlobalSearchMessagesViewModel.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit on 09.04.26
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import Combine
import CoreData
import SceytChat

open class GlobalSearchMessagesViewModel: NSObject {

    // MARK: - Section

    public enum Section: Int, CaseIterable {
        case chats    = 0  // messages from direct / group channels
        case channels = 1  // messages from broadcast channels
    }

    // MARK: - Event

    public enum Event {
        case reload
    }

    // MARK: - Published state

    @Published public var event: Event?

    // MARK: - Data

    /// Messages from direct / group channels (section 0).
    @Atomic public var chatMessages: [ChatMessage] = []
    /// Messages from broadcast channels (section 1).
    @Atomic public var channelMessages: [ChatMessage] = []

    /// Channels keyed by channelId for chat message results (section 0).
    @Atomic public var chatMessageChannels: [ChannelId: ChatChannel] = [:]
    /// Channels keyed by channelId for channel message results (section 1).
    @Atomic public var channelMessageChannels: [ChannelId: ChatChannel] = [:]

    /// Flat ordered union: chats first, then channels.
    /// Convenient for tests and index-based access.
    public var messages: [ChatMessage] { chatMessages + channelMessages }
    public var numberOfMessages: Int { messages.count }

    /// Current search query – internal so testable subclasses can read/write it.
    var searchQuery: String?

    /// When set, message results are scoped to channels that include this user.
    /// - Direct channels with this user: all messages matching the query are shown.
    /// - Group channels with this user: only messages sent by this user are shown.
    public var filterUser: ChatUser?

    /// Returns true when the messages section should be visible:
    /// - Always true when a user filter is active (show all their messages, or filter by >= 1 char).
    /// - True only when the query has >= 2 characters otherwise.
    public var shouldShowMessagesSection: Bool {
        if filterUser != nil { return true }
        let trimmed = (searchQuery ?? "").trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 2
    }

    private var currentSearchTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?

    public static let pageSize = 20

    private var chatMessagesOffset = 0
    private var channelMessagesOffset = 0
    @Atomic public private(set) var hasMoreChatMessages = false
    @Atomic public private(set) var hasMoreChannelMessages = false

    /// Stored search parameters for `loadMoreMessages(in:)`.
    private var currentTrimmedQuery: String?
    private var currentFilterUserId: UserId?

    /// Override in test subclasses to inject an in-memory database.
    open var database: Database { SceytChatUIKit.shared.database }

    /// Override in test subclasses to inject an in-memory FTS store.
    open var messageSearchStore: MessageSearchStore { SceytChatUIKit.shared.messageSearchStore }

    /// Observes messages transitioning to the `deleted` state so rows disappear from the
    /// on-screen results without requiring the user to re-search. We only care about the
    /// state flipping to `deleted`, so the predicate is narrow and the observer is cheap.
    private var deletedMessageObserver: DatabaseObserver<MessageDTO, ChatMessage>?

    /// The initial `onDidChange` invocation replays every historically-deleted message as
    /// an `insert`; skip that snapshot so we don't do needless work at startup.
    private var didReceiveInitialDeletionSnapshot = false

    // MARK: - Init

    public override required init() {
        super.init()
    }

    // MARK: - Observer

    open func stopDatabaseObserver() {
        deletedMessageObserver?.stopObserver()
        deletedMessageObserver = nil
        didReceiveInitialDeletionSnapshot = false
        currentSearchTask?.cancel()
        loadMoreTask?.cancel()
    }

    /// Starts observing message deletions so the search results drop rows when another
    /// user (or the current user from a different device) deletes a message that's in view.
    open func startDatabaseObserver() {
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
            // Ignore the initial historical snapshot – the displayed arrays are
            // populated later via search, and those results already filter state==2.
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
                guard let self else { return }
                let beforeChat = chatMessages.count
                let beforeChannel = channelMessages.count
                chatMessages = chatMessages.filter { !deletedIds.contains($0.id) }
                channelMessages = channelMessages.filter { !deletedIds.contains($0.id) }
                if chatMessages.count != beforeChat || channelMessages.count != beforeChannel {
                    event = .reload
                }
            }
        }
        deletedMessageObserver = observer
        do {
            try observer.startObserver()
        } catch {
            logger.errorIfNotNil(error, "GlobalSearchMessagesViewModel deletedMessageObserver.startObserver")
        }
    }

    // MARK: - Search

    open func search(query: String?) {
        searchQuery = query
        applyFilter()
    }

    // MARK: - Section accessors

    public func numberOfMessages(in section: Section) -> Int {
        switch section {
        case .chats:    return chatMessages.count
        case .channels: return channelMessages.count
        }
    }

    public func message(at indexPath: IndexPath) -> ChatMessage? {
        guard let section = Section(rawValue: indexPath.section) else { return nil }
        let list = messages(in: section)
        guard list.indices.contains(indexPath.row) else { return nil }
        return list[indexPath.row]
    }

    /// Flat index access – used by tests and single-section callers.
    public func message(at index: Int) -> ChatMessage? {
        let all = messages
        guard all.indices.contains(index) else { return nil }
        return all[index]
    }

    public func messages(in section: Section) -> [ChatMessage] {
        switch section {
        case .chats:    return chatMessages
        case .channels: return channelMessages
        }
    }

    // MARK: - Filter

    /// Override in testable subclasses to do in-memory filtering instead of a DB query.
    public func applyFilter() {
        let trimmed = (searchQuery ?? "").trimmingCharacters(in: .whitespaces)
        let config = SceytChatUIKit.shared.config.channelTypesConfig
        let pageSize = Self.pageSize

        // No user filter: require >= 2 characters before searching.
        if filterUser == nil, trimmed.count < 2 {
            chatMessages = []
            channelMessages = []
            chatMessageChannels = [:]
            channelMessageChannels = [:]
            hasMoreChatMessages = false
            hasMoreChannelMessages = false
            currentTrimmedQuery = nil
            currentFilterUserId = nil
            DispatchQueue.main.async { [weak self] in self?.event = .reload }
            return
        }

        currentTrimmedQuery = trimmed
        currentFilterUserId = filterUser?.id
        chatMessagesOffset = 0
        channelMessagesOffset = 0

        let chatTypes = [config.direct, config.group]
        let broadcastTypes = [config.broadcast]
        let filterUserId = filterUser?.id

        currentSearchTask?.cancel()
        loadMoreTask?.cancel()
        currentSearchTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            async let chatResult      = searchPage(query: trimmed,
                                                   channelTypes: chatTypes,
                                                   filterUserId: filterUserId,
                                                   offset: 0,
                                                   limit: pageSize)
            async let broadcastResult = searchPage(query: trimmed,
                                                   channelTypes: broadcastTypes,
                                                   filterUserId: filterUserId,
                                                   offset: 0,
                                                   limit: pageSize)
            let (chats, broadcast) = await (chatResult, broadcastResult)

            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                guard let self else { return }
                chatMessages           = chats.0
                channelMessages        = broadcast.0
                chatMessageChannels    = chats.1
                channelMessageChannels = broadcast.1
                hasMoreChatMessages    = chats.0.count >= pageSize
                hasMoreChannelMessages = broadcast.0.count >= pageSize
                event = .reload
            }
        }
    }

    // MARK: - Load more

    open func loadMoreMessages(in section: Section) {
        guard let trimmed = currentTrimmedQuery else { return }
        let config = SceytChatUIKit.shared.config.channelTypesConfig
        let filterUserId = currentFilterUserId

        switch section {
        case .chats:
            guard hasMoreChatMessages else { return }
            let newOffset = chatMessagesOffset + Self.pageSize

            loadMoreTask?.cancel()
            loadMoreTask = Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let result = await searchPage(
                    query: trimmed,
                    channelTypes: [config.direct, config.group],
                    filterUserId: filterUserId,
                    offset: newOffset,
                    limit: Self.pageSize
                )
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    chatMessagesOffset = newOffset
                    chatMessages += result.0
                    chatMessageChannels.merge(result.1) { _, new in new }
                    hasMoreChatMessages = result.0.count >= Self.pageSize
                    event = .reload
                }
            }

        case .channels:
            guard hasMoreChannelMessages else { return }
            let newOffset = channelMessagesOffset + Self.pageSize

            loadMoreTask?.cancel()
            loadMoreTask = Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let result = await searchPage(
                    query: trimmed,
                    channelTypes: [config.broadcast],
                    filterUserId: filterUserId,
                    offset: newOffset,
                    limit: Self.pageSize
                )
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    channelMessagesOffset = newOffset
                    channelMessages += result.0
                    channelMessageChannels.merge(result.1) { _, new in new }
                    hasMoreChannelMessages = result.0.count >= Self.pageSize
                    event = .reload
                }
            }
        }
    }

    // MARK: - DB fetch

    /// Returns one page of search results.
    ///
    /// When `query` has tokens, message IDs come from the FTS5 sidecar (`MessageSearchStore`).
    /// When `query` is empty (only valid when `filterUserId` is set), falls back to a direct
    /// `MessageDTO` fetch — there's nothing for FTS to match against.
    /// In both cases, full `MessageDTO`s are then loaded by id and converted to models.
    private func searchPage(
        query: String,
        channelTypes: [String],
        filterUserId: UserId?,
        offset: Int,
        limit: Int
    ) async -> ([ChatMessage], [ChannelId: ChatChannel]) {
        let store = messageSearchStore
        return await withCheckedContinuation { cont in
            database.read { [query, channelTypes, filterUserId, store] context -> ([ChatMessage], [ChannelId: ChatChannel]) in
                // When scoping to a specific member, resolve their channels of the requested
                // types up-front. FTS then sees the explicit id list instead of channelType,
                // matching the legacy "channels the member currently belongs to" semantics.
                var memberChannelIds: [Int64]?
                if let memberUserId = filterUserId {
                    let memberRequest = MemberDTO.fetchRequest()
                    memberRequest.predicate = NSPredicate(format: "user.id == %@", memberUserId)
                    let memberDTOs = MemberDTO.fetch(request: memberRequest, context: context)
                    let allMemberChannelIds = memberDTOs.map { $0.channelId }

                    let channelRequest = ChannelDTO.fetchRequest()
                    channelRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "type IN %@", channelTypes),
                        NSPredicate(format: "id IN %@", allMemberChannelIds)
                    ])
                    memberChannelIds = ChannelDTO.fetch(request: channelRequest, context: context).map { $0.id }
                    if memberChannelIds?.isEmpty ?? true {
                        return ([], [:])
                    }
                }

                let trimmed = query.trimmingCharacters(in: .whitespaces)
                let messageIds: [Int64]

                if !trimmed.isEmpty {
                    let typesFilter: [String]? = (memberChannelIds == nil) ? channelTypes : nil
                    messageIds = store.search(
                        query: trimmed,
                        channelTypes: typesFilter,
                        userId: filterUserId,
                        channelIds: memberChannelIds,
                        offset: offset,
                        limit: limit
                    )
                } else if let memberChannelIds, let filterUserId {
                    // Empty query + filter user: list the user's messages in their channels.
                    let request = MessageDTO.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "channelId IN %@", memberChannelIds),
                        NSPredicate(format: "user.id == %@", filterUserId),
                        NSPredicate(format: "state != 2"),
                        NSPredicate(format: "transient == NO"),
                        NSPredicate(format: "body.length > 0")
                    ])
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \MessageDTO.createdAt, ascending: false)]
                    request.fetchOffset = offset
                    request.fetchLimit = limit
                    let dtos = (try? context.fetch(request)) ?? []
                    messageIds = dtos.map { $0.id }
                } else {
                    return ([], [:])
                }

                if messageIds.isEmpty { return ([], [:]) }

                let messageRequest = MessageDTO.fetchRequest()
                messageRequest.predicate = NSPredicate(format: "id IN %@", messageIds)
                messageRequest.relationshipKeyPathsForPrefetching = ["user", "attachments", "reactions", "linkMetadatas"]
                let dtos = MessageDTO.fetch(request: messageRequest, context: context)
                let dtoById = Dictionary(uniqueKeysWithValues: dtos.map { ($0.id, $0) })
                let orderedDTOs = messageIds.compactMap { dtoById[$0] }
                let messages = orderedDTOs.map { $0.convert() }

                let resultChannelIds = Set(messages.map { $0.channelId })
                guard !resultChannelIds.isEmpty else { return (messages, [:]) }

                let channelRequest = ChannelDTO.fetchRequest()
                let channelIdInts: [Int64] = resultChannelIds.map { Int64($0) }
                channelRequest.predicate = NSPredicate(format: "id IN %@", channelIdInts)
                let channelDTOs = ChannelDTO.fetch(request: channelRequest, context: context)
                let channelMap: [ChannelId: ChatChannel] = channelDTOs.reduce(into: [:]) { map, dto in
                    map[ChannelId(dto.id)] = dto.convert()
                }

                return (messages, channelMap)
            } completion: { result in
                cont.resume(returning: (try? result.get()) ?? ([], [:]))
            }
        }
    }
}
