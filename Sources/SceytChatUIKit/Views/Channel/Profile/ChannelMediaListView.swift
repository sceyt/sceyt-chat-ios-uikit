//
//  ChannelMediaListView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import AVKit

open class ChannelMediaListView: ChannelAttachmentListView,
                                 UICollectionViewDelegate,
                                 UICollectionViewDataSource,
                                 UICollectionViewDelegateFlowLayout {

    public var settings = Layout.Settings(sectionInset: .init(top: 0, left: 1, bottom: 0, right: 1),
                                          interitemSpacing: 2,
                                          lineSpacing: 2,
                                          sectionHeadersPinToVisibleBounds: true)

    open var mediaViewModel: ChannelAttachmentListVM!
    
    open var layout: Layout? { collectionViewLayout as? Layout }

    public required init() {
        super.init(frame: .zero, collectionViewLayout: Layout(settings: settings))
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    open func calculateItemSize() -> CGSize {
        let width = bounds.width
        let size = floor((width - settings.sectionInset.left - settings.sectionInset.right - settings.interitemSpacing * 2) / 3)
        guard size > 0
        else { return .nan }
        return CGSize(width: size, height: size)
    }

    open override func setup() {
        super.setup()
        noItemsMessage = L10n.Channel.Profile.Segment.Medias.noItems
        register(Components.channelProfileImageAttachmentCell.self)
        register(Components.channelProfileVideoAttachmentCell.self)
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
        let itemSize = calculateItemSize()
        let thumbnailSize = itemSize.isNan ? CGSize(width: 40, height: 40) : itemSize
        mediaViewModel.thumbnailSize = thumbnailSize.applying(.init(scaleX: Config.displayScale, y: Config.displayScale))
        layout?.itemSize = itemSize
        reloadData()
        setNeedsLayout()
        mediaViewModel.startDatabaseObserver()
        mediaViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        mediaViewModel.loadAttachments()
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        let itemSize = calculateItemSize()
        if let layout, layout.itemSize != itemSize {
            layout.itemSize = itemSize
            let thumbnailSize = itemSize.isNan ? CGSize(width: 40, height: 40) : itemSize
            mediaViewModel.thumbnailSize = thumbnailSize.applying(.init(scaleX: Config.displayScale, y: Config.displayScale))
            layout.invalidateLayout()
        }
    }
    
    open func onEvent(_ event: ChannelAttachmentListVM.Event) {
        switch event {
        case .change(let paths):
            var indexes = paths
            indexes.updates = []
            updateCollectionView(paths: indexes)
        }
    }

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        mediaViewModel.numberOfSections
    }
    
    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        mediaViewModel.numberOfAttachments(in: section)
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let model = mediaViewModel.attachmentLayout(at: indexPath)
        if indexPath.row > mediaViewModel.numberOfAttachments(in: indexPath.section) - 3 {
            mediaViewModel.loadAttachments()
        }
        let cell: ChannelProfileAttachmentCell
        
        switch model?.attachment.type {
        case "video":
            cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileVideoAttachmentCell.self)
        default:
            cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileImageAttachmentCell.self)
        }
        
        cell.data = mediaViewModel.attachmentLayout(at: indexPath, onLoadThumbnail: { [weak cell] layout in
            guard layout == cell?.data else { return }
            cell?.imageView.image = layout.thumbnail
        })
        cell.previewer = { [unowned self] in
            previewer?()
        }
        
        if let model {
            mediaViewModel.downloadAttachmentIfNeeded(model) { [weak cell] model in
                if let cell, cell.data.attachment.id == model.attachment.id {
                    cell.imageView.image = model.thumbnail
                }
            }
        }
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return .init(width: collectionView.width, height: ChannelProfileFileHeaderView.Layouts.headerHeight)
    }
    
    public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.SupplementaryViewKind.header.rawValue:
            let cell = collectionView.dequeueReusableSupplementaryView(for: indexPath, cellType: Components.channelProfileFileHeaderView.self, kind: .header)
            cell.date = mediaViewModel.attachmentLayout(at: indexPath)?.attachment.createdAt
            return cell
        default:
            fatalError("should not happen")
        }
    }
    
    open var previewer: (() -> AttachmentPreviewDataSource?)?
}

extension ChannelMediaListView {

    open class Layout: ChannelAttachmentListView.Layout {

    }
}
