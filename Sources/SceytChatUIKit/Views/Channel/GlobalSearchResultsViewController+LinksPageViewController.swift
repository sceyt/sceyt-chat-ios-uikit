//
//  GlobalSearchResultsViewController+LinksPageViewController.swift
//  SceytChatUIKit
//

import UIKit
import Combine
import SceytChat

extension GlobalSearchResultsViewController {

    open class LinksPageViewController: AttachmentPageViewController {

        open lazy var searchTableView: UITableView = {
            let tv = UITableView()
            tv.translatesAutoresizingMaskIntoConstraints = false
            tv.separatorStyle = .none
            tv.rowHeight = UITableView.automaticDimension
            tv.estimatedRowHeight = 72
            tv.dataSource = self
            tv.delegate = self
            tv.register(
                Components.globalSearchLinkCell,
                forCellReuseIdentifier: String(describing: Components.globalSearchLinkCell)
            )
            return tv
        }()

        open var linkSearchCellAppearance: GlobalSearchLinkCell.Appearance?

        /// The active search query forwarded to each cell so matches in the title/URL/
        /// summary are re-coloured in `.primaryText`, surfacing which part was hit.
        open var searchQuery: String?

        open lazy var searchEmptyStateView = EmptyStateStackView()
            .withoutAutoresizingMask

        private var _linkViewModel: (any ChannelAttachmentListViewModelProviding)?
        private var searchItems: [(indexPath: IndexPath, layout: MessageLayoutModel.AttachmentLayout)] = []
        private var cancellables = Set<AnyCancellable>()
        /// URLs we've already issued a batch DB lookup for (success or miss). Prevents
        /// re-querying the same URLs on every paginated `reloadSearchTable`.
        private var requestedMetadataURLs = Set<URL>()

        override open func setup() {
            super.setup()
            noItemsMessage = L10n.Channel.Info.Segment.Links.noItems
            noItemsMessageSubTitle = L10n.Channel.Info.Segment.Links.noItemsSubTitle
            noItemsIcon = UIImage.emptyLinks
            searchEmptyStateView.title = L10n.Search.NoResults.title
            searchEmptyStateView.message = L10n.Search.NoResults.message
            searchEmptyStateView.icon = .noResultsSearch
        }

        override open func setupLayout() {
            super.setupLayout()
            embedAttachmentView(searchTableView)
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
            _linkViewModel?.eventPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.reloadSearchTable()
                }
                .store(in: &cancellables)
            // Start the observer first so `loadAttachments()` actually has somewhere to
            // dispatch into; otherwise the very first `loadNext()` runs against an
            // un-started observer and is wasted, delaying initial content.
            RunLoop.main.perform { [weak self] in
                self?._linkViewModel?.startDatabaseObserver()
                self?._linkViewModel?.loadAttachments()
            }
            reloadSearchTable()
        }

        override open var scrollViewsToAdjust: [UIScrollView] { [searchTableView] }

        open func configure(linkViewModel: any ChannelAttachmentListViewModelProviding) {
            _linkViewModel = linkViewModel
        }

        open func reloadSearchTable() {
            guard let vm = _linkViewModel else { return }
            let filtered = vm.isFiltered
            // Reset so new layout objects (e.g. from searchObserver) can re-query
            // the DB for metadata that may have been evicted from the in-memory cache.
            requestedMetadataURLs.removeAll()

            var items: [(indexPath: IndexPath, layout: MessageLayoutModel.AttachmentLayout)] = []
            for section in 0..<vm.numberOfSections {
                for row in 0..<vm.numberOfAttachments(in: section) {
                    let ip = IndexPath(row: row, section: section)
                    if let layout = vm.attachmentLayout(at: ip) {
                        items.append((indexPath: ip, layout: layout))
                    }
                }
            }
            searchItems = items

            // Sync pass: pull anything already in the in-memory cache so the first
            // `cellForRowAt` paints title/summary/icon immediately — no async race.
            resolveCachedLinkMetadata()

            searchTableView.reloadData()

            let isEmpty = searchItems.isEmpty
            if filtered {
                emptyStateView.isHidden = true
                searchTableView.isHidden = isEmpty
                searchEmptyStateView.isHidden = !isEmpty
            } else {
                searchEmptyStateView.isHidden = true
                emptyStateView.isHidden = !isEmpty
                searchTableView.isHidden = isEmpty
            }

            // Async pass: one batched DB lookup for the URLs still missing metadata.
            loadMissingLinkMetadata()
        }

