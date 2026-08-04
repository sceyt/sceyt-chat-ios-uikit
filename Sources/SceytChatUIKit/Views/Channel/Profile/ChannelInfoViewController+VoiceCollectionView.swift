//
//  ChannelInfoViewController+VoiceCollectionView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

extension ChannelInfoViewController {
    open class VoiceCollectionView: ChannelInfoViewController.AttachmentCollectionView,
                                           UICollectionViewDelegate,
                                           UICollectionViewDataSource,
                                           UICollectionViewDelegateFlowLayout  {
        
        public var settings = Layout.Settings(sectionInset: .zero,
                                              interitemSpacing: 0,
                                              lineSpacing: 0,
                                              sectionHeadersPinToVisibleBounds: true)
        
        open var voiceViewModel: any ChannelAttachmentListViewModelProviding = ChannelAttachmentListViewModel.Empty()

        open override var attachmentViewModel: (any ChannelAttachmentListViewModelProviding)? { voiceViewModel }

        /// Called when the user taps a voice cell. Provides the owning message and channel.
        open var onSelectVoice: ((ChatMessage, ChatChannel?) -> Void)?
        
        open var layout: Layout? { collectionViewLayout as? Layout }
        
        public required init() {
            super.init(frame: .zero, collectionViewLayout: Layout(settings: settings))
        }
        
        public required init?(coder: NSCoder) {
            super.init(coder: coder)
        }
        
        open override func setup() {
            super.setup()
            
            noItemsMessage = L10n.Channel.Info.Segment.Voice.noItems
            noItemsMessageSubTitle = L10n.Channel.Info.Segment.Voice.noItemsSubTitle
            noItemsIcon = UIImage.emptyVoice
            register(Components.channelInfoVoiceCell.self)
            register(Components.channelInfoDateSeparatorView.self, kind: .header)
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
            voiceViewModel.eventPublisher
                .compactMap { $0 }
                .sink { [weak self] in
                    self?.onEvent($0)
                }.store(in: &subscriptions)
            voiceViewModel.loadAttachments()
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
            let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.channelInfoVoiceCell.self)
            cell.parentAppearance = appearance.cellAppearance
            cell.data = voiceViewModel.attachmentLayout(at: indexPath)
            cell.event
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in
                    guard let self else { return }
                    switch $0 {
                    case .pause(let layout):
                        self.voiceViewModel.pauseDownload(layout)
                    case .resume(let layout):
                        self.voiceViewModel.resumeDownload(layout)
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
        
        public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            collectionView.deselectItem(at: indexPath, animated: true)
            guard let layout = voiceViewModel.attachmentLayout(at: indexPath),
                  let message = layout.ownerMessage
            else { return }
            let channel: ChatChannel? = layout.ownerChannel ?? {
                let ctx = SceytChatUIKit.shared.database.viewContext
                return ChannelDTO.fetch(id: message.channelId, context: ctx)?.convert()
            }()
            onSelectVoice?(message, channel)
        }

        public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
            return .init(width: collectionView.width, height: Components.channelInfoDateSeparatorView.Layouts.headerHeight)
        }
        
        public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
            switch kind {
            case UICollectionView.SupplementaryViewKind.header.rawValue:
                let cell = collectionView.dequeueReusableSupplementaryView(for: indexPath, cellType: Components.channelInfoDateSeparatorView.self, kind: .header)
                cell.parentAppearance = appearance.separatorAppearance
                cell.date = voiceViewModel.attachmentLayout(at: indexPath)?.attachment.createdAt
                return cell
            default:
                fatalError("should not happen")
            }
        }
    }
}

public extension ChannelInfoViewController.VoiceCollectionView {
    enum Layouts {
        public static var horizontalPadding: CGFloat = 16
        public static var verticalPadding: CGFloat = 8
        public static var headerHeight: CGFloat = 32
        public static var iconSize: CGFloat = 40
    }
}
