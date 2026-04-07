//
//  GlobalSearchResultsViewController.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit on 06.04.25
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

open class GlobalSearchResultsViewController: ChannelSearchResultsBaseViewController,
    UIPageViewControllerDataSource,
    UIPageViewControllerDelegate
{

    // MARK: - Category

    public enum Category: Int, CaseIterable {
        case chats
        case channels
        case media
        case voice
        case files
        case links

        public var title: String {
            switch self {
            case .chats:    return L10n.Search.Category.chats
            case .channels: return L10n.Search.Category.channels
            case .media:    return L10n.Search.Category.media
            case .voice:    return L10n.Search.Category.voice
            case .files:    return L10n.Search.Category.files
            case .links:    return L10n.Search.Category.links
            }
        }
    }

    // MARK: - UI

    open lazy var categoryTabBar = CategoryTabBar(categories: Category.allCases.map { $0.title })
        .withoutAutoresizingMask

    open lazy var pageViewController = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal,
        options: nil
    )

    /// Container that owns the pageViewController's view, so UIPageViewController's
    /// internal layout doesn't conflict with our categoryTabBar constraints.
    open lazy var pageContainerView = UIView()
        .withoutAutoresizingMask

    // MARK: - Pages

    open lazy var chatsPage: ChatsPageViewController = {
        let vc = ChatsPageViewController()
        vc.onSelect = { [weak self] channel in
            self?.resultsUpdater.select(channel)
        }
        return vc
    }()

    open lazy var channelsPage: ChannelsPageViewController = {
        let vc = ChannelsPageViewController()
        vc.onSelect = { [weak self] channel in
            self?.resultsUpdater.select(channel)
        }
        return vc
    }()

    open lazy var mediaPage = MediaPageViewController()
    open lazy var voicePage = VoicePageViewController()
    open lazy var filesPage = FilesPageViewController()
    open lazy var linksPage = LinksPageViewController()

    public var pages: [UIViewController] {
        [chatsPage, channelsPage, mediaPage, voicePage, filesPage, linksPage]
    }

    // MARK: - State

    private var currentIndex: Int = 0
    private var isAnimatingPageTransition = false

    // MARK: - Init

    public required init() {
        super.init(nibName: nil, bundle: nil)
        parentAppearance = GlobalSearchResultsViewController.defaultAppearance
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        parentAppearance = GlobalSearchResultsViewController.defaultAppearance
    }

    // MARK: - Lifecycle

    override open func setup() {
        categoryTabBar.onSelect = { [weak self] index in
            self?.selectPage(at: index, animated: true)
        }

        pageViewController.dataSource = self
        pageViewController.delegate = self
        pageViewController.setViewControllers([chatsPage], direction: .forward, animated: false)

        addChild(pageViewController)
    }

    override open func setupLayout() {
        view.addSubview(pageContainerView)
        view.addSubview(categoryTabBar) // added last so it stays on top

        pageContainerView.addSubview(pageViewController.view.withoutAutoresizingMask)

        NSLayoutConstraint.activate([
            categoryTabBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            categoryTabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryTabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryTabBar.heightAnchor.constraint(equalToConstant: Layouts.tabBarHeight),

            pageContainerView.topAnchor.constraint(equalTo: categoryTabBar.bottomAnchor),
            pageContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            pageViewController.view.topAnchor.constraint(equalTo: pageContainerView.topAnchor),
            pageViewController.view.leadingAnchor.constraint(equalTo: pageContainerView.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: pageContainerView.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: pageContainerView.bottomAnchor)
        ])
    }

    override open func setupAppearance() {
        view.backgroundColor = appearance.backgroundColor
        if let tabAppearance = (appearance as? Appearance)?.tabBarAppearance {
            categoryTabBar.appearance = tabAppearance
        }
    }

    override open func setupDone() {
        pageViewController.didMove(toParent: self)
        // Attach live scroll sync after layout
        DispatchQueue.main.async { [weak self] in
            self?.attachPageScrollObservation()
        }
    }

    // MARK: - Public API

    override open func reloadData() {
        let result = resultsUpdater.searchResults

        // Chats: direct + group channels (section 0 in ChannelSearchResultImp)
        var chatChannels: [ChatChannel] = []
        var broadcastChannels: [ChatChannel] = []

        for section in 0..<result.numberOfSections {
            for row in 0..<result.numberOfChannels(in: section) {
                guard let ch = result.channel(at: IndexPath(row: row, section: section)) else { continue }
                switch ch.channelType {
                case .direct, .group:
                    chatChannels.append(ch)
                case .broadcast:
                    broadcastChannels.append(ch)
                }
            }
        }

        chatsPage.channels = chatChannels
        channelsPage.channels = broadcastChannels
        chatsPage.reloadData()
        channelsPage.reloadData()
    }

    override open func showEmptyViewIfNeeded() {
        // Per-page empty state is handled by each page VC
    }

    // MARK: - Page Navigation

    open func selectPage(at index: Int, animated: Bool) {
        guard index != currentIndex, pages.indices.contains(index) else { return }
        let direction: UIPageViewController.NavigationDirection = index > currentIndex ? .forward : .reverse
        isAnimatingPageTransition = true
        pageViewController.setViewControllers([pages[index]], direction: direction, animated: animated) { [weak self] _ in
            self?.isAnimatingPageTransition = false
        }
        categoryTabBar.setSelectedIndex(index, animated: animated)
        currentIndex = index
    }

    // MARK: - UIPageViewControllerDataSource

    open func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let index = pages.firstIndex(of: viewController), index > 0 else { return nil }
        return pages[index - 1]
    }

    open func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let index = pages.firstIndex(of: viewController), index < pages.count - 1 else { return nil }
        return pages[index + 1]
    }

    // MARK: - UIPageViewControllerDelegate

    open func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let currentVC = pageViewController.viewControllers?.first,
              let index = pages.firstIndex(of: currentVC)
        else { return }

        currentIndex = index
        categoryTabBar.setSelectedIndex(index, animated: true)
    }

    // MARK: - Live scroll progress

    private var pageScrollObservation: NSKeyValueObservation?

    private func attachPageScrollObservation() {
        guard let scrollView = pageViewController.view.subviews.compactMap({ $0 as? UIScrollView }).first
        else { return }

        pageScrollObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] sv, _ in
            guard let self, !self.isAnimatingPageTransition else { return }
            let pageWidth = sv.bounds.width
            guard pageWidth > 0 else { return }
            // UIPageViewController internal scroll view keeps the current page at x = pageWidth (center of 3-page layout)
            let progress = (sv.contentOffset.x / pageWidth) - 1.0  // -1…0…+1
            self.categoryTabBar.updateIndicatorProgress(
                progress: progress,
                currentIndex: self.currentIndex,
                pageCount: self.pages.count
            )
        }
    }
}

