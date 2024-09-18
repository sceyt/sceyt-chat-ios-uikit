//
//  MediaPickerViewController+MediaPickerCollectionView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension MediaPickerViewController {
    open class MediaPickerCollectionView: CollectionView {
        
        public required init() {
            super.init(frame: UIScreen.main.bounds, collectionViewLayout: Components.mediaPickerCollectionViewLayout.init())
        }
        
        public required override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
            super.init(frame: frame, collectionViewLayout: layout)
        }
        
        public required init?(coder: NSCoder) {
            super.init(coder: coder)
        }
    }
}
