//
//  ComposerVC+ActionView.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import AVFoundation
import UIKit

extension ComposerVC {
    open class ActionView: View {
        public lazy var appearance = ComposerVC.appearance {
            didSet {
                setupAppearance()
            }
        }

        open lazy var iconView = UIImageView()
            .withoutAutoresizingMask
            .contentHuggingPriorityH(.required)

        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.required)

        open lazy var messageLabel = UILabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.required)
        
        open lazy var imageView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFill)
        
        open lazy var mediaTimestampLabel = ComposerVC.ThumbnailView.TimeLabel()
            .withoutAutoresizingMask

        open lazy var cancelButton = UIButton()
            .withoutAutoresizingMask
        
        open lazy var contentStackView = UIStackView()
            .withoutAutoresizingMask
        
        override open func setup() {
            super.setup()
            
            let s1 = UIStackView(arrangedSubviews: [iconView, titleLabel])
                .withoutAutoresizingMask
            s1.axis = .horizontal
            s1.spacing = 4
            s1.distribution = .fillProportionally
            s1.alignment = .center
            
            let s2 = UIStackView(arrangedSubviews: [s1, messageLabel])
                .withoutAutoresizingMask
            s2.axis = .vertical
            s2.spacing = 5
            s2.distribution = .fillProportionally
            contentStackView.addArrangedSubview(imageView)
            contentStackView.addArrangedSubview(s2)
            contentStackView.axis = .horizontal
            contentStackView.spacing = 8
            contentStackView.distribution = .fillProportionally
            
            titleLabel.textAlignment = .left
            titleLabel.lineBreakMode = .byTruncatingTail

            messageLabel.textAlignment = .left
            messageLabel.lineBreakMode = .byTruncatingTail
            imageView.isHidden = true
            imageView.clipsToBounds = true
            mediaTimestampLabel.isHidden = true
            cancelButton.setImage(Images.replyX, for: .normal)
        }

        override open func setupLayout() {
            super.setupLayout()

            addSubview(contentStackView)
            addSubview(cancelButton)
            addSubview(mediaTimestampLabel)

            contentStackView.pin(to: self, anchors: [.leading(4), .top(13), .bottom(-11), .trailing(0, .lessThanOrEqual)])
            imageView.widthAnchor.pin(to: imageView.heightAnchor)
            cancelButton.pin(to: self, anchors: [.trailing(-12), .centerY()])
            cancelButton.resize(anchors: [.width(20), .height(20)])
            messageLabel.trailingAnchor.pin(to: cancelButton.leadingAnchor, constant: -8)
            mediaTimestampLabel.pin(to: imageView, anchors: [.leading(4), .bottom(-4), .trailing(0, .lessThanOrEqual)])
        }

        override open func setupAppearance() {
            super.setupAppearance()
            
            imageView.layer.cornerRadius = 4
            imageView.layer.masksToBounds = true
            
            titleLabel.textColor = appearance.actionReplyTitleColor
            titleLabel.font = appearance.actionReplyTitleFont
            
            messageLabel.textColor = appearance.actionMessageColor
            messageLabel.font = appearance.actionMessageFont
            
//            titleLabel.leadingAnchor.pin(to: iconView.trailingAnchor, constant: 4)
//            titleLabel.topAnchor.pin(to: iconView.topAnchor)
//            titleLabel.trailingAnchor.pin(lessThanOrEqualTo: cancelButton.leadingAnchor, constant: -10)
//
//            messageLabel.leadingAnchor.pin(to: iconView.leadingAnchor)
//            messageLabel.topAnchor.pin(to: titleLabel.bottomAnchor)
//            messageLabel.trailingAnchor.pin(lessThanOrEqualTo: cancelButton.leadingAnchor, constant: -10)
//            messageLabel.bottomAnchor.pin(to: bottomAnchor, constant: 1)
        }
        
        override open func layoutSubviews() {
            super.layoutSubviews()
        }
    }
    
    class MiniAudioPlayerView: View {
        public lazy var appearance = ComposerVC.appearance {
            didSet {
                setupAppearance()
            }
        }

        enum State {
            case playing, stopped, paused
        }
        
        var state = State.stopped {
            didSet {
                switch state {
                case .stopped:
                    button.setImage(Images.audioPlayerPlayGrey, for: [])
                    waveformView.progress = 0
                    displayDuration = 0
                    player?.seek(to: .zero)
                case .paused:
                    button.setImage(Images.audioPlayerPlayGrey, for: [])
                case .playing:
                    button.setImage(Images.audioPlayerPauseGrey, for: [])
                }
            }
        }
        
        private var playerItem: AVPlayerItem?
        private var player: AVPlayer?
        
        private let button = {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            return $0
        }(UIButton())
        
        private let waveformView = WaveformView()
        
        private lazy var durationLabel = {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            $0.textAlignment = .right
            return $0
        }(UILabel())
        
        private lazy var row = {
            $0.setCustomSpacing(12, after: button)
            return $0
        }(UIStackView(row: button, waveformView, durationLabel))
        
        private let bg = UIView()
        
        override func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.recorderBackgroundColor
            layer.cornerRadius = 16
            layer.masksToBounds = true
            
            bg.backgroundColor = appearance.recorderPlayerBackgroundColor
            bg.layer.cornerRadius = 18
            bg.layer.masksToBounds = true
            
            durationLabel.font = appearance.recorderDurationFont
            durationLabel.textColor = appearance.recorderDurationColor
            
            button.setImage(Images.audioPlayerPlayGrey, for: [])
        }
        
        override func setup() {
            super.setup()
            
            button.addTarget(self, action: #selector(onTapPlay), for: .touchUpInside)
        }
        
        override func setupLayout() {
            super.setupLayout()
            
            addSubview(bg.withoutAutoresizingMask)
            bg.pin(to: self)
            
            addSubview(row.withoutAutoresizingMask)
            row.pin(to: self, anchors: [.leading(12), .trailing(-12), .top(8), .bottom(-8)])
            
            waveformView.resize(anchors: [.height(20)])
            durationLabel.resize(anchors: [.width(38)])
        }
        
        private var displayDuration = 0.0 {
            didSet {
                durationLabel.text = Formatters.videoAssetDuration.format(displayDuration)
            }
        }
        
        @discardableResult
        func setup(url: URL, metadata: ChatMessage.Attachment.Metadata<[Int]>) -> Self {
            waveformView.progress = 0
            waveformView.data = metadata.thumbnail.map { Float($0) }
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                playerItem = AVPlayerItem(url: url)
                player = AVPlayer(playerItem: playerItem)
                player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: Int32(NSEC_PER_SEC)), queue: DispatchQueue.main) { [weak self] _ in
                    guard let self else { return }
                    if self.player?.currentItem?.status == .readyToPlay {
                        let duration = CMTimeGetSeconds(self.playerItem!.duration)
                        self.displayDuration = max(0, CMTimeGetSeconds(self.player!.currentTime()))
                        self.waveformView.progress = self.displayDuration / duration
                        if self.displayDuration >= duration {
                            self.player?.pause()
                            self.state = .stopped
                        }
                    }
                }
                displayDuration = CMTimeGetSeconds(playerItem!.asset.duration)
            } catch {
                print(error.localizedDescription)
                displayDuration = 0
            }
            return self
        }
        
        @objc
        private func onTapPlay() {
            switch state {
            case .stopped:
                displayDuration = 0.0
                player?.seek(to: .zero)
                play()
            case .playing:
                pause()
            case .paused:
                play()
            }
        }
        
        func play() {
            state = .playing
            player?.play()
        }
        
        func pause() {
            state = .paused
            player?.pause()
        }
    }
        
    open class RecorderView: View {
        public lazy var appearance = ComposerVC.appearance {
            didSet {
                setupAppearance()
            }
        }

        enum Event {
            case
                noPermission,
                send(URL, ChatMessage.Attachment.Metadata<[Int]>)
        }
        
        let onEvent: (Event) -> Void
        
        enum State {
            case unlock, lock, locked, cancel, recorded
        }
        
        private var state = State.unlock {
            didSet {
                UIView.transition(with: lockButton, duration: 0.2, options: .transitionCrossDissolve) { [weak self] in
                    guard let self else { return }
                    switch self.state {
                    case .unlock:
                        self.lockButton.setImage(Images.audioPlayerUnlock, for: [])
                        self.micButton.setImage(Images.audioPlayerMicGreen, for: [])
                    case .lock:
                        self.lockButton.setImage(Images.audioPlayerLock, for: [])
                        self.micButton.setImage(Images.audioPlayerMicGreen, for: [])
                    case .locked:
                        self.lockButton.setImage(Images.audioPlayerStop, for: [])
                        self.micButton.setImage(Images.audioPlayerSendLarge, for: [])
                    case .cancel:
                        self.lockButton.setImage(nil, for: [])
                        self.micButton.setImage(Images.audioPlayerDelete, for: [])
                    case .recorded:
                        self.lockButton.setImage(Images.audioPlayerUnlock, for: [])
                        self.micButton.setImage(Images.audioPlayerMicGreen, for: [])
                        
                        if let recorder = self.recorder {
                            recorder.stopRecording()
                            let metadata = recorder.metadata
                            self.recordedView.setup(url: recorder.url, metadata: metadata)
                        }
                    }
                    self.lockButton.isHidden = self.state == .recorded
                    self.micButton.isHidden = self.state == .recorded
                    self.slidingView.isHidden = self.state == .recorded
                    self.recordedView.isHidden = self.state != .recorded
                }
            }
        }
        
        private var recorder: AudioRecorder?

        private let lockButton = UIButton()
        
        private let micButton = UIButton()
        
        private lazy var slidingView = SlidingView { [weak self] in
            self?.reset(animated: false)
        }
        
        private lazy var recordedView = RecordedView()
        
        init(onEvent: @escaping ((Event) -> Void)) {
            self.onEvent = onEvent
            super.init(frame: UIScreen.main.bounds)
            
            recordedView.onEvent = { [weak self] in
                guard let self else { return }
                switch $0 {
                case .cancel:
                    self.reset(animated: false)
                case .send:
                    self.reset(animated: false)
                    self.onEvent(.send(self.recorder!.url, self.recorder!.metadata))
                }
            }
        }
        
        @available(*, unavailable)
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let view = super.hitTest(point, with: event)
            guard view != self else { return nil }
            return view
        }
        
        private var startCenter: CGPoint?
        private var currentCenter: CGPoint?
        
        @objc
        func onLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard
                let window = UIApplication.shared.windows.last,
                let gestureView = gesture.view,
                state != .locked
            else { return }
            
            switch gesture.state {
            case .began:
                let recordingSession = AVAudioSession.sharedInstance()
                switch recordingSession.recordPermission {
                case .granted:
                    startRecording(window: window, gestureView: gestureView)
                case .undetermined:
                    recordingSession.requestRecordPermission { [weak self] allowed in
                        DispatchQueue.main.async { [weak self] in
                            if !allowed {
                                self?.onEvent(.noPermission)
                            }
                        }
                    }
                default:
                    onEvent(.noPermission)
                }
            case .changed:
                guard let startCenter else { return }
                
                let gestureLocation = gesture.location(in: self)
                let xDelta = startCenter.x - gestureLocation.x
                let yDelta = startCenter.y - gestureLocation.y
                if currentCenter!.y > startCenter.y || yDelta > xDelta {
                    currentCenter = .init(x: startCenter.x, y: min(startCenter.y, max(startCenter.y - 100, gestureLocation.y)))
                    if currentCenter!.y < startCenter.y - 40 {
                        if state != .lock {
                            state = .lock
                        }
                        if currentCenter!.y <= startCenter.y - 100 {
                            gesture.isEnabled = false
                            gesture.isEnabled = true
                        }
                    } else if state != .unlock {
                        state = .unlock
                        slidingView.state = .unlock
                    }
                } else {
                    currentCenter = .init(x: min(gestureLocation.x, startCenter.x), y: startCenter.y)
                    if currentCenter!.x <= startCenter.x - micButton.width * 1.5 {
                        if state != .cancel {
                            state = .cancel
                            slidingView.state = .delete
                        }
                        if currentCenter!.x <= slidingView.convert(slidingView.slideButton.center, to: self).x {
                            gesture.isEnabled = false
                            gesture.isEnabled = true
                        }
                    } else if state != .unlock {
                        state = .unlock
                        slidingView.state = .unlock
                    }
                }
                updateCenter()
            case .ended:
                endLongPress()
            default:
                endLongPress()
            }
        }
        
        private func startRecording(window: UIWindow, gestureView: UIView) {
            UIView.performWithoutAnimation {
                alpha = 1
                translatesAutoresizingMaskIntoConstraints = false
                window.addSubview(withoutAutoresizingMask)
                pin(to: window)
                
                let top = gestureView.convert(CGPoint.zero, to: self).y
                
                addSubview(slidingView.withoutAutoresizingMask)
                addSubview(lockButton.withoutAutoresizingMask)
                addSubview(micButton.withoutAutoresizingMask)
                addSubview(recordedView.withoutAutoresizingMask)
                
                state = .unlock
                slidingView.state = .unlock
                
                lockButton.bottomAnchor.pin(to: micButton.topAnchor, constant: 16)
                lockButton.centerXAnchor.pin(to: micButton.centerXAnchor)
                micButton.pin(to: self, anchors: [.trailing(9), .top(top)])
                slidingView.pin(to: self, anchors: [.leading(), .trailing(), .top(top)])
                recordedView.pin(to: slidingView)
                recordedView.isHidden = true
                startCenter = gestureView.convert(.init(x: gestureView.width / 2, y: gestureView.height / 2), to: self)
                currentCenter = startCenter
                
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString).m4a")
                recorder = AudioRecorder(url: url) { [weak self] in
                    guard let self else { return }
                    switch $0 {
                    case .durationChanged(let duration):
                        self.slidingView.duration = duration
                    case .reset:
                        self.slidingView.duration = 0
                        self.reset()
                    case .noPermission:
                        self.onEvent(.noPermission)
                    case .start:
                        self.slidingView.startAnimating()
                    case .stopped:
                        self.slidingView.duration = 0
                    }
                }
                recorder?.startRecording()
            }
        }
        
        private func endLongPress(animated: Bool = true) {
            if state == .lock {
                currentCenter = nil
                state = .locked
                slidingView.state = .locked
                
                UIView.animate(withDuration: 0.2) { [weak self] in
                    guard let self else { return }
                    self.setNeedsLayout()
                    self.layoutIfNeeded()
                }
            } else if state == .cancel || recorder == nil || recorder!.metadata.duration < 1 {
                reset(animated: animated)
            } else if state != .recorded {
                reset(animated: animated)
                onEvent(.send(recorder!.url, recorder!.metadata))
            }
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = .clear
        }
        
        override open func setup() {
            super.setup()
            
            lockButton.addTarget(self, action: #selector(onTapStop), for: .touchUpInside)
            micButton.addTarget(self, action: #selector(onTapSend), for: .touchUpInside)
        }
        
        override open func layoutSubviews() {
            super.layoutSubviews()
            updateCenter()
        }
        
        private func updateCenter() {
            guard let currentCenter
            else { return }
            micButton.center = currentCenter
            lockButton.center.y = micButton.center.y - (micButton.height + lockButton.height) / 2 + 16
        }
        
        private func reset(animated: Bool = true) {
            recorder?.stopRecording()
            
            if animated, let startCenter {
                UIView.animate(withDuration: 0.2) { [weak self] in
                    guard let self else { return }
                    self.alpha = 0
                    self.currentCenter = startCenter
                    self.updateCenter()
                } completion: { [weak self] _ in
                    self?.dismiss()
                }
            } else {
                dismiss()
            }
        }
        
        private func dismiss() {
            state = .unlock
            recordedView.pause()
            startCenter = nil
            currentCenter = nil
            lockButton.removeFromSuperview()
            micButton.removeFromSuperview()
            slidingView.removeFromSuperview()
            recordedView.removeFromSuperview()
            removeFromSuperview()
        }
        
        @objc
        private func onTapStop() {
            state = .recorded
        }
        
        @objc
        private func onTapSend() {
            reset(animated: false)
            onEvent(.send(recorder!.url, recorder!.metadata))
        }
        
        func stop() {
            state = .cancel
            recorder?.stopRecording()
            recordedView.pause()
        }
        
        open func stopAndPreview() {
            state = .recorded
        }
    }
    
    private class SlidingView: View {
        public lazy var appearance = ComposerVC.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        let onCancel: () -> Void
        var duration: Double = 0.0 {
            didSet {
                durationLabel.text = Formatters.videoAssetDuration.format(duration)
            }
        }
        
        enum State {
            case unlock, locked, delete
        }
        
        var state = State.unlock {
            didSet {
                UIView.performWithoutAnimation {
                    switch state {
                    case .unlock:
                        slideButton.setAttributedTitle(.init(
                            string: L10n.Recorder.slideToCancel, attributes: [
                                .font: appearance.recorderSlideToCancelFont,
                                .foregroundColor: appearance.recorderSlideToCancelColor
                            ]
                        ), for: [])
                    case .locked:
                        slideButton.setAttributedTitle(.init(
                            string: L10n.Recorder.cancel, attributes: [
                                .font: appearance.recorderCancelFont,
                                .foregroundColor: appearance.recorderCancelColor
                            ]
                        ), for: [])
                    case .delete:
                        slideButton.setAttributedTitle(nil, for: [])
                    }
                    slideButton.layoutIfNeeded()
                }
            }
        }
        
        private let line = UIView()
        
        private let dotView = DotView()
        private lazy var durationLabel = {
            $0.text = "0:00"
            return $0
        }(UILabel())

        fileprivate let slideButton = UIButton()
        
        private lazy var row = UIStackView(row: dotView, durationLabel, spacing: 8, alignment: .center)
        
        init(frame: CGRect = .zero, onCancel: @escaping (() -> Void)) {
            self.onCancel = onCancel
            super.init(frame: frame)
            
            state = .unlock
        }
        
        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.recorderBackgroundColor
            line.backgroundColor = Colors.background4
            durationLabel.font = appearance.recorderRecordingDurationFont
            durationLabel.textColor = appearance.recorderRecordingDurationColor
        }
        
        override func setup() {
            super.setup()
            
            slideButton.addTarget(self, action: #selector(onTapCancel), for: .touchUpInside)
        }
        
        override func setupLayout() {
            super.setupLayout()
            
            addSubview(line.withoutAutoresizingMask)
            
            line.pin(to: self, anchors: [.top, .leading, .trailing])
            line.resize(anchors: [.height(0.5)])
            
            addSubview(row.withoutAutoresizingMask)
            addSubview(slideButton.withoutAutoresizingMask)
            row.pin(to: self, anchors: [.leading(12), .top(16)])
            resize(anchors: [.height(52)])
            slideButton.centerXAnchor.pin(to: centerXAnchor)
            slideButton.centerYAnchor.pin(to: row.centerYAnchor)
            
            dotView.resize(anchors: [.height(8), .width(8)])
        }
        
        @objc
        private func onTapCancel() {
            onCancel()
        }
        
        func startAnimating() {
            dotView.startAnimating()
        }
    }
    
    private class DotView: View {
        public lazy var appearance = ComposerVC.appearance {
            didSet {
                setupAppearance()
            }
        }

        override func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.recorderRecordingDotColor
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            layer.cornerRadius = height / 2
        }
        
        func startAnimating() {
            UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseInOut, .repeat, .autoreverse], animations: { [weak self] in
                self?.alpha = self?.alpha == 1 ? 0 : 1
            })
        }
    }
    
    private class RecordedView: View {
        public lazy var appearance = ComposerVC.appearance {
            didSet {
                setupAppearance()
            }
        }

        enum Event {
            case send, cancel
        }
        
        var onEvent: ((Event) -> Void)?
        
        private let line = UIView()

        private let cancelButton = {
            $0.setImage(Images.audioPlayerCancel, for: [])
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            return $0
        }(UIButton())
        
        private let audioPlayerView = MiniAudioPlayerView()
        
        private let sendButton = {
            $0.setImage(Images.audioPlayerSend, for: [])
            $0.imageView?.contentMode = .scaleAspectFit
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            return $0
        }(UIButton())
        
        private lazy var row = UIStackView(row: cancelButton, audioPlayerView, sendButton, spacing: 8)
        
        override func setupAppearance() {
            super.setupAppearance()
            
            line.backgroundColor = Colors.background4
            backgroundColor = appearance.recorderBackgroundColor
        }
        
        override func setup() {
            super.setup()
            
            cancelButton.addTarget(self, action: #selector(onTapCancel), for: .touchUpInside)
            sendButton.addTarget(self, action: #selector(onTapSend), for: .touchUpInside)
        }
        
        override func setupLayout() {
            super.setupLayout()
            
            addSubview(line.withoutAutoresizingMask)
            
            line.pin(to: self, anchors: [.top, .leading, .trailing])
            line.resize(anchors: [.height(0.5)])
            
            addSubview(row.withoutAutoresizingMask)
            
            row.pin(to: self, anchors: [.leading(8), .trailing(-8), .top(8), .bottom(-8)])
            
            sendButton.resize(anchors: [.height(32), .width(32)])
        }
        
        func setup(url: URL, metadata: ChatMessage.Attachment.Metadata<[Int]>) {
            audioPlayerView.setup(url: url, metadata: metadata)
        }
        
        @objc
        private func onTapCancel() {
            onEvent?(.cancel)
        }
        
        @objc
        private func onTapSend() {
            onEvent?(.send)
        }
        
        func pause() {
            audioPlayerView.pause()
        }
    }
}
