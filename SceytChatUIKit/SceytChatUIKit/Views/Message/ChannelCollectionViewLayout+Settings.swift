//
//  ChannelCollectionViewLayout+Defaults.swift
//  SceytChatUIKit
//

import UIKit

extension ChannelCollectionViewLayout {
    
    public struct Defaults {
        public var estimatedCellHeight = CGFloat(33)
        public var estimatedFooterHeight = CGFloat(33)
        public var estimatedInterItemSpacing = CGFloat(5)
        public var pinHeader = false
        
        public var cellZIndex = 2
        public var footerZIndex = 1
        public var pinnedFooterZIndex = ZIndex.dynamicNextToLatItemInRow
        
        public var elementHeader = UICollectionView.elementKindSectionHeader
        
        public init() {}
    }
    
    public enum ScrollToPosition: Equatable {
        case none
        case end
        case indexPath(IndexPath)
    }
}

extension ChannelCollectionViewLayout.Defaults {
    public static var `default` = ChannelCollectionViewLayout.Defaults()
}

extension ChannelCollectionViewLayout.Defaults {
    public enum ZIndex {
        case `static`(Int)
        case dynamicNextToLatItemInRow
    }
}
