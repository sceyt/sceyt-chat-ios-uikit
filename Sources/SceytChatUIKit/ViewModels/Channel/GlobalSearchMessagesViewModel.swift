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
    private var currentBasePredicate: NSPredicate?
    private var currentMemberUserId: UserId?

    /// Override in test subclasses to inject an in-memory database.
    open var database: Database { SceytChatUIKit.shared.database }

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
        let tokens = trimmed
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        let config = SceytChatUIKit.shared.config.channelTypesConfig

        if let filterUser = filterUser {
            // User filter active:
            //   - Empty query  → show all messages from that user (no body filter).
            //   - Any query    → filter their messages by tokens (1+ char is enough).
            let basePredicate: NSPredicate
            if tokens.isEmpty {
                basePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "state != 2"),
                    NSPredicate(format: "body.length > 0"),
                    NSPredicate(format: "transient == NO"),
                    NSPredicate(format: "user.id == %@", filterUser.id)
                ])
            } else {
                basePredicate = NSCompoundPredicate(andPredicateWithSubpredicates:
                    tokens.map { token in
                        let escaped = NSRegularExpression.escapedPattern(for: token)
                        let pattern = "(?i)(?s).*\\b\(escaped).*"
                        return NSPredicate(format: "body MATCHES %@", pattern)
                    } + [
                        NSPredicate(format: "state != 2"),
                        NSPredicate(format: "body.length > 0"),
                        NSPredicate(format: "transient == NO"),
                        NSPredicate(format: "user.id == %@", filterUser.id)
                    ]
                )
            }

            currentBasePredicate = basePredicate
            currentMemberUserId = filterUser.id
            chatMessagesOffset = 0
            channelMessagesOffset = 0

            currentSearchTask?.cancel()
            loadMoreTask?.cancel()
            currentSearchTask = Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }

                async let chatResult      = fetchMessages(basePredicate: basePredicate,
                                                          channelTypes: [config.direct, config.group],
                                                          memberUserId: filterUser.id,
                                                          offset: 0,
                                                          limit: Self.pageSize)
                async let broadcastResult = fetchMessages(basePredicate: basePredicate,
                                                          channelTypes: [config.broadcast],
                                                          memberUserId: filterUser.id,
                                                          offset: 0,
                                                          limit: Self.pageSize)
                let (chats, broadcast) = await (chatResult, broadcastResult)

                guard !Task.isCancelled else { return }

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    chatMessages           = chats.0
                    channelMessages        = broadcast.0
                    chatMessageChannels    = chats.1
                    channelMessageChannels = broadcast.1
                    hasMoreChatMessages    = chats.0.count >= Self.pageSize
                    hasMoreChannelMessages = broadcast.0.count >= Self.pageSize
                    event = .reload
                }
            }
        } else {
            // No user filter: require >= 2 characters before searching.
            guard trimmed.count >= 2, !tokens.isEmpty else {
                chatMessages = []
                channelMessages = []
                chatMessageChannels = [:]
                channelMessageChannels = [:]
                hasMoreChatMessages = false
                hasMoreChannelMessages = false
                currentBasePredicate = nil
                currentMemberUserId = nil
                DispatchQueue.main.async { [weak self] in self?.event = .reload }
                return
            }

            // Every token must match as a prefix of a word (AND semantics, case-insensitive).
            let basePredicate = NSCompoundPredicate(andPredicateWithSubpredicates:
                tokens.map { token in
                    let escaped = NSRegularExpression.escapedPattern(for: token)
                    let pattern = "(?i)(?s).*\\b\(escaped).*"
                    return NSPredicate(format: "body MATCHES %@", pattern)
                } + [
                    NSPredicate(format: "state != 2"),
                    NSPredicate(format: "body.length > 0"),
                    NSPredicate(format: "transient == NO")
                ]
            )

            currentBasePredicate = basePredicate
            currentMemberUserId = nil
            chatMessagesOffset = 0
            channelMessagesOffset = 0

            currentSearchTask?.cancel()
            loadMoreTask?.cancel()
            currentSearchTask = Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }

                async let chatResult    = fetchMessages(basePredicate: basePredicate,
                                                        channelTypes: [config.direct, config.group],
                                                        offset: 0,
                                                        limit: Self.pageSize)
                async let channelResult = fetchMessages(basePredicate: basePredicate,
                                                        channelTypes: [config.broadcast],
                                                        offset: 0,
                                                        limit: Self.pageSize)
                let (chatsResult, channelsResult) = await (chatResult, channelResult)

                guard !Task.isCancelled else { return }

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    chatMessages            = chatsResult.0
                    channelMessages         = channelsResult.0
                    chatMessageChannels     = chatsResult.1
                    channelMessageChannels  = channelsResult.1
                    hasMoreChatMessages     = chatsResult.0.count >= Self.pageSize
                    hasMoreChannelMessages  = channelsResult.0.count >= Self.pageSize
                    event = .reload
                }
            }
        }
    }

    // MARK: - Load more

    open func loadMoreMessages(in section: Section) {
        guard let basePredicate = currentBasePredicate else { return }
        let config = SceytChatUIKit.shared.config.channelTypesConfig

        switch section {
        case .chats:
            guard hasMoreChatMessages else { return }
            let newOffset = chatMessagesOffset + Self.pageSize

            loadMoreTask?.cancel()
            loadMoreTask = Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let result = await fetchMessages(
                    basePredicate: basePredicate,
                    channelTypes: [config.direct, config.group],
                    memberUserId: currentMemberUserId,
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
                let result = await fetchMessages(
                    basePredicate: basePredicate,
                    channelTypes: [config.broadcast],
                    memberUserId: currentMemberUserId,
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

    private func fetchMessages(basePredicate: NSPredicate,
                               channelTypes: [String],
                               memberUserId: UserId? = nil,
                               offset: Int = 0,
                               limit: Int = pageSize) async -> ([ChatMessage], [ChannelId: ChatChannel]) {
        await withCheckedContinuation { cont in
            database.read { [basePredicate, channelTypes, memberUserId] context in
                // 1. Resolve channel IDs for the requested types,
                //    optionally restricted to channels containing a specific member.
                let channelRequest = ChannelDTO.fetchRequest()
                if let memberUserId {
                    let memberRequest = MemberDTO.fetchRequest()
                    memberRequest.predicate = NSPredicate(format: "user.id == %@", memberUserId)
                    let memberDTOs = MemberDTO.fetch(request: memberRequest, context: context)
                    let memberChannelIds = memberDTOs.map { $0.channelId }
                    channelRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "type IN %@", channelTypes),
                        NSPredicate(format: "id IN %@", memberChannelIds)
                    ])
                } else {
                    channelRequest.predicate = NSPredicate(format: "type IN %@", channelTypes)
                }
                let channelDTOs = ChannelDTO.fetch(request: channelRequest, context: context)
                let channelIds: [Int64] = channelDTOs.map { $0.id }

                guard !channelIds.isEmpty else { return ([ChatMessage](), [:]) }

                // 2. Fetch messages matching the body tokens within those channels.
                let msgRequest = MessageDTO.fetchRequest()
                msgRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    basePredicate,
                    NSPredicate(format: "channelId IN %@", channelIds)
                ])
                msgRequest.sortDescriptors = [
                    NSSortDescriptor(keyPath: \MessageDTO.createdAt, ascending: false)
                ]
                msgRequest.fetchOffset = offset
                msgRequest.fetchLimit = limit

                let messages = (try? context.fetch(msgRequest))?.map { $0.convert() } ?? []

                // 3. Build channelId → ChatChannel map for only the channels that have results.
                let resultChannelIds = Set(messages.map { $0.channelId })
                let channelMap: [ChannelId: ChatChannel] = channelDTOs.reduce(into: [:]) { map, dto in
                    let id = ChannelId(dto.id)
                    guard resultChannelIds.contains(id) else { return }
                    map[id] = dto.convert()
                }

                return (messages, channelMap)
            } completion: { result in
                cont.resume(returning: (try? result.get()) ?? ([], [:]))
            }
        }
    }
}
