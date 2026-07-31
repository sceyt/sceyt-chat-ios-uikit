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
                // Updates are excluded from the batch above because reloadItems would
                // flash the thumbnails — but they carry transfer-status transitions
                // (e.g. a download that finished while the app was backgrounded, whose
                // in-memory completion callback never reached the cell). Re-apply the
                // overlay state on the visible cells in place instead.
                if !paths.updates.isEmpty {
                    syncVisibleTransferOverlays()
                }
            }
        }

        /// Re-applies the transfer overlay (progress ring / pause button) of every
        /// visible cell from its layout's current state. Layout instances are mutated
        /// in place by the database observer, so `cell.data` already reflects the
        /// change that was excluded from the batch update.
        open func syncVisibleTransferOverlays() {
            visibleCells
                .compactMap { $0 as? ChannelInfoViewController.AttachmentCell }
                .forEach { syncTransferOverlay(for: $0) }
        }

        /// The single source of truth for a cell's transfer overlay, used both when a
        /// cell is bound and when a database update re-syncs the visible cells.
        ///
        /// It deliberately decides from the *transfer reality* — is there a live
        /// percent, are the bytes on disk, will the view model auto-download this —
        /// rather than from the stored status alone. Driving it off the status left
        /// cells blank in every case the status switch had no branch for (anything
        /// outside `.pending`/`.downloading`/`.done`, plus a `.done` whose file no
        /// longer exists): the view model started the download anyway, so the overlay
        /// only showed up later, when the first progress tick landed.
        open func syncTransferOverlay(for cell: ChannelInfoViewController.AttachmentCell) {
            guard let layout = cell.data else { return }
            let attachment = layout.attachment

            // A live transfer always wins — show its real percent.
            if let message = layout.ownerMessage,
               let progress = fileProvider.currentProgressPercent(message: message, attachment: attachment) {
                cell.setProgress(progress)
                return
            }
            // No live percent means no running transfer, so the last progress tick's
            // snapshot describes a dead one. Drop it, or the pause button keeps
            // resolving its action from a stale `.downloading` and toggles a
            // transfer that no longer exists instead of acting on the real state.
            cell.lastAttachmentTransferProgress = nil
            // The bytes are on disk: nothing to overlay, whatever the status claims.
            // A transfer can end without its completion ever reaching this cell.
            if fileProvider.filePath(attachment: attachment) != nil {
                cell.update(status: .done)
                return
            }
            // No file and no percent yet. The transfer either is about to start —
            // `downloadAttachmentIfNeeded` runs off the main thread and resolves the
            // owner message before it fetches, so the ring has to be up front to cover
            // that gap — or it waits for an explicit tap.
            if mediaViewModel.shouldAutoDownload(attachment) {
                cell.setProgress(0.0001)
            } else if attachment.status == .failedUploading {
                // An upload that failed on the sender side: there is no remote copy to
                // pull, so offering a download button would be a dead end.
                cell.update(status: .done)
            } else {
                // `.pauseDownloading` is the appearance's "tap to download" state;
                // a failed transfer renders the same way.
                cell.update(status: attachment.status == .failedDownloading ? .failedDownloading : .pauseDownloading)
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
            let lastSection = mediaViewModel.numberOfSections - 1
            if indexPath.section == lastSection {
                let count = mediaViewModel.numberOfAttachments(in: lastSection)
                if count > 0 && indexPath.row >= max(0, count - 3) {
                    mediaViewModel.loadAttachments()
                }
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
                syncTransferOverlay(for: cell)

                cell.onPauseAction = { [weak cell, weak self] in
                    guard let cell, let self, let data = cell.data else { return }
                    // The overlay can outlive its transfer — a completion that fired
                    // while the app was backgrounded may never have reached this cell.
                    // With the bytes already on disk there is nothing to pause, resume,
                    // or cancel: hide the overlay and let `resumeDownload`'s
                    // file-on-disk fast path reconcile the stored status to `.done`.
                    if fileProvider.filePath(attachment: data.attachment) != nil {
                        cell.lastAttachmentTransferProgress = nil
                        cell.update(status: .done)
                        self.mediaViewModel.resumeDownload(data)
                        return
                    }
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
                    // `.done` is here because the overlay only puts a download button on
                    // a `.done` attachment when its file is gone from disk — tapping it
                    // has to re-fetch, not no-op.
                    case .pending, .done:
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
