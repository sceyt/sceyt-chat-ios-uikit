//
//  PhotosPickerCollectionView.swift
//  SceytChatUIKit
//

import UIKit

open class PhotosPickerCollectionView: CollectionView {
    
    public required init() {
        super.init(frame: UIScreen.main.bounds, collectionViewLayout: Components.imagePickerCollectionViewLayout.init())
    }
    
    public required override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
