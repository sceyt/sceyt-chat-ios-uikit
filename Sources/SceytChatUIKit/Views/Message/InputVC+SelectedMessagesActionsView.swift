//
//  InputViewController+SelectedMessagesActionsView.swift
//  SceytChatUIKit
//
//  Created by Duc on 02/09/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension InputViewController {
    open class SelectedMessagesActionsView: View {
        private let buttonDelete = {
            $0.setImage(.chatDelete, for: [])
            $0.contentEdgeInsets = .init(top: 14, left: 16, bottom: 14, right: 16)
            return $0
        }(UIButton())
        
        private let buttonShare = {
            $0.setImage(.chatShare, for: [])
            $0.contentEdgeInsets = .init(top: 14, left: 16, bottom: 14, right: 16)
            return $0
        }(UIButton())
        
        private let buttonForward = {
            $0.setImage(.chatForward, for: [])
            $0.contentEdgeInsets = .init(top: 14, left: 16, bottom: 14, right: 16)
            return $0
        }(UIButton())
        
        private lazy var row = {
            return $0.withoutAutoresizingMask
        }(UIStackView(row: [buttonDelete, buttonShare, buttonForward], spacing: 4, distribution: .equalSpacing))
        
        private let line = UIView().withoutAutoresizingMask
        
        public enum Action {
            case delete, share, forward
        }
        
        open var onAction: ((Action) -> Void)?
        
        open override func setup() {
            super.setup()
            
            buttonDelete.addTarget(self, action: #selector(onDelete), for: .touchUpInside)
            buttonShare.addTarget(self, action: #selector(onShare), for: .touchUpInside)
            buttonForward.addTarget(self, action: #selector(onForward), for: .touchUpInside)
        }
        
        open override func setupLayout() {
            super.setupLayout()
            
            addSubview(row)
            row.pin(to: self)
            
            addSubview(line)
            line.pin(to: self, anchors: [.top, .leading, .trailing])
            line.resize(anchors: [.height(0.5)])
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.backgroundColor
            line.backgroundColor = appearance.dividerColor
        }
        
        @objc open func onDelete() { onAction?(.delete) }
        @objc open func onShare() { onAction?(.share) }
        @objc open func onForward() { onAction?(.forward) }
    }
}
