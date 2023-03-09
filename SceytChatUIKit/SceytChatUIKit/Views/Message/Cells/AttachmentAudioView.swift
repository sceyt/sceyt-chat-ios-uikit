//
//  AttachmentAudioView.swift
//  SceytChatUIKit
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
                    playPauseButton.image = Images.audioPlayerPlay
                    waveformView.progress = 0
                case .paused:
                    playPauseButton.image = Images.audioPlayerPlay
                case .playing:
                    playPauseButton.image = Images.audioPlayerPause
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
                    player?.rate = 1
                case .x1_5:
                    player?.rate = 1.5
                case .x2:
                    player?.rate = 2
                }
                if state != .playing {
                    player?.pause()
                }
                speedLabel.text = speed.rawValue + "x"
            }
        }
        
        private var player: AVPlayer?
        
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
                
        private lazy var row = UIStackView(row: playPauseButton, UIStackView(column: waveformRow, durationLabel, spacing: 3), spacing: 12, alignment: .center)
        
        override open func setupAppearance() {
            super.setupAppearance()

            backgroundColor = .clear
            layer.cornerRadius = 16
            layer.masksToBounds = true
            
            playPauseButton.image = Images.audioPlayerPlay
            
            speedLabel.backgroundColor = .white
            speedLabel.layer.cornerRadius = 10
            speedLabel.layer.masksToBounds = true
            speedLabel.font = Fonts.semiBold.withSize(12)
            speedLabel.textColor = .init(light: Colors.textGray, dark: .white)
            speedLabel.textAlignment = .center
            
            durationLabel.font = Fonts.regular.withSize(11)
            durationLabel.textColor = Colors.textGray
            
            imageView.clipsToBounds = true
            
            progressView.backgroundColor = .kitBlue
            progressView.contentInsets = .init(top: 4, left: 4, bottom: 4, right: 4)
            progressView.trackColor = .white.withAlphaComponent(0.3)
            progressView.progressColor = .white
        }
        
        override open func setup() {
            super.setup()
            
            speedButton.addTarget(self, action: #selector(onTapSpeed), for: .touchUpInside)
            
            speed = .x1
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            addSubview(row.withoutAutoresizingMask)
            row.pin(to: self, anchors: [.leading(10), .trailing(0), .top(6)])
            waveformView.resize(anchors: [.height(20)])
            speedLabel.resize(anchors: [.height(20), .width(30)])
            
            speedButton.addSubview(speedLabel.withoutAutoresizingMask)
            speedLabel.pin(to: speedButton, anchors: [.leading(10), .trailing(-10), .top(0), .bottom(0)])
            
            playPauseButton.resize(anchors: [.width(40), .height(40)])

            addSubview(progressView)
            addSubview(pauseButton)
                        
            progressView.resize(anchors: [.width(40), .height(40)])
            progressView.pin(to: playPauseButton, anchors: [.centerX, .centerY])
            pauseButton.pin(to: progressView)
        }
        
        override open var data: ChatMessage.Attachment! {
            didSet {
                waveformView.data = data.voiceDecodedMetadata?.thumbnail.map { Float($0) }
                displayDuration = Double(data.voiceDecodedMetadata?.duration ?? 0)
            }
        }
        
        private var displayDuration = 0.0 {
            didSet {
                durationLabel.text = Formatters.videoAssetDuration.format(displayDuration)
            }
        }
        
        func play() {
            switch state {
            case .stopped:
                state = .playing
                
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)
                    let mimeType = "audio/mp4"
                    let asset = AVURLAsset(url: data.originUrl, options: ["AVURLAssetOutOfBandMIMETypeKey": mimeType])
                    let playerItem = AVPlayerItem(asset: asset)
                    player = AVPlayer(playerItem: playerItem)
                    player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: Int32(NSEC_PER_SEC)), queue: DispatchQueue.main) { [weak self] _ in
                        guard let self else { return }
                        if self.player?.currentItem?.status == .readyToPlay {
                            let duration = CMTimeGetSeconds(playerItem.duration)
                            self.displayDuration = max(0, CMTimeGetSeconds(self.player!.currentTime()))
                            self.waveformView.progress = self.displayDuration / duration
                            if self.displayDuration >= duration {
                                self.player?.pause()
                                self.state = .stopped
                            }
                        }
                    }
                    player?.seek(to: .zero)
                    player?.playImmediately(atRate: Float(speed.rawValue) ?? 1)
                } catch {
                    debugPrint(error)
                }
            case .playing:
                state = .paused
                player?.pause()
            case .paused:
                state = .playing
                player?.play()
            }
        }
        
        func stop() {
            state = .stopped
            player?.pause()
            player?.seek(to: .zero)
            player = nil
            displayDuration = Double(data.voiceDecodedMetadata?.duration ?? 0)
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
    }
}