        /// Pulls metadata that's already in `LinkMetadataProvider`'s in-memory cache and
        /// assigns it to layouts before the table reloads — no DB hop, no flicker.
        private func resolveCachedLinkMetadata() {
            for item in searchItems where item.layout.linkMetadata == nil {
                let attachment = item.layout.attachment
                guard attachment.imageDecodedMetadata?.hideLinkDetails != true,
                      let urlStr = attachment.url,
                      let url = URL(string: urlStr)?.normalizedURL,
                      let metadata = LinkMetadataProvider.default.metadata(for: url)
                else { continue }
                item.layout.linkMetadata = metadata
            }
        }

        /// Issues a single batched DB query for any visible link whose metadata isn't yet
        /// in the layout, then surgically updates only the still-visible cells. Avoids the
        /// N+1 fetch pattern and the full `reloadData()` shuffle that breaks scrolling.
        private func loadMissingLinkMetadata() {
            var urlsToFetch = [URL]()
            var seen = Set<URL>()
            for item in searchItems where item.layout.linkMetadata == nil {
                let attachment = item.layout.attachment
                guard attachment.imageDecodedMetadata?.hideLinkDetails != true,
                      let urlStr = attachment.url,
                      let url = URL(string: urlStr)?.normalizedURL,
                      !requestedMetadataURLs.contains(url),
                      seen.insert(url).inserted
                else { continue }
                urlsToFetch.append(url)
            }
            guard !urlsToFetch.isEmpty else { return }

            requestedMetadataURLs.formUnion(urlsToFetch)
            LinkMetadataProvider.default.fetchManyFromCacheOrDB(urls: urlsToFetch) { [weak self] resolved in
                guard let self, !resolved.isEmpty else { return }
                self.applyLinkMetadata(resolved)
            }
        }

        /// Assigns resolved metadata back to its layout and live-updates only the
        /// cells currently on screen, then asks the table to recompute their heights.
        private func applyLinkMetadata(_ resolved: [URL: LinkMetadata]) {
            var didTouchVisibleCell = false
            let visibleIndexPaths = Set(searchTableView.indexPathsForVisibleRows ?? [])
            for (i, item) in searchItems.enumerated() {
                guard item.layout.linkMetadata == nil,
                      let urlStr = item.layout.attachment.url,
                      let url = URL(string: urlStr)?.normalizedURL,
                      let metadata = resolved[url]
                else { continue }
                item.layout.linkMetadata = metadata
                let cellIP = IndexPath(row: i, section: 0)
                if visibleIndexPaths.contains(cellIP),
                   let cell = searchTableView.cellForRow(at: cellIP) as? GlobalSearchLinkCell {
                    cell.metadata = metadata
                    didTouchVisibleCell = true
                }
            }
            if didTouchVisibleCell {
                // No-op row updates that flush the auto-row-height layout pass for the
                // cells we just mutated — content stays put, no animations, smooth.
                UIView.performWithoutAnimation {
                    searchTableView.beginUpdates()
                    searchTableView.endUpdates()
                }
            }
        }
    }

}

extension GlobalSearchResultsViewController.LinksPageViewController: UITableViewDataSource, UITableViewDelegate {

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        searchItems.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: String(describing: Components.globalSearchLinkCell),
            for: indexPath
        ) as! GlobalSearchLinkCell
        if let appearance = linkSearchCellAppearance {
            cell.parentAppearance = appearance
        }
        guard indexPath.row < searchItems.count else { return cell }
        let item = searchItems[indexPath.row]
        // Set searchQuery before data/metadata so their `didSet` highlight passes pick it up.
        cell.searchQuery = searchQuery
        cell.data = item.layout

        if item.layout.attachment.imageDecodedMetadata?.hideLinkDetails != true,
           let cached = item.layout.linkMetadata {
            cell.metadata = cached
        }
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < searchItems.count else { return }
        let item = searchItems[indexPath.row]
        if let urlString = item.layout.attachment.url,
           let url = URL(string: urlString)?.normalizedURL {
            UIApplication.shared.open(url, options: [:])
        }
    }

    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let vm = _linkViewModel, !vm.isFiltered, vm.hasMore else { return }
        if indexPath.row == searchItems.count - 1 {
            vm.loadAttachments()
        }
    }
}
