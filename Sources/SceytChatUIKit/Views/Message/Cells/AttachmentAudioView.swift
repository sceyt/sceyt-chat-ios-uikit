//
//  AttachmentAudioView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 25.12.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import AVFoundation
import UIKit

extension MessageCell {
    open class AttachmentAudioView: AttachmentView {
        enum State {
            case playing, stopped, paused
        }
        
        var state = State.stopped {
            didSet {
                switch state {
                case .stopped:
                    playPauseButton.image = .audioPlayerPlay
                    waveformView.progress = 0
                case .paused:
                    playPauseButton.image = .audioPlayerPlay
                case .playing:
                    playPauseButton.image = .audioPlayerPause
                }
            }
        }
        
        enum Speed: String, CaseIterable {
            case x1 = "1", x1_5 = "1.5", x2 = "2"
        }
        
        var speed = Speed.x1 {
            didSet {
                switch speed {
                case .x1:
                    SimpleSinglePlayer.setRate(1)
                case .x1_5:
                    SimpleSinglePlayer.setRate(1.5)
                case .x2:
                    SimpleSinglePlayer.setRate(2)
                }
                speedLabel.text = speed.rawValue + "x"
            }
        }
        
        let playPauseButton = {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            $0.isUserInteractionEnabled = true
            $0.tag = 999
            return $0
        }(UIImageView())
        
        private let waveformView = WaveformView()
        private let speedButton = {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            return $0
        }(UIButton())

        private let speedLabel = UILabel()
        
        private lazy var waveformRow = UIStackView(row: [waveformView, speedButton], alignment: .center)
        
        private lazy var durationLabel = UILabel()
                
        private lazy var row = UIStackView(row: playPauseButton, UIStackView(column: waveformRow, durationLabel, spacing: 3), spacing: Layouts.horizontalPadding, alignment: .center)
        
        override open func setupAppearance() {
            super.setupAppearance()

            backgroundColor = .clear
            layer.cornerRadius = 16
            layer.masksToBounds = true
            
            playPauseButton.image = .audioPlayerPlay
            
            speedLabel.backgroundColor = appearance.audioSpeedBackgroundColor
            speedLabel.layer.cornerRadius = 10
            speedLabel.layer.masksToBounds = true
            speedLabel.font = appearance.audioSpeedFont
            speedLabel.textColor = appearance.audioSpeedColor
            speedLabel.textAlignment = .center
            
            durationLabel.font = appearance.audioDurationFont
            durationLabel.textColor = appearance.audioDurationColor
            
            imageView.clipsToBounds = true
            
            progressView.backgroundColor = appearance.audioProgressBackgroundColor
            progressView.contentInsets = .init(top: 4, left: 4, bottom: 4, right: 4)
            progressView.trackColor = appearance.audioProgressTrackColor
            progressView.progressColor = appearance.audioProgressColor
        }
        
        override open func setup() {
            super.setup()
            
            speedButton.addTarget(self, action: #selector(onTapSpeed), for: .touchUpInside)
            
            speed = .x1
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            addSubview(row.withoutAutoresizingMask)
            row.pin(to: self, anchors: [.leading(Layouts.horizontalPadding), .trailing(0), .top(6)])
            waveformView.resize(anchors: [.height(20)])
            speedLabel.resize(anchors: [.height(20), .width(30)])
            
            speedButton.addSubview(speedLabel.withoutAutoresizingMask)
            speedLabel.pin(to: speedButton, anchors: [.leading(Layouts.horizontalPadding), .trailing(-Layouts.horizontalPadding), .top(0), .bottom(0)])
            
            playPauseButton.resize(anchors: [.width(Layouts.attachmentIconSize), .height(Layouts.attachmentIconSize)])

            addSubview(progressView)
            addSubview(pauseButton)
                        
            progressView.resize(anchors: [.width(Layouts.attachmentIconSize), .height(Layouts.attachmentIconSize)])
            progressView.pin(to: playPauseButton, anchors: [.centerX, .centerY])
            pauseButton.pin(to: progressView)
        }
        
        override open var data: MessageLayoutModel.AttachmentLayout! {
            didSet {
                waveformView.data = data.voiceWaveform
                displayDuration = data.mediaDuration
                
                if let fileUrl = data.attachment.fileUrl, fileUrl == SimpleSinglePlayer.url {
                    state = SimpleSinglePlayer.isPlaying ? .playing : .paused
                    SimpleSinglePlayer.set(durationBlock: setDuration, stopBlock: stop)
                } else {
                    state = .stopped
                }
            }
        }
        
        private var displayDuration = 0.0 {
            didSet {
                durationLabel.text = SceytChatUIKit.shared.formatters.mediaDurationFormatter.format(displayDuration)
            }
        }
        
        func play(onPlayed: (_ url: URL) -> Void) {
            guard let fileUrl = data.attachment.fileUrl else { return }

            switch state {
            case .stopped:
                state = .playing
                SimpleSinglePlayer.play(fileUrl, durationBlock: setDuration, stopBlock: stop)
                onPlayed(fileUrl)
            case .playing:
                state = .paused
                SimpleSinglePlayer.pause()
            case .paused:
                state = .playing
                SimpleSinglePlayer.play(fileUrl, durationBlock: setDuration, stopBlock: stop)
            }
        }
        
        func stop() {
            state = .stopped
            displayDuration = data.mediaDuration
        }
        
        @objc
        private func onTapSpeed() {
            switch speed {
            case .x1:
                speed = .x1_5
            case .x1_5:
                speed = .x2
            case .x2:
                speed = .x1
            }
        }
        
        func setDuration(duration: TimeInterval, progress: Double) {
            displayDuration = duration
            waveformView.progress = progress
        }
    }
}
