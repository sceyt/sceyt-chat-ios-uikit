//
//  MediaPreviewerViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import AVFoundation
import SceytChat
import UIKit

open class MediaPreviewerViewController: ViewController, UIGestureRecognizerDelegate {
    open lazy var router = Components.previewerRouter
        .init(rootViewController: self)
    
    open var viewModel: PreviewerViewModel!
    open var viewOnce: Bool = false
    open var messageText: String?
    private var isMessageTextExpanded: Bool = false
    private var messageTextViewHeightConstraint: NSLayoutConstraint?
    private var messageTextContainerBottomConstraint: NSLayoutConstraint?
    
    var targetView: UIImageView {
        if !scrollView.isHidden {
            return imageView
        } else {
            return playerView
        }
    }
    
    open var imageContentMode: UIView.ContentMode = .scaleAspectFit {
        didSet {
            imageView.contentMode = imageContentMode
            playerView.contentMode = imageContentMode
        }
    }
    
    open lazy var playerView = UIImageView()
        .withoutAutoresizingMask
    
    open lazy var playerControlView = UIStackView(row: currentTimeLabel, slider, durationLabel)
        .withoutAutoresizingMask
    
    open lazy var containerView = UIView()
        .withoutAutoresizingMask
    
    open lazy var playerControlContainerView = UIView()
        .withoutAutoresizingMask
    
    open lazy var playPauseButton = UIButton()
        .withoutAutoresizingMask
    
    open lazy var scrollView = Components.mediaPreviewerScrollView.init(contentMode: imageContentMode)
        .withoutAutoresizingMask
    
    public var imageView: UIImageView { scrollView.imageView }
    
    open lazy var currentTimeLabel = UILabel()
        .contentHuggingPriorityH(.required)
    
    open lazy var durationLabel = UILabel()
        .contentHuggingPriorityH(.required)

    open lazy var slider: UISlider = {
        let slider = PreviewerSlider()
        slider.thumbPadding = appearance.thumbPadding
        return slider
    }()

