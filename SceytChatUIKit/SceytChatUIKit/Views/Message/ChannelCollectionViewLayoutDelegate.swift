//
//  ChannelCollectionViewLayoutDelegate.swift
//  SceytChatUIKit
//

import Foundation

public protocol ChannelCollectionViewLayoutDelegate: AnyObject {
    
    func interItemSpacing(layout: ChannelCollectionViewLayout, before indexPath: IndexPath) -> CGFloat
}
