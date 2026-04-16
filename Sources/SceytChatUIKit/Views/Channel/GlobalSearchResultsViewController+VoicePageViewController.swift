//
//  GlobalSearchResultsViewController+VoicePageViewController.swift
//  SceytChatUIKit
//

import UIKit
import Combine
import SceytChat

extension GlobalSearchResultsViewController {

    open class VoicePageViewController: AttachmentPageViewController {
        open lazy var collectionView = Components.channelInfoVoiceCollectionView.init()

        open lazy var searchEmptyStateView = EmptyStateStackView()
            .withoutAutoresizingMask

        private var _voiceViewModel: (any ChannelAttachmentListViewModelProviding)?
        private var cancellables = Set<AnyCancellable>()

        override open func setup() {
            super.setup()
            noItemsMessage = L10n.Channel.Info.Segment.Voice.noItems
            noItemsMessageSubTitle = L10n.Channel.Info.Segment.Voice.noItemsSubTitle
            noItemsIcon = UIImage.emptyVoice
            searchEmptyStateView.title = L10n.Search.NoResults.title
            searchEmptyStateView.message = L10n.Search.NoResults.message
            searchEmptyStateView.icon = .noResultsSearch
        }

        override open func setupLayout() {
            super.setupLayout()
            embedAttachmentView(collectionView)
            view.addSubview(searchEmptyStateView)
            searchEmptyStateView.pin(to: view, anchors: [.centerX, .top(50), .leading(16, .greaterThanOrEqual)])
            searchEmptyStateView.isHidden = true
        }

        override open func setupAppearance() {
            super.setupAppearance()
            collectionView.backgroundColor = .background
        }

        override open var scrollViewsToAdjust: [UIScrollView] { [collectionView] }

        open func configure(voiceViewModel: any ChannelAttachmentListViewModelProviding) {
            _voiceViewModel = voiceViewModel
            collectionView.voiceViewModel = voiceViewModel
            voiceViewModel.eventPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateSearchEmptyState()
                }
                .store(in: &cancellables)
        }

        private func updateSearchEmptyState() {
            guard let vm = _voiceViewModel else { return }
            let filtered = vm.isFiltered
            var totalItems = 0
            for section in 0..<vm.numberOfSections {
                totalItems += vm.numberOfAttachments(in: section)
            }
            let isEmpty = totalItems == 0
            if filtered {
                emptyStateView.isHidden = true
                collectionView.isHidden = isEmpty
                searchEmptyStateView.isHidden = !isEmpty
            } else {
                searchEmptyStateView.isHidden = true
                emptyStateView.isHidden = !isEmpty
                collectionView.isHidden = isEmpty
            }
        }
    }

}
