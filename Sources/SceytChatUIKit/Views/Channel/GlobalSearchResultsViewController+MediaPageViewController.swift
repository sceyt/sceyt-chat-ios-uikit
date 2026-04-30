//
//  GlobalSearchResultsViewController+MediaPageViewController.swift
//  SceytChatUIKit
//

import UIKit
import Combine
import SceytChat

extension GlobalSearchResultsViewController {

    open class MediaPageViewController: AttachmentPageViewController {
        
        private var _isFiltered: Bool?
        
        open lazy var collectionView = Components.channelInfoMediaCollectionView.init()

        override open var scrollViewsToAdjust: [UIScrollView] { [collectionView, searchTableView] }

        open lazy var searchTableView: UITableView = {
            let tv = UITableView()
            tv.translatesAutoresizingMaskIntoConstraints = false
            tv.separatorStyle = .none
            tv.rowHeight = UITableView.automaticDimension
            tv.estimatedRowHeight = 80
            tv.dataSource = self
            tv.delegate = self
            tv.register(
                Components.globalSearchMediaCell,
                forCellReuseIdentifier: String(describing: Components.globalSearchMediaCell)
            )
            return tv
        }()

        /// Appearance applied to `GlobalSearchMediaCell` cells in the search table.
        open var mediaSearchCellAppearance: GlobalSearchMediaCell.Appearance?

        /// The active search query forwarded to each cell for text highlighting.
        open var searchQuery: String?

        /// Called when the user taps a row in the search table.
        open var onSelectAttachment: ((ChatMessage, ChatChannel?) -> Void)?

        open lazy var searchEmptyStateView = EmptyStateStackView()
            .withoutAutoresizingMask

        private var _mediaViewModel: (any ChannelAttachmentListViewModelProviding)?
        private var searchLayouts: [MessageLayoutModel.AttachmentLayout] = []
        private var channelCache: [ChannelId: ChatChannel] = [:]
        private var cancellables = Set<AnyCancellable>()

        override open func setup() {
            super.setup()
            noItemsMessage = L10n.Channel.Info.Segment.Medias.noItems
            noItemsMessageSubTitle = L10n.Channel.Info.Segment.Medias.noItemsSubTitle
            noItemsIcon = UIImage.emptyMedia
            searchEmptyStateView.title = L10n.Search.NoResults.title
            searchEmptyStateView.message = L10n.Search.NoResults.message
            searchEmptyStateView.icon = .noResultsSearch
        }

        override open func setupLayout() {
            super.setupLayout()
            embedAttachmentView(collectionView)
            view.insertSubview(searchTableView, belowSubview: emptyStateView)
            searchTableView.pin(to: view)
            searchTableView.isHidden = true
            view.addSubview(searchEmptyStateView)
            searchEmptyStateView.pin(to: view, anchors: [.centerX, .top(50), .leading(16, .greaterThanOrEqual)])
            searchEmptyStateView.isHidden = true
        }

        override open func setupAppearance() {
            super.setupAppearance()
            searchTableView.backgroundColor = .background
        }

        override open func setupDone() {
            super.setupDone()
            _mediaViewModel?.eventPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.reloadSearchTable() }
                .store(in: &cancellables)
            reloadSearchTable()
        }

        open func configure(mediaViewModel: any ChannelAttachmentListViewModelProviding) {
            _mediaViewModel = mediaViewModel
            collectionView.mediaViewModel = mediaViewModel
        }

        open func setFiltered(_ filtered: Bool) {
            guard _isFiltered != filtered else { return }
            _isFiltered = filtered

            if filtered {
                searchEmptyStateView.isHidden = true
            } else {
                collectionView.reloadData()
                collectionView.layoutIfNeeded()
                collectionView.updateNoItems()
                searchEmptyStateView.isHidden = true
            }

            DispatchQueue.main.async {
                self.collectionView.isHidden = filtered
                self.searchTableView.isHidden = !filtered
            }
        }

        open func reloadSearchTable() {
            guard let vm = _mediaViewModel else { return }
            let filtered = vm.isFiltered
            setFiltered(filtered)
            guard filtered else {
                searchLayouts = []
                searchTableView.reloadData()
                return
            }

            var layouts: [MessageLayoutModel.AttachmentLayout] = []
            var rowsPerSection: [Int] = []
            for section in 0..<vm.numberOfSections {
                let rows = vm.numberOfAttachments(in: section)
                rowsPerSection.append(rows)
                for row in 0..<rows {
                    if let layout = vm.attachmentLayout(at: IndexPath(row: row, section: section)) {
                        layouts.append(layout)
                    }
                }
            }
            searchLayouts = layouts
            channelCache.removeAll()
            searchTableView.reloadData()
            searchEmptyStateView.isHidden = !searchLayouts.isEmpty
        }

        func channel(for layout: MessageLayoutModel.AttachmentLayout) -> ChatChannel? {
            if let channel = layout.ownerChannel { return channel }
            guard let channelId = layout.ownerMessage?.channelId else { return nil }
            if let cached = channelCache[channelId] { return cached }
            let ctx = SceytChatUIKit.shared.database.viewContext
            let channel = ChannelDTO.fetch(id: channelId, context: ctx)?.convert()
            channelCache[channelId] = channel
            return channel
        }
    }

}

extension GlobalSearchResultsViewController.MediaPageViewController: UITableViewDataSource, UITableViewDelegate {

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        searchLayouts.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: String(describing: Components.globalSearchMediaCell),
            for: indexPath
        ) as! GlobalSearchMediaCell
        if let appearance = mediaSearchCellAppearance {
            cell.parentAppearance = appearance
        }
        let layout = searchLayouts[indexPath.row]
        let ch = channel(for: layout)
        if let message = layout.ownerMessage {
            cell.searchQuery = searchQuery
            cell.data = (channel: ch, message: message, layout: layout)
        }
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let layout = searchLayouts[indexPath.row]
        guard let message = layout.ownerMessage else { return }
        let ch = channel(for: layout)
        onSelectAttachment?(message, ch)
    }
}
