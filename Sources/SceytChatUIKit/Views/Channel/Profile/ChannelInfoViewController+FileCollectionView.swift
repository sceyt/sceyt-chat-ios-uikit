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
        
        open var fileViewModel: ChannelAttachmentListViewModel!
        
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
            
            fileViewModel.$event
                .compactMap { $0 }
                .sink { [weak self] in
                    self?.onEvent($0)
                }.store(in: &subscriptions)
            fileViewModel.loadAttachments()
        }
        
        open override func layoutSubviews() {
            super.layoutSubviews()
            
            layout?.itemSize = .init(width: width,
                                     height: Layouts.iconSize + Layouts.verticalPadding * 2)
        }
        
        open func onEvent(_ event: ChannelAttachmentListViewModel.Event) {
            switch event {
            case .change(let paths):
                updateCollectionView(paths: paths)
            }
        }
        
        public func numberOfSections(in collectionView: UICollectionView) -> Int {
            fileViewModel.numberOfSections
        }
        
        open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            fileViewModel.numberOfAttachments(in: section)
        }
        
        open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.channelInfoFileCell.self)
            cell.parentAppearance = appearance.cellAppearance
            cell.data = fileViewModel.attachmentLayout(at: indexPath, onLoadThumbnail: { [weak cell] layout in
                guard layout == cell?.data else { return }
                cell?.iconView.image = layout.thumbnail
            })
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
            if let attachmentLayout = cell.data {
                fileViewModel.downloadAttachmentIfNeeded(attachmentLayout)
            }
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
