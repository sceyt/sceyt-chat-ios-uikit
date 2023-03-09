//
//  ChannelAttachmentListVC.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelAttachmentListView: CollectionView {
    open override func setup() {
        super.setup()
        isPrefetchingEnabled = false
        bounces = false
        alwaysBounceVertical = false
        alwaysBounceHorizontal = false
    }
    
    open override func setupAppearance() {
        backgroundColor = .white
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        if (collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize.width == 0 {
            collectionViewLayout.invalidateLayout()
        }
    }
}

extension ChannelAttachmentListView {

    open class Layout: UICollectionViewFlowLayout {
        public let settings: Settings

        public required init(settings: Settings) {
            self.settings = settings
            super.init()
            
            if !settings.estimatedItemSize.isNan {
                estimatedItemSize = settings.estimatedItemSize
            }
            if !settings.interitemSpacing.isNaN {
                minimumInteritemSpacing = settings.interitemSpacing
            }
            if !settings.lineSpacing.isNaN {
                minimumLineSpacing = settings.lineSpacing
            }
        }

        public required init?(coder: NSCoder) {
            settings = .init()
            super.init(coder: coder)
        }
        
        open override func invalidateLayout() {
            super.invalidateLayout()
            itemSize = CGSize(width: collectionView?.width ?? 0, height: 60)
        }
    }
}

public extension ChannelAttachmentListView.Layout {

    struct Settings {
        public let edgeInsets: UIEdgeInsets
        public let interitemSpacing: CGFloat
        public let lineSpacing: CGFloat
        public let estimatedItemSize: CGSize

        public init(edgeInsets: UIEdgeInsets = .zero,
                    interitemSpacing: CGFloat = .nan,
                    lineSpacing: CGFloat = .nan,
                    estimatedItemSize: CGSize = .nan) {
            self.edgeInsets = edgeInsets
            self.interitemSpacing = interitemSpacing
            self.lineSpacing = lineSpacing
            self.estimatedItemSize = estimatedItemSize
        }
    }
}
