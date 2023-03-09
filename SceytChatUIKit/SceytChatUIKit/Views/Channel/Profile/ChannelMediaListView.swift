//
//  ChannelMediaListView.swift
//  SceytChatUIKit
//

import UIKit
import AVKit

open class ChannelMediaListView: ChannelAttachmentListView,
                                 UICollectionViewDelegate,
                                 UICollectionViewDataSource,
                                 UICollectionViewDelegateFlowLayout {

    public static var settings = Layout.Settings(edgeInsets: .init(top: 8, left: 4, bottom: 4, right: 4),
                                                 interitemSpacing: 4,
                                                 lineSpacing: 4)

    open var mediaViewModel: ChannelAttachmentListVM!

    public required init() {
        super.init(frame: .zero, collectionViewLayout: Layout(settings: Self.settings))
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    open override func setup() {
        super.setup()
        register(Components.channelMediaImageCell.self)
        register(Components.channelMediaVideoCell.self)
        delegate = self
        dataSource = self
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        backgroundColor = appearance.backgroundColor
    }
    
    open override func setupDone() {
        super.setupDone()
        mediaViewModel.startDatabaseObserver()
        mediaViewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        mediaViewModel.loadAttachments()
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
        mediaViewModel.numberOfAttachments
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let attachment = mediaViewModel.attachment(at: indexPath)
        if indexPath.row > mediaViewModel.numberOfAttachments - 3 {
            mediaViewModel.loadAttachments()
        }
        
        if let attachment {
            mediaViewModel.downloadAttachmentIfNeeded(attachment)
        }
        
        switch attachment?.type {
        case "image":
            let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.channelMediaImageCell.self)
            cell.data = attachment
            cell.previewer = previewer
            return cell
        case "video":
            let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.channelMediaVideoCell.self)
            cell.data = attachment
            cell.previewer = previewer
            return cell
        default:
            break
        }
        return collectionView.dequeueReusableCell(for: indexPath, cellType: Components.channelMediaImageCell.self)
    }
    
    open var previewer: AttachmentPreviewDataSource?
}

extension ChannelMediaListView {

    open class Layout: ChannelAttachmentListView.Layout {

        public required init(settings: Settings) {
            super.init(settings: settings)
        }

        public required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        open var firstItemFrame: CGRect {
            let width = collectionView?.width ?? 0
            let itemSize = CGSize(width: Int((width - 16) / 3),
                                  height: Int((width - 16) / 3))
            return CGRect(
                x: settings.edgeInsets.left,
                y: settings.edgeInsets.top,
                width: itemSize.width,
                height: itemSize.height)
        }
        open var contentSize: CGSize = .zero
        open var layoutAttributes = [IndexPath: UICollectionViewLayoutAttributes]()

        open override func prepare() {
            super.prepare()
            guard let collectionView = collectionView else { return }
            let numberOfItems = collectionView.numberOfItems(inSection: 0)
            let collectionViewWidth = collectionView.bounds.width
            guard collectionViewWidth > 0 else { return }
            var frame = firstItemFrame
            (0 ..< numberOfItems).forEach { (index) in
                let indexPath = IndexPath(item: index, section: 0)
                if let atr = layoutAttributesForItem(at: indexPath) {
                    atr.frame = frame
                    layoutAttributes[indexPath] = atr
                }
                frame.origin.x = frame.maxX + settings.interitemSpacing
                if index < numberOfItems - 1,
                   frame.maxX + settings.edgeInsets.right > collectionViewWidth
                {
                    frame.origin.x = settings.edgeInsets.left
                    frame.origin.y = frame.maxY + settings.lineSpacing
                }

            }
            contentSize = CGSize(width: collectionViewWidth, height: frame.maxY + settings.edgeInsets.bottom)
        }

        open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
            layoutAttributes.values.filter { rect.intersects($0.frame) }
        }

        open override var collectionViewContentSize: CGSize {
            contentSize
        }

        open override func invalidateLayout() {
            super.invalidateLayout()
            contentSize = .zero
            layoutAttributes = [:]
        }
    }
}
