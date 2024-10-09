//
//  MessageCell+ReactionLabel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit


extension MessageCell {
    open class ReactionLabel: UILabel {
        private var isConfigured = false

        public let key: String

        public lazy var appearance = Components.messageCell.appearance {
            didSet {
                setupAppearance()
            }
        }

        public required init(key: String) {
            self.key = key
            super.init(frame: .zero)
            setup()
            setupAppearance()
        }

        public required init?(coder: NSCoder) {
            key = ""
            super.init(coder: coder)
            setup()
            setupAppearance()
        }
        
        override open func didMoveToSuperview() {
            super.didMoveToSuperview()
            guard !isConfigured else { return }
            setupLayout()
            setupDone()
            isConfigured = true
        }
        
        open func setup() {
            showsLargeContentViewer = false
            textAlignment = .center
            lineBreakMode = .byCharWrapping
            layer.drawsAsynchronously = true
            text = key
        }
        
        open func setupAppearance() {
            font = appearance.reactionCountLabelAppearance.font
            textColor = appearance.reactionCountLabelAppearance.foregroundColor
        }
        
        open func setupLayout() {}
        open func setupDone() {}
    }
}
