//
//  MediaPickerViewController+MediaPickerCollectionViewLayout.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension MediaPickerViewController {
    open class MediaPickerCollectionViewLayout: UICollectionViewFlowLayout {
        
        public required override init() {
            super.init()
            sectionInset = .init(top: 2, left: 2, bottom: 2, right: 2)
        }
        
        public required init?(coder: NSCoder) {
            super.init(coder: coder)
        }
    }
}
