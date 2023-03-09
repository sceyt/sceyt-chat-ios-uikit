//
//  ChannelVoiceListView.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelVoiceListView: ChannelAttachmentListView,
                                 UICollectionViewDelegate,
                                 UICollectionViewDataSource,
                                 UICollectionViewDelegateFlowLayout  {
    
    public static var settings = Layout.Settings(edgeInsets: .init(top: 8, left: 0, bottom: 0, right: 8),
                                                 interitemSpacing: 0,
                                                 lineSpacing: 0)

    open var voiceViewModel: ChannelAttachmentListVM!
    
    public required init() {
        super.init(frame: .zero, collectionViewLayout: Layout(settings: Self.settings))
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    open override func setup() {
        super.setup()
        register(Components.channelVoiceCell.self)
        delegate = self
        dataSource = self
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        backgroundColor = appearance.backgroundColor
    }
    
    open override func setupDone() {
        super.setupDone()
        voiceViewModel.startDatabaseObserver()
        voiceViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        voiceViewModel.loadAttachments()
    }
    
    open func onEvent(_ event: ChannelAttachmentListVM.Event) {
        switch event {
        case .change(let paths):
            updateCollectionView(paths: paths)
        }
    }
    
    open func updateCollectionView(paths: DBChangeItemPaths) {
        if superview == nil || visibleCells.isEmpty {
            reloadData()
        } else {
            UIView.performWithoutAnimation {
                performBatchUpdates {
                    self.insertItems(at: paths.inserts + paths.moves.map { $0.to })
                    self.reloadItems(at: paths.updates)
                    self.deleteItems(at: paths.deletes + paths.moves.map { $0.from })
                }
            }
        }
    }

    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        voiceViewModel.numberOfAttachments
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let attachment = voiceViewModel.attachment(at: indexPath)
        if indexPath.row > voiceViewModel.numberOfAttachments - 3 {
            voiceViewModel.loadAttachments()
        }
        
        if let attachment {
            voiceViewModel.downloadAttachmentIfNeeded(attachment)
        }
        
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.channelVoiceCell.self)
        cell.data = attachment
        return cell
    }
}
