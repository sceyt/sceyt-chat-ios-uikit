//
//  ChannelInfoViewController+LinkCollectionView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController {
    open class LinkCollectionView: ChannelInfoViewController.AttachmentCollectionView,
                                   UICollectionViewDelegate,
                                   UICollectionViewDataSource,
                                   UICollectionViewDelegateFlowLayout {

        public static var settings = Layout.Settings(sectionInset: .zero,
                                                     interitemSpacing: 0,
                                                     lineSpacing: 0,
                                                     sectionHeadersPinToVisibleBounds: true)

        open var linkViewModel: any ChannelAttachmentListViewModelProviding = ChannelAttachmentListViewModel.Empty()

        open var layout: Layout { collectionViewLayout as! Layout }

        public required init() {
            super.init(frame: .zero, collectionViewLayout: Layout(settings: Self.settings))
        }

        public required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        open override func setup() {
            super.setup()

            noItemsMessage = L10n.Channel.Info.Segment.Links.noItems
            noItemsMessageSubTitle = L10n.Channel.Info.Segment.Links.noItemsSubTitle
            noItemsIcon = UIImage.emptyLinks
            register(Components.channelInfoLinkCell.self)
            register(Components.channelInfoDateSeparatorView.self, kind: .header)
            delegate = self
            dataSource = self
        }

        open override func setupAppearance() {
            super.setupAppearance()
            backgroundColor = appearance.backgroundColor
        }

        open override func setupDone() {
            super.setupDone()
            RunLoop.main.perform {[weak self] in
                self?.linkViewModel.startDatabaseObserver()
            }
            linkViewModel.eventPublisher
                .compactMap { $0 }
                .sink { [weak self] in
                    self?.onEvent($0)
                }.store(in: &subscriptions)
            linkViewModel.loadAttachments()
        }

        /// Every link row has the same height: one line of title, one line of URL and up to
        /// two lines of description (`LinkCell` caps its labels to match; longer text
        /// truncates). Depending only on the appearance fonts lets the flow layout use a
        /// uniform `itemSize`, so rows never need measuring and metadata loads never
        /// invalidate the layout.
        open var preferredCellHeight: CGFloat {
            let cellAppearance = appearance.cellAppearance
            let textHeight = ceil(cellAppearance.linkPreviewAppearance.titleLabelAppearance.font.lineHeight)
                + ceil(cellAppearance.linkLabelAppearance.font.lineHeight)
                + ceil(cellAppearance.linkPreviewAppearance.descriptionLabelAppearance.font.lineHeight * 2)
                + Layouts.textSpacing * 2
            return max(Layouts.iconSize, textHeight) + Layouts.verticalPadding * 2
        }

        open override func layoutSubviews() {
            super.layoutSubviews()
            guard width > 0 else { return }
            let itemSize = CGSize(width: width, height: preferredCellHeight)
            if layout.itemSize != itemSize {
                layout.itemSize = itemSize
            }
        }

        open func onEvent(_ event: ChannelAttachmentListViewModel.Event) {
            switch event {
            case .change(let paths):
                updateCollectionView(paths: paths)
            }
        }

        public func numberOfSections(in collectionView: UICollectionView) -> Int {
            linkViewModel.numberOfSections
        }

        open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            linkViewModel.numberOfAttachments(in: section)
        }

        open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.channelInfoLinkCell.self)
            cell.parentAppearance = appearance.cellAppearance
            guard let attachmentLayout = linkViewModel.attachmentLayout(at: indexPath) else { return cell }
            cell.data = attachmentLayout.attachment
            guard attachmentLayout.attachment.imageDecodedMetadata?.hideLinkDetails != true else { return cell }

            // `data` must be set before the metadata request: cached metadata is delivered
            // synchronously, and the guard below relies on `cell.data` to drop results that
            // arrive after the cell has been reused for another link.
            let url = attachmentLayout.attachment.url
            _ = linkViewModel.attachmentLayout(
                at: indexPath,
                onLoadLinkMetadata: { [weak cell] metadata in
                    guard let cell, let metadata, cell.data?.url == url else { return }
                    cell.metadata = metadata
                })
            linkViewModel.downloadAttachmentIfNeeded(attachmentLayout)
            return cell
        }

        public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            let lastSection = linkViewModel.numberOfSections - 1
            let lastRow = linkViewModel.numberOfAttachments(in: lastSection) - 1
            if lastRow >= 0,
               indexPath == IndexPath(row: lastRow, section: lastSection) {
                linkViewModel.loadAttachments()
            }
        }

        public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            if let urlString = linkViewModel.attachmentLayout(at: indexPath)?.attachment.url,
               let url = URL(string: urlString)?.normalizedURL {
                UIApplication.shared.open(url, options: [:])
            }
            collectionView.deselectItem(at: indexPath, animated: true)
        }

        public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
            return .init(width: collectionView.width, height: Components.channelInfoDateSeparatorView.Layouts.headerHeight)
        }

        public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
            switch kind {
            case UICollectionView.SupplementaryViewKind.header.rawValue:
                let cell = collectionView.dequeueReusableSupplementaryView(for: indexPath, cellType: Components.channelInfoDateSeparatorView.self, kind: .header)
                cell.parentAppearance = appearance.separatorAppearance
                cell.date = linkViewModel.attachmentLayout(at: indexPath)?.attachment.createdAt
                return cell
            default:
                fatalError("should not happen")
            }
        }
    }
}

extension ChannelInfoViewController.LinkCollectionView {
    /// All link rows share one `itemSize` (set in `layoutSubviews` from
    /// `preferredCellHeight`), so the layout keeps no per-item sizing state.
    open class Layout: ChannelInfoViewController.AttachmentCollectionView.Layout {}
}

public extension ChannelInfoViewController.LinkCollectionView {
    enum Layouts {
        public static var horizontalPadding: CGFloat = 16
        public static var verticalPadding: CGFloat = 8
        public static var headerHeight: CGFloat = 32
        public static var iconSize: CGFloat = 40
        public static var cornerRadius: CGFloat = 8
        /// Vertical spacing between the title, URL and description labels; used both by
        /// `LinkCell`'s stack and by `preferredCellHeight`.
        public static var textSpacing: CGFloat = 4
    }
}
