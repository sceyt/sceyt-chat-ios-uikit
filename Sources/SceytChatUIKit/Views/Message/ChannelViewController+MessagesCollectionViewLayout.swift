//
//  ChannelViewController+MessagesCollectionViewLayout.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

public extension ChannelViewController {
    open class MessagesCollectionViewLayout: UICollectionViewFlowLayout {
        
        public required override init() {
            super.init()
        }
        
        required public init?(coder: NSCoder) {
            super.init(coder: coder)
        }
        
        open override class var layoutAttributesClass: AnyClass {
            MessagesCollectionViewLayoutAttributes.self
        }
        
        open override func prepare() {
            super.prepare()
        }
        
        open override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
            true
        }
        
        open override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
            super.invalidateLayout(with: context)
        }
    }
}
