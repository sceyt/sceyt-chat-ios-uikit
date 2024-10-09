//
//  MessageInputViewController+VoiceRecordPlaybackView.swift
//  SceytChatUIKit
//
//  Created by Duc on 19/03/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import AVFoundation
import UIKit

extension MessageInputViewController {
    open class VoiceRecordPlaybackView: View {
        enum Event {
            case send(url: URL, metadata: ChatMessage.Attachment.Metadata<[Int]>), cancel
        }
        
        var onEvent: ((Event) -> Void)?
        
        open lazy var cancelButton = {
            $0.setImage(appearance.closeIcon, for: [])
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            return $0
        }(UIButton())
        
        open lazy var audioPlayerView = Components.messageInputVoiceRecordPlaybackPlayerView.init()
        
        open lazy var sendButton = {
            $0.setImage(appearance.sendVoiceIcon, for: [])
            $0.imageView?.contentMode = .scaleAspectFit
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            return $0
        }(UIButton())
        
        open lazy var spacerColumn = UIStackView(column: UIView(), audioPlayerView, UIView(), spacing: 0, distribution: .equalSpacing)
        open lazy var row = UIStackView(row: cancelButton, spacerColumn, sendButton, spacing: 0)
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.backgroundColor
            audioPlayerView.appearance = appearance
        }
        
        override open func setup() {
            super.setup()
            
            cancelButton.addTarget(self, action: #selector(onTapCancel), for: .touchUpInside)
            sendButton.addTarget(self, action: #selector(onTapSend), for: .touchUpInside)
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            addSubview(row.withoutAutoresizingMask)
            
            row.pin(to: self)
            sendButton.resize(anchors: [.height(52), .width(52)])
            cancelButton.resize(anchors: [.height(52), .width(52)])
        }
        
        private var url: URL!
        private var metadata: ChatMessage.Attachment.Metadata<[Int]>!
        
        open func setup(url: URL, metadata: ChatMessage.Attachment.Metadata<[Int]>) {
            self.url = url
            self.metadata = metadata
            audioPlayerView.setup(url: url, metadata: metadata)
        }
        
        @objc
        private func onTapCancel() {
            SimpleSinglePlayer.stop()
            onEvent?(.cancel)
        }
        
        @objc
        private func onTapSend() {
            onEvent?(.send(url: url, metadata: metadata))
        }
        
        open func pause() {
            audioPlayerView.pause()
        }
    }
}
