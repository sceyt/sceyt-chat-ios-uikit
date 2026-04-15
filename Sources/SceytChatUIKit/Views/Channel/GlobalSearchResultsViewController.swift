//
//  GlobalSearchResultsViewController.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit on 06.04.25
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit
import Combine
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
        case files
        case voice
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

    open lazy var searchUserBarView = Components.globalSearchUserBarView.init()
        .withoutAutoresizingMask

    private var userBarBottom: NSLayoutConstraint!

    public var hasSearchToken: Bool = false

    /// When set, message results are scoped to channels that include this user.
    /// Passed down to the chats page's messagesViewModel before each search.
    public var filterUser: ChatUser?

    // MARK: - Pages

    /// Called when the user taps a message search result from any page.
    /// Receives the message and its parent channel so the caller can open the channel and scroll to the message.
    public var onSelectMessage: ((ChatMessage, ChatChannel) -> Void)?

    /// Called when the user taps a file attachment in the Files tab.
    public var onSelectAttachment: ((ChatMessage.Attachment) -> Void)?

    open lazy var chatsPage: ChatsPageViewController = {
        let vc = Components.globalSearchChatsPageViewController.init()
        vc.onSelect = { [weak self] channel in
            self?.resultsUpdater.select(channel)
        }
        vc.onSelectMessage = { [weak self] message, channel in
            guard let channel else { return }
            self?.onSelectMessage?(message, channel)
        }
        return vc
    }()

    open lazy var channelsPage: ChannelsPageViewController = {
        let vc = ChannelsPageViewController()
        vc.onSelect = { [weak self] channel in
            self?.resultsUpdater.select(channel)
        }
        vc.onSelectMessage = { [weak self] message, channel in
            guard let channel else { return }
            self?.onSelectMessage?(message, channel)
        }
        return vc
    }()

    private let channelListProvider = ChannelListProvider()

    open lazy var mediaPage = MediaPageViewController()
    open lazy var voicePage = VoicePageViewController()
    open lazy var filesPage = FilesPageViewController()
    open lazy var linksPage = LinksPageViewController()

    /// Loads all image/video attachments across every channel for the Media tab initial (no-query) state.
    open lazy var allMediaViewModel: any ChannelAttachmentListViewModelProviding =
        Components.globalSearchAllMediaViewModel.init(
            attachmentTypes: ["image", "video"],
            appearance: MessageCell.appearance
        )

    /// Loads all voice attachments across every channel for the Voice tab initial (no-query) state.
    open lazy var allVoiceViewModel: any ChannelAttachmentListViewModelProviding =
        Components.globalSearchAllVoiceViewModel.init(
            attachmentTypes: ["voice"],
            appearance: MessageCell.appearance
        )

    /// Loads all file attachments across every channel for the Files tab initial (no-query) state.
    open lazy var allFilesViewModel: any ChannelAttachmentListViewModelProviding =
        Components.globalSearchAllFilesViewModel.init(
            attachmentTypes: ["file"],
            appearance: MessageCell.appearance
        )

    /// Loads all link attachments across every channel for the Links tab initial (no-query) state.
    open lazy var allLinksViewModel: any ChannelAttachmentListViewModelProviding =
        Components.globalSearchAllLinksViewModel.init(
            attachmentTypes: ["link"],
            appearance: MessageCell.appearance
        )

    public var pages: [UIViewController] {
        [chatsPage, channelsPage, mediaPage, filesPage, voicePage, linksPage]
    }

    // MARK: - State

    private var currentIndex: Int = 0
    private var isAnimatingPageTransition = false
    private var serverSearchWorkItem: DispatchWorkItem?

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

        mediaPage.configure(mediaViewModel: allMediaViewModel)
        mediaPage.collectionView.previewer = {
            Components.globalSearchMediaPreviewDataSource.init()
        }
        mediaPage.onSelectAttachment = { [weak self] message, channel in
            guard let channel else { return }
            self?.onSelectMessage?(message, channel)
        }

        voicePage.configure(voiceViewModel: allVoiceViewModel)
        filesPage.configure(fileViewModel: allFilesViewModel) { [weak self] indexPath in
            guard let self,
                  let attachment = self.allFilesViewModel.attachmentLayout(at: indexPath)?.attachment
            else { return }
            self.onSelectAttachment?(attachment)
        }
        linksPage.configure(linkViewModel: allLinksViewModel)

        // searchUserBarView.onSelect can be customized by subclasses or the presenting VC
    }

    override open func setupLayout() {
        view.addSubview(pageContainerView)
        view.addSubview(searchUserBarView)
        view.addSubview(categoryTabBar) // added last so it stays on top

        pageContainerView.addSubview(pageViewController.view.withoutAutoresizingMask)

        userBarBottom = searchUserBarView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)

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
            pageViewController.view.bottomAnchor.constraint(equalTo: pageContainerView.bottomAnchor),

            searchUserBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchUserBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchUserBarView.heightAnchor.constraint(equalToConstant: GlobalSearchUserBarView.Layouts.height),
            userBarBottom
        ])

        searchUserBarView.alpha = 0
        searchUserBarView.isUserInteractionEnabled = false
    }

    override open func setupAppearance() {
        view.backgroundColor = appearance.backgroundColor
        if let appearance = appearance as? Appearance {
            categoryTabBar.appearance = appearance.tabBarAppearance
            chatsPage.cellAppearance = appearance.cellAppearance
            chatsPage.separatorViewAppearance = appearance.separatorViewAppearance
            chatsPage.messagesSeparatorViewAppearance = appearance.messagesSeparatorViewAppearance
            channelsPage.separatorViewAppearance = appearance.channelsSeparatorViewAppearance
            channelsPage.messagesSeparatorViewAppearance = appearance.messagesSeparatorViewAppearance
            searchUserBarView.parentAppearance = appearance.userBarAppearance
        }
    }

    override open func setupDone() {
        pageViewController.didMove(toParent: self)
        // Attach live scroll sync after layout
        DispatchQueue.main.async { [weak self] in
            self?.attachPageScrollObservation()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        searchUserBarView.viewModel.$event
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                setUserBarVisible(!hasSearchToken && !searchUserBarView.viewModel.users.isEmpty, animated: true)
            }
            .store(in: &subscriptions)
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
            let curveRaw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt,
            isViewLoaded, let window = view.window
        else { return }

        let frameInView = window.convert(endFrame, to: view)
        let overlap = max(0, view.bounds.maxY - frameInView.minY)
        userBarBottom.constant = -max(0, overlap - view.safeAreaInsets.bottom)

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curveRaw << 16)
        ) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Public API

    @objc open func search(query: String?) {
        chatsPage.viewModel.filterUser = filterUser
        chatsPage.messagesViewModel.filterUser = filterUser
        chatsPage.search(query: query)
        channelsPage.viewModel.filterUser = filterUser
        channelsPage.messagesViewModel.filterUser = filterUser
        channelsPage.search(query: query)
        allMediaViewModel.search(query: query, filterUser: filterUser)
        allVoiceViewModel.search(query: query, filterUser: filterUser)
        allFilesViewModel.search(query: query, filterUser: filterUser)
        allLinksViewModel.search(query: query, filterUser: filterUser)
        mediaPage.searchQuery = query
        if mediaPage.isViewLoaded { mediaPage.reloadSearchTable() }
        if linksPage.isViewLoaded { linksPage.reloadSearchTable() }
        searchUserBarView.viewModel.search(query: query)
        let hasQuery = !(query ?? "").isEmpty
        if !hasQuery { setUserBarVisible(false, animated: true) }
        serverSearchWorkItem?.cancel()
        if let trimmed = query?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty, trimmed.count > 1 {
            let workItem = DispatchWorkItem { [weak self] in
                self?.fetchChannelsFromServer(query: trimmed)
            }
            serverSearchWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
        }
    }

    private func fetchChannelsFromServer(query: String) {
        let channelListQuery = ChannelListQuery
            .Builder()
            .order(SceytChatUIKit.shared.config.channelListOrder)
            .filterKey(.subject)
            .search(.contains)
            .limit(SceytChatUIKit.shared.config.queryLimits.channelListQueryLimit)
            .query(query)
            .build()
        channelListProvider.loadChannels(query: channelListQuery)
    }

    override open func reloadData() {
        chatsPage.reloadData()
        channelsPage.reloadData()
    }

    override open func showEmptyViewIfNeeded() {
        // Per-page empty state is handled by each page VC
    }

    open func setUserBarVisible(_ visible: Bool, animated: Bool) {
        let targetAlpha: CGFloat = visible ? 1 : 0
        guard searchUserBarView.alpha != targetAlpha else { return }
        if visible {
            searchUserBarView.isHidden = false
            searchUserBarView.isUserInteractionEnabled = true
        }
        UIView.animate(withDuration: animated ? 0.2 : 0, animations: {
            self.searchUserBarView.alpha = targetAlpha
        }, completion: { _ in
            self.searchUserBarView.isHidden = !visible
            self.searchUserBarView.isUserInteractionEnabled = visible
        })
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
        else {
            // Swipe cancelled — snap indicator back to the current page
            categoryTabBar.setSelectedIndex(currentIndex, animated: true)
            return
        }

        currentIndex = index
        // Block the UIPageViewController internal scroll-view reset from
        // triggering a spurious progress update with the new currentIndex.
        isAnimatingPageTransition = true
        categoryTabBar.setSelectedIndex(index, animated: true)
        DispatchQueue.main.async { [weak self] in
            self?.isAnimatingPageTransition = false
        }
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
                separatorLine.heightAnchor.constraint(equalToConstant: 0),

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
            // At the first or last page the indices clamp to the same value — nothing to animate.
            guard fromIndex != toIndex else { return }

            let fromBtn = tabButtons[fromIndex]
            let toBtn = tabButtons[toIndex]

            let fromX = fromBtn.frame.minX
            let toX = toBtn.frame.minX
            let fromW = fromBtn.frame.width
            let toW = toBtn.frame.width

            indicatorLeading.constant = fromX + (toX - fromX) * t
            indicatorWidth.constant = fromW + (toW - fromW) * t

            // Interpolate text colour, background colour and border colour
            let selectedText = appearance.selectedTabColor
            let unselectedText = appearance.unselectedTabColor
            let selectedBg: UIColor = appearance.selectedTabBackgroundColor ?? .clear
            // Keep both endpoints in the same colour space so getRed succeeds
            let clearBg = selectedBg.withAlphaComponent(0)
            let unselectedBorder = appearance.unselectedTabBorderColor
            let clearBorder = unselectedBorder.withAlphaComponent(0)

            tabButtons.enumerated().forEach { idx, btn in
                if idx == fromIndex {
                    btn.setTitleColor(selectedText.interpolated(to: unselectedText, fraction: t), for: .normal)
                    btn.backgroundColor = selectedBg.interpolated(to: clearBg, fraction: t)
                    btn.layer.borderColor = clearBorder.interpolated(to: unselectedBorder, fraction: t).cgColor
                } else if idx == toIndex {
                    btn.setTitleColor(unselectedText.interpolated(to: selectedText, fraction: t), for: .normal)
                    btn.backgroundColor = clearBg.interpolated(to: selectedBg, fraction: t)
                    btn.layer.borderColor = unselectedBorder.interpolated(to: clearBorder, fraction: t).cgColor
                } else {
                    btn.setTitleColor(unselectedText, for: .normal)
                    btn.backgroundColor = nil
                    btn.layer.borderColor = unselectedBorder.cgColor
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
            if index == 0 {
                scrollView.setContentOffset(CGPoint(x: -scrollView.contentInset.left, y: 0), animated: animated)
                return
            }
            if index == tabButtons.count - 1 {
                let maxX = scrollView.contentSize.width - scrollView.bounds.width + scrollView.contentInset.right
                scrollView.setContentOffset(CGPoint(x: max(-scrollView.contentInset.left, maxX), y: 0), animated: animated)
                return
            }
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

        fileprivate static var currentKeyboardInset: CGFloat = 0

        override open func setupDone() {
            super.setupDone()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillChangeFrame(_:)),
                name: UIResponder.keyboardWillChangeFrameNotification,
                object: nil
            )
        }

        override open func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            let inset = ChannelTablePageViewController.currentKeyboardInset + GlobalSearchUserBarView.Layouts.height
            tableView.contentInset.bottom = inset
            tableView.verticalScrollIndicatorInsets.bottom = inset
        }

        @objc private func keyboardWillChangeFrame(_ notification: Notification) {
            guard
                let info = notification.userInfo,
                let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
                let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
                let curveRaw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt,
                isViewLoaded, let window = view.window
            else { return }

            let keyboardFrameInView = window.convert(endFrame, to: view)
            let overlap = max(0, view.bounds.maxY - keyboardFrameInView.minY)
            let safeBottom = view.safeAreaInsets.bottom
            let inset = max(0, overlap - safeBottom)

            ChannelTablePageViewController.currentKeyboardInset = inset

            let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
            UIView.animate(withDuration: duration, delay: 0, options: options) {
                self.tableView.contentInset.bottom = inset + GlobalSearchUserBarView.Layouts.height
                self.tableView.verticalScrollIndicatorInsets.bottom = inset + GlobalSearchUserBarView.Layouts.height
            }
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
            tableView.register(Components.channelCell)
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
                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.channelCell)
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

    // MARK: Channels Page

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

        /// Override in subclasses to return the scroll views whose bottom inset should track keyboard + user bar height.
        open var scrollViewsToAdjust: [UIScrollView] { [] }

        open func embedAttachmentView(_ attachmentView: UIView) {
            view.insertSubview(attachmentView.withoutAutoresizingMask, belowSubview: emptyStateView)
            attachmentView.pin(to: view)
            emptyStateView.isHidden = true
        }

        open func updateEmptyState() {
            // Override in subclasses if needed
        }

        override open func setupDone() {
            super.setupDone()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillChangeFrame(_:)),
                name: UIResponder.keyboardWillChangeFrameNotification,
                object: nil
            )
        }

        override open func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            let inset = ChannelTablePageViewController.currentKeyboardInset + GlobalSearchUserBarView.Layouts.height
            scrollViewsToAdjust.forEach {
                $0.contentInset.bottom = inset
                $0.verticalScrollIndicatorInsets.bottom = inset
            }
        }

        @objc private func keyboardWillChangeFrame(_ notification: Notification) {
            guard
                let info = notification.userInfo,
                let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
                let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
                let curveRaw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt,
                isViewLoaded, let window = view.window
            else { return }

            let keyboardFrameInView = window.convert(endFrame, to: view)
            let overlap = max(0, view.bounds.maxY - keyboardFrameInView.minY)
            let safeBottom = view.safeAreaInsets.bottom
            let inset = max(0, overlap - safeBottom)

            let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
            UIView.animate(withDuration: duration, delay: 0, options: options) {
                let bottomInset = inset + GlobalSearchUserBarView.Layouts.height
                self.scrollViewsToAdjust.forEach {
                    $0.contentInset.bottom = bottomInset
                    $0.verticalScrollIndicatorInsets.bottom = bottomInset
                }
            }
        }
    }

    // MARK: Media Page

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

        override open var scrollViewsToAdjust: [UIScrollView] { [collectionView] }

        open func configure(voiceViewModel: any ChannelAttachmentListViewModelProviding) {
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

        override open var scrollViewsToAdjust: [UIScrollView] { [collectionView] }

        open func configure(fileViewModel: any ChannelAttachmentListViewModelProviding, onSelect: ((IndexPath) -> Void)? = nil) {
            collectionView.fileViewModel = fileViewModel
            collectionView.onSelect = onSelect
        }
    }

    // MARK: Links Page

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

// MARK: - MediaPageViewController + UITableView

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

// MARK: - LinksPageViewController + UITableView

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
