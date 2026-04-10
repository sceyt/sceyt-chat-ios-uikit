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

    /// Override in test subclasses to inject an in-memory database.
    open var database: Database { SceytChatUIKit.shared.database }

    // MARK: - Init

    public override required init() {
        super.init()
    }

    // MARK: - Observer

    /// No persistent observer is needed – results are fetched on demand.
    open func startDatabaseObserver() {}

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

            currentSearchTask?.cancel()
            currentSearchTask = Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }

                async let directResult    = fetchMessages(basePredicate: basePredicate,
                                                          channelTypes: [config.direct],
                                                          memberUserId: filterUser.id)
                async let groupResult     = fetchMessages(basePredicate: basePredicate,
                                                          channelTypes: [config.group],
                                                          memberUserId: filterUser.id)
                async let broadcastResult = fetchMessages(basePredicate: basePredicate,
                                                          channelTypes: [config.broadcast],
                                                          memberUserId: filterUser.id)
                let (direct, group, broadcast) = await (directResult, groupResult, broadcastResult)

                guard !Task.isCancelled else { return }

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    chatMessages           = direct.0 + group.0
                    channelMessages        = broadcast.0
                    chatMessageChannels    = direct.1.merging(group.1) { $1 }
                    channelMessageChannels = broadcast.1
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

            currentSearchTask?.cancel()
            currentSearchTask = Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }

                async let chatResult    = fetchMessages(basePredicate: basePredicate,
                                                        channelTypes: [config.direct, config.group])
                async let channelResult = fetchMessages(basePredicate: basePredicate,
                                                        channelTypes: [config.broadcast])
                let (chatsResult, channelsResult) = await (chatResult, channelResult)

                guard !Task.isCancelled else { return }

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    chatMessages            = chatsResult.0
                    channelMessages         = channelsResult.0
                    chatMessageChannels     = chatsResult.1
                    channelMessageChannels  = channelsResult.1
                    event = .reload
                }
            }
        }
    }

    // MARK: - DB fetch

    private func fetchMessages(basePredicate: NSPredicate,
                               channelTypes: [String],
                               memberUserId: UserId? = nil) async -> ([ChatMessage], [ChannelId: ChatChannel]) {
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
                msgRequest.fetchLimit = 100

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
