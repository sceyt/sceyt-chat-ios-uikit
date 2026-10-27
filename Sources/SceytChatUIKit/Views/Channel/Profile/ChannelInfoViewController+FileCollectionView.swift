//
//  ChannelInfoViewController+FileCollectionView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

extension ChannelInfoViewController {
    open class FileCollectionView: ChannelInfoViewController.AttachmentCollectionView,
                                          UICollectionViewDelegate,
                                          UICollectionViewDataSource,
                                          UICollectionViewDelegateFlowLayout {
        
        public var settings = Layout.Settings(sectionInset: .zero,
                                              interitemSpacing: 0,
                                              lineSpacing: 0,
                                              sectionHeadersPinToVisibleBounds: true)
        
        open var fileViewModel: any ChannelAttachmentListViewModelProviding = ChannelAttachmentListViewModel.Empty()

        open override var attachmentViewModel: (any ChannelAttachmentListViewModelProviding)? { fileViewModel }

        open var layout: Layout? { collectionViewLayout as? Layout }
        
        public var onSelect: ((IndexPath) -> Void)?
        
        public required init() {
            super.init(frame: .zero, collectionViewLayout: Layout(settings: settings))
        }
        
        public required init?(coder: NSCoder) {
            super.init(coder: coder)
        }
        
        open override func setup() {
            super.setup()
            
            noItemsMessage = L10n.Channel.Info.Segment.Files.noItems
            noItemsMessageSubTitle = L10n.Channel.Info.Segment.Files.noItemsSubTitle
            noItemsIcon = UIImage.emptyFiles
            register(Components.channelInfoFileCell.self)
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
                self?.fileViewModel.startDatabaseObserver()
            }
            
            fileViewModel.eventPublisher
                .compactMap { $0 }
                .sink { [weak self] in
                    self?.onEvent($0)
                }.store(in: &subscriptions)
            fileViewModel.loadAttachments()
        }
        
        open override func layoutSubviews() {
            super.layoutSubviews()
            guard width > 0 else { return }
            layout?.itemSize = .init(width: width,
                                     height: Layouts.iconSize + Layouts.verticalPadding * 2)
        }
        
        open func onEvent(_ event: ChannelAttachmentListViewModel.Event) {
            switch event {
            case .change(let paths):
                // Updates are left out of the batch: `reloadItems` swaps the row for a freshly
                // bound cell, so a finished download jumped to its new state — the button gone at
                // once, the text and the sharp icon snapped in. Re-binding the visible rows in
                // place lets each animate its own change (see `FileCell.data`).
                var indexes = paths
                indexes.updates = []
                updateCollectionView(paths: indexes)
                if !paths.updates.isEmpty {
                    rebindVisibleCells()
                }
            }
        }

        /// Re-binds every visible row to its current layout, in place. A row whose attachment
        /// didn't change re-renders the same state, which is a no-op.
        open func rebindVisibleCells() {
            for cell in visibleCells.compactMap({ $0 as? ChannelInfoViewController.FileCell }) {
                guard let indexPath = indexPath(for: cell) else { continue }
                configure(cell, at: indexPath)
            }
        }

        /// Binds `cell` to the layout at `indexPath`. Shared by `cellForItemAt` and
        /// `rebindVisibleCells()`. The pause/resume subscription and the auto-download stay in
        /// `cellForItemAt`: a re-bind would add a second subscription, and ask again for a
        /// download that is already running.
        open func configure(_ cell: ChannelInfoViewController.FileCell, at indexPath: IndexPath) {
            cell.parentAppearance = appearance.cellAppearance
            cell.data = fileViewModel.attachmentLayout(at: indexPath, onLoadThumbnail: { [weak cell] layout in
                guard let cell, layout == cell.data else { return }
                cell.setIcon(layout.thumbnail ?? cell.appearance.iconProvider.provideVisual(for: layout.attachment), animated: true)
            })
        }
        
        public func numberOfSections(in collectionView: UICollectionView) -> Int {
            fileViewModel.numberOfSections
        }
        
        open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            fileViewModel.numberOfAttachments(in: section)
        }
        
        open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.channelInfoFileCell.self)
            configure(cell, at: indexPath)
            if let attachmentLayout = cell.data {
                fileViewModel.downloadAttachmentIfNeeded(attachmentLayout)
            }
            cell.event
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in
                    guard let self else { return }
                    switch $0 {
                    case .pause(let layout):
                        self.fileViewModel.pauseDownload(layout)
                    case .resume(let layout):
                        self.fileViewModel.resumeDownload(layout)
                    }
                }.store(in: &cell.subscriptions)
            return cell
        }
        
        public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            let lastSection = fileViewModel.numberOfSections - 1
            let lastRow = fileViewModel.numberOfAttachments(in: lastSection) - 1
            if lastRow >= 0,
               indexPath == IndexPath(row: lastRow, section: lastSection) {
                fileViewModel.loadAttachments()
            }
        }
        
        open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            onSelect?(indexPath)
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
                cell.date = fileViewModel.attachmentLayout(at: indexPath)?.attachment.createdAt
                return cell
            default:
                fatalError("should not happen")
            }
        }
    }
}

public extension ChannelInfoViewController.FileCollectionView {
    enum Layouts {
        public static var horizontalPadding: CGFloat = 16
        public static var verticalPadding: CGFloat = 8
        public static var iconSize: CGFloat = 40
        public static var cornerRadius: CGFloat = 8
    }
}
