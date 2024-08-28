//
//  ComposerVC+RecorderView.swift
//  SceytChatUIKit
//
//  Created by Duc on 19/03/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import AVFoundation
import UIKit

extension ComposerVC {
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
            
            button.setImage(.audioPlayerPlayGrey, for: [])
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
        
        private var displayDuration: Double = 0 {
            didSet {
                durationLabel.text = Formatters.videoAssetDuration.format(displayDuration)
            }
        }
        
        private var url: URL?
        @discardableResult
        func setup(url: URL, metadata: ChatMessage.Attachment.Metadata<[Int]>) -> Self {
            self.url = url
            
            waveformView.progress = 0
            waveformView.data = metadata.thumbnail.map { Float($0) }
            displayDuration = CMTimeGetSeconds(AVPlayerItem(url: url).asset.duration)
            return self
        }
        
        func setDuration(duration: Double, progress: Double) {
            displayDuration = duration
            waveformView.progress = progress
        }
        
        @objc
        private func onTapPlay() {
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
        
        func play() {
            guard let url
            else { return stop() }
            
            state = .playing
            SimpleSinglePlayer.play(url, durationBlock: setDuration, stopBlock: stop)
        }
        
        func pause() {
            state = .paused
            SimpleSinglePlayer.pause()
        }
        
        func stop() {
            state = .stopped
            displayDuration = 0
            waveformView.progress = 0
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
                recorded(url: URL, metadata: ChatMessage.Attachment.Metadata<[Int]>),
                send(URL, ChatMessage.Attachment.Metadata<[Int]>),
                didStartRecording, didStopRecording
        }
        
        let onEvent: (Event) -> Void
        
        enum State {
            case unlock, lock, locked, cancel, recorded
        }
        
        private var state = State.unlock {
            didSet {
                setState(state, animated: true)
            }
        }
        
        private func setState(_ state: State, animated: Bool = true) {
            if self.state != state { self.state = state }
            UIView.transition(with: lockButton,
                              duration: animated ? 0.2 : 0,
                              options: .transitionCrossDissolve)
            { [weak self] in
                guard let self else { return }
                switch state {
                case .unlock:
                    var lockImage = UIImage.audioPlayerUnlock
                    if ComposerVC.Layouts.recorderShadowBlur > 0 {
                        lockImage = Components.imageBuilder.addShadow(to: lockImage, blur: ComposerVC.Layouts.recorderShadowBlur)
                    }
                    self.lockButton.setImage(lockImage, for: [])
                    self.micButton.setImage(.audioPlayerMicGreen, for: [])
                case .lock:
                    var lockImage = UIImage.audioPlayerLock
                    if ComposerVC.Layouts.recorderShadowBlur > 0 {
                        lockImage = Components.imageBuilder.addShadow(to: lockImage, blur: ComposerVC.Layouts.recorderShadowBlur)
                    }
                    self.lockButton.setImage(lockImage, for: [])
                    self.micButton.setImage(.audioPlayerMicGreen, for: [])
                case .locked:
                    var lockImage = UIImage.audioPlayerStop
                    if ComposerVC.Layouts.recorderShadowBlur > 0 {
                        lockImage = Components.imageBuilder.addShadow(to: lockImage, blur: ComposerVC.Layouts.recorderShadowBlur)
                    }
                    self.lockButton.setImage(lockImage, for: [])
                    self.micButton.setImage(.audioPlayerSendLarge, for: [])
                case .cancel:
                    self.lockButton.setImage(nil, for: [])
                    self.micButton.setImage(.audioPlayerDelete, for: [])
                case .recorded:
                    var lockImage = UIImage.audioPlayerUnlock
                    if ComposerVC.Layouts.recorderShadowBlur > 0 {
                        lockImage = Components.imageBuilder.addShadow(to: lockImage, blur: ComposerVC.Layouts.recorderShadowBlur)
                    }
                    self.lockButton.setImage(lockImage, for: [])
                    self.micButton.setImage(.audioPlayerMicGreen, for: [])
                    
                    if let recorder = self.recorder,
                       recorder.audioRecorder?.isRecording == true
                    {
                        recorder.stopRecording()
                        let metadata = recorder.metadata
                        self.onEvent(.recorded(url: recorder.url, metadata: metadata))
                    }
                    self.dismiss()
                }
                self.lockButton.isHidden = self.state == .recorded
                self.micButton.isHidden = self.state == .recorded
                self.slidingView.isHidden = self.state == .recorded
            }
        }
        
        public var recorder: AudioRecorder?
        
        private let lockButton = UIButton()
        
        private let micButton = UIButton()
        
        private lazy var slidingView = SlidingView { [weak self] in
            self?.reset(animated: false)
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        init(onEvent: @escaping ((Event) -> Void)) {
            self.onEvent = onEvent
            super.init(frame: UIScreen.main.bounds)
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didEnterBackgroundNotification),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
        }
        
        @available(*, unavailable)
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc func didEnterBackgroundNotification(_ n: Notification) {
            stopAndPreview()
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
            SimpleSinglePlayer.pause()
            
            guard state != .locked
            else { return }
            
            switch gesture.state {
            case .began:
                let recordPermission = Components.audioSession.recordPermission
                switch recordPermission {
                case .granted:
                    startRecording(gesture: gesture)
                case .undetermined:
                    Components.audioSession.requestRecordPermission { [weak self] allowed in
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
        
        private func startRecording(gesture: UILongPressGestureRecognizer) {
            guard
                let gestureView = gesture.view,
                let window = gestureView.window
            else { return }
            UIView.performWithoutAnimation {
                alpha = 1
                translatesAutoresizingMaskIntoConstraints = false
                window.addSubview(withoutAutoresizingMask)
                pin(to: window)
                                
                addSubview(slidingView.withoutAutoresizingMask)
                addSubview(lockButton.withoutAutoresizingMask)
                addSubview(micButton.withoutAutoresizingMask)
                
                setState(.unlock, animated: false)
                slidingView.state = .unlock
                
                lockButton.bottomAnchor.pin(to: micButton.topAnchor, constant: -8 + ComposerVC.Layouts.recorderShadowBlur)
                lockButton.centerXAnchor.pin(to: micButton.centerXAnchor)
                micButton.pin(to: self, anchors: [.trailing(9)])
                micButton.centerYAnchor.pin(to: gestureView.centerYAnchor)
                slidingView.pin(to: self, anchors: [.leading(), .trailing()])
                slidingView.topAnchor.pin(to: gestureView.topAnchor)
                startCenter = gestureView.convert(.init(x: gestureView.width / 2, y: gestureView.height / 2), to: self)
                currentCenter = startCenter
                
                window.layoutIfNeeded() // fix: Bad animation of audio recording icon
                
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString).m4a")
                recorder = AudioRecorder(url: url) { [weak self] in
                    guard let self else { return }
                    switch $0 {
                    case .durationChanged(let duration):
                        self.slidingView.duration = duration
                    case .reset:
                        self.slidingView.stopAnimating()
                        self.slidingView.duration = 0
                        self.reset()
                    case .noPermission:
                        self.slidingView.stopAnimating()
                        self.onEvent(.noPermission)
                    case .start:
                        self.slidingView.startAnimating()
                    case .stopped:
                        self.slidingView.stopAnimating()
                        self.slidingView.duration = 0
                        self.onEvent(.didStopRecording)
                    }
                }
                recorder?.startRecording()
                onEvent(.didStartRecording)
            }
        }
        
        private func endLongPress(animated: Bool = true) {
            if state == .lock {
                currentCenter = nil
                state = .locked
                slidingView.state = .locked
                
                impactFeebackGenerator.impactOccurred()
                
                UIView.animate(withDuration: 0.25) { [weak self] in
                    guard let self else { return }
                    self.setNeedsLayout()
                    self.layoutIfNeeded()
                }
            } else if state == .cancel || recorder == nil || recorder!.metadata.duration < 1 {
                impactFeebackGenerator.impactOccurred()
                reset(animated: animated)
            } else if state != .recorded, superview != nil {
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
            
            impactFeebackGenerator.prepare()
            lockButton.addTarget(self, action: #selector(onTapStop), for: .touchUpInside)
            micButton.addTarget(self, action: #selector(onTapSend), for: .touchUpInside)
        }
        
        override open func layoutSubviews() {
            super.layoutSubviews()
            updateCenter()
        }
        
        open lazy var impactFeebackGenerator = UIImpactFeedbackGenerator(style: .light)
        
        private func updateCenter() {
            guard let currentCenter
            else { return }
            micButton.center = currentCenter
            lockButton.bottom = micButton.top - 8 + ComposerVC.Layouts.recorderShadowBlur
        }
        
        private func reset(animated: Bool = true) {
            recorder?.stopRecording()
            
            if animated, let startCenter {
                UIView.animate(withDuration: 0.25) { [weak self] in
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
            startCenter = nil
            currentCenter = nil
            lockButton.removeFromSuperview()
            micButton.removeFromSuperview()
            slidingView.removeFromSuperview()
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
                                .font: appearance.recorderSlideToCancelFont as Any,
                                .foregroundColor: appearance.recorderSlideToCancelColor as Any
                            ]
                        ), for: [])
                    case .locked:
                        slideButton.setAttributedTitle(.init(
                            string: L10n.Recorder.cancel, attributes: [
                                .font: appearance.recorderCancelFont as Any,
                                .foregroundColor: appearance.recorderCancelColor as Any
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
            line.backgroundColor = appearance.dividerColor
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
        
        func stopAnimating() {
            dotView.stopAnimating()
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
        
        func stopAnimating() {
            layer.removeAnimation(forKey: "pulsating")
        }
        
        func startAnimating() {
            stopAnimating()
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 1
            animation.toValue = 0
            animation.duration = 0.5
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.isRemovedOnCompletion = false
            layer.add(animation, forKey: "pulsating")
        }
    }
    
    open class RecordedView: View {
        public lazy var appearance = ComposerVC.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        enum Event {
            case send(url: URL, metadata: ChatMessage.Attachment.Metadata<[Int]>), cancel
        }
        
        var onEvent: ((Event) -> Void)?
        
        private let cancelButton = {
            $0.setImage(.audioPlayerCancel, for: [])
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            return $0
        }(UIButton())
        
        private let audioPlayerView = MiniAudioPlayerView()
        
        private let sendButton = {
            $0.setImage(.messageSendAction, for: [])
            $0.imageView?.contentMode = .scaleAspectFit
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            return $0
        }(UIButton())
        
        private lazy var row = UIStackView(row: cancelButton, audioPlayerView, sendButton, spacing: 8)
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.recorderBackgroundColor
        }
        
        override open func setup() {
            super.setup()
            
            cancelButton.addTarget(self, action: #selector(onTapCancel), for: .touchUpInside)
            sendButton.addTarget(self, action: #selector(onTapSend), for: .touchUpInside)
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            addSubview(row.withoutAutoresizingMask)
            
            row.pin(to: self, anchors: [.leading(8), .trailing(-8), .top(8), .bottom(-8)])
            
            sendButton.resize(anchors: [.height(32), .width(32)])
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
