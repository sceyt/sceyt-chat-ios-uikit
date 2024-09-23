//
//  MessageInputViewController+ThumbnailView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInputViewController {
    open class ThumbnailView: View {
        public lazy var appearance = Components.messageInputViewController.appearance {
            didSet {
                setupAppearance()
            }
        }

        open lazy var closeButton = UIButton()
            .withoutAutoresizingMask
                
        public let containerView: View
        
        public required init(containerView: View) {
            self.containerView = containerView
            super.init(frame: .zero)
        }
        
        @available(*, unavailable)
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override open func setup() {
            super.setup()
            closeButton.setImage(Images.closeCircle, for: .normal)
            closeButton.addTarget(self, action: #selector(deleteAction), for: .touchUpInside)
        }

        override open func setupAppearance() {
            super.setupAppearance()
        }

        override open func setupLayout() {
            super.setupLayout()
            addSubview(containerView)
            addSubview(closeButton)
            containerView.pin(to: self, anchors: [.leading(0), .top(6), .trailing(-6), .bottom()])
            closeButton.pin(to: self, anchors: [.top(), .trailing()])
        }

        open var onDelete: ((ThumbnailView) -> Void)?

        @objc
        open func deleteAction() {
            onDelete?(self)
        }
    }
}
