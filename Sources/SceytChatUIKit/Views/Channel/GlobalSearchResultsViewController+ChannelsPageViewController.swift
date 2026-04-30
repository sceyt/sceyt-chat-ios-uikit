//
//  GlobalSearchResultsViewController+ChannelsPageViewController.swift
//  SceytChatUIKit
//

import UIKit
import Combine
import SceytChat

extension GlobalSearchResultsViewController {

    open class ChannelsPageViewController: ChannelTablePageViewController {

        // MARK: - Properties

        open var separatorViewAppearance: SeparatorHeaderView.Appearance = Components.separatorHeaderView.appearance
        open var messagesSeparatorViewAppearance: SeparatorHeaderView.Appearance = Components.separatorHeaderView.appearance

        private var showMessagesSection = false

        /// Section 0: matching broadcast channels (by subject).
        open lazy var viewModel: GlobalSearchViewModel = {
            let vm = Components.globalSearchViewModel.init()
            vm.channelTypes = [SceytChatUIKit.shared.config.channelTypesConfig.broadcast]
            return vm
        }()

        /// Section 1: matching messages (by body text) inside broadcast channels.
        open lazy var messagesViewModel: GlobalSearchMessagesViewModel =
            Components.globalSearchMessagesViewModel.init()

        /// Stable snapshot used by both numberOfRowsInSection and cellForRowAt.
        private var channelMessagesSnapshot: [ChatMessage] = []

        /// Called when the user taps a message search result. Provides both the message and its channel.
        public var onSelectMessage: ((ChatMessage, ChatChannel?) -> Void)?

        // MARK: - Setup

        override open func setup() {
            super.setup()
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
            channelMessagesSnapshot = messagesViewModel.channelMessages
            tableView.reloadData()
            let hasVisibleChannels = viewModel.shouldShowChannelSection && !channels.isEmpty
            emptyStateView.isHidden = hasVisibleChannels || !channelMessagesSnapshot.isEmpty
        }

        // MARK: - UITableViewDataSource

        public func numberOfSections(in tableView: UITableView) -> Int { 2 }

        override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            switch section {
            case 0: return viewModel.shouldShowChannelSection ? channels.count : 0
            case 1: return showMessagesSection ? channelMessagesSnapshot.count : 0
            default: return 0
            }
        }

        override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            switch indexPath.section {
            case 0:
                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.searchResultChannelCell.self)
                cell.separatorView.isHidden = indexPath.row == channels.count - 1
                cell.channelData = channels[indexPath.row]
                return cell
            default:
                guard channelMessagesSnapshot.indices.contains(indexPath.row) else {
                    return UITableViewCell()
                }
                let message = channelMessagesSnapshot[indexPath.row]
                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.globalSearchMessageCell.self)
                let channel = messagesViewModel.channelMessageChannels[message.channelId]
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
                guard showMessagesSection, !channelMessagesSnapshot.isEmpty else { return nil }
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
            case 1: return (showMessagesSection && !channelMessagesSnapshot.isEmpty) ? Components.separatorHeaderView.Layouts.height : 0
            default: return 0
            }
        }

        // MARK: - UITableViewDelegate

        public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
            guard indexPath.section == 1,
                  messagesViewModel.hasMoreChannelMessages,
                  indexPath.row >= channelMessagesSnapshot.count - 3
            else { return }
            messagesViewModel.loadMoreMessages(in: .channels)
        }

        override public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            switch indexPath.section {
            case 0: onSelect?(channels[indexPath.row])
            default:
                guard channelMessagesSnapshot.indices.contains(indexPath.row) else { return }
                let message = channelMessagesSnapshot[indexPath.row]
                let channel = messagesViewModel.channelMessageChannels[message.channelId]
                onSelectMessage?(message, channel)
            }
        }
    }

}
