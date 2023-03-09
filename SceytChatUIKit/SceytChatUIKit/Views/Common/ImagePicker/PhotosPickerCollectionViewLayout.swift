//
//  PhotosPickerCollectionViewLayout.swift
//  SceytChatUIKit
//

import UIKit

open class PhotosPickerCollectionViewLayout: UICollectionViewFlowLayout {
    
    public required override init() {
        super.init()
        sectionInset = .init(top: 2, left: 2, bottom: 2, right: 2)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
