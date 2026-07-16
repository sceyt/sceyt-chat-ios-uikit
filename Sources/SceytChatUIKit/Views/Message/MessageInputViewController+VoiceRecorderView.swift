//
//  MessageInputViewController+VoiceRecorderView.swift
//  SceytChatUIKit
//
//  Created by Duc on 19/03/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import AVFoundation
import UIKit

extension MessageInputViewController {
    open class VoiceRecorderView: View {
        
        enum Event {
            case
                noPermission,
                recordingUnavailable,
                recorded(url: URL, metadata: ChatMessage.Attachment.Metadata<[Int]>, viewOnce: Bool),
                send(URL, ChatMessage.Attachment.Metadata<[Int]>, viewOnce: Bool),
                didStartRecording, didStopRecording
        }

        var onEvent: ((Event) -> Void)?
        
        open var minDuration: TimeInterval = 1.0

        enum State {
            case unlock, lock, locked, cancel, recorded
        }
        
        enum RecordingState {
            case idle, start, stop, process
        }

        private var isViewOnceEnabled: Bool = false {
            didSet {
                updateViewOnceButton()
            }
        }

        private var recordingEventTimer: Timer?

        private var state = State.unlock {
            didSet {
                setState(state, animated: true)
            }
        }
        
        private var recordingState: RecordingState = .idle
        
        private func setState(_ state: State, animated: Bool = true) {
            if self.state != state { self.state = state }
            UIView.transition(with: lockButton,
                              duration: animated ? 0.2 : 0,
                              options: .transitionCrossDissolve)
            { [weak self] in
                guard let self else { return }
                switch state {
                case .unlock:
                    var lockImage = appearance.unlockedIcon
                    if MessageInputViewController.Layouts.recorderShadowBlur > 0 {
                        lockImage = Components.imageBuilder.addShadow(to: lockImage, blur: MessageInputViewController.Layouts.recorderShadowBlur)
                    }
                    self.lockButton.setImage(lockImage, for: [])
                    self.micButton.setImage(appearance.recordingIcon, for: [])
                case .lock:
                    var lockImage = appearance.lockedIcon
                    if MessageInputViewController.Layouts.recorderShadowBlur > 0 {
                        lockImage = Components.imageBuilder.addShadow(to: lockImage, blur: MessageInputViewController.Layouts.recorderShadowBlur)
                    }
                    self.lockButton.setImage(lockImage, for: [])
                    self.micButton.setImage(appearance.recordingIcon, for: [])
                case .locked:
                    var lockImage = appearance.stopRecordingIcon
                    if MessageInputViewController.Layouts.recorderShadowBlur > 0 {
                        lockImage = Components.imageBuilder.addShadow(to: lockImage, blur: MessageInputViewController.Layouts.recorderShadowBlur)
                    }
                    self.lockButton.setImage(lockImage, for: [])
                    self.micButton.setImage(appearance.sendVoiceIcon, for: [])
                case .cancel:
                    self.lockButton.setImage(nil, for: [])
                    self.micButton.setImage(appearance.deleteRecordIcon, for: [])
                case .recorded:
                    var lockImage = appearance.unlockedIcon
                    if MessageInputViewController.Layouts.recorderShadowBlur > 0 {
                        lockImage = Components.imageBuilder.addShadow(to: lockImage, blur: MessageInputViewController.Layouts.recorderShadowBlur)
                    }
                    self.lockButton.setImage(lockImage, for: [])
                    self.micButton.setImage(appearance.recordingIcon, for: [])
                    
                    if let recorder = self.recorder,
                       recorder.audioRecorder?.isRecording == true
                    {
                        recorder.stopRecording()
                        let metadata = recorder.metadata
                        self.onEvent?(.recorded(url: recorder.url, metadata: metadata, viewOnce: isViewOnceEnabled))
                    }
                    self.dismiss()
                }
                self.lockButton.isHidden = self.state == .recorded
                self.micButton.isHidden = self.state == .recorded
                self.slidingView.isHidden = self.state == .recorded
                self.viewOnceButton.isHidden = self.state != .locked || !appearance.enableViewOnce
            }
        }
        
        public var recorder: AudioRecorder?

        private let lockButton = UIButton()

        private let micButton = UIButton()

        private let viewOnceButton = UIView()

        private let viewOnceImageView = UIImageView()