// MARK: - Layouts

public extension GlobalSearchResultsViewController {
    enum Layouts {
        public static var tabBarHeight: CGFloat = 49
    }
}

// MARK: - CategoryTabBar

extension GlobalSearchResultsViewController {

    open class CategoryTabBar: View {

        // MARK: Appearance

        public struct Appearance {
            public var backgroundColor: UIColor? = .background
            public var tabFont: UIFont = Fonts.semiBold.withSize(14)
            public var selectedTabColor: UIColor = .primaryText
            public var unselectedTabColor: UIColor = .secondaryText
            public var selectedTabBackgroundColor: UIColor? = DefaultColors.surface1
            public var unselectedTabBorderColor: UIColor = DefaultColors.border
            public var indicatorColor: UIColor = .accent
            public var separatorColor: UIColor = DefaultColors.border
            public var indicatorHeight: CGFloat = 0
            public var tabCornerRadius: CGFloat = 16
            public var tabMinWidth: CGFloat = 72
            public var tabHorizontalPadding: CGFloat = 16
            public var tabVerticalPadding: CGFloat = 8
            public var tabSpacing: CGFloat = 8
            public var scrollViewContentInset: UIEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

            public init() {}
        }

        // MARK: Properties

        public var appearance = Appearance() {
            didSet { applyAppearance() }
        }

