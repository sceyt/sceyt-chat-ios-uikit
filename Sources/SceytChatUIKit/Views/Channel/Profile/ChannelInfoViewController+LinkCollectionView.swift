//
//  ChannelInfoViewController+LinkCollectionView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import LinkPresentation

extension ChannelInfoViewController {
    open class LinkCollectionView: ChannelInfoViewController.AttachmentCollectionView,
                                   UICollectionViewDelegate,
                                   UICollectionViewDataSource,
                                   UICollectionViewDelegateFlowLayout {
        
        public static var settings = Layout.Settings(sectionInset: .zero,
                                                     interitemSpacing: 0,
                                                     lineSpacing: 0,
                                                     sectionHeadersPinToVisibleBounds: true)
        
        open var linkViewModel: ChannelAttachmentListViewModel!
        
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
            linkViewModel.$event
                .compactMap { $0 }
                .sink { [weak self] in
                    self?.onEvent($0)
                }.store(in: &subscriptions)
            linkViewModel.loadAttachments()
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
            let attachmentLayout = linkViewModel.attachmentLayout(
                at: indexPath,
                onLoadLinkMetadata: { [weak cell, weak self] metadata in
                    if let metadata {
                        if cell?.titleLabel.text == nil || cell?.titleLabel.text == metadata.url.absoluteString {
                            cell?.metadata = metadata
                        }
                        self?.layout.calculateLinkHeight(metadata, attachment: cell?.data)
                    }
                })
            cell.data = attachmentLayout?.attachment
            if let attachmentLayout, !(attachmentLayout.attachment.imageDecodedMetadata?.hideLinkDetails == true) {
                linkViewModel.downloadAttachmentIfNeeded(attachmentLayout)
            }
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
        
        public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            if let urlString = linkViewModel.attachmentLayout(at: indexPath)?.attachment.url,
               let url = URL(string: urlString),
               let cellHeight = layout.cellHeights[url.normalizedURL] {
                return .init(width: collectionView.width, height: cellHeight)
            }
            return .init(width: collectionView.width, height: Layouts.iconSize + Layouts.verticalPadding * 2)
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
    open class Layout: ChannelInfoViewController.AttachmentCollectionView.Layout {
        open var cellHeights: [URL: CGFloat] = [:]
        
        open func calculateLinkHeight(_ metadata: LinkMetadata, attachment: ChatMessage.Attachment?) {
            let appearance = Components.channelInfoLinkCollectionView.appearance
            var hideLinkDetails: Bool {
                attachment?.imageDecodedMetadata?.hideLinkDetails == true
            }
            let titleMaxSize = CGSize(width: (collectionView?.width ?? 0) - Layouts.iconSize - Layouts.horizontalPadding * 3,
                                      height: ceil(appearance.cellAppearance.linkPreviewAppearance.titleLabelAppearance.font.lineHeight))
            let linkMaxSize = CGSize(width: (collectionView?.width ?? 0) - Layouts.iconSize - Layouts.horizontalPadding * 3,
                                     height: ceil(appearance.cellAppearance.linkLabelAppearance.font.lineHeight))
            let detailMaxSize = CGSize(width: (collectionView?.width ?? 0) - Layouts.iconSize - Layouts.horizontalPadding * 3,
                                       height: ceil(appearance.cellAppearance.linkPreviewAppearance.descriptionLabelAppearance.font.lineHeight) * 2)
            
            let title = hideLinkDetails ? "" : (metadata.title ?? "")
            let summary = hideLinkDetails ? "" : (metadata.summary ?? "")
            
            let titleHeight: CGFloat = title.isEmpty ? 0 : (ceil(NSAttributedString(
                string: title,
                attributes: [
                    .font: appearance.cellAppearance.linkPreviewAppearance.titleLabelAppearance.font
                ])
                .boundingRect(with: titleMaxSize, options: [.usesLineFragmentOrigin], context: nil).height) + 4)

            let linkHeight: CGFloat = ceil(NSAttributedString(
                string: metadata.url.absoluteString,
                attributes: [
                    .font: appearance.cellAppearance.linkLabelAppearance.font
                ])
                .boundingRect(with: linkMaxSize, options: [.usesLineFragmentOrigin], context: nil).height) + 4

            let detailHeight: CGFloat = summary.isEmpty ? 0 : (ceil(NSAttributedString(
                string: summary,
                attributes: [
                    .font: appearance.cellAppearance.linkPreviewAppearance.descriptionLabelAppearance.font
                ])
                .boundingRect(with: detailMaxSize, options: [.usesLineFragmentOrigin], context: nil).height) + 4)
            
            let cellHeight = max(Layouts.iconSize + Layouts.verticalPadding * 2, (titleHeight + linkHeight + detailHeight + Layouts.verticalPadding * 2))
            if cellHeights[metadata.url] != cellHeight {
            cellHeights[metadata.url.normalizedURL] = cellHeight
                invalidateLayout()
            }
        }
    }
}

public extension ChannelInfoViewController.LinkCollectionView {
    enum Layouts {
        public static var horizontalPadding: CGFloat = 16
        public static var verticalPadding: CGFloat = 8
        public static var headerHeight: CGFloat = 32
        public static var iconSize: CGFloat = 40
        public static var cornerRadius: CGFloat = 8
    }
}