        private lazy var slidingView = SlidingView { [weak self] in
            self?.reset(animated: false)
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        public required init() {
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
        open func onLongPress(_ gesture: UILongPressGestureRecognizer) {
            SimpleSinglePlayer.pause()
            
            guard state != .locked
            else { return }
            
            switch gesture.state {
            case .began:
                isViewOnceEnabled = false
                let recordPermission = Components.audioSession.recordPermission
                switch recordPermission {
                case .granted:
                    startRecording(gesture: gesture)
                case .undetermined:
                    Components.audioSession.requestRecordPermission { [weak self] allowed in
                        DispatchQueue.main.async { [weak self] in
                            if !allowed {
                                self?.onEvent?(.noPermission)
                            }
                        }
                    }
                default:
                    onEvent?(.noPermission)
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
                addSubview(viewOnceButton.withoutAutoresizingMask)
                viewOnceButton.addSubview(viewOnceImageView.withoutAutoresizingMask)

                typealias RecorderAID = SceytChatUIKit.AccessibilityIdentifiers.MessageInput.Recorder
                accessibilityIdentifier = RecorderAID.root
                lockButton.accessibilityIdentifier = RecorderAID.lockButton
                micButton.accessibilityIdentifier = RecorderAID.micButton
                viewOnceButton.accessibilityIdentifier = RecorderAID.viewOnceButton
                slidingView.durationLabel.accessibilityIdentifier = RecorderAID.duration
                slidingView.slideButton.accessibilityIdentifier = RecorderAID.cancelButton

                setState(.unlock, animated: false)
                slidingView.state = .unlock

                lockButton.bottomAnchor.pin(to: micButton.topAnchor, constant: -8 + MessageInputViewController.Layouts.recorderShadowBlur)
                lockButton.centerXAnchor.pin(to: micButton.centerXAnchor)
                micButton.pin(to: self, anchors: [.trailing(9)])
                micButton.centerYAnchor.pin(to: gestureView.centerYAnchor)
                slidingView.pin(to: self, anchors: [.leading(), .trailing()])
                slidingView.topAnchor.pin(to: gestureView.topAnchor)
                viewOnceButton.bottomAnchor.pin(to: lockButton.topAnchor, constant: -8 + MessageInputViewController.Layouts.recorderShadowBlur)
                viewOnceButton.centerXAnchor.pin(to: lockButton.centerXAnchor)
                viewOnceButton.resize(anchors: [.width(42), .height(42)])
                viewOnceImageView.centerXAnchor.pin(to: viewOnceButton.centerXAnchor)
                viewOnceImageView.centerYAnchor.pin(to: viewOnceButton.centerYAnchor)
                viewOnceImageView.resize(anchors: [.width(24), .height(24)])
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
                        self.recordingState = .idle
                        self.slidingView.stopAnimating()
                        self.slidingView.duration = 0
                        self.reset()
                    case .noPermission:
                        self.recordingState = .idle
                        self.slidingView.stopAnimating()
                        self.onEvent?(.noPermission)
                    case .recordingUnavailable:
                        self.recordingState = .idle
                        self.slidingView.stopAnimating()
                        self.reset()
                        self.onEvent?(.recordingUnavailable)
                    case .start:
                        self.recordingState = .start
                        self.slidingView.startAnimating()
                        self.startSendingStartRecordingEvents()
                    case .stopped:
                        self.recordingState = .stop
                        self.slidingView.stopAnimating()
                        self.slidingView.duration = 0
                        self.onEvent?(.didStopRecording)
                    case .maxDurationReached:
                        self.stopAndPreview()
                    }
                }
                recorder?.startRecording()
                onEvent?(.didStartRecording)
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
            } else if state == .cancel || recorder == nil || TimeInterval(recorder?.metadata.duration ?? 0) < minDuration {
                impactFeebackGenerator.impactOccurred()
                reset(animated: animated)
            } else if state != .recorded, superview != nil {
                reset(animated: animated)
                onEvent?(.send(recorder!.url, recorder!.metadata, viewOnce: isViewOnceEnabled))
            }
        }
        
        override open func setupAppearance() {
            super.setupAppearance()

            backgroundColor = .clear
            slidingView.appearance = appearance
            viewOnceButton.backgroundColor = appearance.backgroundColor
            viewOnceButton.layer.cornerRadius = 21
            viewOnceButton.layer.shadowColor = UIColor.black.cgColor
            viewOnceButton.layer.shadowOffset = CGSize(width: 0, height: 2)
            viewOnceButton.layer.shadowOpacity = 0.1
            viewOnceButton.layer.shadowRadius = 4
            viewOnceImageView.contentMode = .scaleToFill
            updateViewOnceButton()
        }
        
        override open func setup() {
            super.setup()

            impactFeebackGenerator.prepare()
            lockButton.addTarget(self, action: #selector(onTapStop), for: .touchUpInside)
            micButton.addTarget(self, action: #selector(onTapSend), for: .touchUpInside)

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onTapViewOnce))
            viewOnceButton.addGestureRecognizer(tapGesture)
            viewOnceButton.isUserInteractionEnabled = true
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
            lockButton.bottom = micButton.top - 8 + MessageInputViewController.Layouts.recorderShadowBlur
            viewOnceButton.bottom = lockButton.top
        }
        
        private func startSendingStartRecordingEvents() {
            recordingEventTimer?.invalidate()

            recordingEventTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if self.recordingState == .start {
                    self.onEvent?(.didStartRecording)
                }
            }
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
            viewOnceButton.removeFromSuperview()
            slidingView.removeFromSuperview()
            removeFromSuperview()
        }
        
        @objc
        private func onTapStop() {
            state = .recorded
        }
        
        @objc
        private func onTapSend() {
            guard let recorder else { return }
            if TimeInterval(recorder.metadata.duration) < minDuration {
                reset(animated: false)
                return
            }
            reset(animated: false)
            onEvent?(.send(recorder.url, recorder.metadata, viewOnce: isViewOnceEnabled))
        }

        @objc
        private func onTapViewOnce() {
            isViewOnceEnabled.toggle()
        }

        private func updateViewOnceButton() {
            var buttonImage: UIImage = isViewOnceEnabled ? appearance.viewOnceActiveIcon : appearance.viewOnceIcon
            self.viewOnceImageView.image = buttonImage
        }

        func stop() {
            state = .cancel
            recorder?.stopRecording()
        }

        open func stopAndPreview() {
            state = .recorded
        }
    }
}
