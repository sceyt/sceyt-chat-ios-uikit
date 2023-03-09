//
//  SelectedUserListView.swift
//  SceytChatUIKit
//

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
        cell.data = items[indexPath.item]
        cell.onDelete = { [weak self] cell in
            guard let self,
                    let indexPath = collectionView.indexPath(for: cell) else { return }
            self.removeContact = self.items[indexPath.item]
        }
        return cell
    }
}
