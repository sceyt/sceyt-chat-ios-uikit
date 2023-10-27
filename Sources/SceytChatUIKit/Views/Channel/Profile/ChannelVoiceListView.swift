//
//  ChannelVoiceListView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelVoiceListView: ChannelAttachmentListView,
                                 UICollectionViewDelegate,
                                 UICollectionViewDataSource,
                                 UICollectionViewDelegateFlowLayout  {
    
    public var settings = Layout.Settings(sectionInset: .zero,
                                          interitemSpacing: 0,
                                          lineSpacing: 0,
                                          sectionHeadersPinToVisibleBounds: true)

    open var voiceViewModel: ChannelAttachmentListVM!
    
    open var layout: Layout? { collectionViewLayout as? Layout }
    
    public required init() {
        super.init(frame: .zero, collectionViewLayout: Layout(settings: settings))
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    open override func setup() {
        super.setup()
        
        noItemsMessage = L10n.Channel.Profile.Segment.Voice.noItems
        register(Components.channelProfileVoiceCell.self)
        register(Components.channelProfileFileHeaderView.self, kind: .header)
        delegate = self
        dataSource = self
    }
    
    deinit {
        SimpleSinglePlayer.stop()
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        backgroundColor = appearance.backgroundColor
    }
    
    open override func setupDone() {
        super.setupDone()
        RunLoop.main.perform {[weak self] in
            self?.voiceViewModel.startDatabaseObserver()
        }
        voiceViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        voiceViewModel.loadAttachments()
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        layout?.itemSize = .init(width: width,
                                 height: Layouts.iconSize + Layouts.verticalPadding * 2)
    }
    
    open func onEvent(_ event: ChannelAttachmentListVM.Event) {
        switch event {
        case .change(let paths):
            updateCollectionView(paths: paths)
        }
    }
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        voiceViewModel.numberOfSections
    }

    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        voiceViewModel.numberOfAttachments(in: section)
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.channelProfileVoiceCell.self)
        cell.data = voiceViewModel.attachmentLayout(at: indexPath)
        cell.event
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                switch $0 {
                case .pause(let layout):
                    voiceViewModel.pauseDownload(layout)
                case .resume(let layout):
                    voiceViewModel.resumeDownload(layout)
                }
            }.store(in: &cell.subscriptions)
        if let attachment = cell.data {
            voiceViewModel.downloadAttachmentIfNeeded(attachment)
        }
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let lastSection = voiceViewModel.numberOfSections - 1
        let lastRow = voiceViewModel.numberOfAttachments(in: lastSection) - 1
        if lastRow >= 0,
           indexPath == IndexPath(row: lastRow, section: lastSection) {
            voiceViewModel.loadAttachments()
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return .init(width: collectionView.width, height: ChannelProfileFileHeaderView.Layouts.headerHeight)
    }
    
    public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.SupplementaryViewKind.header.rawValue:
            let cell = collectionView.dequeueReusableSupplementaryView(for: indexPath, cellType: Components.channelProfileFileHeaderView.self, kind: .header)
            cell.date = voiceViewModel.attachmentLayout(at: indexPath)?.attachment.createdAt
            return cell
        default:
            fatalError("should not happen")
        }
    }
}

public extension ChannelVoiceListView {
    enum Layouts {
        public static var horizontalPadding: CGFloat = 16
        public static var verticalPadding: CGFloat = 8
        public static var headerHeight: CGFloat = 32
        public static var iconSize: CGFloat = 40
    }
}
