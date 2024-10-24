//
//  SelectedChannelListView.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Combine
import UIKit

open class SelectedChannelListView: SelectedItemListView<ChatChannel> {
    
    open var appearance: SelectedChannelCell.Appearance = SelectedChannelCell.appearance
    
    public var onDelete: ((ChatChannel) -> Void)?
    
    override open func setup() {
        super.setup()
        
        collectionView.register(Components.selectedChannelCell.self)
    }
    
    override open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.selectedChannelCell.self)
        cell.parentAppearance = appearance
        cell.channelData = items[indexPath.item]
        cell.onDelete = { [weak self] cell in
            guard let self,
                  let indexPath = collectionView.indexPath(for: cell) else { return }
            self.onDelete?(self.items[indexPath.item])
        }
        return cell
    }
}
