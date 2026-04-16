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

        open lazy var searchEmptyStateView = EmptyStateStackView()
            .withoutAutoresizingMask

        private var _linkViewModel: (any ChannelAttachmentListViewModelProviding)?
        private var searchItems: [(indexPath: IndexPath, layout: MessageLayoutModel.AttachmentLayout)] = []
        private var cancellables = Set<AnyCancellable>()
        private var heightUpdateWork: DispatchWorkItem?

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
            RunLoop.main.perform { [weak self] in
                self?._linkViewModel?.startDatabaseObserver()
            }
            _linkViewModel?.loadAttachments()
            _linkViewModel?.eventPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    print("called reloadSearchTable()")
                    self?.reloadSearchTable()
                }
                .store(in: &cancellables)
            reloadSearchTable()
        }

        override open var scrollViewsToAdjust: [UIScrollView] { [searchTableView] }

        open func configure(linkViewModel: any ChannelAttachmentListViewModelProviding) {
            _linkViewModel = linkViewModel
        }

        func prefetchLinkMetadata() {
            guard let vm = _linkViewModel else { return }
            for item in searchItems where item.layout.linkMetadata == nil {
                guard item.layout.attachment.imageDecodedMetadata?.hideLinkDetails != true else { continue }
                _ = vm.attachmentLayout(at: item.indexPath, onLoadLinkMetadata: { [weak self] metadata in
                    item.layout.linkMetadata = metadata
                    self?.setNeedsHeightUpdate()
                })
            }
        }

        func setNeedsHeightUpdate() {
            print("setNeedsHeightUpdate() called")
            heightUpdateWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.searchTableView.beginUpdates()
                self?.searchTableView.endUpdates()
            }
            heightUpdateWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
        }

        open func reloadSearchTable() {
            guard let vm = _linkViewModel else { return }
            let filtered = vm.isFiltered

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
            prefetchLinkMetadata()
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
