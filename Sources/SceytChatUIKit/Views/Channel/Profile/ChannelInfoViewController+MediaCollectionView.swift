//
//  ChannelInfoViewController+MediaCollectionView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit
import AVKit

extension ChannelInfoViewController {
    open class MediaCollectionView: ChannelInfoViewController.AttachmentCollectionView,
                                    UICollectionViewDelegate,
                                    UICollectionViewDataSource,
                                    UICollectionViewDelegateFlowLayout {
        
        public var settings = Layout.Settings(sectionInset: .init(top: 0, left: 1, bottom: 0, right: 1),
                                              interitemSpacing: 2,
                                              lineSpacing: 2,
                                              sectionHeadersPinToVisibleBounds: true)
        
        open var mediaViewModel: any ChannelAttachmentListViewModelProviding = ChannelAttachmentListViewModel.Empty()
        
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
            noItemsMessage = L10n.Channel.Info.Segment.Medias.noItems
            noItemsMessageSubTitle = L10n.Channel.Info.Segment.Medias.noItemsSubTitle
            noItemsIcon = UIImage.emptyMedia
            register(Components.channelInfoImageAttachmentCell.self)
            register(Components.channelInfoVideoAttachmentCell.self)
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
            let itemSize = calculateItemSize()
            let thumbnailSize = itemSize.isNan ? CGSize(width: 40, height: 40) : itemSize
            mediaViewModel.thumbnailSize = thumbnailSize.applying(.init(scaleX: UIScreen.main.traitCollection.displayScale, y: UIScreen.main.traitCollection.displayScale))
            if !itemSize.isNan {
                layout?.itemSize = itemSize
            }
            reloadData()
            setNeedsLayout()
            mediaViewModel.startDatabaseObserver()
            mediaViewModel.eventPublisher
                .compactMap { $0 }
                .sink { [weak self] in
                    self?.onEvent($0)
                }.store(in: &subscriptions)
            mediaViewModel.loadAttachments()
        }
        
        open override func layoutSubviews() {
            super.layoutSubviews()
            let itemSize = calculateItemSize()
            guard !itemSize.isNan else { return }
            if let layout, layout.itemSize != itemSize {
                layout.itemSize = itemSize
                mediaViewModel.thumbnailSize = itemSize.applying(.init(scaleX: UIScreen.main.traitCollection.displayScale, y: UIScreen.main.traitCollection.displayScale))
                layout.invalidateLayout()
            }
        }
        
        open func onEvent(_ event: ChannelAttachmentListViewModel.Event) {
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
            let cell: ChannelInfoViewController.AttachmentCell

            switch model?.attachment.type {
            case "video":
                cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.channelInfoVideoAttachmentCell.self)
                (cell as? VideoAttachmentCell)?.parentAppearance = appearance.videoAttachmentCellAppearance
            default:
                cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.channelInfoImageAttachmentCell.self)
            }

            cell.overlayLoaderAppearance = appearance.overlayLoaderAppearance
            cell.data = mediaViewModel.attachmentLayout(at: indexPath, onLoadThumbnail: { [weak cell] layout in
                guard layout == cell?.data else { return }
                cell?.imageView.image = layout.thumbnail
            })
            cell.previewer = { [unowned self] in
                previewer?()
            }

            if let model {
                cell.setProgressHandler()

                switch model.attachment.status {
                case .pending, .downloading:
                    if let message = model.ownerMessage,
                       let progress = fileProvider.currentProgressPercent(message: message, attachment: model.attachment) {
                        cell.setProgress(progress)
                    } else if fileProvider.filePath(attachment: model.attachment) == nil {
                        let willAutoDownload = model.attachment.status == .downloading
                            || mediaViewModel.minAutoDownloadSize <= 0
                            || model.attachment.uploadedFileSize <= mediaViewModel.minAutoDownloadSize
                        if willAutoDownload {
                            cell.setProgress(0.0001)
                        } else {
                            cell.update(status: .pauseDownloading)
                        }
                    }
                case .done:
                    cell.setProgress(0)
                default:
                    break
                }

                cell.onPauseAction = { [weak cell, weak self] in
                    guard let cell, let self, let data = cell.data else { return }
                    let progressStatus = cell.lastAttachmentTransferProgress?.attachment.status
                    let dataStatus = data.attachment.status
                    let status = progressStatus ?? dataStatus
                    switch status {
                    case .pauseDownloading, .failedDownloading:
                        logger.debug("[MediaGallery] onPauseAction → resumeDownload")
                        cell.update(status: .downloading)
                        cell.setProgressHandler()
                        self.mediaViewModel.resumeDownload(data)
                    case .downloading:
                        cell.update(status: .pauseDownloading)
                        self.mediaViewModel.pauseDownload(data)
                    case .pending:
                        if let message = data.ownerMessage,
                           fileProvider.currentProgressPercent(message: message, attachment: data.attachment) != nil {
                            cell.update(status: .pauseDownloading)
                            self.mediaViewModel.pauseDownload(data)
                        } else {
                            cell.update(status: .downloading)
                            cell.setProgressHandler()
                            self.mediaViewModel.resumeDownload(data)
                        }
                    default:
                        logger.debug("[MediaGallery] pauseButton tapped but status=\(status) — no action taken")
                        break
                    }
                }

                mediaViewModel.downloadAttachmentIfNeeded(model) { [weak cell] model in
                    if let cell, cell.data?.attachment.id == model.attachment.id {
                        cell.imageView.image = model.thumbnail
                    }
                }
            }
            return cell
        }
        
        public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
            return .init(width: collectionView.width, height: Components.channelInfoDateSeparatorView.Layouts.headerHeight)
        }
        
        public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
            switch kind {
            case UICollectionView.SupplementaryViewKind.header.rawValue:
                let cell = collectionView.dequeueReusableSupplementaryView(for: indexPath, cellType: Components.channelInfoDateSeparatorView.self, kind: .header)
                cell.parentAppearance = appearance.separatorAppearance
                cell.date = mediaViewModel.attachmentLayout(at: indexPath)?.attachment.createdAt
                return cell
            default:
                fatalError("should not happen")
            }
        }
        
        open var previewer: (() -> (any PreviewDataSource)?)?
    }
}

extension ChannelInfoViewController.MediaCollectionView {

    open class Layout: ChannelInfoViewController.AttachmentCollectionView.Layout {

    }
}
