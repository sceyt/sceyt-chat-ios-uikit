//
//  SelectedUserListView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Combine
import UIKit

open class SelectedUserListView: SelectedItemListView<ChatUser> {
    @Published open private(set) var removeContact: ChatUser?
    
    open func add(user: ChatUser) {
        add(item: user)
    }
    
    open func remove(user: ChatUser) {
        remove(item: user)
    }
    
    open func reload(user: [ChatUser]) {
        reload(items: user)
    }
    
    override open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: SelectedUserCell.self)
        cell.userData = items[indexPath.item]
        cell.onDelete = { [weak self] cell in
            guard let self,
                  let indexPath = collectionView.indexPath(for: cell) else { return }
            self.removeContact = self.items[indexPath.item]
        }
        return cell
    }
}

open class SelectedChannelListView: SelectedItemListView<ChatChannel> {
    public var onDelete: ((ChatChannel) -> Void)?
    
    override open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: SelectedUserCell.self)
        cell.channelData = items[indexPath.item]
        cell.onDelete = { [weak self] cell in
            guard let self,
                  let indexPath = collectionView.indexPath(for: cell) else { return }
            onDelete?(self.items[indexPath.item])
        }
        return cell
    }
}
