//
//  MessageInputViewController+VoiceRecordPlaybackView+PlayerView.swift
//  SceytChatUIKit
//
//  Created by Duc on 19/03/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import AVFoundation
import UIKit

extension MessageInputViewController.VoiceRecordPlaybackView {
    open class PlayerView: View {
        public lazy var appearance = Components.messageInputVoiceRecordPlaybackView.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        public enum State {
            case playing, stopped, paused
        }
        
        open var state = State.stopped {
            didSet {
                switch state {
                case .stopped:
                    button.setImage(appearance.playIcon, for: [])
                    audioWaveformView.progress = 0
                case .paused:
                    button.setImage(appearance.playIcon, for: [])
                case .playing:
                    button.setImage(appearance.pauseIcon, for: [])
                }
            }
        }
                
        public let button = {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            return $0
        }(UIButton())
        
        public let audioWaveformView = Components.audioWaveformView.init()
        
        open lazy var durationLabel = {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            $0.textAlignment = .right
            return $0
        }(UILabel())
        
        private lazy var row = {
            $0.setCustomSpacing(12, after: button)
            return $0
        }(UIStackView(row: button, audioWaveformView, durationLabel))
        
        public let bg = UIView()
        
        open override func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.backgroundColor
            layer.cornerRadius = 18
            layer.masksToBounds = true
            
            bg.backgroundColor = appearance.playerBackgroundColor
            bg.layer.cornerRadius = 18
            bg.layer.masksToBounds = true
            
            durationLabel.font = appearance.durationLabelAppearance.font
            durationLabel.textColor = appearance.durationLabelAppearance.foregroundColor
            
            button.setImage(appearance.playIcon, for: [])
            audioWaveformView.parentAppearance = appearance.audioWaveformViewAppearance
        }
        
        open override func setup() {
            super.setup()
            
            button.addTarget(self, action: #selector(onTapPlay), for: .touchUpInside)
        }
        
        open override func setupLayout() {
            super.setupLayout()
            
            addSubview(bg.withoutAutoresizingMask)
            bg.pin(to: self)
            
            addSubview(row.withoutAutoresizingMask)
            row.pin(to: self, anchors: [.leading(12), .trailing(-12), .top(8), .bottom(-8)])
            
            audioWaveformView.resize(anchors: [.height(20)])
            durationLabel.resize(anchors: [.width(38)])
        }
        
        open var displayDuration: Double = 0 {
            didSet {
                durationLabel.text = appearance.durationFormatter.format(displayDuration)
            }
        }
        
        open var url: URL?
        @discardableResult
        open func setup(url: URL, metadata: ChatMessage.Attachment.Metadata<[Int]>) -> Self {
            self.url = url
            
            audioWaveformView.progress = 0
            audioWaveformView.data = metadata.thumbnail.map { Float($0) }
            displayDuration = CMTimeGetSeconds(AVPlayerItem(url: url).asset.duration)
            return self
        }
        
        open func setDuration(duration: Double, progress: Double) {
            displayDuration = duration
            audioWaveformView.progress = progress
        }
        
        @objc
        open func onTapPlay() {
            switch state {
            case .stopped:
                displayDuration = 0
                play()
            case .playing:
                pause()
            case .paused:
                play()
            }
        }
        
        open func play() {
            guard let url
            else { return stop() }
            
            state = .playing
            SimpleSinglePlayer.play(url, durationBlock: setDuration, stopBlock: stop)
        }
        
        open func pause() {
            state = .paused
            SimpleSinglePlayer.pause()
        }
        
        open func stop() {
            state = .stopped
            displayDuration = 0
            audioWaveformView.progress = 0
        }
    }        
}
