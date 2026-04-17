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
                    channels = viewModel.channels
                    reloadData()
                }
                .store(in: &subscriptions)

            // Section 1 – message results
            messagesViewModel.startDatabaseObserver()
            messagesViewModel.$event
                .compactMap { $0 }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.reloadData()
                }
                .store(in: &subscriptions)
        }

        // MARK: - Search

        @objc open func search(query: String?) {
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
            emptyStateView.isHidden = hasVisibleChannels || !chatMessagesSnapshot.isEmpty
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
