//
//  SelectedItemListView.swift
//  SceytChatUIKit
//

import UIKit

open class SelectedItemListView<Item:Equatable>: View, UICollectionViewDataSource, UICollectionViewDelegate {
        
    open lazy var collectionViewLayout: UICollectionViewLayout = {
        $0.scrollDirection = .horizontal
        $0.estimatedItemSize = CGSize(width: 64, height: 108)
        $0.minimumInteritemSpacing = 22
        return $0
    }(UICollectionViewFlowLayout())
    
    open lazy var collectionView: UICollectionView = {
        $0.backgroundColor = .clear
        $0.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 12, right: 16)
        return $0.withoutAutoresizingMask
    }(UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout))
    
    override open func setupLayout() {
        super.setupLayout()
        addSubview(collectionView)
        collectionView.pin(to: self, anchors: [.top(), .leading(), .trailing()])
        collectionView.heightAnchor.pin(constant: 120)
    }
    
    override open func setup() {
        super.setup()
        collectionView.register(SelectedUserCell.self)
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    public private(set) var items = [Item]()
    
    open func add(item: Item) {
        items.append(item)
        collectionView.insertItems(at: [IndexPath(item: items.count - 1, section: 0)])
    }
    
    open func remove(item: Item) {
        if let index = items.firstIndex(where: { $0 == item}) {
            items.remove(at: index)
            collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
        }
    }
    
    open func reload(items: [Item]) {
        self.items = items
        collectionView.reloadData()
    }
    
    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        fatalError("override")
    }
    
    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }
}

