//
//  InputVC+VoiceRecordPlaybackView+PlayerView.swift
//  SceytChatUIKit
//
//  Created by Duc on 19/03/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import AVFoundation
import UIKit

extension InputVC.VoiceRecordPlaybackView {
    open class PlayerView: View {
        public lazy var appearance = Components.inputVC.appearance {
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
                    button.setImage(.audioPlayerPlayGrey, for: [])
                    waveformView.progress = 0
                    displayDuration = 0
                case .paused:
                    button.setImage(.audioPlayerPlayGrey, for: [])
                case .playing:
                    button.setImage(.audioPlayerPauseGrey, for: [])
                }
            }
        }
                
        public let button = {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            return $0
        }(UIButton())
        
        public let waveformView = Components.waveformView.init()
        
        open lazy var durationLabel = {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            $0.textAlignment = .right
            return $0
        }(UILabel())
        
        private lazy var row = {
            $0.setCustomSpacing(12, after: button)
            return $0
        }(UIStackView(row: button, waveformView, durationLabel))
        
        public let bg = UIView()
        
        open override func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.recorderBackgroundColor
            layer.cornerRadius = 18
            layer.masksToBounds = true
            
            bg.backgroundColor = appearance.recorderPlayerBackgroundColor
            bg.layer.cornerRadius = 18
            bg.layer.masksToBounds = true
            
            durationLabel.font = appearance.recorderDurationFont
            durationLabel.textColor = appearance.recorderDurationColor
            
            button.setImage(.audioPlayerPlayGrey, for: [])
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
            
            waveformView.resize(anchors: [.height(20)])
            durationLabel.resize(anchors: [.width(38)])
        }
        
        open var displayDuration: Double = 0 {
            didSet {
                durationLabel.text = SceytChatUIKit.shared.formatters.mediaDurationFormatter.format(displayDuration)
            }
        }
        
        open var url: URL?
        @discardableResult
        open func setup(url: URL, metadata: ChatMessage.Attachment.Metadata<[Int]>) -> Self {
            self.url = url
            
            waveformView.progress = 0
            waveformView.data = metadata.thumbnail.map { Float($0) }
            displayDuration = CMTimeGetSeconds(AVPlayerItem(url: url).asset.duration)
            return self
        }
        
        open func setDuration(duration: Double, progress: Double) {
            displayDuration = duration
            waveformView.progress = progress
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
            waveformView.progress = 0
        }
    }        
}
