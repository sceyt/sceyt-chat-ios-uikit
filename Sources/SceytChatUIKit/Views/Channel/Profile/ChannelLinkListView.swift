//
//  ChannelLinkListView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import LinkPresentation

open class ChannelLinkListView: ChannelAttachmentListView,
                                UICollectionViewDelegate,
                                UICollectionViewDataSource,
                                UICollectionViewDelegateFlowLayout {

    public static var settings = Layout.Settings(sectionInset: .zero,
                                                 interitemSpacing: 0,
                                                 lineSpacing: 0,
                                                 sectionHeadersPinToVisibleBounds: true)

    open var linkViewModel: ChannelAttachmentListVM!
    
    open var layout: Layout { collectionViewLayout as! Layout }
    
    public required init() {
        super.init(frame: .zero, collectionViewLayout: Layout(settings: Self.settings))
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    open override func setup() {
        super.setup()
        
        noItemsMessage = L10n.Channel.Profile.Segment.Links.noItems
        register(Components.channelProfileLinkCell.self)
        register(Components.channelProfileFileHeaderView.self, kind: .header)
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
    
    open func onEvent(_ event: ChannelAttachmentListVM.Event) {
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
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileLinkCell.self)
        let attachmentLayout = linkViewModel.attachmentLayout(
            at: indexPath,
            onLoadLinkMetadata: { [weak cell, weak self] metadata in
                if let metadata {
                    if cell?.titleLabel.text == nil || cell?.titleLabel.text == metadata.url.absoluteString {
                        cell?.metadata = metadata
                    }
                    self?.layout.calculateLinkHeight(metadata)
                }
            })
        cell.data = attachmentLayout?.attachment
        if let attachmentLayout {
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
           let url = URL(string: urlString)?.sanitise {
            UIApplication.shared.open(url, options: [:])
        }
        collectionView.deselectItem(at: indexPath, animated: true)
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if let urlString = linkViewModel.attachmentLayout(at: indexPath)?.attachment.url,
           let url = URL(string: urlString),
           let cellHeight = layout.cellHeights[url] {
            return .init(width: collectionView.width, height: cellHeight)
        }
        return .init(width: collectionView.width, height: Layouts.iconSize + Layouts.verticalPadding * 2)
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return .init(width: collectionView.width, height: ChannelProfileFileHeaderView.Layouts.headerHeight)
    }
    
    public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.SupplementaryViewKind.header.rawValue:
            let cell = collectionView.dequeueReusableSupplementaryView(for: indexPath, cellType: Components.channelProfileFileHeaderView.self, kind: .header)
            cell.date = linkViewModel.attachmentLayout(at: indexPath)?.attachment.createdAt
            return cell
        default:
            fatalError("should not happen")
        }
    }

}

extension ChannelLinkListView {
    open class Layout: ChannelAttachmentListView.Layout {
        open var cellHeights: [URL: CGFloat] = [:]
        
        open func calculateLinkHeight(_ metadata: LinkMetadata) {
            let appearance = ChannelLinkListView.appearance
            let maxSize = CGSize(width: (collectionView?.width ?? 0) - Layouts.iconSize - Layouts.horizontalPadding * 3, height: 32)
            let title = metadata.title ?? ""
            let summary = metadata.summary ?? ""
            let titleHeight: CGFloat = title.isEmpty ? 0 : (22 + 4)
            let linkHeight: CGFloat = 20
            let detailHeight: CGFloat = summary.isEmpty ? 0 : (max(16, ceil(NSAttributedString(
                string: summary,
                attributes: [.font: appearance.detailLabelFont ?? Fonts.regular.withSize(13)])
                .boundingRect(with: maxSize, options: [.usesLineFragmentOrigin], context: nil).height)) + 4)
            let cellHeight = min(100, titleHeight + linkHeight + detailHeight + Layouts.verticalPadding * 2)
            if cellHeights[metadata.url] != cellHeight {
                cellHeights[metadata.url] = cellHeight
                invalidateLayout()
            }
        }
    }
}

public extension ChannelLinkListView {
    enum Layouts {
        public static var horizontalPadding: CGFloat = 16
        public static var verticalPadding: CGFloat = 8
        public static var headerHeight: CGFloat = 32
        public static var iconSize: CGFloat = 40
        public static var cornerRadius: CGFloat = 8
    }
}
