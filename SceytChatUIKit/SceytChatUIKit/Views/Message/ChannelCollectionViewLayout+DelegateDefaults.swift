//
//  ChannelCollectionViewLayout+DelegateDefaults.swift
//  SceytChatUIKit
//

import UIKit

public extension ChannelCollectionViewLayout {
    
    @inlinable
    func interItemSpacing(before
        indexPath: IndexPath
    ) -> CGFloat {
        delegate?
            .interItemSpacing(
                layout: self,
                before: indexPath
            )
        ?? defaults.estimatedInterItemSpacing
    }
    
}
