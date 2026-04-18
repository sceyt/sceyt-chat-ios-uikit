//
//  GlobalSearchResultsViewController+ChatsPageViewController.swift
//  SceytChatUIKit
//

import UIKit
import Combine
import SceytChat

extension GlobalSearchResultsViewController {

    open class ChatsPageViewController: ChannelTablePageViewController {

        // MARK: - Properties

        open var cellAppearance: ChannelListViewController.ChannelCell.Appearance = Components.channelCell.appearance

        private var layoutModels: [ChatChannel: ChannelLayoutModel] = [:]

        /// Clears all cached layout models so the next `reloadData()` call recreates them from scratch.
        /// Call this when something external to the channel (e.g. contact names) has changed so that
        /// `attributedView` is rebuilt with up-to-date formatter output.
        open func invalidateLayoutModels() {
            layoutModels.removeAll()
        }

        /// Stable snapshot used by both numberOfRowsInSection and cellForRowAt.
        /// Captured atomically inside reloadData() before tableView.reloadData() is called,
        /// preventing index-out-of-range crashes caused by async updates racing with cell dequeue.
        private var chatMessagesSnapshot: [ChatMessage] = []

        /// Section 0: matching chat channels (by subject).
        open lazy var viewModel: GlobalSearchViewModel = {
            let vm = Components.globalSearchViewModel.init()
            let config = SceytChatUIKit.shared.config.channelTypesConfig
            vm.channelTypes = [config.direct, config.group]
            return vm
        }()

        /// Section 1: matching messages (by body text) inside chat channels.
        open lazy var messagesViewModel: GlobalSearchMessagesViewModel =
            Components.globalSearchMessagesViewModel.init()

        open var separatorViewAppearance: SeparatorHeaderView.Appearance = Components.separatorHeaderView.appearance
        open var messagesSeparatorViewAppearance: SeparatorHeaderView.Appearance = Components.separatorHeaderView.appearance

        private var showMessagesSection = false

        /// Monotonically increasing counter bumped on every `search()` call.
        /// Sinks record the generation they last handled; if it differs from the current
        /// generation the response is stale and must not decrement `pendingResponseCount`.
        private var searchGeneration = 0
        private var channelsLastHandledGeneration = -1
        private var messagesLastHandledGeneration = -1

        /// Counts how many VM responses are still outstanding for the current search generation.
        /// Set to 2 when a new search starts; each VM response decrements it.
        /// The empty state is suppressed while this is > 0 to avoid a flash of "no results"
        /// before all VMs have had a chance to return data.
        private var pendingResponseCount = 0

        /// Called when the user taps a message search result. Provides both the message and its channel.
        public var onSelectMessage: ((ChatMessage, ChatChannel?) -> Void)?

        // MARK: - Setup

        override open func setup() {
            super.setup()
            tableView.register(Components.globalSearchChatsChannelCell)
            tableView.register(Components.separatorHeaderView.self)
            tableView.register(Components.globalSearchMessageCell.self)
        }

        override open func setupDone() {
            super.setupDone()

            // Section 0 – channel results
            viewModel.startDatabaseObserver()
            viewModel.$event
                .compactMap { $0 }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    if pendingResponseCount > 0 {
                        // Active search: deduplicate per generation to discard stale Task results
                        // from the previous query (viewModel does not cancel old Tasks).
                        guard channelsLastHandledGeneration != searchGeneration else { return }
                        channelsLastHandledGeneration = searchGeneration
                        channels = viewModel.channels
                        pendingResponseCount -= 1
                        if pendingResponseCount == 0 { reloadData() }
                    } else {
                        // Search already settled — this is a live DB observer update; reload immediately.
                        channels = viewModel.channels
                        reloadData()
                    }
                }
                .store(in: &subscriptions)