        private let tabTitles: [String]
        private var tabButtons: [UIButton] = []
        private(set) public var selectedIndex: Int = 0

        public var onSelect: ((Int) -> Void)?

        // MARK: Subviews

        open lazy var scrollView: UIScrollView = {
            let sv = UIScrollView()
            sv.showsHorizontalScrollIndicator = false
            sv.showsVerticalScrollIndicator = false
            sv.bounces = true
            sv.alwaysBounceHorizontal = true
            sv.translatesAutoresizingMaskIntoConstraints = false
            return sv
        }()

        open lazy var stackView: UIStackView = {
            let sv = UIStackView()
            sv.axis = .horizontal
            sv.alignment = .center
            sv.distribution = .fill
            sv.spacing = appearance.tabSpacing
            sv.translatesAutoresizingMaskIntoConstraints = false
            return sv
        }()

        open lazy var indicatorView: UIView = {
            let v = UIView()
            v.translatesAutoresizingMaskIntoConstraints = false
            return v
        }()

        open lazy var separatorLine: UIView = {
            let v = UIView()
            v.translatesAutoresizingMaskIntoConstraints = false
            return v
        }()

        private var indicatorLeading: NSLayoutConstraint!
        private var indicatorWidth: NSLayoutConstraint!

        // MARK: Init

        public required init(categories: [String]) {
            self.tabTitles = categories
            super.init(frame: .zero)
        }

        public required init?(coder: NSCoder) {
            self.tabTitles = []
            super.init(coder: coder)
        }

        // MARK: Configurable

        override open func setup() {
            super.setup()
            buildTabs()
        }

        override open func setupLayout() {
            super.setupLayout()

            addSubview(scrollView)
            addSubview(separatorLine)
            scrollView.addSubview(stackView)
            scrollView.addSubview(indicatorView)

            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: separatorLine.topAnchor),

                separatorLine.leadingAnchor.constraint(equalTo: leadingAnchor),
                separatorLine.trailingAnchor.constraint(equalTo: trailingAnchor),
                separatorLine.bottomAnchor.constraint(equalTo: bottomAnchor),
                separatorLine.heightAnchor.constraint(equalToConstant: 1),

                stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
                stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
            ])

            indicatorLeading = indicatorView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor)
            indicatorWidth = indicatorView.widthAnchor.constraint(equalToConstant: appearance.tabMinWidth)
            NSLayoutConstraint.activate([
                indicatorLeading,
                indicatorWidth,
                indicatorView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                indicatorView.heightAnchor.constraint(equalToConstant: appearance.indicatorHeight)
            ])
        }

        override open func setupAppearance() {
            super.setupAppearance()
            applyAppearance()
        }

        // MARK: Build

        private func buildTabs() {
            tabButtons = tabTitles.enumerated().map { index, title in
                makeTabButton(title: title, index: index)
            }
            tabButtons.forEach { stackView.addArrangedSubview($0) }
            updateTabStates()
        }

        private func makeTabButton(title: String, index: Int) -> UIButton {
            let btn = UIButton(type: .system)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = appearance.tabFont
            btn.contentEdgeInsets = UIEdgeInsets(
                top: appearance.tabVerticalPadding,
                left: appearance.tabHorizontalPadding,
                bottom: appearance.tabVerticalPadding,
                right: appearance.tabHorizontalPadding
            )
            btn.layer.cornerRadius = appearance.tabCornerRadius
            btn.layer.borderWidth = 1
            btn.clipsToBounds = true
            btn.tag = index
            btn.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            let minW = btn.widthAnchor.constraint(greaterThanOrEqualToConstant: appearance.tabMinWidth)
            minW.isActive = true
            return btn
        }

        @objc
        private func tabTapped(_ sender: UIButton) {
            let index = sender.tag
            guard index != selectedIndex else { return }
            setSelectedIndex(index, animated: true)
            onSelect?(index)
        }

        // MARK: Public API

        open func setSelectedIndex(_ index: Int, animated: Bool) {
            guard tabButtons.indices.contains(index) else { return }
            selectedIndex = index
            updateTabStates()
            scrollToVisible(index: index, animated: animated)
            moveIndicator(to: index, animated: animated)
        }

        /// Animates the indicator between pages as the user swipes.
        /// progress: -1.0 (swiping to previous) … 0 … +1.0 (swiping to next)
        open func updateIndicatorProgress(progress: CGFloat, currentIndex: Int, pageCount: Int) {
            guard !tabButtons.isEmpty else { return }

            let fromIndex = max(0, min(currentIndex, tabButtons.count - 1))
            let toIndex: Int
            let t: CGFloat  // 0…1

            if progress < 0 {
                toIndex = max(0, fromIndex - 1)
                t = -progress
            } else if progress > 0 {
                toIndex = min(pageCount - 1, fromIndex + 1)
                t = progress
            } else {
                return
            }

            guard tabButtons.indices.contains(fromIndex), tabButtons.indices.contains(toIndex) else { return }

            let fromBtn = tabButtons[fromIndex]
            let toBtn = tabButtons[toIndex]

            let fromX = fromBtn.frame.minX
            let toX = toBtn.frame.minX
            let fromW = fromBtn.frame.width
            let toW = toBtn.frame.width

            indicatorLeading.constant = fromX + (toX - fromX) * t
            indicatorWidth.constant = fromW + (toW - fromW) * t

            // Interpolate label colours
            let selected = appearance.selectedTabColor
            let unselected = appearance.unselectedTabColor

            tabButtons.enumerated().forEach { idx, btn in
                if idx == fromIndex {
                    btn.setTitleColor(selected.interpolated(to: unselected, fraction: t), for: .normal)
                } else if idx == toIndex {
                    btn.setTitleColor(unselected.interpolated(to: selected, fraction: t), for: .normal)
                } else {
                    btn.setTitleColor(unselected, for: .normal)
                }
            }
        }

        // MARK: Helpers

        private func moveIndicator(to index: Int, animated: Bool) {
            guard tabButtons.indices.contains(index) else { return }
            let btn = tabButtons[index]
            let apply = {
                self.indicatorLeading.constant = btn.frame.minX
                self.indicatorWidth.constant = btn.frame.width
                self.layoutIfNeeded()
            }
            if animated {
                UIView.animate(withDuration: 0.25, animations: apply)
            } else {
                apply()
            }
        }

        private func updateTabStates() {
            tabButtons.enumerated().forEach { idx, btn in
                let isSelected = idx == selectedIndex
                btn.setTitleColor(isSelected ? appearance.selectedTabColor : appearance.unselectedTabColor, for: .normal)
                btn.backgroundColor = isSelected ? appearance.selectedTabBackgroundColor : nil
                btn.layer.borderColor = isSelected ? UIColor.clear.cgColor : appearance.unselectedTabBorderColor.cgColor
            }
        }

        private func scrollToVisible(index: Int, animated: Bool) {
            guard tabButtons.indices.contains(index) else { return }
            let btn = tabButtons[index]
            let rect = btn.convert(btn.bounds, to: scrollView)
            scrollView.scrollRectToVisible(rect.insetBy(dx: -16, dy: 0), animated: animated)
        }

        private func applyAppearance() {
            backgroundColor = appearance.backgroundColor
            separatorLine.backgroundColor = appearance.separatorColor
            indicatorView.backgroundColor = appearance.indicatorColor
            stackView.spacing = appearance.tabSpacing
            scrollView.contentInset = appearance.scrollViewContentInset
            tabButtons.enumerated().forEach { idx, btn in
                let isSelected = idx == selectedIndex
                btn.titleLabel?.font = appearance.tabFont
                btn.setTitleColor(isSelected ? appearance.selectedTabColor : appearance.unselectedTabColor, for: .normal)
                btn.backgroundColor = isSelected ? appearance.selectedTabBackgroundColor : nil
                btn.layer.cornerRadius = appearance.tabCornerRadius
                btn.layer.borderWidth = 1
                btn.layer.borderColor = isSelected ? UIColor.clear.cgColor : appearance.unselectedTabBorderColor.cgColor
                btn.contentEdgeInsets = UIEdgeInsets(
                    top: appearance.tabVerticalPadding,
                    left: appearance.tabHorizontalPadding,
                    bottom: appearance.tabVerticalPadding,
                    right: appearance.tabHorizontalPadding
                )
            }
        }

        override open func layoutSubviews() {
            super.layoutSubviews()
            // Sync indicator to selected tab after layout pass (no animation)
            guard tabButtons.indices.contains(selectedIndex) else { return }
            let btn = tabButtons[selectedIndex]
            indicatorLeading.constant = btn.frame.minX
            indicatorWidth.constant = btn.frame.width
        }
    }
}

