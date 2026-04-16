//
//  GlobalSearchResultsViewController+FilesPageViewController.swift
//  SceytChatUIKit
//

import UIKit
import SceytChat

extension GlobalSearchResultsViewController {

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

}