    open lazy var messageTextView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = false
        textView.textAlignment = .center
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byTruncatingTail
        textView.textContainer.maximumNumberOfLines = 3
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isUserInteractionEnabled = false
        textView.showsVerticalScrollIndicator = true
        textView.showsHorizontalScrollIndicator = false
        return textView
    }()

    open lazy var messageTextContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        return view
    }()
    
    public private(set) var isSliderDragging = false {
        didSet {
            if isSliderDragging, player?.timeControlStatus == .playing {
                player?.pause()
            } else if !isSliderDragging, player?.timeControlStatus == .paused {
                player?.play()
            }
        }
    }

    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var isPreparingToPlay = false

    private var videoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var videoTransform: CGAffineTransform = .identity
    
    public var backgroundView: UIView? {
        return carouselViewController?.backgroundView
    }
    
    open var carouselViewController: MediaPreviewerCarouselViewController? {
        super.parent as? MediaPreviewerCarouselViewController
    }
    
    // MARK: Layout Constraints
    
    private var lastLocation: CGPoint = .zero
    private var isAnimating: Bool = false
    private var isViewDidAppear = false
    private var isConfiguredPlayer = false
    private var isFirstAppear = true
    private var isScreenshotProtectionConfigured = false
    
    private var timeObserver: Any?

    deinit {
        logger.debug("[PreviewerViewController] deinit")

        displayLink?.invalidate()
        displayLink = nil
        videoOutput = nil

        removeObservers()
        player?.pause()
        player?.currentItem?.cancelPendingSeeks()
        player?.currentItem?.asset.cancelLoading()
        try? Components.audioSession.notifyOthersOnDeactivation()
    }
    
    open func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        player?.removeObserver(self, forKeyPath: "timeControlStatus")
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
    }
    
    override open func setup() {
        super.setup()
        playerView.isUserInteractionEnabled = true
        playPauseButton.contentEdgeInsets = .init(top: 16, left: 16, bottom: 16, right: 16)
        playPauseButton.addTarget(self, action: #selector(onTapPlay), for: .touchUpInside)
        
        currentTimeLabel.text = "0:00"
        
        slider.setThumbImage(Images.videoPlayerThumb.imageWithInsets(insets: .init(
            top: appearance.thumbPadding,
            left: appearance.thumbPadding,
            bottom: appearance.thumbPadding,
            right: appearance.thumbPadding)), for: [])
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        
        durationLabel.text = "0:00"
        durationLabel.textAlignment = .right
        
        addGestureRecognizers()
        
        viewModel.$event
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.onEvent(event)
            }.store(in: &subscriptions)

        // Add app lifecycle observers for displayLink
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        view.backgroundColor = .clear
        playerView.backgroundColor = .clear
        playerControlContainerView.backgroundColor = appearance.videoControlsBackgroundColor
        
        navigationController?.navigationBar.apply(appearance: appearance.navigationBarAppearance)
        
        currentTimeLabel.font = appearance.timelineLabelAppearance.font
        currentTimeLabel.textColor = appearance.timelineLabelAppearance.foregroundColor
        
        slider.minimumTrackTintColor = appearance.progressColor
        slider.maximumTrackTintColor = appearance.trackColor
        slider.thumbTintColor = appearance.thumbColor
        
        durationLabel.font = appearance.timelineLabelAppearance.font
        durationLabel.textColor = appearance.timelineLabelAppearance.foregroundColor

        playPauseButton.setImage(appearance.playIcon, for: [])

        messageTextView.font = appearance.timelineLabelAppearance.font
        messageTextView.textColor = .white
        messageTextView.text = messageText
    }
    
    lazy var screenShotProtectedScrollView = ScreenshotProtectController(content: self.containerView)

    override open func setupLayout() {
        super.setupLayout()
        
        let contentView: UIView = viewOnce ? self.containerView : self.view
        
        if viewOnce {
            view.addSubview(screenShotProtectedScrollView.container)
            screenShotProtectedScrollView.container.translatesAutoresizingMaskIntoConstraints = false
            
            screenShotProtectedScrollView.container.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            screenShotProtectedScrollView.container.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
            screenShotProtectedScrollView.container.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
            screenShotProtectedScrollView.container.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            screenShotProtectedScrollView.setupContentAsHiddenInScreenshotMode()
        }
        
        contentView.addSubview(playerView)
        playerView.pin(to: contentView, anchors: [.leading, .trailing, .top, .bottom])
        
        contentView.addSubview(playerControlContainerView)
        playerControlContainerView.pin(to: contentView, anchors: [.leading, .trailing, .bottom])
        
        playerControlContainerView.addSubview(playerControlView)
        playerControlContainerView.addSubview(playPauseButton)
        
        playerControlView.pin(to: playerControlContainerView, anchors: [.leading(16), .trailing(-16), .top(10)])
        playPauseButton.pin(to: playerControlContainerView, anchors: [.centerX])
        playPauseButton.topAnchor.pin(to: playerControlView.bottomAnchor)
        playPauseButton.bottomAnchor.pin(to: playerControlContainerView.safeAreaLayoutGuide.bottomAnchor)
        
        currentTimeLabel.resize(anchors: [.width(44), .height(28)])
        durationLabel.resize(anchors: [.width(44), .height(28)])
        
        contentView.addSubview(scrollView)
        scrollView.pin(to: contentView)

        // Add message text view for view-once messages
        if viewOnce, let text = messageText, !text.isEmpty {
            contentView.addSubview(messageTextContainerView)
            messageTextContainerView.addSubview(messageTextView)

            // Add tap gesture to container for collapsing/expanding
            let containerTapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleMessageTextExpansion))
            messageTextContainerView.addGestureRecognizer(containerTapGesture)

            // Create height constraint with max 70 for collapsed state
            messageTextViewHeightConstraint = messageTextView.heightAnchor.constraint(lessThanOrEqualToConstant: 70)
            messageTextViewHeightConstraint?.isActive = true

            // Create bottom constraint (will be updated based on content type)
            messageTextContainerBottomConstraint = messageTextContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)

            NSLayoutConstraint.activate([
                messageTextContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                messageTextContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                messageTextContainerView.topAnchor.constraint(greaterThanOrEqualTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 8),
                messageTextContainerBottomConstraint!,

                messageTextView.leadingAnchor.constraint(equalTo: messageTextContainerView.leadingAnchor, constant: 0),
                messageTextView.trailingAnchor.constraint(equalTo: messageTextContainerView.trailingAnchor, constant: 0),
                messageTextView.topAnchor.constraint(equalTo: messageTextContainerView.topAnchor, constant: 0),
                messageTextView.bottomAnchor.constraint(equalTo: messageTextContainerView.bottomAnchor, constant: -30)
            ])
        }

    }
    
    override open func setupDone() {
        super.setupDone()
        bindPreviewItem()
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Leave immersive mode when a page appears (shows the nav bar + status bar).
        (carouselViewController?.navigationController as? MediaPreviewerNavigationController)?.isPreviewStatusBarHidden = false
        UIView.animate(withDuration: animated ? 0.3 : 0) { [weak self] in
            guard let self else { return }
            self.carouselViewController?.navigationController?.navigationBar.alpha = 1.0
            self.playerControlContainerView.alpha = 1.0
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        isViewDidAppear = true

        if isConfiguredPlayer {
            DispatchQueue.main.asyncAfter(deadline: .now() + (animated ? 0 : 0.3)) { [weak self] in
                self?.play()
            }
        }
        
        var title = ""
        let previewUser: ChatUser? = try? DataProvider.database.read {
                MessageDTO.fetch(id: self.viewModel.previewItem.attachment.messageId, context: $0)?.convert()
            }.get()?.user
        if let user = previewUser {
            title = appearance.userNameFormatter.format(user)
        }
        carouselViewController?.titleLabel.text = title
        carouselViewController?.subtitleLabel.text = appearance.mediaDateFormatter.format(viewModel.previewItem.attachment.createdAt)

        // Post notification for view_once messages
        if viewOnce {
            let messageId = viewModel.previewItem.attachment.messageId
            NotificationCenter.default.post(
                name: .didOpenViewOnceMessage,
                object: nil,
                userInfo: ["messageId": messageId]
            )
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isViewDidAppear = false
        pause()
    }
    
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        layout()
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // For view-once messages, defer layout to the next run loop cycle.
        // The screenshot-protection view (screenShotProtectedScrollView) updates its
        // internal frame asynchronously after UIKit finishes the layout pass, so calling
        // layout() synchronously here would size content against stale bounds.
        // Dispatching async ensures the protected container has its final frame before
        // we position subviews inside it.
        if viewOnce {
            DispatchQueue.main.async {
                self.layout()
            }
        } else {
            layout()
        }
    }
    
    open func layout() {
        playerLayer?.frame = playerView.bounds
        
        scrollView.updateConstraintsForSize(view.bounds.size)
        scrollView.updateMinMaxZoomScaleForSize(view.bounds.size)
    }
    
    open func onEvent(_ event: PreviewerViewModel.Event) {
        switch event {
        case .photoSaved(nil):
            router.showAlert(message: L10n.Previewer.photoSaved)
        case .videoSaved(nil):
            router.showAlert(message: L10n.Previewer.videoSaved)
        case .didUpdateItem:
            isPreparingToPlay = false
            bindPreviewItem()
        default:
            return
        }
    }
    
    open func play() {
        configureAudioSessionForPlayback()
        player?.seek(to: .zero)
        player?.play()
    }
    
    open func pause() {
        player?.pause()
    }
    
    open func configureAudioSessionForPlayback() {
        do {
            try Components.audioSession.configure(category: .playback)
        } catch {
            logger.errorIfNotNil(error, "Setting category to .playback failed.")
        }
    }
    
    open func bindPreviewItem() {
        switch viewModel.previewItem {
        case let .attachment(attachment):
            if attachment.type == "video",
               let fileUrl = attachment.fileUrl
            {
                if isPreparingToPlay {
                    return
                } else {
                    isPreparingToPlay = true
                }
                scrollView.isHidden = true
                playerView.isHidden = false
                playerControlContainerView.isHidden = false
                updateMessageTextConstraintForVideo()

                let asset = AVAsset(url: fileUrl)
                
                let assetKeys = ["playable", "duration"]
                asset.loadValuesAsynchronously(forKeys: assetKeys) {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.configurePlayer(asset: asset, assetKeys: assetKeys)
                        self.isConfiguredPlayer = true
                        if self.isViewDidAppear {
                            self.play()
                        }
                    }
                }
            } else {
                scrollView.isHidden = false
                playerView.isHidden = true
                playerControlContainerView.isHidden = true
                updateMessageTextConstraintForImage()
                imageView.image = attachment.originalImage
                imageView.setNeedsLayout()
                scrollView.setNeedsLayout()
                imageView.layoutIfNeeded()
            }
        }
    }

    private func updateMessageTextConstraintForVideo() {
        guard viewOnce, messageText != nil, !messageText!.isEmpty,
              let bottomConstraint = messageTextContainerBottomConstraint else { return }

        let contentView: UIView = viewOnce ? self.containerView : self.view

        // Deactivate current constraint
        bottomConstraint.isActive = false

        // Create new constraint to position above player controls
        messageTextContainerBottomConstraint = messageTextContainerView.bottomAnchor.constraint(equalTo: playerControlContainerView.topAnchor)
        messageTextContainerBottomConstraint?.isActive = true
    }

    private func updateMessageTextConstraintForImage() {
        guard viewOnce, messageText != nil, !messageText!.isEmpty,
              let bottomConstraint = messageTextContainerBottomConstraint else { return }

        let contentView: UIView = viewOnce ? self.containerView : self.view

        // Deactivate current constraint
        bottomConstraint.isActive = false

        // Create new constraint to position at bottom of content view
        messageTextContainerBottomConstraint = messageTextContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        messageTextContainerBottomConstraint?.isActive = true
    }

    open func configurePlayer(asset: AVAsset, assetKeys: [String]) {
        let playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: assetKeys)

        if viewOnce {
            // Setup video output for frame extraction (secure rendering)
            let pixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBufferAttributes)
            playerItem.add(videoOutput!)

            // Get video track's preferred transform for correct orientation
            if let videoTrack = asset.tracks(withMediaType: .video).first {
                videoTransform = videoTrack.preferredTransform
            }

            // Don't use AVPlayerLayer for viewOnce - frames will be rendered to playerView.image
            playerLayer?.removeFromSuperlayer()
            playerLayer = nil
        } else {
            // Standard AVPlayerLayer for non-viewOnce videos
            playerLayer?.removeFromSuperlayer()
            playerLayer = AVPlayerLayer(player: player)
            playerLayer?.videoGravity = .resizeAspect
            playerView.contentMode = imageContentMode
            playerView.layer.insertSublayer(playerLayer!, at: 0)
        }

        // Create or update player
        if let player {
            player.replaceCurrentItem(with: playerItem)
        } else {
            player = AVPlayer(playerItem: playerItem)
            timeObserver = player?.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.1, preferredTimescale: Int32(NSEC_PER_SEC)),
                queue: DispatchQueue.main)
            { [weak self] _ in
                guard let self else { return }
                if self.player?.currentItem?.status == .readyToPlay {
                    self.currentTimeLabel.text = appearance.durationFormatter.format(self.player!.currentTime().seconds)
                    if !self.isSliderDragging {
                        self.slider.setValue(
                            Float(self.player!.currentTime().seconds / playerItem.duration.seconds),
                            animated: self.player!.currentTime().seconds > 0)
                    }
                }
            }
            player?.addObserver(
                self,
                forKeyPath: "timeControlStatus",
                options: [.old, .new],
                context: nil)
        }

        // Setup display link for viewOnce frame extraction
        if viewOnce {
            setupDisplayLink()
        }

        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default
            .addObserver(
                self,
                selector: #selector(onPlayToEnd),
                name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                object: playerItem)

        if !viewOnce {
            playerLayer?.player = player
        }
        playerView.image = viewModel.previewItem.attachment.originalImage
        durationLabel.text = appearance.durationFormatter.format(player!.currentItem?.duration.seconds ?? 0)
    }

    private func setupDisplayLink() {
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidRefresh))
        displayLink?.preferredFramesPerSecond = 30 // Limit to 30fps for efficiency
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func displayLinkDidRefresh(_ link: CADisplayLink) {
        guard let output = videoOutput,
              let player = player else { return }

        let currentTime = player.currentTime()

        // Check if new frame is available
        guard output.hasNewPixelBuffer(forItemTime: currentTime) else { return }

        // Extract and render frame
        guard let pixelBuffer = output.copyPixelBuffer(
            forItemTime: currentTime,
            itemTimeForDisplay: nil
        ) else { return }

        // Convert to UIImage and display (inside secure container)
        autoreleasepool {
            var ciImage = CIImage(cvPixelBuffer: pixelBuffer)

            // Apply video track transform for correct orientation
            // Note: We use inverted transform because CIImage coordinate system
            if videoTransform != .identity {
                ciImage = ciImage.transformed(by: videoTransform.inverted())
            }

            if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                DispatchQueue.main.async { [weak self] in
                    self?.playerView.image = UIImage(cgImage: cgImage)
                }
            }
        }
    }

    @objc private func appDidEnterBackground() {
        displayLink?.isPaused = true
    }

    @objc private func appWillEnterForeground() {
        if player?.timeControlStatus == .playing {
            displayLink?.isPaused = false
        }
    }

    // MARK: Add Gesture Recognizers

    open func addGestureRecognizers() {
        let panGesture = UIPanGestureRecognizer(
            target: self, action: #selector(onPan(_:)))
        panGesture.cancelsTouchesInView = false
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
        
        let singleTapGesture = UITapGestureRecognizer(
            target: self, action: #selector(onTap(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.numberOfTouchesRequired = 1
        view.addGestureRecognizer(singleTapGesture)
        
        singleTapGesture.require(toFail: scrollView.doubleTapRecognizer)
    }
    
    @objc
    open func onPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard
            isAnimating == false,
            scrollView.zoomScale == scrollView.minimumZoomScale
        else { return }
        
        player?.pause()
        
        if gestureRecognizer.state == .began {
            lastLocation = targetView.center
        }
        
        if gestureRecognizer.state != .cancelled {
            let translation: CGPoint = gestureRecognizer
                .translation(in: view)
            targetView.center = CGPoint(
                x: lastLocation.x + translation.x,
                y: lastLocation.y + translation.y)
        }
        
        let diffY = view.center.y - targetView.center.y
        backgroundView?.alpha = 1.0 - abs(diffY / view.center.y)
        carouselViewController?.navigationController?.navigationBar.alpha = 1.0 - abs(diffY / view.center.y)
        playerControlContainerView.alpha = 1.0 - abs(diffY / view.center.y)
        if gestureRecognizer.state == .ended {
            if abs(diffY) > 60 {
                dismiss(animated: true)
            } else {
                executeCancelAnimation(targetView)
            }
        }
    }
    
    @objc
    open func onTap(_ recognizer: UITapGestureRecognizer) {
        guard let navigationController = carouselViewController?.navigationController as? MediaPreviewerNavigationController
        else { return }
        // Toggle immersive mode. Setting the flag hides/shows the nav bar (via
        // setNavigationBarHidden) and the status bar; we only animate the player controls.
        let shouldHide = !navigationController.isPreviewStatusBarHidden
        navigationController.isPreviewStatusBarHidden = shouldHide
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.playerControlContainerView.alpha = shouldHide ? 0.0 : 1.0
        }
    }
    
    open func gestureRecognizerShouldBegin(
        _ gestureRecognizer: UIGestureRecognizer) -> Bool
    {
        guard scrollView.zoomScale == scrollView.minimumZoomScale,
              let panGesture = gestureRecognizer as? UIPanGestureRecognizer
        else { return false }

        // If messageTextView is expanded and scrollable, check if touch is inside it
        if isMessageTextExpanded {
            let touchLocation = panGesture.location(in: messageTextView)
            if messageTextView.bounds.contains(touchLocation) {
                // Touch is inside the messageTextView, don't allow pan gesture to begin
                // so messageTextView can handle scrolling
                return false
            }
        }

        let velocity = panGesture.velocity(in: scrollView)
        return abs(velocity.y) > abs(velocity.x)
    }
    
    @objc
    open func onTapPlay() {
        if player?.timeControlStatus != .playing {
            player?.play()
        } else {
            player?.pause()
        }
    }

    @objc
    private func toggleMessageTextExpansion() {
        isMessageTextExpanded.toggle()

        if isMessageTextExpanded {
            // Expand: remove the height constraint and line limit to show full content
            messageTextViewHeightConstraint?.isActive = false
            messageTextView.textContainer.maximumNumberOfLines = 0
            messageTextView.isUserInteractionEnabled = true
            // Keep scrolling disabled so the text view auto-sizes to its content
            // The top constraint will limit maximum height
            messageTextView.isScrollEnabled = false
        } else {
            // Collapse: re-apply the max height constraint and line limit with ellipsis
            messageTextViewHeightConstraint?.isActive = true
            messageTextView.textContainer.maximumNumberOfLines = 3
            messageTextView.isUserInteractionEnabled = false
            messageTextView.isScrollEnabled = false
        }

        // Force the text view to recalculate its size
        messageTextView.invalidateIntrinsicContentSize()
        let textLength = messageTextView.text?.count ?? 0
        if textLength > 0 {
            messageTextView.layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textLength), actualCharacterRange: nil)
            messageTextView.layoutManager.ensureLayout(for: messageTextView.textContainer)
        }

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
            self.view.layoutIfNeeded()
        }, completion: { _ in
            // After expansion animation completes, check if content exceeds available space
            if self.isMessageTextExpanded {
                self.messageTextView.isScrollEnabled = true
            }
        })
    }
    
    override open func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?)
    {
        if keyPath == "timeControlStatus",
           let change = change,
           let newValue = change[NSKeyValueChangeKey.newKey] as? Int,
           let oldValue = change[NSKeyValueChangeKey.oldKey] as? Int
        {
            let oldStatus = AVPlayer.TimeControlStatus(rawValue: oldValue)
            let newStatus = AVPlayer.TimeControlStatus(rawValue: newValue)
            if newStatus != oldStatus {
                if newStatus == .playing {
                    playPauseButton.setImage(appearance.pauseIcon, for: [])
                } else {
                    playPauseButton.setImage(appearance.playIcon, for: [])
                }
            }
        }
    }
    
    @objc
    open func onPlayToEnd(_ notification: Notification) {
        guard notification.object as? AVPlayerItem == player?.currentItem
        else { return }
        DispatchQueue.main.async { [weak self] in
            self?.player?.seek(to: .zero)
            self?.playerControlContainerView.alpha = 1.0
        }
    }
    
    @objc
    open func sliderValueChanged(_ slider: UISlider, for event: UIEvent) {
        let phase = event.allTouches?.first?.phase
        switch phase {
        case .began:
            isSliderDragging = true
        case .ended:
            isSliderDragging = false
        default:
            break
        }
        
        let time = CMTime(seconds: Double(slider.value) * (player?.currentItem?.duration.seconds ?? 0), preferredTimescale: 60000)
        player?.seek(to: time)
    }
    
    @objc
    open func shareButtonAction(_ sender: UIBarButtonItem) {
        let previewItem = viewModel.previewItem
        let topActions = (carouselViewController?.previewDataSource as? PreviewShareActionProviding)?
            .previewShareTopActions(previewItem: previewItem) ?? []
        router
            .showShareActionSheet(
                previewItem: previewItem,
                from: sender,
                topActions: topActions)
        { [unowned self] option in
            switch option {
            case .saveGallery:
                viewModel.save()
            case let .forward(channelIds):
                loader.show()
                viewModel.forward(channelIds: channelIds) { [weak self] in
                    guard let self else { return }
                    router.dismiss()
                    loader.hide()
                }
            case .share:
                router.share([previewItem.attachment.fileUrl ?? previewItem.attachment.originUrl], from: sender)
            case .cancel:
                return
            }
        }
    }
    
    // MARK: Animation Related stuff

    open func executeCancelAnimation(_ container: UIView) {
        isAnimating = true
        UIView.animate(
            withDuration: 0.3,
            animations: { [weak self] in
                guard let self else { return }
                self.targetView.center = self.view.center
                self.backgroundView?.alpha = 1.0
                // onPan fades navigationBar.alpha proportionally with the drag; restore it
                // here so a cancelled drag doesn't leave the bar translucent. (Whether the
                // bar is shown at all is governed by setNavigationBarHidden.)
                self.carouselViewController?.navigationController?.navigationBar.alpha = 1.0
            }) { [weak self] _ in
                self?.isAnimating = false
            }
    }
}

private class PreviewerSlider: UISlider {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        var bounds: CGRect = self.bounds
        bounds = bounds.insetBy(dx: -44, dy: -14)
        return bounds.contains(point)
    }

    var thumbPadding: CGFloat = {
        if #available(iOS 26, *) {
            return 6
        } else {
            return 20
        }
    }()

    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        let startingOffset = 0 - Float(thumbPadding)
        let endingOffset = 2 * Float(thumbPadding)
        let xTranslation = startingOffset + (minimumValue + endingOffset) / maximumValue * value
        return super.thumbRect(forBounds: bounds,
                               trackRect: rect.applying(CGAffineTransform(translationX: CGFloat(xTranslation), y: 0)),
                               value: value)
    }
}

private extension UIImage {
    func imageWithInsets(insets: UIEdgeInsets) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(
            CGSize(width: size.width + insets.left + insets.right,
                   height: size.height + insets.top + insets.bottom), false, scale)
        _ = UIGraphicsGetCurrentContext()
        let origin = CGPoint(x: insets.left, y: insets.top)
        draw(at: origin)
        let imageWithInsets = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return imageWithInsets
    }
}