// MARK: - Page View Controllers

extension GlobalSearchResultsViewController {

    // MARK: Shared Table Page Base

    open class ChannelTablePageViewController: ViewController,
        UITableViewDelegate,
        UITableViewDataSource
    {
        public var channels: [ChatChannel] = []
        public var onSelect: ((ChatChannel) -> Void)?

        open lazy var tableView = UITableView()
            .withoutAutoresizingMask

        open lazy var emptyStateView = EmptyStateStackView()
            .withoutAutoresizingMask

        override open func setup() {
            super.setup()
            tableView.delegate = self
            tableView.dataSource = self
            tableView.separatorStyle = .none
            tableView.register(Components.searchResultChannelCell.self)
            tableView.tableFooterView = UIView()
            tableView.estimatedRowHeight = 56
            if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 0 }

            emptyStateView.title = L10n.Search.NoResults.title
            emptyStateView.message = L10n.Search.NoResults.message
            emptyStateView.icon = .noResultsSearch
        }

        override open func setupLayout() {
            super.setupLayout()
            view.addSubview(tableView)
            view.addSubview(emptyStateView)
            tableView.pin(to: view)
            emptyStateView.pin(to: view, anchors: [.centerX, .top(50), .leading(16, .greaterThanOrEqual)])
        }

        override open func setupAppearance() {
            super.setupAppearance()
            view.backgroundColor = .background
            tableView.backgroundColor = .clear
        }

        open func reloadData() {
            tableView.reloadData()
            emptyStateView.isHidden = !channels.isEmpty
        }

        // MARK: UITableViewDataSource

