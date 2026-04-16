//
//  GlobalSearchResultsViewController+VoicePageViewController.swift
//  SceytChatUIKit
//

import UIKit
import SceytChat

extension GlobalSearchResultsViewController {

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

}
