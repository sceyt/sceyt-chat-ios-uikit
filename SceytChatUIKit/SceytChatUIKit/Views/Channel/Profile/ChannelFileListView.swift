//
//  ChannelFileListView.swift
//  SceytChatUIKit
//

import UIKit
import SceytChat

open class ChannelFileListView: ChannelAttachmentListView,
                                UICollectionViewDelegate,
                                UICollectionViewDataSource,
                                UICollectionViewDelegateFlowLayout {

    public static var settings = Layout.Settings(edgeInsets: .init(top: 8, left: 0, bottom: 0, right: 8),
                                                 interitemSpacing: 0,
                                                 lineSpacing: 0)

    open var fileViewModel: ChannelAttachmentListVM!
    
    public var onSelect: ((IndexPath) -> Void)?

    public required init() {
        super.init(frame: .zero, collectionViewLayout: Layout(settings: Self.settings))
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    open override func setup() {
        super.setup()
        register(Components.channelFileCell.self)
        delegate = self
        dataSource = self
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        backgroundColor = appearance.backgroundColor
    }
    
    open override func setupDone() {
        super.setupDone()
        fileViewModel.startDatabaseObserver()
        fileViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        fileViewModel.loadAttachments()
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
        fileViewModel.numberOfAttachments
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let attachment = fileViewModel.attachment(at: indexPath)
        if indexPath.row > fileViewModel.numberOfAttachments - 3 {
            fileViewModel.loadAttachments()
        }
        
        if let attachment {
            fileViewModel.downloadAttachmentIfNeeded(attachment)
        }
        
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.channelFileCell.self)
        cell.data = attachment
        return cell
    }
    
    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelect?(indexPath)
    }
}