        public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            channels.count
        }

        public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.searchResultChannelCell.self)
            cell.separatorView.isHidden = indexPath.row == channels.count - 1
            cell.channelData = channels[indexPath.row]
            return cell
        }

        public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            onSelect?(channels[indexPath.row])
        }
    }

    // MARK: Chats Page

    open class ChatsPageViewController: ChannelTablePageViewController {}

    // MARK: Channels Page

    open class ChannelsPageViewController: ChannelTablePageViewController {}

    // MARK: Base Attachment Page

    open class AttachmentPageViewController: ViewController {
        open var noItemsMessage: String? {
            didSet { emptyStateView.title = noItemsMessage }
        }
        open var noItemsMessageSubTitle: String? {
            didSet { emptyStateView.message = noItemsMessageSubTitle }
        }
        open var noItemsIcon: UIImage? {
            didSet { emptyStateView.icon = noItemsIcon }
        }

        open lazy var emptyStateView = EmptyStateStackView()
            .withoutAutoresizingMask

        override open func setupLayout() {
            super.setupLayout()
            view.addSubview(emptyStateView)
            emptyStateView.pin(to: view, anchors: [.centerX, .centerY, .leading(16, .greaterThanOrEqual)])
        }

        override open func setupAppearance() {
            super.setupAppearance()
            view.backgroundColor = .background
        }

        open func embedAttachmentView(_ attachmentView: UIView) {
            view.insertSubview(attachmentView.withoutAutoresizingMask, belowSubview: emptyStateView)
            attachmentView.pin(to: view)
            emptyStateView.isHidden = true
        }

        open func updateEmptyState() {
            // Override in subclasses if needed
        }
    }

    // MARK: Media Page

    open class MediaPageViewController: AttachmentPageViewController {
        open lazy var collectionView = Components.channelInfoMediaCollectionView.init()

        override open func setup() {
            super.setup()
            noItemsMessage = L10n.Channel.Info.Segment.Medias.noItems
            noItemsMessageSubTitle = L10n.Channel.Info.Segment.Medias.noItemsSubTitle
            noItemsIcon = UIImage.emptyMedia
        }

        override open func setupLayout() {
            super.setupLayout()
            embedAttachmentView(collectionView)
        }

        open func configure(mediaViewModel: ChannelAttachmentListViewModel) {
            collectionView.mediaViewModel = mediaViewModel
        }
    }

    // MARK: Voice Page

    open class VoicePageViewController: AttachmentPageViewController {
        open lazy var collectionView = Components.channelInfoVoiceCollectionView.init()

        override open func setup() {
            super.setup()
            noItemsMessage = L10n.Channel.Info.Segment.Voice.noItems
            noItemsMessageSubTitle = L10n.Channel.Info.Segment.Voice.noItemsSubTitle
            noItemsIcon = UIImage.emptyVoice
        }

        override open func setupLayout() {
            super.setupLayout()
            embedAttachmentView(collectionView)
        }

        open func configure(voiceViewModel: ChannelAttachmentListViewModel) {
            collectionView.voiceViewModel = voiceViewModel
        }
    }

    // MARK: Files Page

    open class FilesPageViewController: AttachmentPageViewController {
        open lazy var collectionView = Components.channelInfoFileCollectionView.init()

        override open func setup() {
            super.setup()
            noItemsMessage = L10n.Channel.Info.Segment.Files.noItems
            noItemsMessageSubTitle = L10n.Channel.Info.Segment.Files.noItemsSubTitle
            noItemsIcon = UIImage.emptyFiles
        }

        override open func setupLayout() {
            super.setupLayout()
            embedAttachmentView(collectionView)
        }

        open func configure(fileViewModel: ChannelAttachmentListViewModel, onSelect: ((IndexPath) -> Void)? = nil) {
            collectionView.fileViewModel = fileViewModel
            collectionView.onSelect = onSelect
        }
    }

    // MARK: Links Page

    open class LinksPageViewController: AttachmentPageViewController {
        open lazy var collectionView = Components.channelInfoLinkCollectionView.init()

        override open func setup() {
            super.setup()
            noItemsMessage = L10n.Channel.Info.Segment.Links.noItems
            noItemsMessageSubTitle = L10n.Channel.Info.Segment.Links.noItemsSubTitle
            noItemsIcon = UIImage.emptyLinks
        }

        override open func setupLayout() {
            super.setupLayout()
            embedAttachmentView(collectionView)
        }

        open func configure(linkViewModel: ChannelAttachmentListViewModel) {
            collectionView.linkViewModel = linkViewModel
        }
    }
}

// MARK: - UIColor interpolation helper

private extension UIColor {
    func interpolated(to other: UIColor, fraction: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = max(0, min(1, fraction))
        return UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }
}
