//
//  MessageCell+AttachmentAudioView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 25.12.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import AVFoundation
import SceytChat
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
                    playPauseButton.image = appearance.voicePlayIcon
                    audioWaveformView.progress = 0
                case .paused:
                    playPauseButton.image = appearance.voicePlayIcon
                case .playing:
                    playPauseButton.image = appearance.voicePauseIcon
                }
            }
        }
        
        enum Speed: String, CaseIterable {
            case x1 = "1", x1_5 = "1.5", x2 = "2"
        }
        
        var speed = Speed.x1 {
            didSet {
                setPlayerSpeed(speed)
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

        open lazy var fireIconView: UIImageView = {
            let view = UIImageView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.contentMode = .scaleAspectFit
            view.isUserInteractionEnabled = false
            view.isHidden = true
            return view
        }()
        
        private let audioWaveformView = Components.audioWaveformView.init()
        private let speedButton = {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            return $0
        }(UIButton())

        private let speedLabel = UILabel()
        
        private lazy var waveformRow = UIStackView(row: [audioWaveformView, speedButton], alignment: .center)
        
        private lazy var durationLabel = UILabel()
                
        private lazy var row = UIStackView(row: playPauseButton, UIStackView(column: waveformRow, durationLabel, spacing: 3), spacing: Layouts.horizontalPadding, alignment: .center)
        
        override open func setupAppearance() {
            super.setupAppearance()

            backgroundColor = .clear
            layer.cornerRadius = 16
            layer.masksToBounds = true

            playPauseButton.image = appearance.voicePlayIcon
            fireIconView.image = appearance.voiceViewOnceIcon

            speedLabel.backgroundColor = appearance.voiceSpeedLabelAppearance.backgroundColor
            speedLabel.layer.cornerRadius = 10
            speedLabel.layer.masksToBounds = true
            speedLabel.font = appearance.voiceSpeedLabelAppearance.font
            speedLabel.textColor = appearance.voiceSpeedLabelAppearance.foregroundColor
            speedLabel.textAlignment = .center

            durationLabel.font = appearance.voiceDurationLabelAppearance.font
            durationLabel.textColor = appearance.voiceDurationLabelAppearance.foregroundColor

            imageView.clipsToBounds = true

            progressView.backgroundColor = appearance.mediaLoaderAppearance.backgroundColor
            progressView.contentInsets = .init(top: 4, left: 4, bottom: 4, right: 4)
            progressView.trackColor = appearance.mediaLoaderAppearance.trackColor
            progressView.progressColor = appearance.mediaLoaderAppearance.progressColor
            audioWaveformView.parentAppearance = appearance.voiceWaveformViewAppearance
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
            audioWaveformView.resize(anchors: [.height(20)])
            speedLabel.resize(anchors: [.height(20), .width(30)])

            speedButton.addSubview(speedLabel.withoutAutoresizingMask)
            speedLabel.pin(to: speedButton, anchors: [.leading(Layouts.horizontalPadding), .trailing(-Layouts.horizontalPadding), .top(0), .bottom(0)])

            playPauseButton.resize(anchors: [.width(Layouts.attachmentIconSize), .height(Layouts.attachmentIconSize)])

            addSubview(progressView)
            addSubview(pauseButton)
            addSubview(fireIconView)

            progressView.resize(anchors: [.width(Layouts.attachmentIconSize), .height(Layouts.attachmentIconSize)])
            progressView.pin(to: playPauseButton, anchors: [.centerX, .centerY])
            pauseButton.pin(to: progressView)

            fireIconView.resize(anchors: [.width(20), .height(20)])
            fireIconView.pin(to: playPauseButton, anchors: [.trailing(6), .bottom(1)])
        }
        
        override open var data: MessageLayoutModel.AttachmentLayout! {
            didSet {
                audioWaveformView.data = data.voiceWaveform
                displayDuration = data.mediaDuration

                data.onLoadThumbnail = { [weak self, weak data] _ in
                    guard let self, let data, self.data === data else { return }
                    self.audioWaveformView.data = data.voiceWaveform
                }

                if data.attachment.playerId == SimpleSinglePlayer.currentId {
                    state = SimpleSinglePlayer.isPlaying ? .playing : .paused
                    SimpleSinglePlayer.set(durationBlock: setDuration, stopBlock: stop)
                    if SimpleSinglePlayer.isPlaying {
                        SimpleSinglePlayer.setPauseBlock { [weak self] in self?.state = .paused }
                    }
                } else {
                    state = .stopped
                }

                // Load stored speed for this recording on cell reuse
                if let storedSpeed = SimpleSinglePlayer.getSpeed(for: data.attachment.playerId) {
                    // Update speed property and UI without triggering didSet
                    switch storedSpeed {
                    case 1.5:
                        speed = .x1_5
                    case 2:
                        speed = .x2
                    default:
                        speed = .x1
                    }
                } else {
                    speed = .x1
                }

                // Show/hide fire icon based on viewOnce
                let isViewOnce = data.ownerMessage?.isViewOnceMessage ?? false
                fireIconView.isHidden = !isViewOnce
            }
        }
        
        private var displayDuration = 0.0 {
            didSet {
                durationLabel.text = appearance.voiceDurationFormatter.format(displayDuration)
            }
        }

        override open func setProgress(_ progress: CGFloat) {
            guard progressView.progress != progress
            else { return }

            // Hide viewOnce fire icon during upload/download to avoid overlap
            if progress > 0, progress < 1 {
                let isViewOnce = data.ownerMessage?.isViewOnceMessage ?? false
                if isViewOnce {
                    fireIconView.isHidden = true
                }
            }
            super.setProgress(progress)
        }

        override open func didHideProgressView() {
            super.didHideProgressView()

            // Show viewOnce fire icon again after upload/download completes
            let isViewOnce = data.ownerMessage?.isViewOnceMessage ?? false
            fireIconView.isHidden = !isViewOnce
        }

        override open func update(status: ChatMessage.Attachment.TransferStatus) {
            super.update(status: status)

            // Hide fire icon when showing download/upload icons
            switch status {
            case .pauseDownloading, .failedDownloading, .pauseUploading, .failedUploading:
                fireIconView.isHidden = true
            default:
                let isViewOnce = data.ownerMessage?.isViewOnceMessage ?? false
                fireIconView.isHidden = !isViewOnce
            }
        }

        func play(onPlayed: (_ url: URL) -> Void) {
            guard let fileUrl = data.attachment.fileUrl else { return }

            switch state {
            case .stopped:
                state = .playing
                SimpleSinglePlayer.play(fileUrl, id: data.attachment.playerId, durationBlock: setDuration, stopBlock: stop)
                SimpleSinglePlayer.setPauseBlock { [weak self] in self?.state = .paused }
                setPlayerSpeed(speed)
                onPlayed(fileUrl)
            case .playing:
                SimpleSinglePlayer.setPauseBlock(nil)
                state = .paused
                SimpleSinglePlayer.pause()
            case .paused:
                state = .playing
                SimpleSinglePlayer.play(fileUrl, id: data.attachment.playerId, durationBlock: setDuration, stopBlock: stop)
                SimpleSinglePlayer.setPauseBlock { [weak self] in self?.state = .paused }
                setPlayerSpeed(speed)
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
        
        func setPlayerSpeed(_ playerSpeed: Speed) {
            // Guard against nil data (can happen during setup before data is assigned)
            guard let fileUrl = data?.attachment.fileUrl else { return }

            switch playerSpeed {
            case .x1:
                SimpleSinglePlayer.setRate(1, for: data.attachment.playerId)
            case .x1_5:
                SimpleSinglePlayer.setRate(1.5, for: data.attachment.playerId)
            case .x2:
                SimpleSinglePlayer.setRate(2, for: data.attachment.playerId)
            }
        }
        
        func setDuration(duration: TimeInterval, progress: Double) {
            displayDuration = duration
            audioWaveformView.progress = progress
        }
    }
}