            // Section 1 – message results
            messagesViewModel.startDatabaseObserver()
            messagesViewModel.$event
                .compactMap { $0 }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    if pendingResponseCount > 0 {
                        // Active search: deduplicate per generation to avoid double-counting.
                        guard messagesLastHandledGeneration != searchGeneration else { return }
                        messagesLastHandledGeneration = searchGeneration
                        pendingResponseCount -= 1
                        if pendingResponseCount == 0 { reloadData() }
                    } else {
                        // Search already settled — live DB observer update (e.g. deleted message); reload immediately.
                        reloadData()
                    }
                }
                .store(in: &subscriptions)
        }

        // MARK: - Search

        @objc open func search(query: String?) {
            searchGeneration &+= 1
            pendingResponseCount = 2
            viewModel.search(query: query)
            messagesViewModel.search(query: query)
            showMessagesSection = messagesViewModel.shouldShowMessagesSection
        }

        // MARK: - Reload

        override open func reloadData() {
            var updated: [ChatChannel: ChannelLayoutModel] = [:]
            for channel in channels {
                if let existing = layoutModels[channel] {
                    _ = existing.update(channel: channel)
                    updated[channel] = existing
                } else {
                    updated[channel] = Components.channelLayoutModel.init(
                        channel: channel,
                        appearance: cellAppearance
                    )
                }
            }
            layoutModels = updated
            // Snapshot before reloadData() so numberOfRowsInSection and cellForRowAt
            // always see the same array, even if the VM updates concurrently.
            chatMessagesSnapshot = messagesViewModel.chatMessages
            tableView.reloadData()
            let hasVisibleChannels = viewModel.shouldShowChannelSection && !channels.isEmpty
            emptyStateView.isHidden = pendingResponseCount > 0 || hasVisibleChannels || !chatMessagesSnapshot.isEmpty
        }

        // MARK: - UITableViewDataSource

        public func numberOfSections(in tableView: UITableView) -> Int { 2 }

        override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            switch section {
            case 0: return viewModel.shouldShowChannelSection ? channels.count : 0
            case 1: return showMessagesSection ? chatMessagesSnapshot.count : 0
            default: return 0
            }
        }

        override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            switch indexPath.section {
            case 0:
                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.globalSearchChatsChannelCell)
                cell.parentAppearance = cellAppearance
                let channel = channels[indexPath.row]
                cell.data = layoutModels[channel]
                return cell
            default:
                guard chatMessagesSnapshot.indices.contains(indexPath.row) else {
                    return UITableViewCell()
                }
                let message = chatMessagesSnapshot[indexPath.row]
                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.globalSearchMessageCell.self)
                let channel = messagesViewModel.chatMessageChannels[message.channelId]
                cell.searchQuery = messagesViewModel.searchQuery
                cell.messageData = channel.map { ($0, message) }
                return cell
            }
        }

        public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
            switch section {
            case 0:
                guard viewModel.shouldShowChannelSection, !channels.isEmpty else { return nil }
                let header = tableView.dequeueReusableHeaderFooterView(Components.separatorHeaderView.self)
                header.parentAppearance = separatorViewAppearance
                return header
            case 1:
                guard showMessagesSection, !chatMessagesSnapshot.isEmpty else { return nil }
                let header = tableView.dequeueReusableHeaderFooterView(Components.separatorHeaderView.self)
                header.parentAppearance = messagesSeparatorViewAppearance
                return header
            default:
                return nil
            }
        }

        public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
            switch section {
            case 0: return (viewModel.shouldShowChannelSection && !channels.isEmpty) ? Components.separatorHeaderView.Layouts.height : 0
            case 1: return (showMessagesSection && !chatMessagesSnapshot.isEmpty) ? Components.separatorHeaderView.Layouts.height : 0
            default: return 0
            }
        }

        // MARK: - UITableViewDelegate

        public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
            guard indexPath.section == 1,
                  messagesViewModel.hasMoreChatMessages,
                  indexPath.row >= chatMessagesSnapshot.count - 3
            else { return }
            messagesViewModel.loadMoreMessages(in: .chats)
        }

        override public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            switch indexPath.section {
            case 0: onSelect?(channels[indexPath.row])
            default:
                guard chatMessagesSnapshot.indices.contains(indexPath.row) else { return }
                let message = chatMessagesSnapshot[indexPath.row]
                let channel = messagesViewModel.chatMessageChannels[message.channelId]
                onSelectMessage?(message, channel)
            }
        }
    }

}
