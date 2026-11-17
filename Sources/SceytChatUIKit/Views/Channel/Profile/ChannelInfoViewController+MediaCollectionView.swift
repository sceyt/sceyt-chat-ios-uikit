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
                                    UICollectionViewDelegateFlowLayout,
                                    UICollectionViewDataSourcePrefetching {
        /// Transfers and local files of the attachments shown here: its view model's.
        public var attachmentTransfer: AttachmentTransfer { mediaViewModel.attachmentTransfer }

        
        public var settings = Layout.Settings(sectionInset: .init(top: 0, left: 1, bottom: 0, right: 1),
                                              interitemSpacing: 2,
                                              lineSpacing: 2,
                                              sectionHeadersPinToVisibleBounds: true)
        
        open var mediaViewModel: any ChannelAttachmentListViewModelProviding = ChannelAttachmentListViewModel.Empty()

        open override var attachmentViewModel: (any ChannelAttachmentListViewModelProviding)? { mediaViewModel }

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
            // Cell prefetching (on by default, turned off by the base list) lets the
            // collection view build the next row's cells before they scroll in, spreading the
            // bind work over idle frames instead of paying it on the frame a row appears.
            isPrefetchingEnabled = true
            prefetchDataSource = self
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            backgroundColor = appearance.backgroundColor
        }
        
        open override func setupDone() {
            super.setupDone()
            let itemSize = calculateItemSize()
            mediaViewModel.thumbnailSize = thumbnailSize(forItemSize: itemSize.isNan ? CGSize(width: 40, height: 40) : itemSize)
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
        
        /// The size the thumbnail files are generated for, in **points**: the data session
        /// multiplies it by the screen scale itself. (It used to be given in pixels, so the
        /// files came out at 3× the pixels — 9× the area — that a tile needs, and every one was
        /// that much slower to make, read and decode.) Twice the tile's side, because the tile
        /// aspect-fills a square: a 3:4 photo or a 9:16 video still has its short side at or
        /// above the tile's pixels.
        open func thumbnailSize(forItemSize itemSize: CGSize) -> CGSize {
            CGSize(width: itemSize.width * 2, height: itemSize.height * 2)
        }

        open override func layoutSubviews() {
            super.layoutSubviews()
            let itemSize = calculateItemSize()
            guard !itemSize.isNan else { return }
            if let layout, layout.itemSize != itemSize {
                layout.itemSize = itemSize
                mediaViewModel.thumbnailSize = thumbnailSize(forItemSize: itemSize)
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
                //
                // A transfer writes its row several times (status, path, done), and dozens can run
                // at once, so these arrive many times a second; each pass touches every visible
                // cell (and the disk, for the file check). They are folded into one pass per
                // `overlaySyncInterval` — the progress itself does not wait for it, it comes from
                // the transfer's own stream.
                if !paths.updates.isEmpty {
                    setNeedsTransferOverlaySync()
                }
                rebindVisibleCellsWithChangedAttachment()
            }
        }

        /// Rebinds, in place, every visible cell whose tap-to-preview item no longer
        /// identifies the attachment it shows — most commonly a pending upload that got its
        /// server id: the recognizer still holds the id-0/no-url snapshot, which the
        /// previewer can't match, so it would open a different item. Transfer-progress
        /// updates keep the attachment's identity and are left to
        /// `syncVisibleTransferOverlays()`, so live progress rings aren't rebuilt.
        open func rebindVisibleCellsWithChangedAttachment() {
            for cell in visibleCells.compactMap({ $0 as? ChannelInfoViewController.AttachmentCell }) {
                guard let indexPath = indexPath(for: cell),
                      let layout = mediaViewModel.attachmentLayout(at: indexPath)
                else { continue }
                if layout === cell.data,
                   let bound = cell.previewAttachment,
                   bound == layout.attachment {
                    continue
                }
                configure(cell, at: indexPath)
            }
        }

        /// The longest a database change waits before the visible overlays are re-synced.
        public static var overlaySyncInterval: TimeInterval = 0.1
        private var isOverlaySyncScheduled = false

        /// Schedules one `syncVisibleTransferOverlays()` for every change that lands before it runs.
        open func setNeedsTransferOverlaySync() {
            guard !isOverlaySyncScheduled else { return }
            isOverlaySyncScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.overlaySyncInterval) { [weak self] in
                guard let self else { return }
                self.isOverlaySyncScheduled = false
                self.syncVisibleTransferOverlays()
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
            let liveStatus = layout.ownerMessage.flatMap {
                self.attachmentTransfer.transferStatus(message: $0, attachment: attachment)
            }
            let livePercent = layout.ownerMessage.flatMap {
                self.attachmentTransfer.currentProgressPercent(message: $0, attachment: attachment)
            }
            // A file-system check (up to three `stat`s): asked at most once, and only when a
            // branch below needs it.
            lazy var isFileOnDisk = self.attachmentTransfer.filePath(attachment: attachment) != nil

            // A paused transfer keeps its task — and with it the last cached percent —
            // so it can resume. Checked before the percent, or a paused upload
            // (paused on the chat thread, say) comes back as a spinning ring here.
            if attachment.isPendingUpload, (liveStatus ?? attachment.status) == .pauseUploading {
                cell.lastAttachmentTransferProgress = nil
                cell.update(status: .pauseUploading)
                return
            }
            if liveStatus == .pauseDownloading, !isFileOnDisk {
                cell.lastAttachmentTransferProgress = nil
                cell.update(status: .pauseDownloading)
                return
            }

            // A live transfer always wins — show its real percent.
            if let progress = livePercent {
                // Restores the pause glyph on a reused cell that last showed a
                // paused/tap-to-transfer icon.
                let status = liveStatus ?? attachment.status
                if status == .uploading || status == .downloading {
                    cell.update(status: status)
                }
                cell.setProgress(ChannelInfoViewController.AttachmentCell.inFlightProgress(progress))
                return
            }
            // No live percent means no running transfer, so the last progress tick's
            // snapshot describes a dead one. Drop it, or the pause button keeps
            // resolving its action from a stale `.downloading` and toggles a
            // transfer that no longer exists instead of acting on the real state.
            cell.lastAttachmentTransferProgress = nil
            // An outgoing file that never finished uploading: the local file is the
            // upload's *source*, not proof it is done, so it keeps the loader while
            // queued or in flight.
            if attachment.isPendingUpload, [.pending, .uploading].contains(liveStatus ?? attachment.status) {
                cell.update(status: .uploading)
                cell.setProgress(0.0001)
                return
            }
            // The bytes are on disk: nothing to overlay, whatever the status claims.
            // A transfer can end without its completion ever reaching this cell.
            if isFileOnDisk {
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
                    logger.info("[MediaGallery] reached bottom at \(indexPath.section)/\(indexPath.row) of \(mediaViewModel.numberOfSections) sections, last section count=\(count) — loading more")
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

            configure(cell, at: indexPath)
            return cell
        }

        /// Binds `cell` to the layout at `indexPath`: thumbnail, tap-to-preview item,
        /// transfer overlay and actions. Shared by `cellForItemAt` and
        /// `rebindVisibleCellsWithChangedAttachment()`, which re-runs it on a visible cell
        /// in place — `reloadItems` would flash the thumbnail.
        open func configure(_ cell: ChannelInfoViewController.AttachmentCell, at indexPath: IndexPath) {
            cell.attachmentTransfer = mediaViewModel.attachmentTransfer
            cell.overlayLoaderAppearance = appearance.overlayLoaderAppearance
            let model = mediaViewModel.attachmentLayout(at: indexPath, onLoadThumbnail: { [weak cell] layout in
                guard layout == cell?.data else { return }
                cell?.setThumbnail(layout.thumbnail)
            })
            cell.data = model
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
                    // Not for an unsent upload: its local file is the upload's source.
                    if !data.attachment.isPendingUpload,
                       self.attachmentTransfer.filePath(attachment: data.attachment) != nil {
                        cell.lastAttachmentTransferProgress = nil
                        cell.update(status: .done)
                        self.mediaViewModel.resumeDownload(data)
                        return
                    }
                    let progressStatus = cell.lastAttachmentTransferProgress?.attachment.status
                    let dataStatus = data.attachment.status
                    let status = progressStatus ?? dataStatus
                    switch status {
                    case .uploading:
                        cell.lastAttachmentTransferProgress = nil
                        cell.update(status: .pauseUploading)
                        self.mediaViewModel.pauseUpload(data)
                        return
                    case .pending where data.attachment.isPendingUpload:
                        cell.lastAttachmentTransferProgress = nil
                        cell.update(status: .pauseUploading)
                        self.mediaViewModel.pauseUpload(data)
                        return
                    case .pauseUploading:
                        cell.update(status: .uploading)
                        cell.setProgress(0.0001)
                        cell.setProgressHandler()
                        self.mediaViewModel.resumeUpload(data)
                        return
                    default:
                        break
                    }
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
                           self.attachmentTransfer.currentProgressPercent(message: message, attachment: data.attachment) != nil {
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
                        cell.setThumbnail(model.thumbnail)
                    }
                }
            }
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

        // MARK: Prefetching

        /// Rows about to scroll in: their layouts are created now (which starts their thumbnail
        /// loads) and a thumbnail already loaded is drawn at the tile's size, so the tile shows a
        /// decoded bitmap from its first frame.
        open func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
            let target = thumbnailTargetPixelSize
            let renderer = ChannelInfoViewController.ThumbnailRenderer.shared
            for indexPath in indexPaths {
                guard let layout = mediaViewModel.attachmentLayout(at: indexPath),
                      let thumbnail = layout.thumbnail,
                      renderer.needsRendering(thumbnail, targetPixelSize: target)
                else { continue }
                let identity = AttachmentTransfer.transferIdentity(of: layout.attachment)
                renderer.render(thumbnail, key: renderer.key(identity: identity, image: thumbnail, targetPixelSize: target), targetPixelSize: target)
            }
        }

        /// The pixel size of one tile, what `AttachmentCell.thumbnailTargetPixelSize` is for a
        /// cell of the layout's item size.
        open var thumbnailTargetPixelSize: CGSize {
            let itemSize = layout?.itemSize ?? .zero
            let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : UIScreen.main.scale
            return CGSize(width: itemSize.width * scale, height: itemSize.height * scale)
        }

        /// A prefetched cell is bound before it is on screen, and `syncVisibleTransferOverlays`
        /// only reaches visible cells: bring its overlay up to date as it appears.
        open func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            guard let cell = cell as? ChannelInfoViewController.AttachmentCell else { return }
            syncTransferOverlay(for: cell)
        }
    }
}
